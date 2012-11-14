/* Nerr SmartTrader - Multi Broker Trader - Master
 *
 * By Leon Zhuang
 * Twitter @Nerrsoft
 * leon@nerrsoft.com
 * http://nerrsoft.com
 * 
 * 
 * @History
 * v0.0.0  [dev] 2012-06-06 init.
 * v0.0.1  [dev] 2012-06-08 complete mysql & sqlite read and write test, final selected mysql wrapper; complete price difference calu.
 * v0.0.2  [dev] 2012-06-14 fix the price difference indicator bug.
 * v0.0.3  [dev] 2012-06-28 finish open order and close order func.
 * v0.0.4  [dev] 2012-06-29 fix table `tradecommand` field typo
 * v0.0.5  [dev] 2012-07-02 add checkBadOrder() func, use to check orderstatus>2 (3-slave client open order failed)
 * v0.1.0  [dev] 2012-07-10 update new version mysql wrapper 2.0.5 and recode master client
 * v0.1.3  [dev] 2012-07-10 fix some bug, redegsin watermark and rename to dubuginfo
 * v0.1.4  [dev] 2012-07-13 recode debuginfo display part
 * v0.1.5  [dev] 2012-07-17 fix typo
 * v0.1.6  [dev] 2012-07-31 adjust param
 * v0.1.7  [dev] 2012-08-01 add connectdb() func, add reconnectdb in start() func.
 * v0.1.8  [dev] 2012-08-01 update relation sql string, add masteraccount and masterbroker field.
 * v0.1.9  [dev] 2012-08-01 fix checkbakorder bug.
 * v0.2.0  [dev] 2012-08-02 add an alert output when re-connect db fail.
 * v0.2.1  [dev] 2012-08-03 fix checkbadorder() func bug, sql and stoploss.
 * v0.2.2  [dev] 2012-08-08 update scanOpportunity() func add tholdpips param.
 * v0.2.3  [dev] 2012-08-16 fix a sql string typo
 * v0.2.4  [dev] 2012-08-20 add stop lose to bad order
 * v0.2.5  [dev] 2012-08-21 fix a sql typo in closeOrder() func (error 1103), add createOrderObj() func
 * v0.2.6  [dev] 2012-08-21 recode displayOrderStatus() func
 * v0.3.0  [dev] 2012-08-22 fix order status display bug, change the brokers name.
 * v0.3.1  [dev] 2012-08-27 add a extern pricetable for special symbol. (XAUUSD & XAUUSDpro)
 * v0.3.2  [dev] 2012-08-27 add allow trade controller
 * v0.3.3  [dev] 2012-08-28 add extern var BeginLevel use for control the open order tholdpips
 * v0.3.4  [dev] 2012-08-28 add extern var MinPip use for calculat for SL, TL and Tholdpips
 * v0.3.5  [dev] 2012-08-30 add margin level safe check
 * v0.3.6  [dev] 2012-09-17 add slave clent trade switch
 * v0.3.7  [dev] 2012-09-17 fix close order color error
 * v0.3.8  [dev] 2012-09-18 add getLots() func, set max lots (10)
 * v0.3.9  [dev] 2012-09-24 improve order management, add order status check, when Metatrader has no order but database has order update the order status in database.
 * v0.5.0  [dev] 2012-11-07 a new version is begin, it will delete slave script, auto load account info from db never need setup manual.
 *
 */



/* 
 * property infomation
 *
 */

#property copyright "Copyright ? 2012 Nerrsoft.com"
#property link 		"http://nerrsoft.com"



/* 
 * define extern
 *
 */

extern bool 	EnableTrade		= true;
extern string 	BaseSetting		= "---------Base Setting---------";
extern double 	BaseLots		= 0.2;
extern int 		BaseTarget		= 10;
extern int 	  	MagicNumber		= 9999;
extern double 	TholdPips		= 5.0;
extern int 		BeginLevel		= 5;
extern double 	StopLossPips	= 500.0;
extern double 	TakeProfitPips	= 50.0;
extern double 	MinPip			= 0.01;
extern bool 	moneymanagment	= true;
extern string 	DBSetting 		= "---------MySQL Setting---------";
extern string 	host			= "127.0.0.1";
extern string 	user			= "root";
extern string 	pass			= "911911";
extern string 	dbName			= "metatrader";
extern string 	pricetable		= "";
extern int 		port			= 3306;



/* 
 * Global variable
 *
 */

string 		mInfo[22];
int 		brokerNum;




/* 
 * include mysql wrapper
 *
 */

#include <mysql_v2.0.5.mqh>
int		socket 		= 0;
int		client 		= 0;
int		dbConnectId = 0;
bool	goodConnect = false;



/* 
 * System Funcs
 *
 */

//-- init
int init()
{
	//-- get market information
	getInfo(mInfo);

	//-- price table
	if(pricetable=="")
		pricetable = mInfo[20];

	//-- connect mysql
	goodConnect = connectdb();

	if(!goodConnect)
	{
		outputLog("connect db failed", "Error");
		return (1);
	}

	//-- add a new record if table have no this broker
	string query = StringConcatenate(
		"INSERT IGNORE INTO `" + pricetable + "` (`broker`, `account`) ",
		"VALUES (\'" + mInfo[1] + "\', " + mInfo[15] + ")"
	);
	mysqlQuery(dbConnectId, query);

	//-- calu thold pips
	//TholdPips = TholdPips * MinPip;

	brokerNum = getBorkerNum(pricetable);

	initDebugInfo(brokerNum);

	return(0);
}

//-- deinit
int deinit()
{
	mysqlDeinit(dbConnectId);
	return(0);
}

//-- start
int start()
{
	//-- calu price differece between two brokers
	//checkPriceDifference();
	//-- open order
	//if(EnableTrade == true)
		//scanOpportunity();

	//-- check current order profit, waitting for close order
	//checkCurrentOrder();
	//-- check bad order
	//checkBadOrder();

	updateThisBrokerPrice(pricetable);
	readBrokersPrice(pricetable, brokerNum);


	
	return(0);
}



/* 
 * Price Funcs
 *
 */

//-- 
void updateThisBrokerPrice(string _tablename)
{
	//-- get information
	double symbolprice[2];
	datetime localtimes = TimeLocal();
	double accountblance = AccountBalance();
	double accountfreemargin = AccountFreeMargin();
	double symbolspread = MarketInfo(mInfo[20], MODE_SPREAD);

	//-- get real spread
	if(Digits % 2 == 1)
		symbolspread /= 10;

	RefreshRates();
	if(Bid>0)
		symbolprice[0] = Bid;
	if(Ask>0)
		symbolprice[1] = Ask;

	//-- update to db
	string query = StringConcatenate(
		"UPDATE `" + _tablename + "` ",
		"SET timecurrent=" + localtimes + ", bidprice=" + symbolprice[0] + ", askprice=" + symbolprice[1] + ", balance=" + accountblance + ", freemargin=" + accountfreemargin + ", spread=" + symbolspread + " ",
		"WHERE account=" + mInfo[15] + " and broker=\'" +  mInfo[1] + "\'"
	);
	mysqlQuery(dbConnectId, query);
}

//--
void readBrokersPrice(string _tablename, int _brokernum)
{
	//-- get price data
	string data[][9];
	string query = "SELECT broker, account, timecurrent, bidprice, askprice, spread FROM `" + _tablename + "`";

	int result = mysqlFetchArray(dbConnectId, query, data);
	if(result == 0)
		outputLog("0 rows selected", "MySQL ERROR");
	else if(result == -1)
		outputLog("some error occured", "MySQL ERROR");
	else
	{
		//-- update new price data to chart
		updateDubugInfo(_brokernum, data);
	}
}

//-- get Price Diff [0]status [1]diff [2]action
void getPriceDiff(int _brokernum, string &_data[][])
{
	//--  highest lowest, invalid, diff, action
	int timecurrent;
	int highest, lowest;
	double highestp = 0;
	double lowestp = 0;
	double bidp = 0;


	for(int i = 0; i < _brokernum; i++)
	{
		timecurrent = StrToInteger(_data[i][2]);
		bidp = StrToDouble(_data[i][3]);

		_data[i][6] = "";


		if((TimeLocal() - timecurrent) < 3)
		{
			if(highest == 0)
			{
				highest = i;
				highestp = bidp;
				lowest = i;
				lowestp = bidp;
			}
			else
			{
				if(bidp > highestp)
				{
					highest = i;
					highestp = bidp;
				}
				else if(bidp < lowestp)
				{
					lowest = i;
					lowestp = bidp;
				}
			}
		}
		else
			_data[i][6] = "invalid";
	}

	//--
	_data[lowest][6] = "lowest";
	_data[highest][6] = "highest";

}





/* 
 * Order Funcs
 *
 */

//-- check account marin level safe or not
bool checkMarginSafe(int _cmd, double _lots)
{
	double freemargin = AccountFreeMarginCheck(Symbol(), _cmd, _lots);

	//-- if free margin less than 0 then return false
	if(freemargin<=0)
		return (false);

	//-- margin level = equity / (equity - free margin)
	double marginlevel = AccountEquity() / (AccountEquity() - freemargin);
	if(marginlevel>30) //-- safe margin level set to 3000%
		return (true);
	else
		return (false);
}





/* 
 * MySQL Funcs
 *
 */

//-- connect to database
int connectdb()
{
	//-- close connection if exists
	if(dbConnectId>0)
		mysqlDeinit(dbConnectId);

	//-- connect mysql
	bool result = mysqlInit(dbConnectId, host, user, pass, dbName, port, socket, client);

	return (result);
}

//-- get brokers number
int getBorkerNum(string _tablename)
{
	int rows = -1;
	string data[][1];
	string query = "SELECT broker FROM `" + _tablename + "`";
	int result = mysqlFetchArray(dbConnectId, query, data);

	if(result == 0)
		outputLog("0 rows selected", "MySQL ERROR");
	else if(result == -1)
		outputLog("some error occured", "MySQL ERROR");
	else
		rows = ArrayRange(data, 0);

	return(rows);
}



/* 
 * Debug Funcs
 *
 */

//-- output log
void outputLog(string _logtext, string _type="Information")
{
	string text = ">>>" + _type + ":" + _logtext;
	Print (text);
}

//-- send alert
void sendAlert(string _text = "null")
{
	outputLog(_text);
	PlaySound("alert.wav");
	Alert(_text);
}

//-- get all market information
void getInfo(string &MInfo[])
{
	// get account type
	if(IsDemo()) MInfo[0] = "Demo";
	else MInfo[0] = "Real";
	// get broker
	MInfo[1] = TerminalCompany();
	// get MT4 name
	MInfo[2] = TerminalName();
	// get server Time
	MInfo[3] = TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS);
	// get account balance
	MInfo[4] = AccountBalance();
	// get account credit
	MInfo[5] = AccountCredit();
	// get account company
	MInfo[6] = AccountCompany();
	// get account currency
	MInfo[7] = AccountCurrency();
	// get account equity
	MInfo[8] = AccountEquity();
	// get account free margin
	MInfo[9] = AccountFreeMargin();
	// get account free margin check
	// MInfo[10] = AccountFreeMarginCheck(Symbol(),);
	// get account free margin mode
	MInfo[11] = AccountFreeMarginMode();
	// get account leverage
	MInfo[12] = AccountLeverage();
	// get account margin
	MInfo[13] = AccountMargin();
	// get account nameh
	MInfo[14] = AccountName();
	// get account number
	MInfo[15] = AccountNumber();
	// get account profit
	MInfo[16] = AccountProfit();
	// get account server
	MInfo[17] = AccountServer();
	// get account stop out level
	MInfo[18] = AccountStopoutLevel();
	// get account stop out mode
	MInfo[19] = AccountStopoutMode();
	// get current symbol
	MInfo[20] = Symbol();
	// get mInfo[21]
	MInfo[21] = MarketInfo(MInfo[20], MODE_DIGITS);
}

void initDebugInfo(int _brokernum)
{
	int y = 0;

	//-- background
	ObjectCreate("background_1", OBJ_LABEL, 0, 0, 0);
	ObjectSetText("background_1", "g", 300, "Webdings", DarkGreen);
	ObjectSet("background_1", OBJPROP_BACK, false);
	ObjectSet("background_1", OBJPROP_XDISTANCE, 20);
	ObjectSet("background_1", OBJPROP_YDISTANCE, 13);

	ObjectCreate("background_2", OBJ_LABEL, 0, 0, 0);
	ObjectSetText("background_2", "g", 300, "Webdings", DarkGreen);
	ObjectSet("background_2", OBJPROP_BACK, false);
	ObjectSet("background_2", OBJPROP_XDISTANCE, 420);
	ObjectSet("background_2", OBJPROP_YDISTANCE, 13);

	//-- broker price table header
	y += 15;
	createTextObj("table_header_col_1", 25,	y, "Broker");
	createTextObj("table_header_col_2", 120,y, "Account");
	createTextObj("table_header_col_3", 190,y, "Time");
	createTextObj("table_header_col_4", 350,y, "Bid");
	createTextObj("table_header_col_5", 420,y, "Ask");
	createTextObj("table_header_col_6", 490,y, "Spread");
	createTextObj("table_header_col_7", 570,y, "Status"); //-- highest or lowest
	createTextObj("table_header_col_8", 670,y, "Diff");
	createTextObj("table_header_col_9", 770,y, "Action");

	//-- broker price table body
	if(_brokernum>0)
	{
		for(int i = 0; i < _brokernum; i++)
		{
			y += 15;
			createTextObj("table_body_row_" + i + "_col_1", 25,	y, "", White);
			createTextObj("table_body_row_" + i + "_col_2", 120,y, "", White);
			createTextObj("table_body_row_" + i + "_col_3", 190,y);
			createTextObj("table_body_row_" + i + "_col_4", 350,y);
			createTextObj("table_body_row_" + i + "_col_5", 420,y);
			createTextObj("table_body_row_" + i + "_col_6", 490,y);
			createTextObj("table_body_row_" + i + "_col_7", 570,y);
			createTextObj("table_body_row_" + i + "_col_8", 670,y);
			createTextObj("table_body_row_" + i + "_col_9", 770,y);
		}
	}
}

//--  update new debug info to chart
void updateDubugInfo(int _brokernum, string &_data[][])
{
	int digit = StrToInteger(mInfo[21]);

	getPriceDiff(_brokernum, _data);

	if(_brokernum>0)
	{
		for(int i = 0; i < _brokernum; i++)	//broker, account, timecurrent, bidprice, askprice, spread
		{
			if(_data[i][0] == mInfo[1])
			{
				setTextObj("table_body_row_" + i + "_col_1", StringSubstr(_data[i][0], 0, 10), DeepSkyBlue);	// broker
				setTextObj("table_body_row_" + i + "_col_2", _data[i][1], DeepSkyBlue);	//account
			}
			else	
			{
				setTextObj("table_body_row_" + i + "_col_1", StringSubstr(_data[i][0], 0, 10));	// broker
				setTextObj("table_body_row_" + i + "_col_2", _data[i][1]);	//account
			}
			setTextObj("table_body_row_" + i + "_col_3", TimeToStr(StrToInteger(_data[i][2]), TIME_DATE|TIME_SECONDS));	//time
			setTextObj("table_body_row_" + i + "_col_4", _data[i][3]);	//bid
			setTextObj("table_body_row_" + i + "_col_5", _data[i][4]);	//ask
			setTextObj("table_body_row_" + i + "_col_6", _data[i][5]);	//spread
			setTextObj("table_body_row_" + i + "_col_7", _data[i][6]);	//status
			setTextObj("table_body_row_" + i + "_col_8", _data[i][7]);	//diff
			setTextObj("table_body_row_" + i + "_col_9", _data[i][8]);	//action
		}
	}
}

//-- create text object
void createTextObj(string objName, int xDistance, int yDistance, string objText="", color fontcolor=GreenYellow, string font="Courier New", int fontsize=9)
{
	if(ObjectFind(objName)<0)
	{
		ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
		ObjectSetText(objName, objText, fontsize, font, fontcolor);
		ObjectSet(objName, OBJPROP_XDISTANCE,	xDistance);
		ObjectSet(objName, OBJPROP_YDISTANCE, 	yDistance);
	}
}

//-- set text object new value
void setTextObj(string objName, string objText="", color fontcolor=White, string font="Courier New", int fontsize=9)
{
	if(ObjectFind(objName)>-1)
	{
		ObjectSetText(objName, objText, fontsize, font, fontcolor);
	}
}




/*
//-- global var
string 		mInfo[22];
double 		localPrice[2], remotePrice[2];
double 		priceDifferenceBuy[3], priceDifferenceSell[3];
datetime 	localTimeCurrent, remoteTimeCurrent;
bool 		HaveOrder = false;
int 		currentLevel = 0;



void checkBadOrder()
{
	string data[][2];
	string query = StringConcatenate(
		"SELECT id,masterorderticket ",
		"FROM `_command` ",
		"WHERE masteraccount=" + mInfo[15] + " AND masterbroker=\'" +  mInfo[1] + "\' AND slaveaccount=" + RemoteAccount + " AND slavebroker=\'" +  RemoteBroker + "\' AND symbol=\'"+pricetable+"\' AND slaveorderstatus=3"
	);

	int result = mysqlFetchArray(dbConnectId, query, data);

	if(result>0)
	{
		int rows = ArrayRange(data, 0);
		int masterorderticket;
		int commandid;
		bool oStatus;

		for(int i = 0; i < rows; i++)
		{
			masterorderticket = StrToInteger(data[i][1]);
			commandid = StrToInteger(data[i][0]);
			oStatus = false;

			if(OrderSelect(masterorderticket, SELECT_BY_TICKET)==true)
			{
				if(OrderProfit()>0)
				{
					if(OrderType()==OP_BUY)
						oStatus = OrderClose(OrderTicket(), OrderLots(), Bid, 1, Blue);
					else
						oStatus = OrderClose(OrderTicket(), OrderLots(), Ask, 1, Red);
				}
				else	//-- bet begin, may be lost may be win.....
				{
					if(OrderType()==OP_BUY)
						//oStatus = OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice()-Point*10, OrderOpenPrice()+Point*5, 1);
						oStatus = OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice()-MinPip*StopLossPips, OrderOpenPrice()+MinPip*TakeProfitPips, 1);
					else
						//oStatus = OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice()+Point*10, OrderOpenPrice()-Point*5, 1);
						oStatus = OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice()+MinPip*StopLossPips, OrderOpenPrice()-MinPip*TakeProfitPips, 1);
				}
				//-- update to db
				if(oStatus==true)
					mysqlQuery(dbConnectId, "UPDATE `_command` SET slaveorderstatus=2 WHERE id=" + commandid);
			}
		}
		else
		{
			mysqlQuery(dbConnectId, "UPDATE `_command` SET slaveorderstatus=2 WHERE id=" + commandid);
		}
	}
	else if(result<0)
	{
		outputLog(query, "SQL_ERROR_CHECK_BAD_ORDER");              
	}
}

void scanOpportunity()
{
	int mutiple, ordert;
	string query;
	string comment;
	datetime currenttime;
	double lots;

	int slaveorderstatus = 0;
	if(EnableSlaveTrade==FALSE)
		slaveorderstatus = 3;

	if(TholdPips==0)
		sendAlert("Thold pips value is zero, check it why, as soon as maybe!");

	//-- open order
	if(priceDifferenceBuy[0] > TholdPips)
	{
		currenttime = TimeLocal();
		mutiple = MathFloor(priceDifferenceBuy[0] / TholdPips);
		if(mutiple>=BeginLevel)
		{
			comment = mutiple;
			sendAlert("Open Signal - Buy-"+mInfo[20]+"@" + priceDifferenceBuy[0] + "|L" + mutiple);

			//-- get lots
			lots = getLots(mutiple);

			//-- check margin level safe or not
			if(checkMarginSafe(OP_BUY, lots)==false)
			{
				sendAlert("Out of safe margin level!");
				return (0);
			}

			//-- open buy order and send a sell command to remote db
			ordert = OrderSend(mInfo[20], OP_BUY, lots, localPrice[1], 0, 0, 0, comment, MagicNumber, 0, Blue);
			if(ordert>0)
			{
				query = StringConcatenate(
					"INSERT INTO `_command` ",
					"(masteraccount, masterbroker, slavebroker, slaveaccount, symbol, commandtype, masterorderticket, masteropenprice, pricedifference, lots, slaveorderstatus, createtime, tholdpips) VALUES ",
					"("+mInfo[15]+", \'"+mInfo[1]+"\', \'" + RemoteBroker + "\', "+RemoteAccount+", \'"+pricetable+"\', 1, "+ordert+", "+localPrice[1]+", "+priceDifferenceBuy[0]+", "+lots+", "+slaveorderstatus+", "+currenttime+", "+TholdPips+")"
				);
				mysqlQuery(dbConnectId,query);
				//currentLevel = mutiple;
			}
		}
	}
	else if(priceDifferenceSell[0] > TholdPips)
	{
		currenttime = TimeLocal();
		mutiple = MathFloor(priceDifferenceSell[0] / TholdPips);
		if(mutiple>=BeginLevel)
		{
			comment = mutiple;
			sendAlert("Open Signal - Sell-"+mInfo[20]+"@" + priceDifferenceSell[0] + "|L" + mutiple);

			//-- get lots
			lots = getLots(mutiple);

			//-- check margin level safe or not
			if(checkMarginSafe(OP_SELL, lots)==false)
			{
				sendAlert("Out of safe margin level!");
				return (0);
			}

			//-- open sell order and send a buy command to remote db
			ordert = OrderSend(Symbol(), OP_SELL, lots, localPrice[0], 0, 0, 0, comment, MagicNumber, 0, Red);
			if(ordert>0)
			{
				query = StringConcatenate(
					"INSERT INTO `_command` ",
					"(masteraccount, masterbroker, slavebroker, slaveaccount, symbol, commandtype, masterorderticket, masteropenprice, pricedifference, lots, slaveorderstatus, createtime, tholdpips) VALUES ",
					"("+mInfo[15]+", \'"+mInfo[1]+"\', \'" + RemoteBroker + "\', "+RemoteAccount+", \'"+pricetable+"\', 0, "+ordert+", "+localPrice[1]+", "+priceDifferenceSell[0]+", "+lots+", "+slaveorderstatus+", "+currenttime+", "+TholdPips+")"
				);
				mysqlQuery(dbConnectId,query);
				//currentLevel = mutiple;
			}
		}
	}
}

void checkCurrentOrder()
{
	int index, line;
	int orderlevel, maxlevel;
	double totalprofit, ordertarget;
	int orderticket;

	//-- remove all order object display
	deleteOrderStatus();

	string data[][3];
	string query = StringConcatenate(
		"SELECT slaveprofit,masterorderticket,slaveorderticket FROM `_command` ",
		"WHERE masteraccount=" + mInfo[15] + " AND masterbroker=\'" +  mInfo[1] + "\' AND slaveaccount=" + RemoteAccount + " AND slavebroker=\'" +  RemoteBroker + "\' AND symbol=\'"+pricetable+"\' AND slaveorderstatus=1"
	);
	int result = mysqlFetchArray(dbConnectId, query, data);
	if(result>0)
	{
		int rows = ArrayRange(data, 0);
		line = 0;
		for(int i = 0; i < rows; i++)
		{
			orderticket = StrToInteger(data[i][1]);
			if(OrderSelect(orderticket, SELECT_BY_TICKET)==true)
			{
				orderlevel = StrToInteger(OrderComment());
				totalprofit = OrderProfit() + OrderSwap() + OrderCommission();
				totalprofit += StrToDouble(data[i][0]);

				if(orderlevel > maxlevel)
					maxlevel = orderlevel;

				ordertarget = orderlevel * BaseTarget;
				if(totalprofit > ordertarget)
				{
					closeOrder(orderticket, StrToInteger(data[i][2]));
				}
				else
				{
					if(line<11)
						displayOrderStatus(line, orderlevel, orderticket, totalprofit, ordertarget);
					line++;
				}
			}
		}
		currentLevel = maxlevel;
	}
	else if(result==0)
	{
		currentLevel = 0;
	}
	else
	{
		outputLog(query, "SQL_ERROR_CHECK_Current_ORDER");
	}
}

void checkPriceDifference()
{
	//-- get master broker price
	RefreshRates();
	if(Bid>0)
		localPrice[0] = Bid;
	else	
		localPrice[0] = 0;
	if(Ask>0)
		localPrice[1] = Ask;
	else	
		localPrice[1] = 0;
	localTimeCurrent = TimeLocal(); //localTimeCurrent = TimeCurrent();

	string data[][3];
	string query = StringConcatenate(
		"SELECT bidprice, askprice, timecurrent FROM `" + pricetable + "` ",
		"WHERE account=" + RemoteAccount + " AND broker=\'" +  RemoteBroker + "\'"
	);
	int result = mysqlFetchArray(dbConnectId, query, data);
	if(result>0)
	{
		remotePrice[0] 		= StrToDouble(data[0][0]);
		remotePrice[1] 		= StrToDouble(data[0][1]);
		remoteTimeCurrent 	= StrToInteger(data[0][2]);
	}
	else
	{
		outputLog(query, "SQL_ERROR_CHECK_Diff_Price");
	}

	//-- calu difference
	if(MathAbs(remoteTimeCurrent-localTimeCurrent)<2) //-- todo
	{
		if(remotePrice[0]>0 && localPrice[1]>0)
		{
			priceDifferenceBuy[0]	= remotePrice[0] - localPrice[1]; //remotebid-localask
			if(priceDifferenceBuy[0]<priceDifferenceBuy[1])
				priceDifferenceBuy[1] = priceDifferenceBuy[0];
			if(priceDifferenceBuy[0]>priceDifferenceBuy[2] || priceDifferenceBuy[2]==0)
				priceDifferenceBuy[2] = priceDifferenceBuy[0];
		}

		
		if(remotePrice[1]>0 && localPrice[0]>0)
		{
			priceDifferenceSell[0] 	= localPrice[0] - remotePrice[1]; //bid-ask
			if(priceDifferenceSell[0]<priceDifferenceSell[1])
				priceDifferenceSell[1] = priceDifferenceSell[0];
			if(priceDifferenceSell[0]>priceDifferenceSell[2] || priceDifferenceSell[2]==0)
				priceDifferenceSell[2] = priceDifferenceSell[0];
		}
	}
	else
	{
		priceDifferenceBuy[0] = 0;
		priceDifferenceSell[0] = 0;
	}
}

void closeOrder(int ticket, int slaveticket)
{
	int closePrice;
	color closeColor;

	if(OrderSelect(ticket, SELECT_BY_TICKET)==true)
	{
		if(OrderType()==OP_BUY)
		{
			closePrice = 0;
			closeColor = Blue;
		}
		else
		{
			closePrice = 1;
			closeColor = Red;
		}

		if(OrderClose(OrderTicket(), OrderLots(), localPrice[closePrice], 3, closeColor)==true)
		{
			//--close remote order
			string query = StringConcatenate(
				"UPDATE `_command` SET commandtype=2 ",
				"WHERE masteraccount=" + mInfo[15] + " AND masterbroker=\'" +  mInfo[1] + "\' AND masterorderticket=" + ticket + " AND slaveorderticket=" + slaveticket + " AND slaveorderstatus=1"
			);
			mysqlQuery(dbConnectId, query);
		}
	}
}

//-- debug
void initDebugInfo()
{
	int y = 0;

	//-- background
	ObjectCreate("background", OBJ_LABEL, 0, 0, 0);
	ObjectSetText("background", "g", 300, "Webdings", DarkGreen);
	ObjectSet("background", OBJPROP_BACK, 		TRUE);
	ObjectSet("background", OBJPROP_XDISTANCE, 	0);
	ObjectSet("background", OBJPROP_YDISTANCE, 	13);

	//-- broker price table
	//-- line 1
	y += 15;
	createTextObj("table_row_1_col_1", 5,	y, "Broker");
	createTextObj("table_row_1_col_2", 55,	y, "Account");
	createTextObj("table_row_1_col_3", 115,	y, "Time");
	createTextObj("table_row_1_col_4", 260,	y, "Bid");
	createTextObj("table_row_1_col_5", 325,	y, "Ask");
	//-- line 2
	y += 15;
	createTextObj("table_row_2_col_1", 5,	y, "Master", "Courier New", 9, White);
	createTextObj("table_row_2_col_2", 55,	y, mInfo[15], "Courier New", 9, White);
	createTextObj("table_row_2_col_3", 115,	y);
	createTextObj("table_row_2_col_4", 260,	y);
	createTextObj("table_row_2_col_5", 325,	y);
	//-- line 3
	y += 15;
	createTextObj("table_row_3_col_1", 5,	y, "Slave", "Courier New", 9, White);
	createTextObj("table_row_3_col_2", 55,	y, RemoteAccount, "Courier New", 9, White);
	createTextObj("table_row_3_col_3", 115,	y);
	createTextObj("table_row_3_col_4", 260,	y);
	createTextObj("table_row_3_col_5", 325,	y);

	//-- price difference table
	//-- line 5
	y += 30;
	createTextObj("table_row_5_col_1", 5,	y, "Diff");
	createTextObj("table_row_5_col_2", 55,	y, "Current");
	createTextObj("table_row_5_col_3", 130,	y, "HistoryLow");
	createTextObj("table_row_5_col_4", 225,	y, "HistoryHigh");
	//-- line 6
	y += 15;
	createTextObj("table_row_6_col_1", 5,	y, "Buy", "Courier New", 9, White);
	createTextObj("table_row_6_col_2", 55,	y);
	createTextObj("table_row_6_col_3", 130,	y);
	createTextObj("table_row_6_col_4", 225,	y);
	//-- line 7
	y += 15;
	createTextObj("table_row_7_col_1", 5,	y, "Sell", "Courier New", 9, White);
	createTextObj("table_row_7_col_2", 55,	y);
	createTextObj("table_row_7_col_3", 130,	y);
	createTextObj("table_row_7_col_4", 225,	y);

	//-- settings table
	//-- line 9
	y += 30;
	createTextObj("table_row_9_col_1", 5,	y, "BaseLots");
	createTextObj("table_row_9_col_2", 85,	y, "TholdPips");
	createTextObj("table_row_9_col_3", 175,	y, "BaseTarget");
	//-- line 10
	y += 15;
	createTextObj("table_row_10_col_1", 5,	y);
	createTextObj("table_row_10_col_2", 85,	y);
	createTextObj("table_row_10_col_3", 175,y);

	//-- order status table
	//-- line 11
	y += 30;
	createTextObj("table_row_11_col_1", 5,	y, "Level");
	createTextObj("table_row_11_col_2", 85,	y, "Ticket");
	createTextObj("table_row_11_col_3", 165,y, "Profit");
	createTextObj("table_row_11_col_4", 245,y, "Target");

	//-- footer
	createTextObj("footer", 5, 390, eaInfo[0]+" "+eaInfo[1]+" "+eaInfo[2], "Courier New", 9, DeepSkyBlue);
}

void updateDubugInfo()
{
	int digit = StrToInteger(mInfo[21]);

	setTextObj("table_row_2_col_3", TimeToStr(localTimeCurrent, TIME_DATE|TIME_SECONDS));
	setTextObj("table_row_2_col_4", DoubleToStr(localPrice[0], digit));
	setTextObj("table_row_2_col_5", DoubleToStr(localPrice[1], digit));

	setTextObj("table_row_3_col_3", TimeToStr(remoteTimeCurrent, TIME_DATE|TIME_SECONDS));
	setTextObj("table_row_3_col_4", DoubleToStr(remotePrice[0], digit));
	setTextObj("table_row_3_col_5", DoubleToStr(remotePrice[1], digit));

	setTextObj("table_row_6_col_2", DoubleToStr(priceDifferenceBuy[0], digit));
	setTextObj("table_row_6_col_3", DoubleToStr(priceDifferenceBuy[1], digit));
	setTextObj("table_row_6_col_4", DoubleToStr(priceDifferenceBuy[2], digit));

	setTextObj("table_row_7_col_2", DoubleToStr(priceDifferenceSell[0], digit));
	setTextObj("table_row_7_col_3", DoubleToStr(priceDifferenceSell[1], digit));
	setTextObj("table_row_7_col_4", DoubleToStr(priceDifferenceSell[2], digit));

	setTextObj("table_row_10_col_1", DoubleToStr(BaseLots, 2));
	setTextObj("table_row_10_col_2", DoubleToStr(TholdPips, StrToInteger(mInfo[21])));
	setTextObj("table_row_10_col_3", BaseTarget);
}

void createTextObj(string objName, int xDistance, int yDistance, string objText="", string font="Courier New", int fontsize=9, color fontcolor=GreenYellow)
{
	if(ObjectFind(objName)<0)
	{
		ObjectCreate(objName, OBJ_LABEL, 0, 0, 0);
		ObjectSetText(objName, objText, fontsize, font, fontcolor);
		ObjectSet(objName, OBJPROP_XDISTANCE,	xDistance);
		ObjectSet(objName, OBJPROP_YDISTANCE, 	yDistance);
	}
}

void setTextObj(string objName, string objText="", string font="Courier New", int fontsize=9, color fontcolor=White)
{
	if(ObjectFind(objName)>-1)
	{
		ObjectSetText(objName, objText, fontsize, font, fontcolor);
	}
}


//-- order obj display manage
void displayOrderStatus(int line, int level, int ticket, double profit, double target)
{
	line += 13; //11+1+1
	int y = line * 15;

	createTextObj(line+"_0", 5,  y, level, "Courier New", 9, White);
	createTextObj(line+"_1", 85, y, ticket,  "Courier New", 9, White);
	createTextObj(line+"_2", 165,y, DoubleToStr(profit, 2), "Courier New", 9, White);
	createTextObj(line+"_3", 245,y, DoubleToStr(target, 2), "Courier New", 9, White);
}

void deleteOrderStatus()
{
	for(int i=13; i<23; i++)
	{
		for(int j=0; j<4; j++)
		{	
			if(ObjectFind(i+"_"+j)>-1)
			{
				ObjectDelete(i+"_"+j);
			}
		}
	}
}





//-- use moneymanagment strategy get lots
double calcuLots(int _digit = 2)
{
	if(moneymanagment==false)
		return(BaseLots);

	double lots, rate, kd;

	kd = iCustom(NULL, 0, "Stochastic", kperiod, dperiod, kdslowing, 0, 0);

	if(kd>75)
		rate = 0.01;
	else
		rate = 0.005;

	if(AccountFreeMargin()>0)
	{
		lots = (AccountFreeMargin() * rate) / stoploss;
		lots = StrToDouble(DoubleToStr(lots, _digit));
	}

	return(lots);
}

*/