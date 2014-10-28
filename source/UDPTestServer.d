
import app;
import vibe.d;

import std.stdio;
import std.conv;

class UDPTestServer
{
  void start()
  {
    runTask({
        ushort port = 8002;
        logInfo("Starting UDPTestServer on %d.", port);
        
        UDPConnection socket = listenUDP(port);
        while (true) {
          NetworkAddress peer_addr;
          
          ubyte[] msg = socket.recv( null, &peer_addr);
          
          socket.send( msg, &peer_addr);
        }
    });
  }
}