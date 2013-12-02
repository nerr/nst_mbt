/* 
 * property infomation
 *
 */

#property copyright "Copyright ? 2013 Nerrsoft.com"
#property link      "http://nerrsoft.com"



/* 
 * define extern
 *
 */

extern bool     EnableTrade     = false;    //-- control master only
extern string   BASESETTING     = "---Base Setting---";
extern string   RunningMode     = "slave";  //-- option: [master] or [slave] or [test]
extern double   BaseLots        = 0.1;
extern double   TholdPips       = 8.0;
extern double   StopLossPips    = 50.0;
extern double   TakeProfitPips  = 3.0;
extern int      MagicNumber     = 5257;     //-- it is avliable only master mode
extern bool     MoneyManagment  = false;

extern string   DBSETTING       = "---PostgreSQL Database Settings---";
extern string   dbhost          = "192.168.11.6";
extern string   dbport          = "5432";
extern string   dbuser          = "postgres";
extern string   dbpass          = "911911";
extern string   dbname          = "nst";



/* 
 * include library
 *
 */
#include <nst_lib_all.mqh>
#include <postgremql4.mqh>



/* 
 * Global variable
 *
 */
int     AccountId, AccountNum, AccountLev, SymbolId, PriceId;
string  SymbolName, SymExt, BrokerName;



/* 
 * System Funcs
 *
 */

//-- init
int init()
{
    //-- connect to pgsql
    string res = pmql_connect(dbhost, dbport, dbuser, dbpass, dbname);
    if((res != "ok") && (res != "already connected"))
    {
        pubLog2Db("DB not connected!", "PGSQL-ERR");
        return (-1);
    }

    //-- get account id by account number 
    AccountNum = AccountNumber();
    AccountLev = AccountLeverage();
    BrokerName = AccountCompany();
    SymbolName = StringSubstr(Symbol(), 0, 6);
    if(StringLen(Symbol()) > 6)
        SymExt = StringSubstr(Symbol(),6);
    //-- get account id from db
    AccountId  = getAccountId(AccountNum, BrokerName, AccountLev); //-- todo -> get AccountId
    //-- get symbolid and priceid
    SymbolId   = getSymbolId(SymbolName);
    PriceId    = getPriceId(AccountId, SymbolId);

    //-- init price record
    //initPriceTable(); //-- todo -> ...
}

//-- deinit
int deinit()
{
    pmql_disconnect();
    return(0);
}

//-- start
int start()
{
    if(RunningMode == "master")
        master();
    else if(RunningMode == "slave")
        slave();
    else if(RunningMode == "test")
        test();
    else
        pubLog2Db("Please check the mode setting (master or slave or test).");
}


/* 
 * Mode Funcs
 *
 */

//-- master mode
void master()
{
    //-- check command
    masterHandleCommand();

    //-- get local price bid & ask
    masterDiffPrice(SymbolName);

    //-- load avilable slave price and find chance


    //-- todo ->

}

//-- slave mode
void slave()
{
    //-- check command
    slaveHandleCommand();
    
    //-- update price to db
    slaveUpdatePrice(PriceId);
}

//-- test mode
void test()
{
    //-- todo -> test mode
}



/* 
 * Init Funcs
 * use to get init data and init settings
 */

//--
int getAccountId(int _an, string _bn, int _lev)
{
    int _id = 0;
    string squery = "SELECT id FROM nst_sys_account WHERE accountnumber='" + _an + "' AND broker='" + _bn + "'";
    string res = pmql_exec(squery);
    if(res == "")
    {
        string iquery = "INSERT INTO nst_sys_account (strategyid, accountnumber, broker, leverage) VALUES (3, " + _an + ", '" + _bn + "', " + _lev + ")";
        res = pmql_exec(iquery);
        if(res == "")
        {
            res = pmql_exec(squery);
            _id = StrToInteger(StringSubstr(res, 3, -1));
        }
    }
    else
        _id = StrToInteger(StringSubstr(res, 3, -1));

    //-- return 
    if(_id > 0)
        return(_id);
    else
        return(0);
}

//-- 
int getPriceId(int _aid, int _sid)
{
    int _id = 0;
    string squery = "SELECT id FROM nst_mbt_price WHERE accountid='" + _aid + "' AND symbolid='" + _sid + "'";
    string res = pmql_exec(squery);
    if(res == "")
    {
        string iquery = "INSERT INTO nst_mbt_price (accountid, symbolid) VALUES (" + _aid + ", " + _sid + ")";
        res = pmql_exec(iquery);
        if(res == "")
        {
            res = pmql_exec(squery);
            _id = StrToInteger(StringSubstr(res, 3, -1));
        }
    }
    else
        _id = StrToInteger(StringSubstr(res, 3, -1));

    //-- return 
    if(_id > 0)
        return(_id);
    else
        return(0);
}

//--
int getSymbolId(string _sn)
{
    int _id = 0;
    string squery = "SELECT id FROM nst_mbt_symbol WHERE symbolname='" + _sn +"'";
    string res = pmql_exec(squery);
    if(res == "")
    {
        string iquery = "INSERT INTO nst_mbt_symbol (symbolname) VALUES ('" + _sn + "')";
        res = pmql_exec(iquery);
        if(res == "")
        {
            res = pmql_exec(squery);
            _id = StrToInteger(StringSubstr(res, 3, -1));
        }
    }
    else
        _id = StrToInteger(StringSubstr(res, 3, -1));

    //-- return 
    if(_id > 0)
        return(_id);
    else
        return(0);
}


/* 
 * Slave Funcs
 * the func who use for slave mode only
 */

void masterHandleCommand()
{

}

void masterDiffPrice()
{

}

int masterOrderTotal()
{

}


/* 
 * Slave Funcs
 * the func who use for slave mode only
 */

//-- update price to database
//-- pid (price id) = symbol record id in price table
void slaveUpdatePrice(int _pid)
{
    RefreshRates();

    string query = "";
    query = "UPDATE nst_mbt_price SET";
    query = query + " bidprice=" + Bid + ",";
    query = query + " askprice=" + Ask + ",";
    query = query + " loctime='" + libDatetimeTm2str(TimeLocal()) + "',";
    query = query + " sertime='" + libDatetimeTm2str(TimeCurrent()) + "'";
    query = query + " WHERE id=" + _pid;

    string res = pmql_exec(query);

    if(StringLen(res)>0)
        pubLog2Db("Update price to db error: SQL return [" + res + "]", "NST-MBT-LOG");
}

//-- load command from db and process command from master client
void slaveHandleCommand()
{
    string query, res;
    query = "select * from nst_mbt_command where commandstatus in (0, 3, 8) and slaveid=" + AccountId + " order by commandstatus";
    res = pmql_exec(query);

    //-- todo ->
}



/* 
 * Public Funcs
 * public funcs in this EA
 */

void pubLog2Db(string _logtext, string _type="Information")
{
    libDebugOutputLog(_logtext, _type);
    string query = "INSERT INTO nst_mbt_tradinglog (logdatetime, logtype, logcontent) VALUES ('" + libDatetimeTm2str(TimeLocal()) + "', '" + _type + "', '" + _logtext + "')";
    string res = pmql_exec(query);
    if(StringLen(res)>0)
        libDebugSendAlert("Can not insert log to database.", "NST-MBT-LOG");
}

bool pubOrderOpen()
{
    //-- todo -> slave order use commandid as comment
}

bool pubOrderClose()
{

}

bool pubSetOrderSTTP()
{
    
}

//--
int pubGetOrderArray(int _mn = 0) //-- magic number = 0 mean all order
{
    if()
    {

    }
}

//-- public func - get command from db return result rows and string array (need define array index)
int pubGetCommandArray(int, _symid, string _mode, int _aid, int _mn, string &_arr[])
{
    //-- make where
    string _where = "";
    if(_mode == "slave")
        _where = " WHERE slaveaid=" + _aid + " AND orderstatus in (0,3,6,8)";
    else if(_mode == "master")
        _where = " WHERE masteraid=" + _aid + " AND orderstatus in (0,1,2,4,5,6)";

    _where = _where + " AND symbolid=" + _symid + " AND ordermagicnum=" + _mn;

    //-- query command
    int _rows = 0;
    string query, res;
    query = "select id,masteraid,slaveaid,commandstatus,commandtype,symbolid,masteropenprice,slaveopenprice from nst_mbt_command" + _where;
    res = pmql_exec(query);

    //-- get array result and result row number
    if(StringLen(res)>0)
    {
        libPgsqlFetchArr(res, _arr);
        _rows = ArraySize(_arr);
    }

    return(_rows);
}


