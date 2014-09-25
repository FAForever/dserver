
import app;
import vibe.d;
import vibe.utils.validation;
import std.conv;

import std.stdio;
// Creates session if not currently running
string getSessionId(string user, string host)
{
  MongoCollection sessions = fareborn_db["sessions"];
  
  Bson session = sessions.findOne(["username":user]);
  
  if( session.isNull() )
  {
  	session = Bson.emptyObject();
  	session.username = user;
  	sessions.insert(session);
  }
  
  {
  	if(!session["hosts"].isNull() && !session["hosts"][host].isNull())
  	{
  	  Bson userSession = session["hosts"][host];
  	  	
  	  return cast(string)userSession["id"];
  	}  
  	else
  	{
  	  string session_id = generateSimplePasswordHash(user ~ host ~ to!string(Clock.currTime().stdTime()));
  	  	
  	  Bson userSession = Bson.emptyObject();
  	  userSession.id = session_id;
  	  
  	  Bson hosts_update = Bson.EmptyObject();
  	  hosts_update.hosts = Bson([host: userSession]);
  	  
  	  Bson update = Bson.emptyObject();
  	  update["$set"] = hosts_update;
  	  
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

  auto email = validateEmail(req.form["email"]);
  auto username = validateUserName(req.form["username"]); // default 3 - 32 length
  auto password = validatePassword(req.form["password"], req.form["password"]); // default 8 -64 length
  
  MongoCollection users = fareborn_db["users"];
  auto user = users.findOne(["email": email]);
  
  enforceHTTP( user.isNull(), HTTPStatus.badRequest,
  	 "User with that email already exists.");
  
  user = users.findOne(["username":username]);
  
  enforceHTTP( user.isNull(), HTTPStatus.badRequest,
  	"User with that name already exists.");
  
  // Okay to go ahead
  
  // fix this sheeo
  string salt = generateSimplePasswordHash(
  	to!string(Clock.currTime().stdTime()) ~ "banana");
  
  password = generateSimplePasswordHash(password, salt);
  
  users.insert( Bson(["email": Bson(email),"username": Bson(username),
  		        "password": Bson(password), "salt": Bson(salt), "validated":Bson(false)]));
  
  Json resp = Json.emptyObject;
  
  resp.success = true;
  resp.session_id = getSessionId(username, "localhost");
  res.writeBody(resp.toString());
}

void loginUser(HTTPServerRequest req, HTTPServerResponse res)
{
  enforceHTTP("username" in req.form, HTTPStatus.badRequest, "Missing username field.");
  enforceHTTP("password" in req.form, HTTPStatus.badRequest, "Missing password field.");

  auto username = validateUserName(req.form["username"]); // default 3 - 32 length
  auto password = validatePassword(req.form["password"], req.form["password"]); // default 8 -64 length
  
  MongoCollection users = fareborn_db["users"];
  Bson user = users.findOne(["username": username]);
  
  enforceHTTP( !user.isNull(), HTTPStatus.badRequest, "No such user or bad password.");
  
  writeln(user.to!string());
  stdout.flush();
  
  writeln(password);
  bool pass_auth = testSimplePasswordHash(cast(string)user["password"], 
  									password, cast(string)user["salt"]);
  
  enforceHTTP( pass_auth, HTTPStatus.badRequest, "No such user or bad password.");
  
  Json resp = Json.emptyObject;
  
  resp.success = true;
  resp.session_id = getSessionId(username, "localhost");
  res.writeBody(resp.toString());
}