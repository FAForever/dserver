module faflegacy;

import std.bitmanip;
import std.range;
import std.conv;

// Utilities for reading QData

void writeQString(R)(ref R range, wstring str) {
  size_t idx = 0;
  writeQString(str);
}
void writeQString(R)(ref R range, wstring str, size_t* idx) {
  range.write!uint(to!uint(str.length), idx);
  foreach(c; str) {
    range.write!wchar(c, idx);
  }
}
string readQString(ref ubyte[] buf) {
  uint l = buf.read!uint();
  auto app = appender!string();
  for(int i = 0; i<l/2; i++) {
    app.put(buf.read!wchar());
  }
  return app.data;
}
