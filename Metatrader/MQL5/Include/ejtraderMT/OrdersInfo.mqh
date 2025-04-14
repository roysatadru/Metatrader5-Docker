//+------------------------------------------------------------------+
#property copyright "ejtrader"
#property link      "https://github.com/ejtraderLabs/MQL5-ejtraderMT"

ENUM_ORDER_TYPE StringToEnum(string orderTypeStr)
{
   if (orderTypeStr == "ORDER_TYPE_BUY") return ORDER_TYPE_BUY;
   if (orderTypeStr == "ORDER_TYPE_SELL") return ORDER_TYPE_SELL;
   if (orderTypeStr == "ORDER_TYPE_BUY_LIMIT") return ORDER_TYPE_BUY_LIMIT;
   if (orderTypeStr == "ORDER_TYPE_SELL_LIMIT") return ORDER_TYPE_SELL_LIMIT;
   if (orderTypeStr == "ORDER_TYPE_BUY_STOP") return ORDER_TYPE_BUY_STOP;
   if (orderTypeStr == "ORDER_TYPE_SELL_STOP") return ORDER_TYPE_SELL_STOP;
   if (orderTypeStr == "ORDER_TYPE_BUY_STOP_LIMIT") return ORDER_TYPE_BUY_STOP_LIMIT;
   if (orderTypeStr == "ORDER_TYPE_SELL_STOP_LIMIT") return ORDER_TYPE_SELL_STOP_LIMIT;
   return ORDER_TYPE_BUY;
}

void OrderCalcMarginAction(CJAVal &dataObject)
{
   mControl.mResetLastError();
   
   ENUM_ORDER_TYPE action = (ENUM_ORDER_TYPE)StringToEnum(dataObject["order_type"].ToStr());
   string symbol = dataObject["symbol"].ToStr();
   double volume = dataObject["volume"].ToDbl();
   double price = dataObject["price"].ToDbl();
   double margin = EMPTY_VALUE;
   
   bool result = OrderCalcMargin(action, symbol, volume, price, margin);
   
   CJAVal response;
   response["error"] = !result;
   response["margin"] = margin;
   response["error_code"] = GetLastError();
   response["error_description"] = GetErrorDescription(GetLastError());
   
   string t = response.Serialize();
   if(debug)
      Print(t);
   InformClientSocket(sysSocket, t);
}

//+------------------------------------------------------------------+
//| Check if an order has been converted to a position               |
//+------------------------------------------------------------------+
void CheckOrderStatus(CJAVal &dataObject)
{
   // Extract the order ticket from the dataObject
   ulong orderTicket = (ulong)dataObject["id"].ToInt();
   
   CJAVal result;
   result["orderTicket"] = (string)orderTicket;
   
   // Initialize position ID
   ulong positionId = 0;
   bool orderFound = false;
   
   if (OrderSelect(orderTicket))
   {
      orderFound = true;
      // Order is active, get its state
      ENUM_ORDER_STATE orderState = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
      
      // In MQL5, an active order won't have a position ID yet
      result["isActive"] = true;
      result["hasPosition"] = false;
   }
   
   // If not found in active orders, check history
   if (!orderFound)
   {
      // Try to directly select the order by ticket
      if (HistoryOrderSelect(orderTicket))
      {
         orderFound = true;
         // Order found in history
         ENUM_ORDER_STATE orderState = (ENUM_ORDER_STATE)HistoryOrderGetInteger(orderTicket, ORDER_STATE);
         
         // If the order was filled, get the position ID
         if (orderState == ORDER_STATE_FILLED)
         {
            positionId = HistoryOrderGetInteger(orderTicket, ORDER_POSITION_ID);
            result["isActive"] = false;
            result["hasPosition"] = true;
            result["positionId"] = (string)positionId;
         }
         else
         {
            // Order was canceled, expired, or rejected
            result["isActive"] = false;
            result["hasPosition"] = false;
         }
      }
   }
   
   // If order not found anywhere
   if (!orderFound)
   {
      result["isActive"] = false;
      result["hasPosition"] = false;
      result["error"] = "Order not found";
   }
   
   // Send the result via ZMQ
   string t = result.Serialize();
   if (debug)
      Print(t);
   InformClientSocket(sysSocket, t);
}
