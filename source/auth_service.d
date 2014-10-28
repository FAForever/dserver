
import app;
import vibe.d;
import vibe.utils.validation;
import std.conv;

import std.stdio;

import scrypt.password;

// Creates session if not currently running
string getSessionId(string user, int user_id, string host)
{
  MongoCollection sessions = fareborn_db["sessions"];
  
  // Look for session
  { 
    Bson session = sessions.findOne(["username":user, "ip":host]);
  
  	if(!session.isNull())
  	  return session["id"].get!string;
	} 
  
  // Insert session
  string session_id = generateSimplePasswordHash(user ~ host ~ to!string(Clock.currTime().stdTime()));
  
  Bson session = Bson.emptyObject;
  
  session.username = user;
  session.user_id = user_id;
  session.id = session_id;
  session.ip = host;
  
  sessions.insert(session);
  
  return session_id;
}

Bson getSession(string ip, string session_id)
{
  Bson session = ["id": Bson(session_id), "ip": Bson(ip)];
  
  Bson ret = fareborn_db["sessions"].findOne( session );

  return ret;
}

string getClientIP(HTTPServerRequest req, HTTPServerResponse res)
{
	return req.peer;
}

// Tiny hack
HTTPServerResponse getResponse(HTTPServerRequest req, HTTPServerResponse res)
{
  return res;
}

struct UserInfo
{
  string peer_ip;
  string session_id;
  string username;
  int id;
  
  bool isValid() @property
  {
    return session_id.length > 0;
  }
}

UserInfo enforceAuthorized(HTTPServerRequest req, HTTPServerResponse res)
{
  UserInfo ret;
  
  ret.peer_ip = req.peer;
  
  string session_id = req.cookies.get("session_id");
  
  enforceHTTP( session_id != null, HTTPStatus.badRequest, "You must be logged in.");
  
  Bson session = getSession( req.peer, session_id);
  
  enforceHTTP( !session.isNull(), HTTPStatus.badRequest, "You must be logged in.");
  
  ret.session_id = session_id;
  ret.username = session.username.get!string;
  ret.id = session.user_id.get!int;
  
  return ret;
}

interface AuthServiceAPI
{
	@path("/register")
	@before!getClientIP("ip")
	Json postRegisterUser(string email, string username, string password, string ip);
	
	@path("/login") 
	@before!getClientIP("ip")
	@before!getResponse("res")
	Json postLoginUser(string username, string password,
	                   string ip, HTTPServerResponse res);
	
	@path("/resend_activation")
  @before!enforceAuthorized("user")
	Json getResendActivation(UserInfo user);
	
	string getActivate(string k);
}

class AuthService : AuthServiceAPI
{ 
	override {
  	Json postRegisterUser(string email, string username, string password, string ip)
  	{
  	  email = validateEmail(email);
  	  username = validateUserName(username); // default 3 - 32 length
  	  password = validatePassword(password, password); // default 8 -64 length
  	  
  	  MongoCollection users = fareborn_db["users"];
  	  auto user = users.findOne(["email": email]);
  	  
  	  logInfo("%s %s %s %s", email, username, password, user);
  	  enforceHTTP( user.isNull(), HTTPStatus.badRequest,
  	  	 "User with that email already exists.");
  	  
  	  user = users.findOne(["username":username]);
  	  
  	  enforceHTTP( user.isNull(), HTTPStatus.badRequest,
  	  	"User with that name already exists.");
  	  
  	  // Okay to go ahead
  	  
      Bson meta = fareborn_db["meta"].findAndModify(["_id":"users"], ["$inc":Bson(["next_id": Bson(1)])]);
      
      int user_id = meta.next_id.get!int;
  	  
  	  // fix this sheeo
  	  string salt = generateSimplePasswordHash(
  	  	to!string(Clock.currTime().stdTime()) ~ "banana");
  	  
  	  password = generateSimplePasswordHash(password, salt);
  	  
  	  users.insert( Bson(["id": Bson(user_id),
  	                      "email": Bson(email),"username": Bson(username),
  	                      "password": Bson(password), "salt": Bson(salt),
  	                      "validated":Bson(false)]));
  	  
  	  sendActivationLink(user_id);
  	  
  	  Json resp = Json.emptyObject;
  	  
  	  resp.success = true;
  	  
  	  resp.user_id = user_id;
  	  resp.email = email;
  	  resp.session_id = getSessionId(username, user_id, ip);
  	  
  	  return resp;
  	}
  	
  	Json postLoginUser(string username, string password, string ip, HTTPServerResponse res)
  	{
  	  username = validateUserName(username); // default 3 - 32 length
  	  password = validatePassword(password, password); // default 8 -64 length
  	  
  	  MongoCollection users = fareborn_db["users"];
  	  Bson user = users.findOne(["username": username]);
  	  
  	  enforceHTTP( !user.isNull(), HTTPStatus.badRequest, "No such user or bad password.");
  	  
  	  bool pass_auth = testSimplePasswordHash(cast(string)user["password"], 
  	  									password, cast(string)user["salt"]);
  	  
  	  enforceHTTP( pass_auth, HTTPStatus.badRequest, "No such user or bad password.");
  	  
  	  int user_id = user.id.get!int;
  	  
  	  Json resp = Json.emptyObject;
  	  
  	  string session_id = getSessionId(username, user_id, ip);
  	  
  	  resp.success = true;
  	  
      resp.user_id = user_id;
      resp.email = user.email.get!string;
  	  resp.session_id = session_id;
  	  
  	  res.setCookie("session_id", session_id);
  	  return resp;
  	}
  	
    Json getResendActivation(UserInfo user)
    {
      MongoCollection users = fareborn_db["users"];
      Bson user_db = users.findOne(["id": Bson(user.id), "validated": Bson(true)],
                                ["_id":1]);
      
      enforceHTTP(user_db.isNull, HTTPStatus.badRequest, "User already validated.");
      
      sendActivationLink(user.id);
      
      return Json(["success": Json(true)]);
    }
    
    string getActivate(string validation_key)
    {
      MongoCollection users = fareborn_db["users"];
      Bson user = users.findOne(["validation_key": validation_key],
                                ["_id":1]);
      
      enforceHTTP(!user.isNull, HTTPStatus.badRequest, "No such validation key exists.");
      
      users.update(["_id":user._id], ["$unset": Bson(["validation_key":Bson(0)]),
                                      "$set": Bson(["validated":Bson(true)])]);
      
      return "Success.";
    }
	}
	
	// NON-API Functions
	void sendActivationLink(int user_id)
	{
    MongoCollection users = fareborn_db["users"];
    
    Bson user_key = ["id": Bson(user_id)];
    Bson user = users.findOne(user_key);
    
    if(user.validated.get!bool)
      return;
    
    string validation_key = generateSimplePasswordHash(
        to!string(Clock.currTime().stdTime()) ~ "banana");
    
    users.update(user_key, ["$set": Bson(["validation_key": Bson(validation_key)]) ]);
    
//    auto settings = new SMTPClientSettings("localhost", 25);
//    settings.connectionType = SMTPConnectionType.startTLS;
//    settings.authType = SMTPAuthType.plain;
//    settings.username = "faf-server";
//    settings.password = "";
  
    auto settings = new SMTPClientSettings();
    
    auto mail = new Mail;
    mail.headers["From"] = "<no-reply@faforever.tk>";
    mail.headers["To"] = "<"~ user.email.get!string ~">";
    mail.headers["Subject"] = "Validate your account FAForever";
    mail.bodyText = "Hi "~ user.username.get!string ~",\n\n"
                    "Here is your validation link: "
                    "http://faforever.tk:44343/auth/activate?k="
                     ~ validation_key ~ "\n\n"
                     "Cheers,\nbotbot";
    
    logInfo("Sending validation link to %s", user.username.get!string);
    sendMail(settings, mail);
	}
}