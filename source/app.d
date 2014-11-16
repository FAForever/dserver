import vibe.d;

MongoClient client;
MongoDatabase fareborn_db;

import sql;

GamesService gamesService;
NotifyService notifyService;
UserService userService;

import auth_service;

import games;
import notify;

import users;
import VersionService;

VersionService versionService;

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
  Json config = readFileUTF8("faf-server.conf").parseJsonString;
  
  mysql_db = new MysqlDB(config.db.host.get!string,
                         config.db.user.get!string,
                         config.db.pass.get!string,
                         config.db.db.get!string,
                         config.db.port.to!ushort);
  
//  client = connectMongoDB("127.0.0.1");
//  fareborn_db = client.getDatabase("fareborn");
	
//  gamesService = new GamesService;
//  notifyService = new NotifyService;
//  userService = new UserService;
  versionService = new VersionService;
  // HTTP Services
  {
  	auto settings = new HTTPServerSettings;
  	settings.port = config.port.to!ushort;
  	
  	auto router = new URLRouter;
  	
//  	router.registerRestInterface(gamesService, "/games");
//  	router.get( "/notify/ws", FAFConnection.FAFConnection.http_handler() );
//  	router.registerRestInterface(userService, "/user");
    router.registerRestInterface(versionService, "/version");

    logInfo("%s", router.getAllRoutes);
  	listenHTTP( settings, router);
  }	
  // HTTPS Services
//  {
//  	auto settings = new HTTPServerSettings;
//  	settings.port = 44343;
//  	
//  	auto ssl_ctx = createSSLContext(SSLContextKind.server);
//  	ssl_ctx.peerValidationMode = SSLPeerValidationMode.none;
//  	
//  	//settings.sslContext = ssl_ctx;
//  	//settings.errorPageHandler = toDelegate(&handleError);
//  	
//  	auto router = new URLRouter;
//  	router.registerRestInterface(new AuthService, "/auth");
//  	
//    logInfo("%s", router.getAllRoutes);
//  	listenHTTP( settings, router);
//  }
//  
//  gamesService.startLegacyBridge();
//  
//  UDPTestServer testServer = new UDPTestServer;
//  testServer.start();
  
//  Server server = new Server(stdout);
//
//  listenTCP(8080, conn => server.acceptConnection(conn));
}
