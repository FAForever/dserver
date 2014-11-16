/*
  Module to wrap around inconsistencies and literal badness in mysql-native
*/
import mysql;

alias MysqlDB = mysql.MysqlDB;
alias MysqlConnection = mysql.Connection;
alias MysqlCommand = mysql.Command;

alias SQLRow = mysql.Row;
alias SQLFieldDescription = mysql.FieldDescription;

// Global connection
MysqlDB mysql_db;

MysqlCommand prepSQL(MysqlConnection con, string sql)
{
  auto cmd = MysqlCommand(con, sql);

  cmd.prepare();

  return cmd;
}

// returns number of affected rows
ulong exec(ref MysqlCommand cmd)
{
  ulong ra;
  assert(cmd.execPrepared(ra));
  return ra;
}

bool execToStruct(T)(ref MysqlCommand cmd, ref T t)
  if (is(T == struct))
{
  cmd.exec;

  SQLRow row = cmd.getNextRow;

  if(!cmd.rowsPending)
    return false;
  //enforce(cmd.rowsPending, "Null row encountered in execToStruct.");

  row.toStruct(t);

  cmd.purgeResult;
  return true;
}

void eachrow(ref MysqlCommand cmd, void delegate(SQLFieldDescription[], SQLRow) rowhandler)
{
  while(cmd.rowsPending)
  {
    SQLRow row = cmd.getNextRow;

    // Last row is null row
    if(!cmd.rowsPending)
      return;

    rowhandler(cmd.preparedFieldDescriptions, row);
  }
}

void eachobj(T)(ref MysqlCommand cmd, void delegate(T) objhandler)
  if (is(T == struct))
{
  while(cmd.rowsPending)
  {
    SQLRow row = cmd.getNextRow;

    // Last row is null row
    if(!cmd.rowsPending)
      return;

    T t;
    row.toStruct(t);
    objhandler( t );
  }
}
