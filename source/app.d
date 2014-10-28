import std.stdio;
import vibe.d;

MongoClient client;
MongoDatabase fareborn_db;

GamesService gamesService;
NotifyService notifyService;

import auth_service;

import games;
import notify;

import FAFConnection;

import UDPTestServer;

void handleError(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error)
{
	Json resp;

	resp.success = false;

	resp.reason = error.message;
	res.writeBody( resp.toString() );
}
shared static this()
{
  client = connectMongoDB("127.0.0.1");
  fareborn_db = client.getDatabase("fareborn");
	
  gamesService = new GamesService;
  notifyService = new NotifyService;
  
  // HTTP Services
  {
  	auto settings = new HTTPServerSettings;
  	settings.port = 8080;
  	
  	auto router = new URLRouter;
  	
  	router.registerRestInterface(gamesService, "/games");
  	router.get( "/notify/ws", FAFConnection.FAFConnection.http_handler() );
  	
    writeln(router.getAllRoutes());
  	listenHTTP( settings, router);
  }	
  // HTTPS Services
  {
  	auto settings = new HTTPServerSettings;
  	settings.port = 44343;
  	
  	auto ssl_ctx = createSSLContext(SSLContextKind.server);
  	ssl_ctx.peerValidationMode = SSLPeerValidationMode.none;
  	
  	//settings.sslContext = ssl_ctx;
  	//settings.errorPageHandler = toDelegate(&handleError);
  	
  	auto router = new URLRouter;
  	router.registerRestInterface(new AuthService, "/auth");
  	
  	writeln(router.getAllRoutes());
  	
  	listenHTTP( settings, router);
  }
  
//  gamesService.startLegacyBridge();
  
  UDPTestServer testServer = new UDPTestServer;
  testServer.start();
  
  stdout.flush();
//  Server server = new Server(stdout);
//
//  listenTCP(8080, conn => server.acceptConnection(conn));
}
