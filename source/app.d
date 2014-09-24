import std.stdio;
import vibe.d;

import server;

shared static this()
{
  auto settings = new HTTPServerSettings;
  settings.port = 8080;
  settings.bindAddresses = ["::1", "127.0.0.1"];

  Server server = new Server(stdout);

  listenTCP(8080, conn => server.acceptConnection(conn));
}
