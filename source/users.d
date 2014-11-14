import app;
import vibe.d;

import std.conv;

interface UserServiceAPI
{
  @path("/info")
  Json getInfo(int id);
  
  @path("/infobyname/:name")
  Json getInfoByName(string _name);
}

class UserService : UserServiceAPI
{ 
  override {
    Json getInfo(int user_id)
    {
      Bson user = fareborn_db["users"].findOne(["id":user_id],
                                               ["_id": 0, "id":1, "username":1]);
      
      enforceHTTP(!user.isNull, HTTPStatus.NotFound, "No such user: "~text(user_id));
        
      Json res = user.toJson;
      
      // TODO: Link avatars, rating, league, clan to db
      res.avatar = ["name": Json("banana"),
                    "tooltip": Json("Updated bananas."),
                    "url": Json("http://placehold.it/128x128")] ;
      res.clan = "BNN";
      res.league = ["league": Json(1), "division":Json("Supreme Dance Commander")];
      res.country = "HN";
      res.rating = ["mean": Json(1000), "deviation":Json(0)];
      
      
      return res;
    }
    Json getInfoByName(string name)
    {
      Bson user = fareborn_db["users"].findOne(["username":name], ["id":1]);
      
      enforceHTTP(!user.isNull, HTTPStatus.NotFound,
                  "No such user: "~name);
      
      int id = user.id.get!int;
      
      return getInfo(id);
    }
  }
}