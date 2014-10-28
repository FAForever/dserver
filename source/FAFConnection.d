
import app;
import vibe.d;

import std.stdio;
import std.conv;

import std.container;
import std.algorithm;
import std.datetime;

import auth_service;
import FAFGame : FAFGame;

/*
	This implements FAF Connection which will handle the transport of 
	all connection-oriented action/event messages for the lobby or other 
	services that use this interface.
*/
class FAFConnection
{
  this(WebSocket sock)
  {
    m_sock = sock;
    
    m_user.peer_ip = sock.request().peer;
    
    subscribed = new RedBlackTree!string;
  }
  
  RedBlackTree!string subscribed;
  Task m_dispatcher;
  Task m_receiver;
  
  WebSocket m_sock; 
  
  UserInfo m_user;
  
  // Game Hosting
  FAFGame m_game;
  
  // event_subsystem represents sender and is used to filter events
  void sendEvent(string event_subsystem, string event_id, Json data)
  {
    if( ! subscribed.equalRange( event_subsystem ).empty )
    {
      Json msg = Json.emptyObject;
      
      msg.subsystem = "events";
      
      // list of [Namespace,][ClassName,]<event_id>
      msg["event_id"] = Json([Json(event_subsystem), 
                              Json(event_id)]); 
      msg.data = data;
      
      send(m_dispatcher, msg.toString());
    }
  }
  
  void sendMsg(string subsystem, string command_id, Json data)
  {
    assert(subsystem != "events" && "sendEvent should be used for events.");
    
    Json msg = Json.emptyObject;
    
    msg.subsystem = subsystem;
    msg.id = command_id;
    msg.data = data;
    
    send(m_dispatcher, msg.toString());
  }
  
  // Subsystem message received
  void onAuthMessage(string command_id, Json args)
  {
    switch(command_id)
    {
      case "login": {
        string session_id = args.get!string();
        Bson session = getSession( m_sock.request.peer,
                                   session_id);
        
        if(!session.isNull())
        {
          //m_user.peer_ip = m_sock.request().peer; // in constructor
          m_user.session_id = session_id;
          m_user.username = session.username.get!string;
          m_user.id = session.user_id.get!int;
          
          logInfo("FAFConnection \"%s\" is %s", m_sock.request().peer,
                                                m_user.username);
          sendMsg("auth","login_resp", Json(["success":Json("true")]));
        }
        else
        {
          sendMsg("auth","login_resp", Json(["success":Json("false")]));
        }  
      } break;
    }
  }
  
  void onNotifyMessage(string command_id, Json args)
  {
    switch(command_id)
    {
      case "subscribe":
        subscribed.insert( args.get!string );
        break;
    }
  }
  
  void onGamesMessage(string command_id, Json args)
  {
    switch(command_id)
    {
      case "open": {
        if(!m_user.isValid)
        {
          Json resp = Json.emptyObject;
          
          resp.success = false;
          resp.reason = "You have to be logged in.";
          
          sendMsg("games", "open_resp", resp);
          return;
        }
        ushort port = args.port.get!ushort;
        string title = args.title.get!string;
        
        m_game = new FAFGame(this, port, title);
        
        sendMsg("games", "open_resp", Json(["success":Json(true)]));
      } break;
      case "close": {
        if(m_game !is null)
        {
          m_game.finish();
          m_game = null;
        }
      } break;
      case "join": {
        int id = args[0].get!int;
        
        // peer game port
        int game_port = args[1].get!int;
        
        if(m_game !is null)
        {
          FAFGame game = FAFGame.game(id);
          if(game !is null)
          {
            FAFConnection host = game.host;
            
            Json msg = Json.emptyArray;
            
            msg ~= m_user.peer_ip ~ ":" ~ to!string(game_port);
            msg ~= m_user.username;
            msg ~= m_user.id;
            
            host.sendMsg("games", "ConnectToPeer", msg);
            
            msg = Json.emptyArray;
            
            msg ~= host.m_user.peer_ip ~ ":" ~ to!string(game.port);
            msg ~= host.m_user.username;
            msg ~= host.m_user.id;
            
            sendMsg("games", "JoinGame", msg);
          }
          else
          {
            sendMsg("games", "error", Json(["reason": Json("Cannot join to non-running game.")]));
          }
        }
      } break;
      case "GameState":
      case "PlayerOption":
      case "GameOption":
      case "GameMods":
        if(m_game !is null && m_game.host is this)
        {
          m_game.onMessage(command_id, args);
        }
        break;
      default:
        logInfo("GAMES command: %s : %s", command_id, 
                                          args.toString());
    }
  }
  
  void onDisconnected()
  {
    // If was hosting, destroy game
    if(m_game !is null)
    {
      m_game.finish(true);
      m_game = null;
    }
  }
  
  // Blocking run
  void run()
  {
    logInfo("FAFConnection to %s opened.", m_sock.request().peer);
    
    m_receiver = runTask({
        while(true)
        {
          string command_;
          try {
            command_ = m_sock.receiveText();
            
            Json command = command_.parseJson();
            
            //logInfo("Recv: %s : %s", command.id.get!string, command.data.toString());
            
            switch(command.subsystem.get!string)
            {
              case "auth":
                onAuthMessage(command.id.get!string, command.data);
                break;
              case "notify":
                onNotifyMessage(command.id.get!string, command.data);
                break;
              case "games":
                onGamesMessage(command.id.get!string, command.data);
                break;
            }
          }
          catch(WebSocketException e)
          {
            // Tell dispatcher to exit
            m_dispatcher.send(0);
            logInfo("FAFConnection to \"%s\"(%s) closed.", m_user.username,
                                                           m_sock.request().peer);
            onDisconnected();
            return;
          }
          catch(Exception e)
          {
            logWarn("%s while processing: %s", e, command_);
          }
        }
      });
    
    m_dispatcher = Task.getThis;
    notifyService.addDispatcher( this );
    
    bool dispatcher_running = true;
    while (dispatcher_running) {
      receive( (string msg) {
                    m_sock.send(msg);
                },
                (int exit) {
                    dispatcher_running = false;
                } );
    }
    
    notifyService.delDispatcher( this );
  }
  
  static void handleConnection(scope WebSocket sock)
  {
    
    FAFConnection conn = new FAFConnection(sock);
    
    conn.run();
  }
  
  // Returns a handler to be used in URLRouter
  static void delegate(HTTPServerRequest, HTTPServerResponse) http_handler()
  {
    return handleWebSockets( &FAFConnection.handleConnection );
  }
};
