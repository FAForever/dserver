
import vibe.d;

import std.stdio;
import std.conv;

import std.container;

import auth_service;
import app;

// UNDOCUMENTED CAVEAT:
// URL Parameters must have '_' in the rest interface 
// function parameter name. 

interface GamesServiceAPI
{
  @path("/current")
  Json getCurrentGames();
  
  @path("/:game_id")
  Json getGameInfo(int _game_id);
  
  @path("/:game_id/livereplay")
  Json getLiveReplay(int _game_id);
  
//  @path("/open")
//  @before!enforceAuthorized("user")
//  Json postOpenGame(ushort port, Json game_params, UserInfo user);
}

class GamesService : GamesServiceAPI
{
  private {
    // stored in the session store
    SessionVar!(bool, "authenticated") m_authenticated;
    SessionVar!(string, "username") m_username;
  }
  
  override {
    Json getCurrentGames()
    {
      Json res = Json.emptyObject;
      
      MongoCollection games_co = fareborn_db["games"];
      
      Json games = Json.emptyArray;
      
      foreach( doc; games_co.find(Bson.emptyObject, ["_id":0]) )
      {
        Json game = doc.toJson();
        
        games ~= game;
      }
      
      res.games = games;
      
      return res;
    }
    
    Json getGameInfo(int game_id)
    {
      Json res = Json.emptyObject;
      
      Bson game = fareborn_db["games"].findOne(["id":game_id], ["_id":Bson(0)]);
      
      return game.toJson();
    }
    
    Json getLiveReplay(int game_id)
    {
      return Json.emptyObject;
    }
    
//    Json postOpenGame(ushort port, Json game_params, UserInfo user)
//    { 
//      Bson game = Bson.fromJson(game_params);
//      
//      //game["options"] = ;
//      
//      game["host"] = ["username": Bson(user.username),
//                            "ip": Bson(user.peer_ip),
//                          "port": Bson(port)];
//                          
//      game._id = BsonObjectID.generate;
//      
//      fareborn_db["games"].insert(game);
//      
//      Json j_game = game.toJson;
//      
//      notifyService.broadcast("games", "open", j_game);
//      
//      return j_game;
//    }
  }
  
  // NON-API
    
  void startLegacyBridge()
  {
    runTask({
        logInfo("Starting legacy bridge.");
        
        TCPConnection socket = connectTCP("faforever.com", 8001);
        
        import faflegacy;
        import std.bitmanip;
        import std.utf;
        
        socket.keepAlive = true;
        
        wstring msg = toUTF16("{command:'ask_session'}");
        
        auto outBuf = new ubyte[msg.length*2 + 4];
        size_t idx = 0;
        
        writeQString( outBuf, msg, &idx);
        
        socket.write(outBuf);
        
        auto outBuf2 = new ubyte[4];
        outBuf2.write!uint(0, 0);
        
        socket.write(outBuf2);
        socket.write(outBuf2);
        
        while(socket.dataAvailableForRead)
        {
          while(socket.leastSize < 4)
            socket.waitForData(1.msecs);
            
          const(ubyte)[] bufp = socket.peek();
          int size = bufp.read!uint();
          
          while(socket.leastSize < size+4)
            socket.waitForData(1.msecs);
            
          ubyte[] buf = new ubyte[size+4];
          socket.read(buf);
          
          string rmsg = readQString(buf);
          
          logInfo(rmsg);
        }
        logInfo("Legacy bridge closed.");
      });
  }
}