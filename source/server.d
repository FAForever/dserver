module server;

import std.stdio;
import std.range;
import std.bitmanip;
import std.conv;
import std.system;
import std.utf;

import vibe.d;
import vibe.data.json;

import faflegacy;

/**
  Main server for FAR-Lobby connections.

  Responsibilites here are:

   - Maintain 1 active TCP connection to clients
   - Parse and dispatch commands from client
 */
class Server {
  this() {
    m_log = stdout;
  }
  this(File loggger) {
    m_log = loggger;
  }
  /**
    Accept a connection from a client, and maintain it until it is closed.

    vibe.d spawns this inside of a fiber, and a pitfall with D fibers is
    that they have a static amount of stack space, so beware of too much recursion.
  */
  void acceptConnection(TCPConnection conn) {
    m_log.writefln("Connection established from: " ~ conn.remoteAddress.toString());
    while(conn.waitForData(60.seconds)) {
      while(conn.dataAvailableForRead) {
        try {
          import std.bitmanip;
          auto buf = new ubyte[conn.leastSize];
          conn.read(buf);
          writeln(buf);
          writeln(cast(string)buf);
          uint nbytes = buf.read!uint();
          m_log.writefln("Total message size: %s", nbytes);

          string actionString = readQString(buf);

          Json input = parseJsonString(actionString);
          m_log.writeln(input);
          m_log.writeln(input["command"].get!string());

          string login = readQString(buf);
          writefln("Login: %s", login);

          Json sessionResponse = Json.emptyObject;
          sessionResponse.command = "welcome";
          sessionResponse.session = "derp";
          writeMessage(conn, sessionResponse);

          Json emailResponse = Json.emptyObject;

          emailResponse.command = "welcome";
          emailResponse.email = "sheeo@sheeo.dk";
          writeMessage(conn, emailResponse);
        }
        catch (JSONException e) {
          m_log.writefln("Error parsing json from client: %s", e);
        }
        //catch {
        //  m_log.writeln("Some other error occured, closing connection.");
        //}
        finally {
        }
      }
    }
    m_log.writeln("Connection closed or timed out");
  }

  void writeMessage(TCPConnection conn, Json j) {
      wstring rStr = toUTF16(j.toString());
      uint len = to!uint(rStr.length)*2;
      uint messageLength = to!uint((rStr.length * 2) + 2*uint.sizeof);
      auto outBuf = new ubyte[messageLength];
      size_t idx = 0;

      outBuf.write!uint(messageLength-4, &idx);

      writeQString(outBuf, rStr, &idx);

      //outBuf.write!uint(len, &idx);
      //foreach(c; rStr) {
      //  outBuf.write!wchar(c, &idx);
      //}

      conn.write(outBuf);
      conn.flush();
  }

  private:
    shared int m_nclients = 0;
    File m_log;
}

unittest {
  import vibe.stream.wrapper : StreamOutputRange;

  Server s = new Server(stdout);
  listenTCP(8080, conn => s.acceptConnection(conn));

  auto conn = connectTCP("localhost", 8080);
  Json j = Json.emptyObject;
  j.command = "ask_session";
  string jsonString = j.toString();
  writefln("Sending string of length %s", jsonString.length);

  auto buf = new MemoryOutputStream;
  ubyte[] testMessage = [0, 0, 0, 74, 0, 0, 0, 52, 0, 123, 0, 34, 0, 99, 0, 111, 0, 109, 0, 109, 0, 97, 0, 110, 0, 100, 0, 34, 0, 58, 0, 32, 0, 34, 0, 97, 0, 115, 0, 107, 0, 95, 0, 115, 0, 101, 0, 115, 0, 115, 0, 105, 0, 111, 0, 110, 0, 34, 0, 125, 0, 0, 0, 10, 0, 83, 0, 104, 0, 101, 0, 101, 0, 111, 255, 255, 255, 255];

  buf.write(testMessage);

  //buf.write(new ubyte[uint.sizeof]);
  //writeJsonString(buf, j);
  //ubyte[] testStr = [0, 123, 0, 34, 0, 99, 0, 111, 0, 109, 0, 109, 0, 97, 0, 110, 0, 100, 0, 34, 0, 58, 0, 32, 0, 34, 0, 97, 0, 115, 0, 107, 0, 95, 0, 115, 0, 101, 0, 115, 0, 115, 0, 105, 0, 111, 0, 110, 0, 34, 0, 125];
  //buf.write(testStr);
  //buf.data[0..uint.sizeof] = nativeToBigEndian(to!uint(buf.data.length));

  conn.write(buf.data);
  conn.flush();
  sleep(400.msecs);

}
