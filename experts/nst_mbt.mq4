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

extern bool     EnableTrade     = false;   //-- control master only
extern string   BASESETTING     = "---Base Setting---";
extern string   RunningMode     = "slave"; //-- option: [master] or [slave] or [test]
extern double   BaseLots        = 0.1;
extern double   TholdPips       = 8.0;
extern double   StopLossPips    = 50.0;
extern double   TakeProfitPips  = 3.0;
extern int      MagicNumber     = 5257;
extern bool     MoneyManagment  = false;

extern string   DBSETTING       = "---PostgreSQL Database Settings---";
extern string   dbhost          = "192.168.11.6";
extern string   dbport          = "5432";
extern string   dbuser          = "postgres";
extern string   dbpass          = "911911";
extern string   dbname          = "nstmbt";



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
int     AccountNum;
string  CurrSymbol;



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
    if(Mode == "master") //-- todo -> trans Mode to upper
        master();
    else if(Mode == "slave")
        slave();
    else if(Mode == "slave")
        test();
    else
        libDebugOutputLog("Please check the mode setting (master or slave).");
}


/* 
 * Mode Funcs
 *
 */

//-- master mode
void master()
{
    //-- todo ->
}

//-- slave mode
void slave()
{
    //-- todo -> check command

    //-- update price to db
    updatePrice();

}

//-- test mode
void test()
{
    //-- todo ->
}