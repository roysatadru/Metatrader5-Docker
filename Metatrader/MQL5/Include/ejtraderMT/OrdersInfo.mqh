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
