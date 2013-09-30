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

extern bool     EnableTrade     = false;

extern string   BASESETTING     = "---Base Setting---";
extern string   Mode            = "slave"; //-- master or slave
extern double   BaseLots        = 0.1;
extern double   TholdPips       = 8.0;
extern double   StopLossPips    = 50.0;
extern double   TakeProfitPips  = 3.0;
extern int      MagicNumber     = 5257;
extern bool     MoneyManagment  = false;

extern string   DBSETTING       = "---PostgreSQL Database Settings---";
extern string   dbhost          = "localhost";
extern string   dbport          = "5432";
extern string   dbuser          = "postgres";
extern string   dbpass          = "911911";
extern string   dbname          = "nstmbt";



/* 
 * Global variable
 *
 */

string      marketInfo[22];
string      symbols[];
int         brokerNum;
double      tp, sl;

int         accountid;


/* 
 * include library
 *
 */
#include <nst_lib_all.mqh>
#include <postgremql4.mqh>



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
        libDebugOutputLog("DB not connected!", "PGSQL-ERR");
        return (-1);
    }

    //-- get all symbols
    libSymbolsList(symbols, true);

    //-- get account id
    accountid = getAccountId(AccountNumber(), TerminalCompany());

    //-- init price record
    initPriceTable();
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
    if(Mode == "master")
        master();
    else if(Mode == "slave")
        slave();
}

//-- master
void master()
{

}

//-- slave
void slave()
{
    /*string query = "";
    string res = "";
    double balance, freemargin, askprice, bidprice;

    //-- check new command

    //-- update price to db
    balance = AccountBalance();
    freemargin = AccountFreeMargin();
    string currtime = libDatetimeTm2str(TimeLocal());
    query = "INSERT INTO price (accountid,symbol,datetime,price_bid,price_ask,balance,freemargin) VALUES ";
    int symbolsnum = ArrayRange(symbols, 0);
    for(int i = 0; i < symbolsnum; i++)
    {
        askprice = MarketInfo(symbols[i], MODE_ASK);
        bidprice = MarketInfo(symbols[i], MODE_BID);
        //-- 
        query = StringConcatenate(
            query,
            "(" + accountid + ", " + symbols[i] + ", '" + currtime + "', " + bidprice + ", " + askprice + ", " + balance + ", " + freemargin + "),"
        );
    }
    query = StringSubstr(query, 0, StringLen(query) - 1);
    res = pmql_exec(query);*/
}

//-- get account id from db by account number and broker name
int getAccountId(int _an, string _borker)
{
    int id = 0;
    string query = "SELECT id FROM account WHERE accountnumber=\'" + _an + "\' AND broker=\'" + _borker + "\'";
    string res = pmql_exec(query);

    if(res == "")
    {
        query = "INSERT INTO account (accountnumber, broker) VALUES (\'" + _an + "', '" + _borker + "\')";
        res = pmql_exec(query);
        id = getAccountId(AccountNumber(), TerminalCompany());
    }
    else
        id = StrToInteger(StringSubstr(res, 3, -1));

    return(id);
}

void initPriceTable()
{
    string query = "";
    string res = "";
    double balance, freemargin, askprice, bidprice;

    //-- delete old symbol record from db
    query = "delete from price where accountid=" + accountid;
    pmql_exec(query);

    //-- insert symbol record to db
    balance = AccountBalance();
    freemargin = AccountFreeMargin();
    string currtime = libDatetimeTm2str(TimeLocal());
    query = "INSERT INTO price (accountid,symbol,datetime,price_bid,price_ask,balance,freemargin) VALUES ";
    int symbolsnum = ArrayRange(symbols, 0);
    for(int i = 0; i < symbolsnum; i++)
    {
        askprice = MarketInfo(symbols[i], MODE_ASK);
        bidprice = MarketInfo(symbols[i], MODE_BID);
        //-- 
        query = StringConcatenate(
            query,
            "(" + accountid + ", " + symbols[i] + ", '" + currtime + "', " + bidprice + ", " + askprice + ", " + balance + ", " + freemargin + "),"
        );
    }
    query = StringSubstr(query, 0, StringLen(query) - 1);
    res = pmql_exec(query);
}