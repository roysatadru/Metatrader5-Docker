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
        // Try to select position history
        if(!HistorySelectByPosition(position_id))
        {
            response["error"] = true;
            response["description"] = "Failed to select position history";
            response["position_id"] = (int)position_id;
        }
        else
        {
            bool is_closed = false;
            int total_deals = HistoryDealsTotal();
            
            // Loop through deals related to this position
            for(int i = 0; i < total_deals; i++)
            {
                ulong dealTicket = HistoryDealGetTicket(i);
                
                // Check if the deal belongs to our position and is a closing deal
                if(dealTicket > 0 && 
                   HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == position_id && 
                   (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
                {
                    is_closed = true;
                    break; // Position is closed, no need to check further deals
                }
            }
            
            response["error"] = false;
            response["position_id"] = (int)position_id;
            response["is_closed"] = is_closed;
        }
    }
    
    string t = response.Serialize();
    if(debug)
        Print(t);
    InformClientSocket(sysSocket, t);
}

