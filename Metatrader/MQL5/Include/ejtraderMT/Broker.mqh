#property copyright "ejtrader"
#property link      "https://github.com/ejtraderLabs/MQL5-ejtraderMT"



//+------------------------------------------------------------------+
//| Fetch positions information                                      |
//+------------------------------------------------------------------+
void GetPositions(CJAVal &dataObject)
{
   CPositionInfo myposition;
   CJAVal data;
   
   // Get positions
   int positionsTotal=PositionsTotal();
   
   // Create empty array if no positions
   if(!positionsTotal)
   {
      CJAVal emptyPosition;
      data["positions"].Add(emptyPosition);
   }
      
   // Go through positions in a loop
   for(int i=0; i<positionsTotal; i++)
   {
      mControl.mResetLastError();
      
      // Get the position ticket directly by index
      ulong ticket = PositionGetTicket(i);
      
      if(ticket && myposition.SelectByTicket(ticket))
      {
         // Create a new position object for each position
         CJAVal position;
         
         position["id"]=PositionGetInteger(POSITION_IDENTIFIER);
         position["magic"]=PositionGetInteger(POSITION_MAGIC);
         position["symbol"]=PositionGetString(POSITION_SYMBOL);
         position["type"]=EnumToString(ENUM_POSITION_TYPE(PositionGetInteger(POSITION_TYPE)));
         position["time_setup"]=PositionGetInteger(POSITION_TIME);
         position["open"]=PositionGetDouble(POSITION_PRICE_OPEN);
         position["stoploss"]=PositionGetDouble(POSITION_SL);
         position["takeprofit"]=PositionGetDouble(POSITION_TP);
         position["volume"]=PositionGetDouble(POSITION_VOLUME);
         position["comment"]=PositionGetString(POSITION_COMMENT);

         data["positions"].Add(position);
      }
      CheckError(__FUNCTION__);
   }
   
   data["error"]=(bool) false;
   
   string t=data.Serialize();
   if(debug)
      Print(t);
   InformClientSocket(sysSocket,t);
}

//+------------------------------------------------------------------+
//| Fetch orders information                                         |
//+------------------------------------------------------------------+
void GetOrders(CJAVal &dataObject)
  {
   mControl.mResetLastError();

   COrderInfo myorder;
   CJAVal data, order;

// Get orders
   if(HistorySelect(0,TimeCurrent()))
     {
      int ordersTotal = OrdersTotal();
      // Create empty array if no orders
      if(!ordersTotal)
        {
         data["error"]=(bool) false;
         data["orders"].Add(order);
        }

      for(int i=0; i<ordersTotal; i++)
        {
         if(myorder.Select(OrderGetTicket(i)))
           {
            order["id"]=(string) myorder.Ticket();
            order["magic"]=OrderGetInteger(ORDER_MAGIC);
            order["symbol"]=OrderGetString(ORDER_SYMBOL);
            order["type"]=EnumToString(ENUM_ORDER_TYPE(OrderGetInteger(ORDER_TYPE)));
            order["time_setup"]=OrderGetInteger(ORDER_TIME_SETUP);
            order["open"]=OrderGetDouble(ORDER_PRICE_OPEN);
            order["stoploss"]=OrderGetDouble(ORDER_SL);
            order["takeprofit"]=OrderGetDouble(ORDER_TP);
            order["volume"]=OrderGetDouble(ORDER_VOLUME_INITIAL);
            order["comment"]=OrderGetString(ORDER_COMMENT);

            data["error"]=(bool) false;
            data["orders"].Add(order);
           }
         // Error handling
         CheckError(__FUNCTION__);
        }
     }

   string t=data.Serialize();
   if(debug)
      Print(t);
   InformClientSocket(sysSocket,t);
  }

//+------------------------------------------------------------------+
//| Trading module                                                   |
//+------------------------------------------------------------------+
void TradingModule(CJAVal &dataObject)
{
  mControl.mResetLastError();
  CTrade trade;

  string actionType = dataObject["actionType"].ToStr();
  string symbol = dataObject["symbol"].ToStr();
  SymbolInfoString(symbol, SYMBOL_DESCRIPTION);
  CheckError(__FUNCTION__);

  int idNumber = dataObject["id"].ToInt();
  double volume = NormalizeDouble(dataObject["volume"].ToDbl(), 2);
  double SL = NormalizeDouble(dataObject["stoploss"].ToDbl(), SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  double TP = NormalizeDouble(dataObject["takeprofit"].ToDbl(), SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  double price = NormalizeDouble(dataObject["price"].ToDbl(), SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  double limitPrice = NormalizeDouble(dataObject["stoplimit"].ToDbl(), SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  int deviation = (int)dataObject["deviation"].ToInt();
  string comment = dataObject["comment"].ToStr();

  // Order expiration section
  ENUM_ORDER_TYPE_TIME exp_type = ORDER_TIME_GTC;
  datetime expiration = 0;
  if(dataObject["expiration"].ToInt() != 0)
  {
    exp_type = ORDER_TIME_SPECIFIED;
    expiration = (datetime)dataObject["expiration"].ToInt();
  }

  // Validate input parameters
  if(volume < 0 || price < 0 || symbol == "")
  {
    ActionDoneOrError(true, __FUNCTION__, "Invalid input parameters");
    return;
  }

  // Set trade parameters
  trade.SetDeviationInPoints(deviation);

  // Handle different order types
  if(actionType == "ORDER_TYPE_BUY" || actionType == "ORDER_TYPE_SELL")
  {
    HandleMarketOrder(trade, actionType, symbol, volume, price, SL, TP, comment);
    return;
  }
  else if(actionType == "ORDER_TYPE_BUY_LIMIT" || actionType == "ORDER_TYPE_SELL_LIMIT" ||
    actionType == "ORDER_TYPE_BUY_STOP" || actionType == "ORDER_TYPE_SELL_STOP" ||
    actionType == "ORDER_TYPE_BUY_STOP_LIMIT" || actionType == "ORDER_TYPE_SELL_STOP_LIMIT")
  {
    if(price == 0)
    {
      ActionDoneOrError(true, __FUNCTION__, "Invalid input parameters");
      return;
    }
    HandlePendingOrder(trade, actionType, symbol, volume, price, limitPrice, SL, TP, exp_type, expiration, comment);
    return;
  }
  else if(actionType == "POSITION_MODIFY")
  {
    HandlePositionModify(trade, idNumber, SL, TP);
    return;
  }
  else if(actionType == "POSITION_PARTIAL" || actionType == "POSITION_CLOSE_ID")
  {
    HandlePositionClose(trade, actionType, idNumber, volume);
    return;
  }
  else if(actionType == "POSITION_CLOSE_SYMBOL")
  {
    HandlePositionCloseSymbol(trade, symbol);
    return;
  }
  else if(actionType == "ORDER_MODIFY")
  {
    HandleOrderModify(trade, idNumber, price, SL, TP, exp_type, expiration);
    return;
  }
  else if(actionType == "ORDER_CANCEL")
  {
    HandleOrderCancel(trade, idNumber);
    return;
  }
  else
  {
    mControl.mSetUserError(65538, GetErrorID(65538));
    CheckError(__FUNCTION__);
    return;
  }
  // This part of the code runs if order was not completed
  OrderDoneOrError(true, __FUNCTION__, trade);
}

void HandleMarketOrder(CTrade &trade, string actionType, string symbol,
  double volume, double price, double SL, double TP, string comment)
{
  ENUM_ORDER_TYPE orderType = (actionType == "ORDER_TYPE_BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
  double currentPrice = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);

  // Price condition check with error reporting
  if(orderType == ORDER_TYPE_BUY && (currentPrice > price && price != 0))
  {
    ActionDoneOrError(true, __FUNCTION__, "Current price (" + DoubleToString(currentPrice) + 
    ") is higher than requested price (" + DoubleToString(price) + ") for BUY order");
    return;
  }
  if(orderType == ORDER_TYPE_SELL && (currentPrice < price && price != 0))
  {
    ActionDoneOrError(true, __FUNCTION__, "Current price (" + DoubleToString(currentPrice) + 
    ") is lower than requested price (" + DoubleToString(price) + ") for SELL order");
    return;
  }

  if(trade.PositionOpen(symbol, orderType, volume, currentPrice, SL, TP, comment))
  {
    OrderDoneOrError(false, __FUNCTION__, trade);
  }
  else
  {
    OrderDoneOrError(true, __FUNCTION__, trade);
  }
}

void HandlePendingOrder(CTrade &trade, string actionType, string symbol,
  double volume, double price, double limitPrice, double SL, double TP, 
  ENUM_ORDER_TYPE_TIME exp_type, datetime expiration, string comment)
{
  ENUM_ORDER_TYPE orderType;
  if(actionType == "ORDER_TYPE_BUY_LIMIT") orderType = ORDER_TYPE_BUY_LIMIT;
  else if(actionType == "ORDER_TYPE_SELL_LIMIT") orderType = ORDER_TYPE_SELL_LIMIT;
  else if(actionType == "ORDER_TYPE_BUY_STOP") orderType = ORDER_TYPE_BUY_STOP;
  else if(actionType == "ORDER_TYPE_SELL_STOP") orderType = ORDER_TYPE_SELL_STOP;
  else if(actionType == "ORDER_TYPE_BUY_STOP_LIMIT") orderType = ORDER_TYPE_BUY_STOP_LIMIT;
  else if(actionType == "ORDER_TYPE_SELL_STOP_LIMIT") orderType = ORDER_TYPE_SELL_STOP_LIMIT;
  else
  {
    ActionDoneOrError(true, __FUNCTION__, "Invalid pending order type: " + actionType);
    return;
  }

  if(orderType == ORDER_TYPE_BUY_STOP_LIMIT || orderType == ORDER_TYPE_SELL_STOP_LIMIT)
  {
    if(orderType == ORDER_TYPE_BUY_STOP_LIMIT && (limitPrice == 0 || limitPrice >= price)) {
      ActionDoneOrError(true, __FUNCTION__, "STOP_LIMIT orders require separate stop and limit prices");
      return;
    }
    else if(orderType == ORDER_TYPE_SELL_STOP_LIMIT && (limitPrice == 0 || limitPrice <= price)) {
      ActionDoneOrError(true, __FUNCTION__, "STOP_LIMIT orders require separate stop and limit prices");
      return;
    }
  } else {
    limitPrice = price;
  }

  if(trade.OrderOpen(symbol, orderType, volume, price, limitPrice, SL, TP, exp_type, expiration, comment))
  {
    OrderDoneOrError(false, __FUNCTION__, trade);
  }
  else
  {
    OrderDoneOrError(true, __FUNCTION__, trade);
  }
}

void HandlePositionModify(CTrade &trade, int idNumber, double SL, double TP)
{
  if(trade.PositionModify(idNumber, SL, TP))
  {
    OrderDoneOrError(false, __FUNCTION__, trade);
  }
  else
  {
    OrderDoneOrError(true, __FUNCTION__, trade);
  }
}

void HandlePositionClose(CTrade &trade, string actionType, int idNumber, double volume)
{
  if(actionType == "POSITION_PARTIAL")
  {
    if(trade.PositionClosePartial(idNumber, volume))
    {
      OrderDoneOrError(false, __FUNCTION__, trade);
    }
    else
    {
      OrderDoneOrError(true, __FUNCTION__, trade);
    }
  }
  else if(actionType == "POSITION_CLOSE_ID")
  {
    if(trade.PositionClose(idNumber))
    {
      OrderDoneOrError(false, __FUNCTION__, trade);
    }
    else
    {
      OrderDoneOrError(true, __FUNCTION__, trade);
    }
  } else {
    ActionDoneOrError(true, __FUNCTION__, "Invalid action type: " + actionType);
  }
}

void HandlePositionCloseSymbol(CTrade &trade, string symbol)
{
  if(trade.PositionClose(symbol))
  {
    OrderDoneOrError(false, __FUNCTION__, trade);
  }
  else
  {
    OrderDoneOrError(true, __FUNCTION__, trade);
  }
}

void HandleOrderModify(CTrade &trade, int idNumber, double price, double SL, double TP, ENUM_ORDER_TYPE_TIME exp_type, datetime expiration)
{
  if(trade.OrderModify(idNumber, price, SL, TP, exp_type, expiration))
  {
    OrderDoneOrError(false, __FUNCTION__, trade);
  }
  else
  {
    OrderDoneOrError(true, __FUNCTION__, trade);
  }
}

void HandleOrderCancel(CTrade &trade, int idNumber)
{
  if(trade.OrderDelete(idNumber))
  {
    OrderDoneOrError(false, __FUNCTION__, trade);
  }
  else
  {
    OrderDoneOrError(true, __FUNCTION__, trade);
  }
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {

   ENUM_TRADE_TRANSACTION_TYPE  trans_type=trans.type;
   switch(trans.type)
     {
      case  TRADE_TRANSACTION_REQUEST:
        {
         CJAVal data, req, res;

         req["action"]=EnumToString(request.action);
         req["order"]=(int) request.order;
         req["symbol"]=(string) request.symbol;
         req["volume"]=(double) request.volume;
         req["price"]=(double) request.price;
         req["stoplimit"]=(double) request.stoplimit;
         req["sl"]=(double) request.sl;
         req["tp"]=(double) request.tp;
         req["deviation"]=(int) request.deviation;
         req["type"]=EnumToString(request.type);
         req["type_filling"]=EnumToString(request.type_filling);
         req["type_time"]=EnumToString(request.type_time);
         req["expiration"]=(int) request.expiration;
         req["comment"]=(string) request.comment;
         req["position"]=(int) request.position;
         req["position_by"]=(int) request.position_by;

         res["retcode"]=(int) result.retcode;
         res["result"]=(string) GetRetcodeID(result.retcode);
         res["deal"]=(int) result.order;
         res["order"]=(int) result.order;
         res["volume"]=(double) result.volume;
         res["price"]=(double) result.price;
         res["comment"]=(string) result.comment;
         res["request_id"]=(int) result.request_id;
         res["retcode_external"]=(int) result.retcode_external;

         data["request"].Set(req);
         data["result"].Set(res);

         string t=data.Serialize();
         if(debug)
            Print(t);
         InformClientSocket(sysSocket,t);
        }
      break;
      default:
        {} break;
     }
  }
//+------------------------------------------------------------------+
