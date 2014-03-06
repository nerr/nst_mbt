int libTaGetAvaiableRings(string &_ring[][], string _currenties[], string _ext)
{
    ArrayResize(_ring, 500);

    int _currnum = ArrayRange(_currenties, 0);
    int i, j, num;

    string _syma, _symb, _symc, _curra1, _curra2, _currb1, _currb2;


    for(i = 0; i < _currnum; i++)
    {
        _syma   = _currenties[i];
        _curra1 = StringSubstr(_currenties[i], 0, 3);
        _curra2 = StringSubstr(_currenties[i], 3, 3);

        for(j = 0; j < _currnum; j++)
        {
            if(_currenties[i] == _currenties[j])
                continue;

            _symb   = _currenties[j];
            _currb1 = StringSubstr(_currenties[j], 0, 3);
            _currb2 = StringSubstr(_currenties[j], 3, 3);

            _symc   = _currb2 + _curra2 + _ext;

            if(_curra1 == _currb1 && MarketInfo(_symc, MODE_ASK) > 0)
            {
                _ring[num][0] = _syma;
                _ring[num][1] = _symb;
                _ring[num][2] = _symc;
                num++;
            }
        }
    }

    ArrayResize(_ring, num);

    return(num);
}

//--
int libTaGetProfitableRings(string &_pring[][], string &_ring[][], int _ml, int _rrtriger = 0)
{
    ArrayResize(_pring, 500);

    double _lTotal, _sTotal, _rMarginRequire, _rrl, _rrs;
    int _num = ArrayRange(_ring, 0);
    int _n = 0;

    if(_num <= 0)
        return(0);

    for(int i = 0; i < _num; i++)
    {
        _lTotal = libTaRingTotalSwap(_ring[i][0], _ring[i][1], _ring[i][2], 0);
        _sTotal = libTaRingTotalSwap(_ring[i][0], _ring[i][1], _ring[i][2], 1);

        _rMarginRequire  = libSymbolMarginRequire(_ring[i][0], 1);
        _rMarginRequire += libSymbolMarginRequire(_ring[i][1], 1);
        _rMarginRequire += libSymbolMarginRequire(_ring[i][2], MarketInfo(_ring[i][1], MODE_ASK));


        _rrl = _lTotal * 360 / _rMarginRequire * 100;
        _rrs = _sTotal * 360 / _rMarginRequire * 100;

        if(_lTotal > 0 && _rrl >= _rrtriger)
        {
            _pring[_n][0] = _ring[i][0];
            _pring[_n][1] = _ring[i][1];
            _pring[_n][2] = _ring[i][2];
            _pring[_n][3] = "L-S";
            _pring[_n][4] = DoubleToStr(_lTotal, 2);
            _pring[_n][5] = DoubleToStr(_rrl, 2);
            _pring[_n][6] = DoubleToStr(_rMarginRequire, 2);

            _n++;
        }
        
        if(_sTotal > 0 && _rrs >= _rrtriger)
        {
            _pring[_n][0] = _ring[i][0];
            _pring[_n][1] = _ring[i][1];
            _pring[_n][2] = _ring[i][2];
            _pring[_n][3] = "S-L";
            _pring[_n][4] = DoubleToStr(_sTotal, 2);
            _pring[_n][5] = DoubleToStr(_rrs, 2);
            _pring[_n][6] = DoubleToStr(_rMarginRequire, 2);
            _n++;
        }
    }

    ArrayResize(_pring, _n);

    return(_n);
}

//--
double libTaRingTotalSwap(string _syma, string _symb, string _symc, int _ot)
{
    double _swap = 0;
    double _bsymprice = MarketInfo(_symb, 10 - _ot);

    _swap += libTaSymbolSwap(_syma, _ot);
    if(_ot == 0)
        _swap += libTaSymbolSwap(_symb, 1) + libTaSymbolSwap(_symc, 1) * _bsymprice;
    else
        _swap += libTaSymbolSwap(_symb, 0) + libTaSymbolSwap(_symc, 0) * _bsymprice;

    return(_swap);
}

double libTaSymbolSwap(string _sy, int _ot, double _lot = 1)
{
    int _swaptype = MarketInfo(_sy, MODE_SWAPTYPE);
    double _tickvalue, _swap;
    /*
    string _swapmethod = "";

    if(Swap_Type == 0) _swapmethod = "is in points";
    if(Swap_Type == 1) _swapmethod = "is in the symbol base currency";
    if(Swap_Type == 2) _swapmethod = "is by interest";
    if(Swap_Type == 3) _swapmethod = "is in the margin currency";*/

    if(_swaptype == 0)
    {
        _tickvalue = MarketInfo(_sy, MODE_TICKVALUE);
        _swap      = MarketInfo(_sy, 18 + _ot) * _tickvalue * _lot;
    }

    return(_swap);
}

double libTaRingFPI(string _syma, string _symb, string _symc, int _t)
{
    if(_t == 0)
        return(MarketInfo(_syma, MODE_ASK) / (MarketInfo(_symb, MODE_BID) * MarketInfo(_symc, MODE_BID)));
    else
        return(MarketInfo(_syma, MODE_BID) / (MarketInfo(_symb, MODE_ASK) * MarketInfo(_symc, MODE_ASK)));
}


double libTaRingCLot(string _syma, string _symb, string _symc, int _t)
{
    
}







/*
    old funcs
*/

//-- find available rings
string findAvailableRing(string &_ring[][], string _currencies, string _symExt)
{
    string avasymbols[100][2];
    findAvailableSymbol(avasymbols, _currencies, _symExt);

    int symbolnum = ArrayRange(avasymbols, 0);

    int i, j;
    int n = 1;
    for(i = 0; i < symbolnum; i++)
    {
        for(j = 0; j < symbolnum; j++)
        {
            if(i != j && avasymbols[i][0] == avasymbols[j][0] && avasymbols[i][1] != avasymbols[j][1])
            {
                if(MarketInfo(avasymbols[j][1] + avasymbols[i][1] + _symExt, MODE_ASK) > 0)
                {
                    _ring[n][1] = avasymbols[i][0] + avasymbols[i][1] + _symExt;
                    _ring[n][2] = avasymbols[j][0] + avasymbols[j][1] + _symExt;
                    _ring[n][3] = avasymbols[j][1] + avasymbols[i][1] + _symExt;
                    n++;
                }
            }
        }
    }
    ArrayResize(_ring, n);
}

//-- find available symbols
string findAvailableSymbol(string &_symbols[][], string _currencies, string _symExt)
{
    int currencynum = StringLen(_currencies) / 4;
    string currencyarr[100];
    ArrayResize(currencyarr, currencynum);

    int i, j, n;
    //-- make currency array
    for(i = 0; i < currencynum; i++)
        currencyarr[i] = StringSubstr(_currencies, i * 4, 3);
    //-- check available symbol
    for(i = 0; i < currencynum; i++)
    {
        for(j = 0; j < currencynum; j++)
        {
            if(i != j)
            {
                if(MarketInfo(currencyarr[i]+currencyarr[j] + _symExt, MODE_ASK) > 0)
                {
                    _symbols[n][0] = currencyarr[i];
                    _symbols[n][1] = currencyarr[j];
                    n++;
                }
            }
        }
    }
    //-- resize array
    ArrayResize(_symbols, n);
}

//-- open ring _direction = 0(buy)/1(sell)
bool openRing(int _direction, int _index, double _price[], double _fpi, string _ring[][], int _magicnumber, double _baselots, int _lotsdigit)
{
    int ticketno[4];
    int b_c_direction, i, limit_direction;
    
    //-- adjust b c order direction
    if(_direction==0)
        b_c_direction = 1;
    else if(_direction==1)
        b_c_direction = 0;

    //-- make comment string
    string commentText = "|" + _direction + "@" + _fpi;

    //-- calculate last symbol order losts
    double c_lots = NormalizeDouble(_baselots * _price[2], _lotsdigit);
    c_lots = getValidLots(c_lots, _ring[_index][3]);


    //-- open order a
    ticketno[1] = OrderSend(_ring[_index][1], _direction, _baselots, _price[1], 0, 0, 0, _index + "#1" + commentText, _magicnumber);
    if(ticketno[1] <= 0)
    {
        if(_direction==0 && MarketInfo(_ring[_index][1], MODE_ASK) < _price[1])
            ticketno[1] = OrderSend(_ring[_index][1], _direction, _baselots, MarketInfo(_ring[_index][1], MODE_ASK), 0, 0, 0, commentText, _magicnumber);
        else if(_direction==1 && MarketInfo(_ring[_index][1], MODE_BID) > _price[1])
            ticketno[1] = OrderSend(_ring[_index][1], _direction, _baselots, MarketInfo(_ring[_index][1], MODE_BID), 0, 0, 0, commentText, _magicnumber);
    }
    if(ticketno[1] > 0)
        libDebugOutputLog("nst_ta - First order opened. [" + _ring[_index][1] + "]", "Trading info");
    else
    {
        libDebugOutputLog("nst_ta - First order can not be send. cancel ring. [" + _ring[_index][1] + "][" + libDebugErrDesc(GetLastError()) + "]", "Trading error");
        //-- exit openRing func
        return(false);
    }


    //-- open order b
    ticketno[2] = OrderSend(_ring[_index][2], b_c_direction, _baselots, _price[2], 0, 0, 0, _index + "#2" + commentText, _magicnumber);
    if(ticketno[2] <= 0)
    {
        if(b_c_direction==0 && MarketInfo(_ring[_index][2], MODE_ASK) < _price[2])
            ticketno[2] = OrderSend(_ring[_index][2], _direction, _baselots, MarketInfo(_ring[_index][2], MODE_ASK), 0, 0, 0, commentText, _magicnumber);
        else if(b_c_direction==1 && MarketInfo(_ring[_index][2], MODE_BID) > _price[2])
            ticketno[2] = OrderSend(_ring[_index][2], _direction, _baselots, MarketInfo(_ring[_index][2], MODE_BID), 0, 0, 0, commentText, _magicnumber);
    }
    if(ticketno[2] > 0)
        libDebugOutputLog("nst_ta - Second order opened. [" + _ring[_index][2] + "]", "Trading info");
    else
    {
        libDebugOutputLog("nst_ta - Second order can not be send. open limit order. [" + _ring[_index][2] + "][" + libDebugErrDesc(GetLastError()) + "]", "Trading error");

        limit_direction = b_c_direction + 2;

        ticketno[2] = OrderSend(_ring[_index][2], limit_direction, _baselots, _price[2], 0, 0, 0, _index + "#2" + commentText, _magicnumber);
        if(ticketno[2] > 0)
            libDebugOutputLog("nst_ta - Second limit order opened. [" + _ring[_index][2] + "]", "Trading info");
        else
            libDebugOutputLog("nst_ta - Second limit order can not be send. [" + _ring[_index][2] + "][" + libDebugErrDesc(GetLastError()) + "]", "Trading error");
    }


    //-- open order c
    ticketno[3] = OrderSend(_ring[_index][3], b_c_direction, c_lots, _price[3], 0, 0, 0, _index + "#3" + commentText, _magicnumber);
    if(ticketno[3] <= 0)
    {
        if(b_c_direction==0 && MarketInfo(_ring[_index][3], MODE_ASK) < _price[3])
            ticketno[3] = OrderSend(_ring[_index][3], _direction, c_lots, MarketInfo(_ring[_index][3], MODE_ASK), 0, 0, 0, commentText, _magicnumber);
        else if(b_c_direction==1 && MarketInfo(_ring[_index][3], MODE_BID) > _price[3])
            ticketno[3] = OrderSend(_ring[_index][3], _direction, c_lots, MarketInfo(_ring[_index][3], MODE_BID), 0, 0, 0, commentText, _magicnumber);
    }
    if(ticketno[3] > 0)
        libDebugOutputLog("nst_ta - Third order opened. [" + _ring[_index][3] + "]", "Trading info");
    else
    {
        libDebugOutputLog("nst_ta - Third order can not be send. open limit order. [" + _ring[_index][3] + "][" + libDebugErrDesc(GetLastError()) + "]", "Trading error");

        limit_direction = b_c_direction + 2;
        
        ticketno[3] = OrderSend(_ring[_index][3], limit_direction, c_lots, _price[3], 0, 0, 0, _index + "#3" + commentText, _magicnumber);
        if(ticketno[3] > 0)
            libDebugOutputLog("nst_ta - Third limit order opened. [" + _ring[_index][3] + "]", "Trading info");
        else
            libDebugOutputLog("nst_ta - Third limit order can not be send. [" + _ring[_index][3] + "][" + libDebugErrDesc(GetLastError()) + "]", "Trading error");
    }

    return(true);
}


//-- check unavailable symbol of current broker
void checkUnavailableSymbol(string _ring[][], string &_Ring[][], int _ringnum)
{
    int range = ArrayRange(_ring, 0);
    ArrayResize(_Ring, range);
    _ringnum = 0;

    //-- check unavailable symbol
    for(int i = 1; i < range; i ++)
    {
        for(int j = 1; j < 4; j ++)
        {
            MarketInfo(_ring[i][j], MODE_ASK);
            if(GetLastError() == 4106)
            {
                libDebugOutputLog("This broker do not support symbol [" + _ring[i][j] + "]", "Information");
                break;
            }
            if(j==3) 
            {
                _ringnum++;
                _Ring[_ringnum][1] = _ring[i][1];
                _Ring[_ringnum][2] = _ring[i][2];
                _Ring[_ringnum][3] = _ring[i][3];
            }
        }
    }

    _ringnum++;
    ArrayResize(_Ring, _ringnum);
}



/*
 * Order management funcs
 *
 */


//-- check ring order have ring index or not
int findRingOrdIdx(int _roticket[][], double _roprofit[][], int _ringindex, double _fpi)
{
    int size = ArrayRange(_roticket, 0);
    for(int i = 0; i < size; i++)
    {
        if(_roticket[i][0] == _ringindex && _roprofit[i][5] == _fpi)
            return(i);
    }
    return(-1);
}

//-- get order information by order comment string
void getInfoByComment(string _comment, int &_ringindex, int &_symbolindex, int &_direction, double &_fpi)
{
    int verticalchart   = StringFind(_comment, "|", 0);
    int atchart         = StringFind(_comment, "@", 0);
    int sharpchart      = StringFind(_comment, "#", 0);

    _fpi        = StrToDouble(StringSubstr(_comment, atchart+1));
    _direction  = StrToDouble(StringSubstr(_comment, verticalchart+1, 1));
    _ringindex  = StrToInteger(StringSubstr(_comment, 0, sharpchart));
    _symbolindex= StrToInteger(StringSubstr(_comment, sharpchart+1, 1));
}

//-- get valid lots
double getValidLots(double _lots, string _symbol)
{
    double minlots = MarketInfo(_symbol, MODE_MINLOT);

    _lots = minlots * MathRound(_lots / minlots);

    return(_lots);
}