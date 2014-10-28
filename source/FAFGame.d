
module FAFGame;

import app;
import vibe.d;

import std.stdio;
import std.conv;

import std.container;
import std.algorithm;
import std.datetime;

import auth_service;

import FAFConnection;

/*
  This implements Open/Running FAF Games.
*/
public class FAFGame
{
  private {
    int m_game_id;
    FAFConnection m_host;
    ushort m_port;
  }
  
  @property 
  int id() { return m_game_id; }
  
  @property
  FAFConnection host() { return m_host; }
  
  @property
  ushort port() { return m_port; }
  
  static {
    private FAFGame[int] games;
    
    FAFGame game(int game_id) {
      return game_id in games ? games[game_id] : null;
    }
  }
  
  // Create game
  this(FAFConnection host, ushort port, string title)
  {
    m_host = host;
    m_port = port;
    
    // Reserve id
    Bson meta = fareborn_db["meta"].findAndModify(["_id":"games"], ["$inc":Bson(["next_id": Bson(1)])]);
    
    m_game_id = meta.next_id.get!int;
    
    // Insert into db
    Bson game = Bson.emptyObject;
    
    game.Title = title;
    game.GameState = "Pre-Lobby";
    game.PlayerOption = Bson.emptyObject;
    game.GameOption = Bson.emptyObject;
    game.GameMods = Bson.emptyArray;
    
    game["host"] = ["username": Bson(host.m_user.username),
                          "ip": Bson(host.m_user.peer_ip),
                        "port": Bson(port)];
                        
    game._id = BsonObjectID.generate;
    
    game.id = m_game_id;
    
    fareborn_db["games"].insert(game);
    
    games[m_game_id] = this;
    
    notifyService.broadcast("games", "opened", game.toJson);
  }
  
  SysTime m_last_update;
  
  Task m_update_push_task;
  
  void onUpdate()
  {
    m_last_update = Clock.currTime;
    
    if(!m_update_push_task || !m_update_push_task.running)
    {
      m_update_push_task = runTask({
          while(Clock.currTime - m_last_update < 1.seconds)
            sleep(500.msecs);
          
          Json game_info = fareborn_db["games"]
                            .findOne(["id":m_game_id], ["_id":Bson(0)])
                            .toJson();
          notifyService.broadcast("games", "updated", game_info);
        });
    }
  }
  
  void onMessage(string command_id, Json args)
  {
    Bson update = Bson.emptyObject;
    
    switch(command_id) {
      case "GameState": {
        string newState = args[0].get!string;
        
        if(newState == "Launching")
          newState = "Live";
        
        update["$set"] = ["GameState": Bson(newState)];
      } break;
      case "PlayerOption": {
        int slot = args[0].get!int;
        string option = args[1].get!string;
        Json value = args.length > 2 ? args[2] : Json();
        
        // Slot switch
        if(option == "StartSpot")
        {
          int newSlot = value.get!int;
          
          if(slot != value.get!int)
          {
            Bson slot_update = Bson.emptyObject;
            slot_update["$rename"] = ["PlayerOption." ~ text(slot):
                                   Bson("PlayerOption." ~ text(newSlot))];
                                   
            fareborn_db["games"].update(["_id":m_game_id], slot_update);
            
            slot = newSlot;
          }
          
          update["$set"] = ["PlayerOption." ~ text(slot) ~ ".StartSpot":
                            Bson(slot)];
        }
        // Slot closed
        else if(option == "Closed")
        {
          string op = value.get!int == 1 ? "$set" : "$unset";
         
          update[op] = ["PlayerOption." ~ text(slot): Bson("Closed")];
        }
        // Slot clear
        else if(option == "Clear")
        {
          update["$unset"] = ["PlayerOption." ~ text(slot): Bson()];
        }
        else
        {
          update["$set"] = ["PlayerOption." ~ text(slot) ~ "." ~ option:
                            Bson(args[2])];
        }
      } break;
      case "GameOption": {
        update["$set"] = ["GameOption." ~ args[0].get!string: Bson(args[1])];
      } break;
      case "GameMods": {
        update["$set"] = ["GameMods": Bson(args)];
      } break;
    }
    
        
    fareborn_db["games"].update(["id":m_game_id], update);
    onUpdate();
  }
  // Game ended.
  void finish(bool forced = false)
  {
    if(m_update_push_task)
    {
      m_update_push_task.terminate();
      m_update_push_task.join();
    }
      
    Json game_info = fareborn_db["games"]
                      .findOne(["id":m_game_id], ["_id":Bson(0)])
                      .toJson();
                      
    notifyService.broadcast("games", "closed", game_info);
    
    games.remove(m_game_id);
      
    fareborn_db["games"].remove(["id":m_game_id]);
  }
}