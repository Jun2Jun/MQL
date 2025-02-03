//+--------------------------------------------------------------
//| Indicator Name : jOutDeal
//| Version : 1.1
//| Last Update : 2023.9.8
//| Description : 過去x日間の取引履歴をcsvファイルに出力する
//|               出力したファイルは、SpreadSheetに取り込む予定
//+--------------------------------------------------------------

#include "ReplaceString.mqh"

struct OrderInfo
{
    string symbol;
    int lots;
    string type;
    datetime open_datetime;
    double open_price;
    double stop_loss;
    datetime close_datetime;
    double close_price;
    int time_difference;
    double order_profit;
    double order_swap;
} AllOrders[];

int OrderIndex = 0;

input int PastDay = 5; //遡ってcsvファイルに出力する取引の日数
input int TimeDifference = 6; //ターミナルとの時差

int OnStart()
{
    //保有、または、注文中のオーダー数を取得し、AllOrdersに格納
    int unsettled_order = OrdersTotal();
    SetAllOrders(unsettled_order, MODE_TRADES);

    //約定済みのオーダー数を取得し、AllOrdersに格納
    int settled_order = OrdersHistoryTotal();
    SetAllOrders(settled_order, MODE_HISTORY);

    //AllOrdersを約定日付順にソート
    SortAllOrders();
    /*
    OrderInfo temp_all_orders[];
    if(ArrayCopy(temp_all_orders, AllOrders) != orders_total + orders_history_total)
    {
        Print("Array copy Error");
        return(-1);
    }

    long sort_index[1][2];
    int all_order = unsettled_order + settled_order;
    ArrayResize(sort_index, all_order);
    
    for(int j=0; j<all_order; j++)
    {
        sort_index[j][0] = AllOrders[j].open_datetime;
        sort_index[j][1] = j;
    }
    ArraySort(sort_index);
    //とりあえず、このソートがうまく言っているか確認する
    */
  
    // csvファイルをオープン
    string file_path = "OutOrder.csv";
    int write_file_handle = FileOpen(file_path, FILE_WRITE | FILE_CSV);
    if(write_file_handle == INVALID_HANDLE)
    {
        Print("File doesn't open");
        return(-1);
    }

    // csvファイルに書き込む行データを生成
    for(int i=0; i<OrderIndex; i++)
    {
        string write_string = AllOrders[i].symbol + "\t"
                                + AllOrders[i].lots + "\t"
                                + AllOrders[i].type + "\t"
                                + AllOrders[i].open_datetime + "\t"
                                + AllOrders[i].open_price + "\t"
                                + AllOrders[i].stop_loss + "\t"
                                + AllOrders[i].close_datetime + "\t"
                                + AllOrders[i].close_price + "\t"
                                + AllOrders[i].time_difference + "\t"
                                + AllOrders[i].order_profit + "\t"
                                + AllOrders[i].order_swap + "\r\n";
        
        // csvファイルへ書き込み
        FileWriteString(write_file_handle, write_string);
    }

    FileClose(write_file_handle);

    return(0);
}

// オーダーをAllOrdersに格納
void SetAllOrders(int total, int mode)
{
    for(int i = total; i>=0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, mode))
        {
            // PastDay以内のオーダーのみAllOrdersに格納
            datetime order_open_datetime = OrderOpenTime() + 60 * 60 * TimeDifference;
            if(order_open_datetime > TimeCurrent() - 24 * 60 * 60 * PastDay)
            {
                AllOrders[OrderIndex].symbol = OrderSymbol();
                AllOrders[OrderIndex].lots = DoubleToString(OrderLots(), 2);

                string order_type = "";
                if(OrderType() == OP_BUY) order_type = "B";
                else if(OrderType() == OP_SELL) order_type = "S";
                AllOrders[OrderIndex].type = order_type;

                string str_order_open_datetime = TimeToString(order_open_datetime, TIME_DATE | TIME_MINUTES);
                StringReplace(str_order_open_datetime, ".", "/");
                AllOrders[OrderIndex].open_datetime = str_order_open_datetime;

                AllOrders[OrderIndex].open_price = DoubleToString(OrderOpenPrice(), 5);
                AllOrders[OrderIndex].stop_loss = DoubleToString(OrderStopLoss(), 5);

                datetime order_close_datetime = OrderCloseTime() + 60 * 60 * TimeDifference;
                string str_order_close_datetime = TimeToString(order_close_datetime, TIME_DATE | TIME_MINUTES);
                StringReplace(str_order_close_datetime, ".", "/");
                AllOrders[OrderIndex].close_datetime = str_order_close_datetime;

                AllOrders[OrderIndex].close_price = DoubleToString(OrderClosePrice(), 5);
                AllOrders[OrderIndex].time_difference = IntegerToString(TimeDifference);
                AllOrders[OrderIndex].order_profit = DoubleToString(OrderProfit(), 5);
                AllOrders[OrderIndex].order_swap = DoubleToString(OrderSwap(), 5);

                OrderIndex++;
            }
        }
    }
}

// オーダーをソート（挿入ソート）
// open_datetimeをキーにして降順でソート
void SortAllOrders() {
    int n = ArraySize(AllOrders);
    for (int i = 1; i < n; i++) {
        datetime key = AllOrders[i].open_datetime;
        int j = i - 1;

        while (j >= 0 && AllOrders[j].open_datetime < key) {
            AllOrders[j + 1] = AllOrders[j];
            j--;
        }

        AllOrders[j + 1] = AllOrders[i];
    }
}