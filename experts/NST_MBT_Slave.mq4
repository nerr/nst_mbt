/* Nerr SmartTrader - Multi Broker Trader - Slave
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
 * v0.0.2  [dev] 2012-06-11 complete slave client main part programe.
 * v0.0.3  [dev] 2012-06-14 fix the create table (copy symbol table struc) bug.
 * v0.0.4  [dev] 2012-06-28 finished "updateProiftToDB()".
 * v0.0.5  [dev] 2012-06-29 fix table `tradecommand` field typo
 * v0.0.6  [dev] 2012-06-29 add more status type in field `orderstatus` 
 * v0.0.7  [dev] 2012-07-02 fix orderAction func bug.
 * v0.1.0  [dev] 2012-07-05 update new version mysql wrapper 2.0.5 and recode slave client
 * v0.1.1  [dev] 2012-07-12 fix updateProfitToDb() bug
 * v0.1.2  [dev] 2012-07-13 update order profit calu func.
 * v0.1.3  [dev] 2012-07-31 update table `_command`, add two field `masterbroker` and `masteraccount`
 * v0.1.4  [dev] 2012-08-01 add connectdb() func, add reconnectdb in start() func.
 * v0.1.5  [dev] 2012-08-02 add an alert output when re-connect db fail.
 * v0.1.6  [dev] 2012-08-02	update table `_command` add two fields, consummate "orderAction()" func.
 * 
 * `command` comment
 * commandtype:
 * 	0-buy / 1-sell / 2-close
 * slaveorderstatus:
 * 	0-newcommand / 1-opened / 2-closed / 3-open order failed / 4-close order failed
 */

//-- property info
#property copyright "Copyright ? 2012 Nerrsoft.com"
#property link      "http://nerrsoft.com"

//-- extern var
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
double 		localPrice[2];
datetime 	localTimeCurrent;
double 		basepip;

//-- include mysql wrapper
#include <mysql_v2.0.5.mqh>
int     socket   = 0;
int     client   = 0;
int     dbConnectId = 0;
bool    goodConnect = false;

#include <nerr_smart_trader_common.mqh>

//-- init
int init()
{
	eaInfo[0]	= "NST-MBT-Slave";
	eaInfo[1]	= "0.1.6 [dev]";
	eaInfo[2]	= "Copyright ? 2012 Nerrsoft.com";
	
	//-- get market information
	getInfo(mInfo);

	//-- connect mysql
	goodConnect = connectdb();

	if(!goodConnect)
	{
		outputLog("connect db failed", "Error");
		return (1);
	}


	//-- create price table if it not exists
	string query = StringConcatenate(
		"CREATE TABLE IF NOT EXISTS `" + mInfo[20] + "` (",
		"`broker`  varchar(48) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT \'\' ,",
		"`account`  int(10) NOT NULL ,",
		"`timecurrent`  int(10) NULL DEFAULT NULL ,",
		"`bidprice`  float NULL DEFAULT NULL ,",
		"`askprice`  float NULL DEFAULT NULL ,",
		"PRIMARY KEY (`account`),",
		"INDEX `idx_accountbroker` (`broker`, `account`) USING BTREE ",
		")",
		"ENGINE=InnoDB ",
		"DEFAULT CHARACTER SET=utf8 COLLATE=utf8_general_ci ",
		"ROW_FORMAT=COMPACT"
	);
	mysqlQuery(dbConnectId, query);

	//-- create command table if it not exists
	query = StringConcatenate(
		"CREATE TABLE IF NOT EXISTS `_command` (",
		"`id`  int(11) NOT NULL AUTO_INCREMENT ,",
		"`masterbroker`  varchar(48) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' ,",
		"`masteraccount`  int(10) NOT NULL ,",
		"`slavebroker`  varchar(48) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT '' ,",
		"`slaveaccount`  int(10) NOT NULL ,",
		"`symbol`  varchar(6) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL ,",
		"`commandtype`  tinyint(4) UNSIGNED NOT NULL ,",
		"`masterorderticket`  int(11) NOT NULL ,",
		"`masteropenprice`  float NULL DEFAULT NULL ,",
		"`pricedifference`  float NULL DEFAULT NULL ,",
		"`lots`  float NULL DEFAULT NULL ,",
		"`slaveorderticket`  int(11) NULL DEFAULT NULL ,",
		"`slaveorderstatus`  tinyint(4) UNSIGNED NULL DEFAULT NULL ,",
		"`slaveprofit`  float NULL DEFAULT NULL ,",
		"`createtime`  int(11) NULL DEFAULT NULL ,",
		"`tholdpips`  float NULL DEFAULT NULL ,",
		"PRIMARY KEY (`id`),",
		"INDEX `idx_orderticket` (`masterorderticket`, `slaveorderticket`) USING BTREE ,",
		"INDEX `idx_orderstatus` (`commandtype`, `slaveorderstatus`) USING BTREE ,",
		"INDEX `idx_brokeraccountsymbol` (`slavebroker`, `slaveaccount`, `symbol`) USING BTREE ",
		")",
		"ENGINE=InnoDB ",
		"DEFAULT CHARACTER SET=utf8 COLLATE=utf8_general_ci ",
		"COMMENT=\'commandtype:[0-buy][1-sell][2-close]\r\norderstatus:[1-opened][2-closed][3-open order failed][4-close order failed]\' ",
		"AUTO_INCREMENT=1 ",
		"ROW_FORMAT=COMPACT "
	);
	mysqlQuery(dbConnectId, query);

	//-- insert record if not exists
	query = StringConcatenate(
		"INSERT IGNORE INTO `" + mInfo[20] + "` (`broker`, `account`) ",
		"VALUES (\'" + mInfo[1] + "\', " + mInfo[15] + ")"
	);
	mysqlQuery(dbConnectId,query);

	//-- base pip
	if(StrToInteger(mInfo[21]) < 4)
		basepip = 0.01;
	else
		basepip = 0.0001;

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
	//-- check new trade command (orderstatus==0)
	checkTradeCommand();

	//-- update profit to db if have
	updateProfitToDb();

	//-- update current symbol price to db
	updatePriceToDb();

	//-- output infarmation into to chart
	watermark_slave(eaInfo, localPrice, localTimeCurrent, mInfo);

	//-- reconnect mysql per hour
	/*if((TimeLocal() % 3600)==0)
	{
		goodConnect = connectdb();

		if(!goodConnect)
		{
			outputLog("connect db failed", "Error");
			return (1);
		}
	}*/

	return(0);
}

void checkTradeCommand()
{
	string data[][8];
	string query = StringConcatenate(
		"SELECT id,commandtype,masterorderticket,masteropenprice,pricedifference,lots,slaveorderstatus,slaveorderticket,createtime,tholdpips ",
		"FROM `_command` WHERE (slaveorderstatus<2 OR slaveorderstatus>3) AND slavebroker=\'" + mInfo[1] + "\' AND slaveaccount=" + mInfo[15] + " AND symbol=\'" + mInfo[20] + "\'"
	);
	int result = mysqlFetchArray(dbConnectId, query, data);
	if(result>0)
	{
		int rows = ArrayRange(data, 0);

		for(int i = 0; i < rows; i++)
		{
			orderAction(data, i);
		}
	}
	else if(result<0)
	{
		outputLog(query, "SQL_ERROR_CHECK_COMMAND");
	}
}

void orderAction(string d[][], int key) //-- todo: check price difference
{
	int commandid 			= StrToInteger(d[key][0]);
	int commandtype 		= StrToInteger(d[key][1]);
	int slaveorderstatus 	= StrToInteger(d[key][6]);
	int magicnumber			= StrToInteger(d[key][2]);
	int slaveorderticket	= StrToInteger(d[key][7]);
	double lots 			= StrToDouble(d[key][5]);
	double pricedifference	= StrToDouble(d[key][4]);
	double masteropenprice	= StrToDouble(d[key][3]);
	int currenttime			= StrToInteger(d[key][8]);
	double tholdpips		= StrToDouble(d[key][9]);

	switch(slaveorderstatus)
	{
		case 0: //- new command, need open order
			//-- check time available
			if((TimeLocal() - currenttime) > 5)
			{
				//respondCommand(3, commandid);
				//break;
			}

			//-- todo
			//-- get open price
			double openprice;
			if(commandtype==0)
			{
				openprice = Ask;
				if((masteropenprice - openprice) < (tholdpips / 2))
				{
					respondCommand(3, commandid);
					break;
				}
			}
			else if(commandtype==1)
			{
				openprice = Bid;
				if((openprice - masteropenprice) < (tholdpips / 2))
				{
					respondCommand(3, commandid);
					break;
				}
			}

			//-- send open order command
			int orderId = OrderSend(mInfo[20], commandtype, lots, openprice, 3, 0, 0, "", magicnumber, 0);
			//-- return result to command record
			if(orderId>0)
				mysqlQuery(dbConnectId, "UPDATE `_command` SET slaveorderticket=" + orderId + ", slaveorderstatus=1" + " WHERE id=" + commandid);
			else
				respondCommand(3, commandid);

			break;
		case 1: //- opened order, waitting for close
			if(commandtype==2)
			{
				if(OrderSelect(slaveorderticket, SELECT_BY_TICKET)==true)
				{
					//-- get open price
					double closeprice;
					if(OrderType()==OP_BUY)
						closeprice = Bid;
					else
						closeprice = Ask;

					//-- send open order command
					if(OrderClose(slaveorderticket, OrderLots(), closeprice, 3) == true)
						respondCommand(2, commandid);
					else
						respondCommand(4, commandid);
				}
			}
			break;
		case 4: //- the order need to close 
			if(commandtype==2)
			{
				if(OrderSelect(slaveorderticket, SELECT_BY_TICKET)==true)
				{
					//-- get open price
					double speccloseprice;
					if(OrderType()==OP_BUY)
						speccloseprice = Bid;
					else
						speccloseprice = Ask;

					//-- send open order command
					if(OrderClose(OrderTicket(), OrderLots(), speccloseprice, 3) == true)
						respondCommand(2, commandid);
					if(GetLastError()==4108)
						respondCommand(2, commandid);
				}
				else
				{
					respondCommand(2, commandid);
				}
			}
			break;
		default: break;
	}
}

void updateProfitToDb()
{
	int slaveorderticket, commandid;

	string data[][2];
	string query = StringConcatenate(
		"SELECT id,slaveorderticket ",
		"FROM `_command` WHERE slaveorderstatus=1 AND commandtype<2 AND slavebroker=\'" + mInfo[1] + "\' AND slaveaccount=" + mInfo[15]
	);

	int result = mysqlFetchArray(dbConnectId, query, data);

	if(result>0)
	{
		int rows = ArrayRange(data, 0);
		double profit = 0;

		for(int i = 0; i < rows; i++)
		{
			slaveorderticket = StrToInteger(data[i][1]);
			commandid = StrToInteger(data[i][0]);
			if(OrderSelect(slaveorderticket, SELECT_BY_TICKET)==true)
			{
				profit = OrderProfit() + OrderSwap() + OrderCommission();
				mysqlQuery(dbConnectId, "UPDATE `_command` SET slaveprofit=" + profit + " WHERE id=" + commandid);
			}
		}
	}
	else if(result<0)
	{
		outputLog(query, "SQL_ERROR_UPDATE_PROFIT");
	}
}

void updatePriceToDb()
{
	RefreshRates();
	//-- get current price - bid, ask and current time
	if(Bid>0)
		localPrice[0] = Bid;
	else
		localPrice[0] = 0;
	if(Ask>0)
		localPrice[1] = Ask;
	else
		localPrice[1] = 0;
	
	localTimeCurrent = TimeLocal(); //localTimeCurrent = TimeCurrent();

	//-- update to db
	string query = StringConcatenate(
		"UPDATE `" + mInfo[20] + "` ",
		"SET timecurrent=" + localTimeCurrent + ", bidprice=" + localPrice[0] + ", askprice=" + localPrice[1] + " ",
		"WHERE account=" + mInfo[15] + " and broker=\'" +  mInfo[1] + "\'"
	);
	mysqlQuery(dbConnectId, query);
}

int connectdb()
{
	//-- close connection if exists
	if(dbConnectId>0)
		mysqlDeinit(dbConnectId);

	//-- connect mysql
	bool result = mysqlInit(dbConnectId, host, user, pass, dbName, port, socket, client);

	return (result);
}

void respondCommand(int status, int id)
{
	mysqlQuery(dbConnectId, "UPDATE `_command` SET slaveorderstatus=" + status + " WHERE id=" + id);
}