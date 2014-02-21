/**
 * Powered by Nerrsoft.com
 *
 * @author Leon Zhuang - leon@nerrsoft.com - @nerrsoft
 * @link http://nerrsoft.com
 * @version 0.2 - dev
 * 
 */



/**
 * property infomation
 *
 */
#property copyright "Copyright ? 2014 Nerrsoft.com"
#property link      "http://nerrsoft.com"



/**
 * define extern variables
 *
 */
extern bool     EnableTrade     = false;    //-- control master only

extern string   BASESETTING     = "---Base Setting---";
extern string   RunningMode     = "slave";  //-- option: [master] or [slave] or [test]
extern double   BaseLots        = 0.1;
extern double   TholdPips       = 5.0;
extern double   StopLossPips    = 50.0;
extern double   TakeProfitPips  = 3.0;
extern int      MagicNumber     = 5257;     //-- it is avliable only master mode
extern bool     MoneyManagment  = false;

extern string   DBSETTING       = "---PostgreSQL Database Settings---";
extern string   dbhost          = "pi.nerrsoft.com";    //-- default host is a intranet server
extern string   dbport          = "5432";
extern string   dbuser          = "postgres";
extern string   dbpass          = "911911";
extern string   dbname          = "nst";



/**
 * include library
 *
 */
#include <nst_lib_all.mqh>
#include <postgremql4.mqh>



/**
 * Global variables
 *
 */
int     AccountId, AccountNum, AccountLev, SymbolId, PriceId, AccountType;
string  SymbolName, SymExt, BrokerName;



/**
 * System Funcs
 *
 */
int init()  //-- init
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
    if(IsDemo())
        AccountType = 1;
    else
        AccountType = 0;
    //-- get account id from db
    AccountId  = pubGetAccountId(AccountNum, BrokerName, AccountLev, AccountType); //-- todo -> get AccountId
    //-- get symbolid and priceid
    SymbolId   = pubGetSymbolId(SymbolName);
    PriceId    = pubGetPriceId(AccountId, SymbolId);

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
    //-- get orders array
    string CommandArr[500, 8];
    pubGetCommandArray(SymbolId, RunningMode, AccountId, MagicNumber, CommandArr);

    //-- get orders array
    string OrderArr[500, 10];
    pubGetOrderArray(SymbolName + SymExt, OrderArr, MagicNumber);

    //-- run by mode
    if(RunningMode == "master")
        master(CommandArr, OrderArr);
    else if(RunningMode == "slave")
        slave(CommandArr, OrderArr);
    else if(RunningMode == "test")
        test();
    else
        pubLog2Db("Please check the mode setting (master, slave or test).");
}



/**
 * Mode Funcs
 *
 */
//-- master mode
void master(string _carr[][], string _oarr[][])
{
    //-- check order
    masterCheckOrder(_oarr, _carr);

    //-- check command
    masterHandleCommand(_carr);

    //-- get local price bid & ask
    masterDiscoverChance();
}

//-- slave mode
void slave(string _carr[][], string _oarr[][])
{
    //-- check commands
    slaveCheckCommand(_carr);

    //-- check order
    slaveCheckOrder(_oarr, _carr);

    //-- update price to db
    slaveUpdatePrice(PriceId);

    //-- update order profit + swap + commission to db
    slaveUpdateOrderProfit(_oarr, AccountId);
}

//-- test mode
void test()
{
    //-- todo -> test mode
}




/**
 * Master Funcs
 * the func who use for slave mode only
 */
void masterCheckOrder(string _oarr[][], string _carr[][])
{
    //-- has order no command

    //-- has command no order

    //-- has order and command
}

void masterHandleCommand(string _carr[][])
{
    //-- 6: slave order closed

    //-- 0: slave not respond yet

    //-- 1/4: slave open order failed

    //-- 5: slave open limit order sucess
}

/**
 * masterDiscoverChance()
 * discover trading chance and begin trade
 * return[void]
 *
 */
void masterDiscoverChance()
{

}

/**
 * masterGetTotalProfit()
 * get master and slave total profit (profit + swap + commission) by ticket
 * return[double] total profit
 *
 * @param int    _mt  [master ticket]
 * @param int    _st  [slave ticket]
 */
double masterGetTotalProfit(int _mt, int _st)
{

}

/**
 * masterGetSlaveTotalProfit()
 * get slave total profit (profit + swap + commission) by ticket from database
 * return[double] total profit
 *
 * @param int    _st  [slave ticket]
 */
double masterGetSlaveTotalProfit(int _st)
{
    
}






/**
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

/**
 * slaveUpdateOrderProfit()
 * update slave order profit info to `nst_mbt_slave_profit` table
 * return[int]
 *
 * @param string    _arr    [array of orders]
 * @param int       _aid    [metatrader account id]
 */
int slaveUpdateOrderProfit(string _arr[][], int _aid)
{
    int size = ArrayRange(_arr, 0);

    if(size <= 0) return(0);

    string query = "";
    string res   = "";
    for(int i = 0; i < size; i++)
    {
        query = "UPDATE nst_mbt_slave_profit SET slaveorderprofit=" + _arr[i][9] + ",slaveswap=" + _arr[i][6] + ", slavecommission=" + _arr[i][4] + " logtime='" + libDatetimeTm2str(TimeLocal()) + "' WHERE slaveorderticket=" + _arr[i][0] + " AND accountid=" + _aid;
        res = pmql_exec(query);

        if(StringLen(res)>0)
            pubLog2Db("Update slave profit to db error: SQL return [" + res + "]", "NST-MBT-LOG");
    }

    return(1);
}

/**
 * slaveCheckCommand()
 * check command who need to handle
 * return[int]
 *
 * @param string    _arr   [array of command]
 */
int slaveCheckCommand(string _arr[][])
{
    int size = ArrayRange(_arr, 1);
    if(size <= 0) return(0);

    int     _ticket      = 0;
    int     _ordertype   = 0;
    double  _totalprofit = 0;
    double  _price       = 0;

    for(int i = 0; i < size; i++)
    {
        //-- open order command 
        if(_arr[i][4] == "0")
        {
            _ordertype = StrToInteger(_arr[i][5]);
            if(_ordertype == 0 && StrToDouble(_arr[i][11]) > Ask)
            {
                _price = Ask;
            }
            else if(_ordertype == 1 && StrToDouble(_arr[i][11]) < Bid)
            {
                _price = Bid;
            }
            else
            {
                pubSetCommandStatus(_arr[i][0], 1);
                pubLog2Db("Slave open order fail no chance, command[" + _arr[i][0] + "]", "NST-MBT-LOG");
                continue;
            }

            _ticket = pubOrderOpen(SymbolName + SymExt, _ordertype, StrToDouble(_arr[i][7]), _price, MagicNumber, _arr[i][0]);
            if(_ticket > 0 && OrderSelect(_ticket, SELECT_BY_TICKET) == true)
            {
                slaveUpdateCommandInfo(_arr[i][0], _ticket, OrderOpenPrice(), 2);
                slaveInsertProfit(_arr[i][0], _ticket);
            }
            else
            {
                pubSetCommandStatus(_arr[i][0], 1);
                pubLog2Db("Slave open order fail, command[" + _arr[i][0] + "]", "NST-MBT-LOG");
            }
        }
        else if(_arr[i][4] == "3")
        {
            _ordertype = StrToInteger(_arr[i][5]) + 2;
            if(_ordertype == 2)
                _price = StrToDouble(_arr[i][11]) - TholdPips * pubGetRealPip(SymbolName + SymExt) * pubGetMinPoint(SymbolName + SymExt);
            else if(_ordertype == 3)
                _price = StrToDouble(_arr[i][11]) + TholdPips * pubGetRealPip(SymbolName + SymExt) * pubGetMinPoint(SymbolName + SymExt);

            _ticket = pubOrderOpen(SymbolName + SymExt, _ordertype, StrToDouble(_arr[i][7]), _price, MagicNumber, _arr[i][0]);
            if(_ticket > 0 && OrderSelect(_ticket, SELECT_BY_TICKET) == true)
            {
                slaveUpdateCommandInfo(_arr[i][0], _ticket, OrderOpenPrice(), 5);
                slaveInsertProfit(_arr[i][0], _ticket);
            }
            else
            {
                pubSetCommandStatus(_arr[i][0], 4);
                pubLog2Db("Slave open limit order fail, command[" + _arr[i][0] + "]", "NST-MBT-LOG");
            }
        }
        else if(_arr[i][4] == "5") //-- todo -> need to test
        {
            if(true)
            {
                pubSetCommandStatus(_arr[i][0], 4);
            }
        }
        else if(_arr[i][4] == "8")
        {
            _ticket = StrToInteger(_arr[i][10]);
            if(OrderSelect(_ticket, SELECT_BY_TICKET) == true)
            {
                if(OrderType() > 1) //-- delete pending order
                    OrderDelete(_ticket);
                else                //-- close order
                {
                    _totalprofit = 0;
                    _totalprofit = slaveGetMasterOrderTotalProfit(_arr[i][0]) + OrderProfit() + OrderSwap() + OrderCommission();

                    if(_totalprofit > 0)
                    {
                        if(pubOrderCloseByTicket(_ticket) == true)
                            pubSetCommandStatus(_arr[i][0], 9);
                        else
                            pubLog2Db("Close Slave order[" + _ticket + "] fail", "NST-MBT-LOG");
                    }
                    else
                    {
                        if(pubSetOrderSLTP(_ticket, TakeProfitPips, StopLossPips) == true)
                            pubSetCommandStatus(_arr[i][0], 9);
                        else
                            pubLog2Db("Close Slave order[" + _ticket + "] fail", "NST-MBT-LOG");
                    }
                }
            }
            else
            {
                pubSetCommandStatus(_arr[i][0], 9);
            }
        }
    }

    return(1);
}

/**
 * slaveCheckOrder()
 * check order who has problem
 * return[void]
 *
 * @param string    _oarr   [array of order]
 * @param string    _carr   [array or command]
 */
void slaveCheckOrder(string _oarr[][], string _carr[][])
{
    int osize = ArrayRange(_oarr, 0);
    int csize = ArrayRange(_carr, 0);
    //if(size <= 0) return(0);
    int i, j, s; //-- counter
    int ticket;

    double totalprofit = 0;


    //-- check has order no command and set SL & TP
    for(i = 0; i < osize; i++)
    {
        s = 0;
        //-- check
        for(j = 0; j < csize; j++)
        {
            if(_oarr[i][0] == _carr[j][10])
            {
                s = 1;
                continue;
            }
        }

        //-- set
        if(s == 0)
        {
            ticket = StrToInteger(_oarr[i][0]);
            if(OrderSelect(ticket, SELECT_BY_TICKET) == true)
            {
                if(pubGetOrderTotalProfit(ticket, totalprofit) == true && totalprofit > 0)
                    pubOrderCloseByTicket(ticket);
                else if(OrderStopLoss() == 0 || OrderTakeProfit() == 0)
                    pubSetOrderSLTP(ticket, TakeProfitPips, StopLossPips);
            }
        }
    }

    //-- check has order no command
    for(i = 0; i < csize; i++)
    {
        s = 0;
        for(j = 0; j < osize; j++)
        {
            if(_oarr[i][0] == _carr[j][10])
            {
                s = 1;
                continue;
            }
        }

        //-- 
        if(s == 0)
        {
            ticket = StrToInteger(_carr[i][10]);
            if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY) == true)
            {
                if(OrderCLosePrice() > 0)
                    pubSetCommandStatus(_carr[i][10], 6);
            }
        }
    }
}

/**
 * slaveInsertProfit()
 * insert slave order proift to database
 * return[bool] insert success or fail
 *
 * @param string    _cid    [command id]
 * @param string    _ticket [order ticket number]
 */
bool slaveInsertProfit(string _cid, string _ticket)
{
    string _query = "INSERT INTO nst_mbt_slave_profit (commandid, slaveorderticket) VALUES (" + _cid + ", " + _ticket + ")";
    string _res   = pmql_exec(_query);
    if(StringLen(_res)>0)
    {
        pubLog2Db("Insert slave profit data fail [" + _res + "] commandid[" + _cid + "]", "NST-MBT-LOG");
        return(false);
    }
    else
        return(true);
}

/**
 * slaveUpdateCommandInfo()
 * command id & order ticket & open price & command status id
 * return[bool] update success or fail
 *
 * @param string    _cid    [command id]
 * @param string    _ticket [order ticket number]
 * @param double    _op     [order open price]
 * @param int       _sid    [command status id]
 */
//-- 
bool slaveUpdateCommandInfo(string _cid, int _ticket, double _op, int _sid)
{
    string _query = "UPDATE nst_mbt_command SET commandstatus=" + _sid + ", slaveorderid=" + _ticket + ", slaveopenprice=" + _op + ",WHERE id=" + _cid;
    string _res   = pmql_exec(_query);
    if(StringLen(_res)>0)
    {
        pubLog2Db("Update command status fail [" + _res + "]", "NST-MBT-LOG");
        return(false);
    }
    else
        return(true);
}

/**
 * slaveGetMasterOrderTotalProfit()
 * called by slave() and use to get closed master order total profit (profit + commission + swap) from database
 * if func return -99999 then query fail
 *
 * @param int _cid - command id
 */
double slaveGetMasterOrderTotalProfit(string _cid)
{
    double _profit = -99999;
    string _query = "SELECT mastercloseprofit,mastercloseswap,masterclosecommission from nst_mbt_master_closed_profit WHERE commandid=" + _cid;
    string _res   = pmql_exec(_query);

    if(StringLen(_res) > 0)
    {
        string _data[,3];
        libPgsqlFetchArr(_res, _data);

        _profit = StrToDouble(_data[0][0]) + StrToDouble(_data[0][1]) + StrToDouble(_data[0][2]);
    }

    return(_profit);
}




/**
 * Public Funcs
 * public funcs in this EA
 */


/**
 * pubLog2Db()
 * use insert the log information to database
 *
 * @param string _logtext
 * @param string _type = "Information"
 */
void pubLog2Db(string _logtext, string _type = "Information")
{
    libDebugOutputLog(_logtext, _type);
    //-- adjust log text len 400 is max (db)
    if(StringLen(_logtext) > 400)
        _logtext = StringSubstr(_logtext, 0, 400);

    string query = "INSERT INTO nst_mbt_tradinglog (logdatetime, logtype, logcontent) VALUES ('" + libDatetimeTm2str(TimeLocal()) + "', '" + _type + "', '" + _logtext + "')";
    string res = pmql_exec(query);
    if(StringLen(res)>0)
        libDebugSendAlert("Can not insert log to database [" + res + "].", "NST-MBT-LOG");
}

/**
 * pubOrderOpen()
 * called by master mode and slave mode when send open order 
 * return[int] ticket number if return 0 mean open order fail
 *
 * @param string    _symbol
 * @param int       _type
 * @param double    _lot
 * @param double    _price
 * @param int       _magic
 * @param string    _comment= ""
 */
int pubOrderOpen(string _symbol, int _type, double _lot, double _price, int _magic, string _comment= "")
{
    int _t = OrderSend(_symbol, _type, _lot, _price, 0, 0, 0, _comment, _magic);
    return(_t);
}


/**
 * pubOrderCloseByTicket()
 * close order by ticket, return bool close order status (success or fail)
 *
 * @param int _ticket
 */
bool pubOrderCloseByTicket(int _ticket)
{
    bool _status = false;
    if(OrderSelect(_ticket, SELECT_BY_TICKET) == true)
    {
      if (OrderType() == OP_BUY)  _status = OrderClose(_ticket, OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 3);
      if (OrderType() == OP_SELL) _status = OrderClose(_ticket, OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), 3);
    }
    else
        pubLog2Db("Close order by ticket fail can not select the ticket[" + _ticket + "] " + GetLastError(), "NST-MBT-LOG");

    return(_status);
}

/**
 * pubSetOrderSLTP()
 * set order stop loss and take profit
 * return[bool] set sucess or fail
 *
 * @param int       _ticket
 * @param double    _tp [pip]
 * @param double    _sl [pip]
 */
bool pubSetOrderSLTP(int _ticket, double _tp, double _sl)
{
    bool _status = false; //-- init status
    int _minpip = 1;
    int _stoplevel;
    int _pip;

    if(OrderSelect(_ticket, SELECT_BY_TICKET) == true)
    {
        //if(OrderStopLoss() > 0 || OrderTakeProfit() > 0) return(true);

        _stoplevel = MarketInfo(OrderSymbol(), MODE_STOPLEVEL);
        _pip = pubGetRealPip(OrderSymbol());
        _tp *= _pip;
        _sl *= _pip;

        //-- adjust takeprofit and stoploss
        if(_tp < _stoplevel) _tp = _stoplevel;
        if(_sl < _stoplevel) _sl = _stoplevel;

        _tp *= pubGetMinPoint(OrderSymbol());
        _sl *= pubGetMinPoint(OrderSymbol());

        if(OrderType() == OP_BUY)
        {
            _tp = OrderOpenPrice() + _tp;
            _sl = OrderOpenPrice() - _sl;
            _status = OrderModify(OrderTicket(), OrderOpenPrice(), _tp, _sl, OrderTakeProfit(), 0);
        }
        if(OrderType() == OP_SELL)
        {
            _tp = OrderOpenPrice() - _tp;
            _sl = OrderOpenPrice() + _sl;
            _status = OrderModify(OrderTicket(), OrderOpenPrice(), _tp, _sl, OrderTakeProfit(), 0);
        }
    }

    return(_status);
}

/**
 * pubGetOrderArray()
 * get order from metatrader4 client into an array
 * return[int] array size
 *
 * @param string    _sym        [symbol name]
 * @param string    &_arr[][]   [empty array use to fill order info]
 * @param int       _mn         [magic number]
 */
int pubGetOrderArray(string _sym, string &_arr[][], int _mn = 0) //-- magic number = 0 mean all order
{
    int symordernum = 0;
    //ArrayResize(_arr, ordernum);

    int ordernum = OrdersTotal();
    for(int i = 0; i < ordernum; i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderMagicNumber() == _mn && OrderSymbol() == _sym)
            {
                _arr[symordernum, 0] = OrderTicket();
                _arr[symordernum, 1] = OrderType();
                _arr[symordernum, 2] = OrderOpenPrice();
                _arr[symordernum, 3] = OrderComment();
                _arr[symordernum, 4] = OrderCommission();
                _arr[symordernum, 5] = OrderLots();
                _arr[symordernum, 6] = OrderSwap();
                _arr[symordernum, 7] = OrderStopLoss();
                _arr[symordernum, 8] = OrderTakeProfit();
                _arr[symordernum, 9] = OrderProfit();

                symordernum++;
            }
        }
    }

    ArrayResize(_arr, symordernum);
    return(symordernum);
}

/**
 * pubGetCommandArray()
 * get command from db return result rows and string array (need define array index
 * return[int] array size
 *
 * @param int       _symid      [symbol id]
 * @param string    _mode       [ea running mode: master/slave]
 * @param int       _aid        [account id]
 * @param int       _mn         [magic number]
 * @param string    &_arr[][]   [empty command array]
 */
int pubGetCommandArray(int _symid, string _mode, int _aid, int _mn, string &_arr[][])
{
    //-- make where
    string _where = "";
    if(_mode == "slave")
        _where = " WHERE slaveaid=" + _aid + " AND orderstatus in (0,3,5,8)";
    else if(_mode == "master")
        _where = " WHERE masteraid=" + _aid + " AND orderstatus in (0,1,2,4,5,6)";

    _where = _where + " AND symbolid=" + _symid + " AND ordermagicnum=" + _mn;

    //-- query command
    int _rows = 0;
    string query, res;
    query = "select id, masteraid, slaveaid, createtime, commandstatus, commandtype, symbolid, orderlots, ordercomment, masterorderid, slaveorderid, masteropenprice, slaveopenprice, ordermagicnum from nst_mbt_command" + _where;
    res = pmql_exec(query);

    //-- get array result and result row number
    if(StringLen(res)>0)
    {
        libPgsqlFetchArr(res, _arr);
        _rows = ArraySize(_arr);
    }

    return(_rows);
}

/**
 * pubSetCommandStatus()
 * set command status in database by command id and status id
 * return[bool] set command status sucess or not
 *
 * @param string    _cid    [command id]
 * @param int       _sid    [status id] - status id list is in 'NST_MBT - Workflow_Order_And_Command.drawing' file
 */
bool pubSetCommandStatus(string _cid, int _sid) //-- command id & status id
{
    string _query = "UPDATE nst_mbt_command SET commandstatus=" + _sid + " WHERE id=" + _cid;
    string _res   = pmql_exec(_query);
    if(StringLen(_res)>0)
    {
        pubLog2Db("Update command status fail [" + _res + "]", "NST-MBT-LOG");
        return(false);
    }
    else
        return(true);
}

/**
 * pubGetRealPip()
 * get current real pip
 * return[int] real pip
 *
 * @param string    _sym    [symbol name]
 */
int pubGetRealPip(string _sym)
{
    int _point_compat = 1;
    int _digit = MarketInfo(_sym, MODE_DIGITS);
    if(_digit == 3 || _digit == 5) _point_compat = 10;

    return(_point_compat);
}

/**
 * pubGetMinPoint()
 * get current min point
 * return[double] min point
 *
 * @param string    _sym    [symbol name]
 */
double pubGetMinPoint(string _sym)
{
    int     _digit = MarketInfo(_sym, MODE_DIGITS);
    double  _point = MarketInfo(_sym, MODE_POINT);

    if (_digit == 5 || _digit == 3)    // Adjust for five (5) digit brokers.       
        _point *= 10;

    return(_point);
}

/**
 * pubGetAccountId()
 * get account id in database by account number, broker name, leverage and account type (demo or not)
 * return[int] accunt id
 *
 * @param int       _an     [account number]
 * @param string    _bn     [broker name]
 * @param int       _lev    [account leverage]
 * @param int       _isdemo [account type (demo or not)]
 */
int pubGetAccountId(int _an, string _bn, int _lev, int _isdemo = 1)
{
    int _id = 0;
    string squery = "SELECT id FROM nst_sys_account WHERE accountnumber='" + _an + "' AND broker='" + _bn + "'";
    string res = pmql_exec(squery);
    if(res == "")
    {
        string iquery = "INSERT INTO nst_sys_account (strategyid, accountnumber, broker, leverage, accounttype) VALUES (3, " + _an + ", '" + _bn + "', " + _lev + ", " + _isdemo + ")";
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

/**
 * pubGetPriceId()
 * get price id in database by account id and symbol id
 * return[int] price record id
 *
 * @param int   _aid  [account id]
 * @param int   _sid  [symbol id]
 */
int pubGetPriceId(int _aid, int _sid)
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

/**
 * pubGetSymbolId()
 * get symbol id in database by symbol name
 * return[int] symbol id
 *
 * @param string    _sn   [symobl name]
 */
int pubGetSymbolId(string _sn)
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


/**
 * pubGetOrderTotalProfit()
 * get order total profit (profit + swap + commission) by ticket
 * return[bool] return false if get fail
 *
 * @param int    _ticket        [symobl name]
 * @param double &_totalprofit  [total profit]
 */
bool pubGetOrderTotalProfit(int _ticket, double &_totalprofit)
{
    bool status = false;
    if(OrderSelect(_ticket, SELECT_BY_TICKET) == true)
    {
        _totalprofit = OrderProfit() + OrderSwap() + OrderCommission();
        status = true;
    }
    return(status);
}