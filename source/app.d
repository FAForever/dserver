import std.stdio;
import vibe.d;

MongoClient client;
MongoDatabase fareborn_db;


import auth_service;
import server;

shared static this()
{
  client = connectMongoDB("127.0.0.1");
  fareborn_db = client.getDatabase("fareborn");
	
  // HTTP Services
  {
  	auto settings = new HTTPServerSettings;
  	settings.port = 8081;
  	settings.bindAddresses = ["::1", "127.0.0.1"];
  	
  	auto router = new URLRouter;
  	
  	listenHTTP( settings, router);
  }	
  // HTTPS Services
  {
  	auto settings = new HTTPServerSettings;
  	settings.port = 44343;
  	
  	auto ssl_ctx = createSSLContext(SSLContextKind.server);
  	ssl_ctx.peerValidationMode = SSLPeerValidationMode.none;
  	
  	settings.sslContext = ssl_ctx;
  	settings.bindAddresses = ["::1", "127.0.0.1"];	
  	
  	auto router = new URLRouter;
  	router.post("/do/register", &registerUser);
  	router.post("/do/login", &loginUser);
  
  	listenHTTP( settings, router);
  }
  
  Server server = new Server(stdout);

  listenTCP(8080, conn => server.acceptConnection(conn));
}
