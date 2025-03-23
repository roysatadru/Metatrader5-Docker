#property copyright "ejtrader"
#property link      "https://github.com/ejtraderLabs/MQL5-ejtraderMT"

//+------------------------------------------------------------------+
//| Check if a position is closed and return result                   |
//+------------------------------------------------------------------+
void CheckPositionClosed(CJAVal &dataObject)
{
    CJAVal response;
    
    // Extract position ID from request
    ulong position_id = (ulong)dataObject["id"].ToInt();
    
    if(position_id <= 0)
    {
        response["error"] = true;
        response["description"] = "Invalid position identifier";
    }
    else
    {
        bool is_closed = IsPositionClosed(position_id);
        response["error"] = false;
        response["position_id"] = (int)position_id;
        response["is_closed"] = is_closed;
        
        // Optional: Get additional information about closing deal if closed
        if(is_closed && HistorySelectByPosition(position_id))
        {
            for(int i = 0; i < HistoryDealsTotal(); i++)
            {
                ulong dealTicket = HistoryDealGetTicket(i);
                if(dealTicket > 0 && 
                HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == position_id &&
                (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
                {
                response["close_price"] = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                response["close_time"] = TimeToString((datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME));
                response["close_profit"] = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                break;
                }
            }
        }
    }
    
    string t = response.Serialize();
    if(debug)
        Print(t);
    InformClientSocket(sysSocket, t);
}
