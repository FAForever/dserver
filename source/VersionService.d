import app;
import vibe.d;
import sql;

import std.datetime;
import std.conv;

struct RepoVersion
{
  uint id;
  string type;
  string name;

  string repo;
  string _ref;
  string url;
  string hash;

  DateTime time_added;
}

struct DefaultVersion
{
  uint id;
  string mod;
  string name;
  uint ver_engine;
  uint ver_main_mod;
  DateTime time_added;
}

interface VersionServiceAPI
{
  @path("/repo/:id")
  Json getRepoVersion(uint _id);

  @path("/default/:mod")
  Json getDefault(string _mod);
}
class VersionService : VersionServiceAPI
{
  override {
    Json getRepoVersion(uint id)
    {
      scope con = mysql_db.lockConnection;

      auto sql = con.prepSQL(
        "select `id`,`type`,`name`,`repo`,`ref`,`url`,`hash`,`time_added` "
        "from versions_repo "
        "where `id`=? limit 1");
      sql.param(0) = id;

      RepoVersion ver;
      bool ok = sql.execToStruct(ver);

      enforceHTTP(ok, HTTPStatus.NotFound,
                  "No repo version with id ("~text(id)~") found.");

      if(ver.url.empty)
        switch(ver.type)
        {
          case "engine":
            ver.url = "http://git."~_FAFServerSettings.hostname~"/"~ver.repo~".git";
            break;
          case "main_mod":
            ver.url = "http://git."~_FAFServerSettings.hostname~"/"~ver.repo~".git";
            break;
          case "map":
            ver.url = "http://git."~_FAFServerSettings.hostname~"/maps/"~ver.repo~".git";
            break;
          case "mod":
            ver.url = "http://git."~_FAFServerSettings.hostname~"/mods/"~ver.repo~".git";
            break;
        }

      return ver.serializeToJson;
    }
    Json getDefault(string mod)
    {
      auto con = mysql_db.lockConnection;

      auto sql = con.prepSQL(
        "select `id`,`mod`,`name`,`ver_engine`,`ver_main_mod`,`time_added` "
        "from versions_default "
        "where `mod`=? order by time_added desc");

      sql.param(0) = mod;

      sql.exec;

      Json ret = Json.emptyArray;

      sql.eachobj(
        (DefaultVersion ver)
        {
          Json jver = ver.serializeToJson;

          jver.ver_engine = getRepoVersion(ver.ver_engine);
          jver.ver_main_mod = getRepoVersion(ver.ver_main_mod);

          ret ~= jver;
        });
      return ret;
    }
  }
}