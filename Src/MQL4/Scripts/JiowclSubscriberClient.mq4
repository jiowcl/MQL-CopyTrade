//+------------------------------------------------------------------+
//|                                       JiowclSubscriberClient.mq4 |
//|                                Copyright 2017-2021, Ji-Feng Tsai |
//|                                        https://github.com/jiowcl |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2021, Ji-Feng Tsai"
#property link        "https://github.com/jiowcl/MQL-CopyTrade"
#property version     "1.12"
#property description "MT4 Copy Trade Subscriber Application. Subscribe order status from source signal trader."
#property strict
#property show_inputs

#include <Zmq/Zmq.mqh>

//--- Inputs
input string Server                  = "tcp://localhost:5559";  // Subscribe server ip
input uint   ServerDelayMilliseconds = 300;                     // Subscribe from server delay milliseconds (Default is 300)
input bool   ServerReal              = false;                   // Under real server (Default is false)
input string SignalAccount           = "";                      // Subscribe signal account from server (Default is empty) 
input double MinLots                 = 0.00;                    // Limit the minimum lots (Default is 0.00)
input double MaxLots                 = 0.00;                    // Limit the maximum lots (Default is 0.00)
input double PercentLots             = 100;                     // Lots Percent from Signal (Default is 100)
input int    Slippage                = 3;
input bool   AllowOpenTrade          = true;                    // Allow Open a New Order (Default is true)
input bool   AllowCloseTrade         = true;                    // Allow Close a Order (Default is true)
input bool   AllowModifyTrade        = true;                    // Allow Modify a Order (Default is true)
input string AllowSymbols            = "";                      // Allow Trading Symbols (Ex: EURUSDq,EURUSDx,EURUSDa)
input bool   InvertOrder             = false;                   // Invert original trade direction (Default is false)
input double MinFreeMargin           = 0.00;                    // Minimum Free Margin to Open a New Order (Default is 0.00)
input string SymbolPrefixAdjust      = "";                      // Adjust the Symbol Name as Local Symbol Name (Ex: d=q,d=)

//--- Globales Struct
struct ClosedOrder 
  { 
    int s_login;
    int s_orderid;
    int s_before_orderid;
    int orderid;
  };
  
struct SymbolPrefix
  {
    string s_name;
    string d_name;
  };

//--- Globales Application
const string app_name    = "Jiowcl Expert Advisor";

//--- Globales ZMQ
Context context;
Socket  subscriber(context, ZMQ_SUB);

string zmq_server        = "";
uint   zmq_subdelay      = 0;
bool   zmq_runningstatus = false;

//--- Globales Order
double order_minlots     = 0.00;
double order_maxlots     = 0.00;
double order_percentlots = 100;
int    order_slippage    = 0;
bool   order_allowopen   = true; 
bool   order_allowclose  = true;
bool   order_allowmodify = true;
bool   order_invert      = false;

//--- Globales Account
int    account_subscriber    = 0;
double account_minmarginfree = 0.00;

//--- Globales File
string       local_drectoryname    = "Data";
string       local_pclosedfilename = "partially_closed.bin";
ClosedOrder  local_pclosed[];

SymbolPrefix local_symbolprefix[];
string       local_symbolallow[];
int          symbolprefix_size     = 0;
int          symbolallow_size      = 0;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  { 
    if (DetectEnvironment() == false)
      {
        Alert("Error: The property is fail, please check and try again.");
        return;
      }
    
    StartZmqClient();
  }

//+------------------------------------------------------------------+
//| Override deinit function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {    
    StopZmqClient();
  }

//+------------------------------------------------------------------+
//| Detect the script parameters                                     |
//+------------------------------------------------------------------+
bool DetectEnvironment()
  {
    if (Server == "") 
      return false;
    
    if (ServerReal == true && IsDemo())
      {
        Print("Account is Demo, please switch the Demo account to Real account.");
        return false;
      }
      
    if (IsDllsAllowed() == false)
      {
        Print("DLL call is not allowed. ", app_name, " cannot run.");
        return false;
      }
    
    zmq_server        = Server;
    zmq_subdelay      = (ServerDelayMilliseconds > 0) ? ServerDelayMilliseconds : 10;
    zmq_runningstatus = false;
    
    order_minlots     = MinLots;
    order_maxlots     = MaxLots;
    order_percentlots = (PercentLots > 0) ? PercentLots : 100;
    order_slippage    = Slippage;
    order_allowopen   = AllowOpenTrade;
    order_allowclose  = AllowCloseTrade;
    order_allowmodify = AllowModifyTrade;
    order_invert      = InvertOrder;
    
    account_subscriber    = (SignalAccount != "") ? StringToInteger(SignalAccount) : -1;
    account_minmarginfree = MinFreeMargin;
    
    // Load the Symbol prefix maps
    if (SymbolPrefixAdjust != "")
      {
        string symboldata[];
        int    symbolsize  = StringSplit(SymbolPrefixAdjust, ',', symboldata);
        int    symbolindex = 0;
        
        ArrayResize(local_symbolprefix, symbolsize);
        
        for (symbolindex=0; symbolindex<symbolsize; symbolindex++)
          {
            string prefixdata[];
            int    prefixsize = StringSplit(symboldata[symbolindex], '=', prefixdata);
            
            if (prefixsize == 2)
              {
                local_symbolprefix[symbolindex].s_name = prefixdata[0];
                local_symbolprefix[symbolindex].d_name = prefixdata[1];
              }
          }
        
        symbolprefix_size = symbolsize;
      }
    
    // Load the Symbol allow map
    if (AllowSymbols != "")
      {
        string symboldata[];
        int    symbolsize  = StringSplit(AllowSymbols, ',', symboldata);
        int    symbolindex = 0;
        
        ArrayResize(local_symbolallow, symbolsize);
        
        for (symbolindex=0; symbolindex<symbolsize; symbolindex++)
          {
            if (symboldata[symbolindex] == "")
              continue;
              
            local_symbolallow[symbolindex] = symboldata[symbolindex];
          }
          
        symbolallow_size = symbolsize;
      }

    return true;
  }

//+------------------------------------------------------------------+
//| Start the zmq client                                             |
//+------------------------------------------------------------------+
void StartZmqClient()
  {
    if (zmq_server == "") 
      return;
    
    int result = subscriber.connect(zmq_server);
    
    if (result != 1)
      {
        Alert("Error: Unable to connect to the server, please check your server settings.");
        return;
      }
    
    // Load closed order to memory
    LocalClosedDataToMemory();
    
    subscriber.subscribe("");   
    
    ZmqMsg received;
    string message         = "";
    int    singallogin     = -1;
    string singalorderdata = "";
    
    uint delay       = zmq_subdelay;
    uint ticketstart = 0; 
    uint tickcount   = 0;
    
    zmq_runningstatus = true;
    
    Print("Load Subscribe: ", zmq_server);
    
    if (account_subscriber > 0)
      Print("Signal Account: " + account_subscriber);
    
    while (!IsStopped())
      {
        ticketstart = GetTickCount();
      
        subscriber.recv(received, true);
        message = received.getData();
        
        if (message != "" && AccountEquity() > 0.00)
          {
            singallogin     = -1;
            singalorderdata = "";
          
            ParseMessage(message, singallogin, singalorderdata);
        
            if (singallogin > 0)
              {
                if (account_subscriber <= 0 || account_subscriber == singallogin)   
                  ParseOrderFromSingal(singallogin, singalorderdata);
              }
          
            continue;
          }
        
        tickcount = GetTickCount() - ticketstart;
        
        if (delay > tickcount)
          Sleep(delay-tickcount-2);
      }
  }

//+------------------------------------------------------------------+
//| Stop the zmq client                                              |
//+------------------------------------------------------------------+
void StopZmqClient()
  {
    if (zmq_server == "") 
      return;
    
    // Save local closed order to file
    LocalClosedDataToFile();
    
    Print("UnLoad Subscribe: ", zmq_server);
       
    ArrayFree(local_pclosed);
    ArrayFree(local_symbolprefix);
    ArrayFree(local_symbolallow);
    
    if (zmq_runningstatus == true)
      {
        subscriber.unsubscribe("");
        subscriber.disconnect(zmq_server);
      }
  }

//+------------------------------------------------------------------+
//| Parse the message from server signal                             |
//+------------------------------------------------------------------+
bool ParseMessage(const string message, 
                  int &login, 
                  string &orderdata)
  {
    if (message == "")
      return false;
      
    string messagedata[];
    int    size = StringSplit(message, ' ', messagedata);
    
    login     = -1;
    orderdata = "";
    
    if (size != 2)
      return false;
      
    login     = StrToInteger(messagedata[0]);
    orderdata = messagedata[1];
      
    return true;
  }

//+------------------------------------------------------------------+
//| Parse the order from signal message                              |
//+------------------------------------------------------------------+
bool ParseOrderFromSingal(const int login, 
                          const string ordermessage)
  {
    if (login <= 0 || ordermessage == "")
      return false;
      
    string orderdata[];
    int    size = StringSplit(ordermessage, '|', orderdata);
    
    if (size != 9)
      return false;
    
    // Order data from signal
    string op            = orderdata[0];
    string symbol        = orderdata[1];
    //int    orderid       = StrToInteger(orderdata[2]);
    int    orderid       = -1;
    int    beforeorderid = -1;
    int    type          = StrToInteger(orderdata[3]);
    double openprice     = StringToDouble(orderdata[4]);
    double closeprice    = StringToDouble(orderdata[5]);
    double lots          = StringToDouble(orderdata[6]);
    double sl            = StringToDouble(orderdata[7]);
    double tp            = StringToDouble(orderdata[8]);
    
    string orderiddata[];
    int    orderidsize = StringSplit(orderdata[2], '_', orderiddata);
    
    symbol = GetOrderSymbolPrefix(symbol);
    
    // Partially closed a trade
    // Partially closed a trade will have 2 order id (orderid and before orderid)
    if (orderidsize == 2)
      {
        orderid       = StrToInteger(orderiddata[0]);
        beforeorderid = StrToInteger(orderiddata[1]);
      }
    else
      {
        orderid = StrToInteger(orderdata[2]);
      }
    
    return MakeOrder(login, op, symbol, orderid, beforeorderid, type, openprice, closeprice, lots, sl, tp);
  }

//+------------------------------------------------------------------+
//| Make a order by signal message (Market and Pending Order)        |
//+------------------------------------------------------------------+
bool MakeOrder(const int login, 
               const string op,
               const string symbol, 
               const int orderid, 
               const int beforeorderid, 
               const int type, 
               const double openprice,
               const double closeprice,
               const double lots, 
               const double sl, 
               const double tp)
  {
    if (login <= 0 || symbol == "" || orderid == 0)
      return false;
    
    if (GetOrderSymbolAllowed(symbol) == false)
      return false; 

    int    ticketid    = -1;
    string comment     = StringFormat("%d|%d", login, orderid);
    bool   orderstatus = false;
    bool   localstatus = false;
    
    if (op == "OPEN")
      {      
        ticketid = FindOrderBySingalComment(symbol, orderid);
        
        if (ticketid <= 0)
          {
            ticketid = MakeOrderOpen(symbol, type, openprice, lots, sl, tp, comment);
          
            Print("Open:", symbol, ", Type:", type, ", TicketId:", ticketid);
          }
      }
    else if (op == "CLOSED")
      {
        ticketid = FindOrderBySingalComment(symbol, orderid);
        
        if (ticketid <= 0)
          {
            ticketid = FindPartClosedOrderByLocal(symbol, orderid);
          }
        
        if (ticketid > 0)
          {
            orderstatus = MakeOrderClose(ticketid, symbol, type, closeprice, lots, sl, tp);
            
            Print("Closed:", symbol, ", Type:", type);
          }
      }
    else if (op == "PCLOSED")
      {
        ticketid = FindOrderBySingalComment(symbol, beforeorderid);
              
        if (ticketid > 0)
          {
            //string localmessage = StringFormat("%d|%d-%d|%d", login, orderid, beforeorderid, ticketid);
            localstatus = LocalClosedDataSave(login, orderid, beforeorderid, ticketid);
            orderstatus = MakeOrderPartiallyClose(ticketid, symbol, type, closeprice, lots, sl, tp);
          
            Print("Partially Closed:", symbol, ", Type:", type);
          }
      }
    else if (op == "MODIFY")
      {
        ticketid = FindOrderBySingalComment(symbol, orderid);
        
        if (ticketid <= 0)
          {
            ticketid = FindPartClosedOrderByLocal(symbol, orderid);
          }
        
        if (ticketid > 0)
          {
            orderstatus = MakeOrderModify(ticketid, symbol, openprice, sl, tp);
          
            Print("Modify:", symbol, ", Type:", type);
          }
      }
    
    return (ticketid > 0) ? true : false;
  }

//+------------------------------------------------------------------+
//| Make a market or pending order by signal message                 |
//+------------------------------------------------------------------+
int MakeOrderOpen(const string symbol, 
                  const int type,
                  const double openprice, 
                  const double lots, 
                  const double sl, 
                  const double tp,
                  const string comment)
  {
    int ticketid = -1;
    
    // Allow signal to open the order
    // Symbol must not be empty
    if (order_allowopen == false || symbol == "")
      return ticketid;
    
    // Allow Expert Advisor to open the order
    if (IsTradeAllowed() == false)
      return ticketid;
      
    // Check if account margin free is less than settings
    if (account_minmarginfree > 0.00 && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < account_minmarginfree)
      return ticketid;
    
    double vprice = openprice;
    double vlots = GetOrderLots(symbol, lots);
    int    vtype = type;
    
    // The parameter price must be greater than zero
    if (vprice <= 0.00)
      vprice = SymbolInfoDouble(symbol, SYMBOL_ASK);

    // Invert the origional order
    if (order_invert)
      {
        switch (vtype)
          {
            case OP_BUY:
              vtype = OP_SELL;
              break;

            case OP_SELL:
              vtype = OP_BUY;
              break;

            case OP_BUYLIMIT:
              vtype = OP_SELLLIMIT;
              break;

            case OP_BUYSTOP:
              vtype = OP_SELLSTOP;
              break;

            case OP_SELLLIMIT:
              vtype = OP_BUYLIMIT;
              break;

            case OP_SELLSTOP:
              vtype = OP_BUYSTOP;
              break;
          }
      }
    
    switch (vtype)
      {
        case OP_BUY:
          ticketid = OrderSend(symbol, OP_BUY, vlots, vprice, order_slippage, sl, tp, comment, 0, 0, clrYellow);
          break;
    
        case OP_SELL:
          ticketid = OrderSend(symbol, OP_SELL, vlots, vprice, order_slippage, sl, tp, comment, 0, 0, clrYellow);
          break;
    
        case OP_BUYLIMIT:
          if (openprice > 0.00)
            ticketid = OrderSend(symbol, OP_BUYLIMIT, vlots, openprice, order_slippage, sl, tp, comment, 0, 0, clrYellow);
          break;
    
        case OP_BUYSTOP:
          if (openprice > 0.00)
            ticketid = OrderSend(symbol, OP_BUYSTOP, vlots, openprice, order_slippage, sl, tp, comment, 0, 0, clrYellow);
          break;
    
        case OP_SELLLIMIT:
          if (openprice > 0.00)
            ticketid = OrderSend(symbol, OP_SELLLIMIT, vlots, openprice, order_slippage, sl, tp, comment, 0, 0, clrYellow);
          break;
    
        case OP_SELLSTOP:
          if (openprice > 0.00)
            ticketid = OrderSend(symbol, OP_SELLSTOP, vlots, openprice, order_slippage, sl, tp, comment, 0, 0, clrYellow);
          break;
      }
    
    return ticketid;
  }

//+------------------------------------------------------------------+
//| Make a order close by signal message                             |
//+------------------------------------------------------------------+
bool MakeOrderClose(const int ticketid, 
                    const string symbol, 
                    const int type,
                    const double closeprice, 
                    const double lots, 
                    const double sl, 
                    const double tp)
  {
    bool result = false;
    
    // Allow signal to close the order
    // The parameter ticketid must be greater than zero
    if (order_allowclose == false || ticketid <= 0)
      return result;
    
    // Allow Expert Advisor to close the order
    if (IsTradeAllowed() == false)
      return result;
    
    if (OrderSelect(ticketid, SELECT_BY_TICKET, MODE_TRADES) == true)
      {
        double price = closeprice;
      
        if (price <= 0.00)
          price = SymbolInfoDouble(symbol, SYMBOL_ASK);
              
        switch (type)
          {
            case OP_BUYLIMIT:
            case OP_BUYSTOP:
            case OP_SELLLIMIT:
            case OP_SELLSTOP:
              result = OrderDelete(ticketid); 
              break;
            
            default:
              result = OrderClose(ticketid, OrderLots(), price, order_slippage, clrYellow); 
              break;  
          }
      }
    
    return result;
  }

//+------------------------------------------------------------------+
//| Make a partially order close by signal message                   |
//+------------------------------------------------------------------+
bool MakeOrderPartiallyClose(const int ticketid, 
                             const string symbol, 
                             const int type,
                             const double closeprice, 
                             const double lots, 
                             const double sl, 
                             const double tp)
  {
    bool result = false;
    
    // Allow signal to close the order
    // The parameter ticketid must be greater than zero
    if (order_allowclose == false || ticketid <= 0)
      return result;
      
    // Allow Expert Advisor to close the order
    if (IsTradeAllowed() == false)
      return result;
    
    if (OrderSelect(ticketid, SELECT_BY_TICKET, MODE_TRADES) == true)
      {
        double price      = closeprice;
        double vlots      = GetOrderLots(symbol, lots);
        double vcloselots = OrderLots();
        
        if (vcloselots - vlots > 0) 
          {
            vlots = vcloselots - vlots;
          }
        
        if (price <= 0.00)
          price = SymbolInfoDouble(symbol, SYMBOL_ASK);
          
        switch (type)
          {
            case OP_BUYLIMIT:
            case OP_BUYSTOP:
            case OP_SELLLIMIT:
            case OP_SELLSTOP:
              break;
            
            default:
              result = OrderClose(ticketid, vlots, price, order_slippage, clrYellow); 
              break;  
          }
      }
       
    return result;
  }                    
  
//+------------------------------------------------------------------+
//| Make a order modify by signal message                            |
//+------------------------------------------------------------------+
bool MakeOrderModify(const int ticketid, 
                     const string symbol, 
                     const double openprice, 
                     const double sl, 
                     const double tp)
  {
    bool result = false;

    // Allow signal to modify the order
    // The parameter ticketid must be greater than zero
    if (order_allowmodify == false || ticketid <= 0)
      return result;
    
    // Allow Expert Advisor to modify the order
    if (IsTradeAllowed() == false)
      return result;
    
    if (OrderSelect(ticketid, SELECT_BY_TICKET, MODE_TRADES) == true)
      {         
        result = OrderModify(ticketid, openprice, sl, tp, 0, clrYellow); 
      }
        
    return result;
  }

//+------------------------------------------------------------------+
//| Get the order lots is greater than or less than max and min lots |
//+------------------------------------------------------------------+
double GetOrderLots(const string symbol, const double lots)
  {
    double result = lots;
  
    if (order_percentlots > 0)
      {
        result = lots * (order_percentlots / 100);
      }
    
    if (order_minlots > 0.00)
      result = (lots <= order_minlots) ? order_minlots : result;
    
    if (order_maxlots > 0.00)
      result = (lots >= order_maxlots) ? order_maxlots : result;
      
    if (order_percentlots > 0)
      {
        double s_maxlots = MarketInfo(symbol, MODE_MAXLOT);
        double s_mixlots = MarketInfo(symbol, MODE_MINLOT);
        
        if (result > s_maxlots)
          result = s_maxlots;
          
        if (result < s_mixlots)
          result = s_mixlots;
      }
    
    return result;
  }

//+------------------------------------------------------------------+
//| Get the order symbol between A broker and B broker               |
//+------------------------------------------------------------------+
string GetOrderSymbolPrefix(const string symbol)
  {
    string result = symbol;
    
    if (symbolprefix_size == 0)
      return result;
    
    int symbolsize  = StringLen(symbol);
    int symbolindex = 0;
    
    for (symbolindex=0; symbolindex<symbolprefix_size; symbolindex++)
      {
        int    prefixsize      = StringLen(local_symbolprefix[symbolindex].s_name);
        string symbolname      = StringSubstr(symbol, 0, symbolsize-prefixsize);
        string tradesymbolname = symbolname + local_symbolprefix[symbolindex].d_name;
        
        if (symbolname + local_symbolprefix[symbolindex].s_name != symbol)
          continue;

        if (SymbolInfoString(tradesymbolname, SYMBOL_CURRENCY_BASE) != "")
          {
            result = tradesymbolname;
            
            break;
          }
      }
      
    return result;
  }

//+------------------------------------------------------------------+
//| Get the symbol allowd on trading                                 |
//+------------------------------------------------------------------+
bool GetOrderSymbolAllowed(const string symbol)
  {
    bool result = true;
    
    if (symbolallow_size == 0)
      return result;
    
    // Change result as FALSE when allow list is not empty
    result = false;
      
    int symbolindex = 0;
    
    for (symbolindex=0; symbolindex<symbolallow_size; symbolindex++)
      {
        if (local_symbolallow[symbolindex] == "")
          continue;
      
        if (symbol == local_symbolallow[symbolindex])
          {
            result = true;
            
            break;
          }
      }
    
    return result;
  }

//+------------------------------------------------------------------+
//| Find a current order by server signal                            |
//+------------------------------------------------------------------+
int FindOrderBySingalComment(const string symbol, 
                             const int signal_ticketid)
  {
    int ticketid = -1;
    
    int ordersize  = OrdersTotal();
    int orderindex = 0;
    
    for (orderindex=0; orderindex<ordersize; orderindex++)
      {
        if (OrderSelect(orderindex, SELECT_BY_POS, MODE_TRADES) == false)
          continue;
          
        string ordercomment = OrderComment();
        
        if (ordercomment == "")
          continue;
        
        string singalorderdata[];
        int    size = StringSplit(ordercomment, '|', singalorderdata);
        
        if (size != 2)
          continue;
        
        // Find a order ticket id from order comment.
        // Order by signal is login|orderid 
        if (symbol == OrderSymbol() 
          && signal_ticketid == StrToInteger(singalorderdata[1]))
          {
            ticketid = OrderTicket();
            
            if (ticketid > 0)
              break;
          }
      }
    
    return ticketid;
  }

//+------------------------------------------------------------------+
//| Find a history order closed by server signal                     |
//+------------------------------------------------------------------+
int FindClosedOrderByHistoryToComment(const string symbol, 
                                      const int signal_ticketid)
  {
    int ticketid = -1;
    
    int ordersize  = OrdersHistoryTotal();
    int orderindex = 0;
    
    // Find a history order closed by part-close order
    for (orderindex=0; orderindex<ordersize; orderindex++)
      {
        if (OrderSelect(orderindex, SELECT_BY_POS, MODE_HISTORY) == false)
          continue;
         
        string ordercomment = OrderComment();
        
        if (ordercomment == "")
          continue;
        
        if (symbol != OrderSymbol())
          continue;
         
        if (signal_ticketid != OrderTicket())
          continue;
        
        // Find a part-close flag in comment column
        if (StringFind(ordercomment, "to #", 0) >= 0)
          {
            if (StringReplace(ordercomment, "to #", "") >= 0)
              {
                ticketid = StringToInteger(ordercomment);
                    
                if (ticketid > 0)
                  break;
              }
          }
      }
    
    return ticketid;
  }

//+------------------------------------------------------------------+
//| Find a part closed order by server signal                        |
//+------------------------------------------------------------------+
int FindPartClosedOrderByLocal(const string symbol, 
                               const int signal_ticketid)
  {
    int ticketid = -1;
    
    int before_orderid = -1;
    int pclosedsize    = ArraySize(local_pclosed);
    int pclosedindex   = 0;
    
    for (pclosedindex=0; pclosedindex<pclosedsize; pclosedindex++)
      {
        if (local_pclosed[pclosedindex].s_orderid == signal_ticketid)
          {
            before_orderid = local_pclosed[pclosedindex].orderid;
            
            break;
          }
      }
    
    // Find a orderid from history closed by part-close order
    if (before_orderid > 0) 
      ticketid = FindClosedOrderByHistoryToComment(symbol, before_orderid);
      
    return ticketid;
  }

//+------------------------------------------------------------------+
//| Local closed data save                                           |
//+------------------------------------------------------------------+
bool LocalClosedDataSave(const int s_login, 
                         const int s_orderid, 
                         const int sl_beforeorderid, 
                         const int orderid)
  {
    bool result = false;
        
    int local_pclosedsize = ArraySize(local_pclosed);
    
    if (ArrayResize(local_pclosed, local_pclosedsize + 1))
      {
        local_pclosed[local_pclosedsize].s_login          = s_login;
        local_pclosed[local_pclosedsize].s_orderid        = s_orderid;
        local_pclosed[local_pclosedsize].s_before_orderid = sl_beforeorderid;
        local_pclosed[local_pclosedsize].orderid          = orderid;
      }

    return result;
  }
 
//+------------------------------------------------------------------+
//| Local closed data to memory                                      |
//+------------------------------------------------------------------+
void LocalClosedDataToMemory()
  {
    int    login    = AccountInfoInteger(ACCOUNT_LOGIN);
    string filename = IntegerToString(login) + "_" + local_pclosedfilename;
    
    int handle = FileOpen(local_drectoryname + "//" + filename, FILE_READ|FILE_BIN); 
    
    if (handle != INVALID_HANDLE)
      {
        FileReadArray(handle, local_pclosed);
        FileClose(handle);
      }
    else
      {
        Print("Failed to open the closed order file, error ", GetLastError());
      }
  }
  
//+------------------------------------------------------------------+
//| Local closed data to file                                        |
//+------------------------------------------------------------------+
void LocalClosedDataToFile()
  {
    int    login    = AccountInfoInteger(ACCOUNT_LOGIN);
    string filename = IntegerToString(login) + "_" + local_pclosedfilename;
    
    int handle = FileOpen(local_drectoryname + "//" + filename, FILE_WRITE|FILE_BIN); 
    
    if (handle != INVALID_HANDLE)
      {    
        int local_pclosedsize = ArraySize(local_pclosed);
    
        FileSeek(handle, 0, SEEK_END);
        FileWriteArray(handle, local_pclosed, 0, local_pclosedsize);
        FileClose(handle);
      }
    else
      {
        Print("Failed to open the closed order file, error ", GetLastError());
      }
  }
