
import app;
import vibe.d;
import vibe.utils.validation;
import std.conv;

// Creates session if not currently running
string getSessionId(string user, string host)
{
  MongoCollection sessions = fareborn_db["users"];
  
  auto session = sessions.findOne(["username":user]);
  
  if( session.isNull() )
  {
  	session.username = user;
  	sessions.insert(session);
  }
  
  {
  	Bson userSession = session["hosts"][host];
  	if(!userSession.isNull())
  	{
  	  session["hosts"][host];
  	  	
  	  return cast(string)userSession["id"];
  	}  
  	else
  	{
  	  string session_id = generateSimplePasswordHash(user ~ host);
  	  	
  	  userSession.id = session_id;
  	  
  	  Bson update;
  	  update["$push"] = ["hosts":userSession];
  	  sessions.update(["username":user], update);
  	  
  	  return session_id;
  	}  
  }
}

void registerUser(HTTPServerRequest req, HTTPServerResponse res)
{
  enforceHTTP("email" in req.form, HTTPStatus.badRequest, "Missing email field.");
  enforceHTTP("username" in req.form, HTTPStatus.badRequest, "Missing username field.");
  enforceHTTP("password" in req.form, HTTPStatus.badRequest, "Missing password field.");

  auto email = validateEmail(req.params["email"]);
  auto username = validateUserName(req.params["username"]); // default 3 - 32 length
  auto password = validatePassword(req.params["password"], req.params["password"]); // default 8 -64 length
  
  MongoCollection users = fareborn_db["users"];
  auto user = users.findOne(["email": email]);
  
  enforceHTTP( user.isNull(), HTTPStatus.badRequest,
  	 "User with that email already exists.");
  
  user = users.findOne(["username":username]);
  
  enforceHTTP( user.isNull(), HTTPStatus.badRequest,
  	"User with that name already exists.");
  
  // Okay to go ahead
  
  // fix this sheeo
  string salt = to!string(Clock.currTime().stdTime()) ~ "banana";
  
  password = generateSimplePasswordHash(password, salt);
  
  users.insert( Bson(["email": Bson(email),"username": Bson(username),
  		        "password": Bson(password), "salt": Bson(salt), "validated":Bson(false)]));
  
  Json resp;
  
  resp.success = true;
  resp.session_id = getSessionId(username, "localhost");
  res.writeBody(resp.toString());
}

void loginUser(HTTPServerRequest req, HTTPServerResponse res)
{
  enforceHTTP("username" in req.form, HTTPStatus.badRequest, "Missing username field.");
  enforceHTTP("password" in req.form, HTTPStatus.badRequest, "Missing password field.");

  auto username = validateUserName(req.params["username"]); // default 3 - 32 length
  auto password = validatePassword(req.params["password"], req.params["password"]); // default 8 -64 length
  
  MongoCollection users = fareborn_db["users"];
  auto user = users.findOne(["username": username]);
  
  enforceHTTP( user.isNull(), HTTPStatus.badRequest, "No such user.");
  
  password = generateSimplePasswordHash(password, cast(string)user["salt"]);
  
  enforceHTTP( cast(string)user["password"] == password, HTTPStatus.badRequest,
  	 "No such user.");
  
  Json resp;
  
  resp.success = true;
  resp.session_id = getSessionId(username, "localhost");
  res.writeBody(resp.toString());
}