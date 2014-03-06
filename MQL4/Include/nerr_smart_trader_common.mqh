//-- output log
void outputLog(string logtext, string type="Information")
{
	string text = ">>>" + type + ":" + logtext;
	Print (text);
}

//-- send alert
void sendAlert(string text = "null")
{
	outputLog(text);
	PlaySound("alert.wav");
	Alert(text);
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
	// get account name
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

//-- display watermark
void watermark_slave(string einfo[], double lp[], int lt, string mi[])
{
	string ComSpacer = "";
	int digits = StrToInteger(mi[21]);

	ComSpacer = ComSpacer
	+ "\n"
	+ "\n"
	+ "\n Version " + einfo[1]
	+ "\n " + einfo[2]
	+ "\n http://nerrsoft.com"
	+ "\n -----------------------------------------------"
	+ "\n " + mi[1]
	+ "\n " + TimeToStr(lt, TIME_DATE|TIME_SECONDS)
	+ "\n ASK: " + DoubleToStr(lp[1], digits)
	+ "\n BID: " + DoubleToStr(lp[0], digits)
	+ "\n -----------------------------------------------";
	
	Comment(ComSpacer);

	if (ObjectFind("TITLE") < 0) {
		ObjectCreate("TITLE", OBJ_LABEL, 0, 0, 0);
		ObjectSetText("TITLE", einfo[0], 9, "Courier New", White);
		ObjectSet("TITLE", OBJPROP_CORNER, 0);
		ObjectSet("TITLE", OBJPROP_BACK, FALSE);
		ObjectSet("TITLE", OBJPROP_XDISTANCE, 9);
		ObjectSet("TITLE", OBJPROP_YDISTANCE, 23);
	}

	if (ObjectFind("BGINFO1") < 0) {
		ObjectCreate("BGINFO1", OBJ_LABEL, 0, 0, 0);
		ObjectSetText("BGINFO1", "g", 110, "Webdings", MediumVioletRed);
		ObjectSet("BGINFO1", OBJPROP_CORNER, 0);
		ObjectSet("BGINFO1", OBJPROP_BACK, TRUE);
		ObjectSet("BGINFO1", OBJPROP_XDISTANCE, 5);
		ObjectSet("BGINFO1", OBJPROP_YDISTANCE, 15);
	}

	if (ObjectFind("BGINFO2") < 0) {
		ObjectCreate("BGINFO2", OBJ_LABEL, 0, 0, 0);
		ObjectSetText("BGINFO2", "g", 110, "Webdings", OliveDrab);
		ObjectSet("BGINFO2", OBJPROP_BACK, TRUE);
		ObjectSet("BGINFO2", OBJPROP_XDISTANCE, 5);
		ObjectSet("BGINFO2", OBJPROP_YDISTANCE, 45);
	}

	/*
	if (ObjectFind("FOOTER") < 0) {
		ObjectCreate("FOOTER", OBJ_LABEL, 0, 0, 0);
		ObjectSetText("FOOTER", eaName + " " + eaVersion + " " +  eaCopyright, 9, "Arial", DeepSkyBlue);
		ObjectSet("FOOTER", OBJPROP_CORNER, 2);
		ObjectSet("FOOTER", OBJPROP_XDISTANCE, 5);
		ObjectSet("FOOTER", OBJPROP_YDISTANCE, 10);
	}*/
}