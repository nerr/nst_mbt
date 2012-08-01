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
 *
 * @Todo
 * # add money mangment
 */

//-- property info
#property copyright "Copyright ? 2012 Nerrsoft.com"
#property link 		"http://nerrsoft.com"

//-- extern var
extern string 	BaseSetting		= "---------Base Setting---------";
extern double 	BaseLots		= 0.2;
extern int 		BaseTarget		= 10;
extern int 	  	MagicNumber		= 9999;
extern double 	TholdPips		= 5;
extern string 	RemoteSetting	= "---------Remote Setting---------";
extern string 	RemoteAccount	= "4149641";
extern string 	RemoteBroker	= "FXPRO Financial Services Ltd";
extern string 	DBSetting		= "---------DB Setting---------";
extern string 	host			= "127.0.0.1";
extern string 	user			= "root";
extern string 	pass			= "911911";
extern string 	dbName			= "metatrader";
extern int 		port			= 3306;

//-- The information of this EA
string eaInfo[3];

//-- global var
string 		mInfo[22];
double 		localPrice[2], remotePrice[2];
double 		priceDifferenceBuy[3], priceDifferenceSell[3];
datetime 	localTimeCurrent, remoteTimeCurrent;
bool 		HaveOrder = false;
int 		currentLevel = 0; 

//-- include mysql wrapper
#include <mysql_v2.0.5.mqh>
int     socket   = 0;
int     client   = 0;
int     dbConnectId = 0;
bool    goodConnect = false;
//-- include common func
#include <nerr_smart_trader_common.mqh>

//-- init
int init()
{
	eaInfo[0]	= "NST-MBT-Master";
	eaInfo[1]	= "0.1.9 [dev]";
	eaInfo[2]	= "Copyright ? 2012 Nerrsoft.com";

	//-- get market information
	getInfo(mInfo);

	//-- connect mysql
	goodConnect = connectdb();

	if(!goodConnect) return (1);

	//-- calu thold pips
	if(StrToInteger(mInfo[21]) < 4)
		TholdPips = TholdPips * 0.01;
	else
		TholdPips = TholdPips * 0.0001;

	initDebugInfo();

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
	checkPriceDifference();
	//-- open order
	scanOpportunity();

	//-- check current order profit, waitting for close order
	checkCurrentOrder();
	//-- check bad order
	checkBadOrder();
	
	//-- output into to chart
	updateDubugInfo();

	//-- reconnect mysql per hour
	if((TimeLocal() % 3600)==0)
		connectdb();
	
	return(0);
}

void checkBadOrder()
{
	string data[][2];
	string query = StringConcatenate(
		"SELECT id,masterorderticket ",
		"FROM `_command` ",
		"WHERE masteraccount=" + mInfo[15] + " AND masterbroker=\'" +  mInfo[1] + "\' AND slaveaccount=" + RemoteAccount + " AND slavebroker=\'" +  RemoteBroker + "\' AND symbol=\'"+mInfo[20]+"\' AND slaveorderstatus=3"
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
						oStatus = OrderClose(OrderTicket(), OrderLots(), Bid, 1);
					else
						oStatus = OrderClose(OrderTicket(), OrderLots(), Ask, 1);
				}
				else	//-- bet begin, may be lost may be win.....
				{
					if(OrderType()==OP_BUY)
						oStatus = OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice()-Point*10, OrderOpenPrice()+Point*5, 1);
					else
						oStatus = OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice()+Point*10, OrderOpenPrice()-Point*5, 1);
				}
				//-- update to db
				if(oStatus==true)
					mysqlQuery(dbConnectId, "UPDATE `_command SET slaveorderstatus=2 WHERE id=" + commandid);
			}
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

	//-- open order
	if(priceDifferenceBuy[0] > TholdPips)
	{
		mutiple = MathFloor(priceDifferenceBuy[0]/TholdPips);
		if(mutiple>currentLevel)
		{
			comment = mutiple;
			sendAlert("Open Signal - Buy-"+mInfo[20]+"@" + priceDifferenceBuy[0] + "|L" + mutiple);

			//-- open buy order and send a sell command to remote db
			ordert = OrderSend(mInfo[20], OP_BUY, BaseLots*mutiple, localPrice[1], 0, 0, 0, comment, MagicNumber, 0, Blue);
			if(ordert>0)
			{
				query = StringConcatenate(
					"INSERT INTO `_command` ",
					"(masteraccount, masterbroker, slavebroker, slaveaccount, symbol, commandtype, masterorderticket, masteropenprice, pricedifference, lots, slaveorderstatus) VALUES ",
					"("+mInfo[15]+", \'"+mInfo[1]+"\', \'" + RemoteBroker + "\', "+RemoteAccount+", \'"+mInfo[20]+"\', 0, "+ordert+", "+localPrice[1]+", "+priceDifferenceSell[0]+", "+BaseLots*mutiple+", 0)");
				mysqlQuery(dbConnectId,query);
				currentLevel = mutiple;
			}
		}
	}
	else if(priceDifferenceSell[0] > TholdPips)
	{
		mutiple = MathFloor(priceDifferenceSell[0]/TholdPips);
		if(mutiple>currentLevel)
		{
			comment = mutiple;
			sendAlert("Open Signal - Sell-"+mInfo[20]+"@" + priceDifferenceSell[0] + "|L" + mutiple);

			//-- open sell order and send a buy command to remote db
			ordert = OrderSend(Symbol(), OP_SELL, BaseLots*mutiple, localPrice[0], 0, 0, 0, comment, MagicNumber, 0, Red);
			if(ordert>0)
			{
				query = StringConcatenate(
					"INSERT INTO `_command` ",
					"(masteraccount, masterbroker, slavebroker, slaveaccount, symbol, commandtype, masterorderticket, masteropenprice, pricedifference, lots, slaveorderstatus) VALUES ",
					"("+mInfo[15]+", \'"+mInfo[1]+"\', \'" + RemoteBroker + "\', "+RemoteAccount+", \'"+mInfo[20]+"\', 0, "+ordert+", "+localPrice[1]+", "+priceDifferenceSell[0]+", "+BaseLots*mutiple+", 0)"
				);
				mysqlQuery(dbConnectId,query);
				currentLevel = mutiple;
			}
		}
	}
}

void checkCurrentOrder()
{
	int index;
	int orderlevel, maxlevel;
	double totalprofit, ordertarget;
	int orderticket;

	string data[][3];
	string query = StringConcatenate(
		"SELECT slaveprofit,masterorderticket,slaveorderticket FROM `_command` ",
		"WHERE masteraccount=" + mInfo[15] + " AND masterbroker=\'" +  mInfo[1] + "\' AND slaveaccount=" + RemoteAccount + " AND slavebroker=\'" +  RemoteBroker + "\' AND symbol=\'"+mInfo[20]+"\' AND slaveorderstatus=1"
	);
	int result = mysqlFetchArray(dbConnectId, query, data);
	if(result>0)
	{
		int rows = ArrayRange(data, 0);
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
					deleteOrderInfoLine(orderlevel);
				}
				else
				{
					updateOrderInfoLine(i, orderlevel, orderticket, totalprofit, ordertarget);
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
		"SELECT bidprice, askprice, timecurrent FROM `" + mInfo[20] + "` ",
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

	if(OrderSelect(ticket, SELECT_BY_TICKET)==true)
	{
		if(OrderType()==OP_BUY)
			closePrice = 0;
		else
			closePrice = 1;

		if(OrderClose(OrderTicket(), OrderLots(), localPrice[closePrice], 3, Red )==true)
		{
			//--close remote order
			string query = StringConcatenate(
				"UPDATE `_command SET commandtype=2 ",
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
	createTextObj("table_row_2_col_1", 5,	y, "Local", "Courier New", 9, White);
	createTextObj("table_row_2_col_2", 55,	y, mInfo[15], "Courier New", 9, White);
	createTextObj("table_row_2_col_3", 115,	y);
	createTextObj("table_row_2_col_4", 260,	y);
	createTextObj("table_row_2_col_5", 325,	y);
	//-- line 3
	y += 15;
	createTextObj("table_row_3_col_1", 5,	y, "Remote", "Courier New", 9, White);
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

	setTextObj("table_row_10_col_1", DoubleToStr(BaseLots, 1));
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

void updateOrderInfoLine(int line, int level, int ticket, double profit, double target)
{
	if(ObjectFind(level+"1")<0)
	{
		line += 12; //11+1
		int y = line * 15;

		createTextObj(level+"_1", 5,	y, level);
		createTextObj(level+"_2", 85,	y, ticket);
		createTextObj(level+"_3", 165,	y, DoubleToStr(profit, 2));
		createTextObj(level+"_4", 245,	y, DoubleToStr(target, 2));
	}
	else
	{
		setTextObj(level+"_3", DoubleToStr(profit, 2));
		setTextObj(level+"_4", DoubleToStr(target, 2));
	}
}

void deleteOrderInfoLine(int level)
{
	if(ObjectFind(level+"_1")>0)
	{
		for(int i=1; i<5; i++)
		{
			ObjectDelete(level+"_"+i);
		}
	}
}

int connectdb()
{
	//-- close connection if exists
	if(dbConnectId>0)
		mysqlDeinit(dbConnectId);

	//-- connect mysql
	int result = mysqlInit(dbConnectId, host, user, pass, dbName, port, socket, client);

	return (result);
}