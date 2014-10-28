
import app;
import vibe.d;

import std.stdio;
import std.conv;

import std.container;
import std.algorithm;

import FAFConnection;

class NotifyService
{
  TaskMutex dispatcher_mutex;
  
  Array!(FAFConnection) dispatchers;
  
  void addDispatcher(FAFConnection dispatcher)
  {
    synchronized (dispatcher_mutex) {
      dispatchers ~= dispatcher;
    }
  }
  void delDispatcher(FAFConnection dispatcher)
  {
    synchronized (dispatcher_mutex) {
      dispatchers.linearRemove( dispatchers[].find(dispatcher) );
    }
  }
  
  this()
  {
    dispatcher_mutex = new TaskMutex;
  }
  
  void broadcast(string subsystem, string command_id, Json data)
  {
    Json msg = Json.emptyObject;
    
    msg.subsystem = subsystem;
    msg.id = command_id;
    msg.data = data;
    
    logInfo("Broadcasting: %s : %s", subsystem, command_id);
    
    synchronized (dispatcher_mutex) {
      foreach(conn; dispatchers)
        conn.sendEvent(subsystem, command_id, data);
    }
  }
}