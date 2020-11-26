//+------------------------------------------------------------------+
//|                                        JiowclPublisherServer.mq4 |
//|                                Copyright 2017-2021, Ji-Feng Tsai |
//|                                        https://github.com/jiowcl |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2021, Ji-Feng Tsai"
#property link        "https://github.com/jiowcl/MQL-CopyTrade"
#property version     "1.12"
#property description "MT4 Copy Trade Publisher Application. Push all order-to-subscribers."
#property strict
#property show_inputs

#include <Zmq/Zmq.mqh>

//--- Inputs
input string Server                  = "tcp://*:5559";  // Push server ip
input uint   ServerDelayMilliseconds = 300;             // Push to clients delay milliseconds (Default is 300)
input bool   ServerReal              = false;           // Under real server (Default is false)
input string AllowSymbols            = "";              // Allow Trading Symbols (Ex: EURUSDq,EURUSDx,EURUSDa)

//--- Globales Application
const string app_name    = "Jiowcl Expert Advisor";

//--- Globales ZMQ
Context context;
Socket  publisher(context, ZMQ_PUB);

string zmq_server        = "";
uint   zmq_pushdelay     = 0;
bool   zmq_runningstatus = false;

//--- Globales Order
int    ordersize            = 0;
int    orderids[];
double orderopenprice[];
double orderlot[];
double ordersl[];
double ordertp[];
bool   orderchanged           = false;
bool   orderpartiallyclosed   = false;
int    orderpartiallyclosedid = -1;

int    prev_ordersize         = 0;

//--- Globales File
string local_symbolallow[];
int    symbolallow_size = 0;

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
      
    StartZmqServer();
  }

//+------------------------------------------------------------------+
//| Override deinit function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    StopZmqServer();
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
    zmq_pushdelay     = (ServerDelayMilliseconds > 0) ? ServerDelayMilliseconds : 10;
    zmq_runningstatus = false;
    
    // Load the Symbol allow map
    if (AllowSymbols != "")
      {
        string symboldata[];
        int    symbolsize = StringSplit(AllowSymbols, ',', symboldata);
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
//| Start the zmq server                                             |
//+------------------------------------------------------------------+
void StartZmqServer()
  {  
    if (zmq_server == "")
      return;
      
    int result = publisher.bind(zmq_server);
    
    if (result != 1)
      {
        Alert("Error: Unable to bind server, please check your port.");
        return;
      }
    
    Print("Load Server: ", zmq_server);
    
    // Init all the current orders to cache.
    // The signal only sends a new order or modify order.
    GetCurrentOrdersOnStart();
    
    int  changed     = 0;
    uint delay       = zmq_pushdelay;
    uint ticketstart = 0; 
    uint tickcount   = 0;
    
    zmq_runningstatus = true;
   
    while (!IsStopped())
      {
        ticketstart = GetTickCount();
        changed = GetCurrentOrdersOnTicket();
        
        if (changed > 0)
          UpdateCurrentOrdersOnTicket();
        
        tickcount = GetTickCount() - ticketstart;
        
        if (delay > tickcount)
          Sleep(delay-tickcount-2);
      }
  }

//+------------------------------------------------------------------+
//| Stop the zmq server                                              |
//+------------------------------------------------------------------+
void StopZmqServer()
  {
    if (zmq_server == "") 
      return;
    
    ArrayFree(orderids);
    ArrayFree(orderopenprice);
    ArrayFree(orderlot);
    ArrayFree(ordersl);
    ArrayFree(ordertp);
    ArrayFree(local_symbolallow);
    
    Print("Unload Server: ", zmq_server);
    
    if (zmq_runningstatus == true)
      publisher.unbind(zmq_server);
      
    zmq_runningstatus = false;
  }

//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
void GetCurrentOrdersOnStart()
  {
    prev_ordersize = 0;
    ordersize      = OrdersTotal();
    
    if (ordersize == prev_ordersize)
      return;

    if (ordersize > 0)
      {
        ArrayResize(orderids, ordersize);
        ArrayResize(orderopenprice, ordersize);
        ArrayResize(orderlot, ordersize);
        ArrayResize(ordersl, ordersize);
        ArrayResize(ordertp, ordersize);
      }
    
    prev_ordersize = ordersize;
    
    int orderindex = 0;
    
    // Save the orders to cache
    for (orderindex=0; orderindex<ordersize; orderindex++)
      {
        if (OrderSelect(orderindex, SELECT_BY_POS, MODE_TRADES) == false)
          continue;
            
        orderids[orderindex]       = OrderTicket();
        orderopenprice[orderindex] = OrderOpenPrice();
        orderlot[orderindex]       = OrderLots();
        ordersl[orderindex]        = OrderStopLoss();
        ordertp[orderindex]        = OrderTakeProfit();
      }
  }

//+------------------------------------------------------------------+
//| Get all of the orders                                            |
//+------------------------------------------------------------------+
int GetCurrentOrdersOnTicket()
  { 
    ordersize = OrdersTotal();
       
    int changed = 0;
             
    if (ordersize > prev_ordersize)
      {
        // Trade has been added
        changed = PushOrderOpen();
      }
    else if (ordersize < prev_ordersize)
      {
        // Trade has been closed
        changed = PushOrderClosed();
      }
    else if (ordersize == prev_ordersize)
      {
        // Trade has been modify
        changed = PushOrderModify();
      }
      
    return changed;
  }

//+------------------------------------------------------------------+
//| Update all of the orders status                                  |
//+------------------------------------------------------------------+
void UpdateCurrentOrdersOnTicket()
  {     
    if (ordersize > 0)
      {
        ArrayResize(orderids, ordersize);
        ArrayResize(orderopenprice, ordersize);
        ArrayResize(orderlot, ordersize);
        ArrayResize(ordersl, ordersize);
        ArrayResize(ordertp, ordersize);
      }
    
    int orderindex = 0;
    
    // Save the orders to cache
    for (orderindex=0; orderindex<ordersize; orderindex++)
      {
        if (OrderSelect(orderindex, SELECT_BY_POS, MODE_TRADES) == false)
          continue;
         
        orderids[orderindex]       = OrderTicket();
        orderopenprice[orderindex] = OrderOpenPrice();
        orderlot[orderindex]       = OrderLots();
        ordersl[orderindex]        = OrderStopLoss();
        ordertp[orderindex]        = OrderTakeProfit();
      }
    
    // Changed the old orders count as current orders count
    prev_ordersize = ordersize;
  }

//+------------------------------------------------------------------+
//| Push the open order to all of the subscriber                     |
//+------------------------------------------------------------------+
int PushOrderOpen()
  {
    int changed    = 0;
    int orderindex = 0;
 
    for (orderindex=0; orderindex<ordersize; orderindex++)
      {
        if (OrderSelect(orderindex, SELECT_BY_POS, MODE_TRADES) == false)
          continue;
            
        if (FindOrderInPrevPool(OrderTicket()) == false)
          {
            if (GetOrderSymbolAllowed(OrderSymbol()) == false)
              continue;

            Print("Order Added:", OrderSymbol(), ", Size:", ArraySize(orderids), ", OrderId:", OrderTicket());
                
            PushToSubscriber(StringFormat("%d %s|%s|%d|%d|%f|%f|%f|%f|%f", 
              AccountInfoInteger(ACCOUNT_LOGIN),
              "OPEN",
              OrderSymbol(), 
              OrderTicket(),
              OrderType(), 
              OrderOpenPrice(),
              OrderClosePrice(),
              OrderLots(), 
              OrderStopLoss(), 
              OrderTakeProfit()
            ));
                 
            changed ++;
          }
      }
     
    return changed;
  }

//+------------------------------------------------------------------+
//| Push the close order to all of the subscriber                    |
//+------------------------------------------------------------------+
int PushOrderClosed()
  {
    int      changed    = 0;
    int      orderindex = 0;
    datetime ctm;
  
    for (orderindex=0; orderindex<prev_ordersize; orderindex++)
      {         
        if (OrderSelect(orderids[orderindex], SELECT_BY_TICKET, MODE_TRADES) == false)
          continue;

        ctm = OrderCloseTime();
            
        if (ctm > 0)
          {
            if (GetOrderSymbolAllowed(OrderSymbol()) == false)
              continue;

            Print("Order Closed:", OrderSymbol(), ", Size:", ArraySize(orderids), ", OrderId:", OrderTicket());

            PushToSubscriber(StringFormat("%d %s|%s|%d|%d|%f|%f|%f|%f|%f", 
              AccountInfoInteger(ACCOUNT_LOGIN),
              "CLOSED",
              OrderSymbol(), 
              OrderTicket(),
              OrderType(), 
              OrderOpenPrice(),
              OrderClosePrice(),
              OrderLots(), 
              OrderStopLoss(), 
              OrderTakeProfit()
            ));

            changed ++;
          }
      }
          
    return changed;
  }

//+------------------------------------------------------------------+
//| Push the modify order to all of the subscriber                   |
//+------------------------------------------------------------------+
int PushOrderModify()
  {
    int changed    = 0;
    int orderindex = 0;
    
    for (orderindex=0; orderindex<ordersize; orderindex++)
      {
        orderchanged           = false;
        orderpartiallyclosed   = false;
        orderpartiallyclosedid = -1;

        if (OrderSelect(orderindex, SELECT_BY_POS, MODE_TRADES) == false)
          continue;          

        if (GetOrderSymbolAllowed(OrderSymbol()) == false)
          continue;  

        if (orderlot[orderindex] != OrderLots())
          {
            orderchanged = true;
            
            string ordercomment = OrderComment();
            int    orderid      = 0;
            
            // Partially closed a trade
            // Partially closed is a different lots from trade
            if (StringFind(ordercomment, "from #", 0) >= 0)
              {
                if (StringReplace(ordercomment, "from #", "") >= 0)
                  {
                    orderpartiallyclosed   = true;
                    orderpartiallyclosedid = StringToInteger(ordercomment);
                  }
              }
          }

        if (ordersl[orderindex] != OrderStopLoss())
          orderchanged = true;

        if (ordertp[orderindex] != OrderTakeProfit())
          orderchanged = true;

        // Temporarily method for recognize modify order or part-closed order
        // Part-close order will close order by a litte lots and re-generate an new order with new order id
        if (orderchanged == true)
          {
            if (orderpartiallyclosed == true)
              {
                Print("Partially Closed:", OrderSymbol(), ", Size:", ArraySize(orderids), ", OrderId:", OrderTicket(), ", Before OrderId: ", orderpartiallyclosedid);
                
                PushToSubscriber(StringFormat("%d %s|%s|%s|%d|%f|%f|%f|%f|%f", 
                  AccountInfoInteger(ACCOUNT_LOGIN),
                  "PCLOSED",
                  OrderSymbol(), 
                  OrderTicket() + "_" + orderpartiallyclosedid,
                  OrderType(), 
                  OrderOpenPrice(),
                  OrderClosePrice(),
                  OrderLots(), 
                  OrderStopLoss(), 
                  OrderTakeProfit()
                ));
              }
            else
              {
                Print("Order Modify:", OrderSymbol(), ", Size:", ArraySize(orderids), ", OrderId:", OrderTicket());
              
                PushToSubscriber(StringFormat("%d %s|%s|%d|%d|%f|%f|%f|%f|%f", 
                  AccountInfoInteger(ACCOUNT_LOGIN),
                  "MODIFY",
                  OrderSymbol(), 
                  OrderTicket(),
                  OrderType(), 
                  OrderOpenPrice(),
                  OrderClosePrice(),
                  OrderLots(), 
                  OrderStopLoss(), 
                  OrderTakeProfit()
                ));
              }
            
            changed ++;
          }
      }

    return changed;
  }

//+------------------------------------------------------------------+
//| Push the message for all of the subscriber                       |
//+------------------------------------------------------------------+
bool PushToSubscriber(const string message)
  {
    if (message == "")
      return false;
  
    ZmqMsg replymsg(message);
    
    int result = publisher.send(replymsg);
    
    return (result == 1) ? true : false;
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
//| Find a order by ticket id                                        |
//+------------------------------------------------------------------+
bool FindOrderInPrevPool(const int order_ticketid)
  {
    int orderfound = 0;
    int orderindex = 0;
    
    if (prev_ordersize == 0)
      return false;
  
    for (orderindex=0; orderindex<prev_ordersize; orderindex++)
      {
        if (order_ticketid == orderids[orderindex])
          orderfound ++;
      }
      
    return (orderfound > 0) ? true : false;
  }
