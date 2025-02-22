//+-------------------------------------------------------------------------+
//| Indicator Name : jShowDealFromFile
//| Version : 1.0
//| Last Update : 2020.10.9
//| Description : チャート上に取引履歴を表示するインジケータ
//|  - csvファイルを読み込み、取引履歴に反映する
//| Change History :
//|  Version 1.0
//|   - 新規作成
//+-------------------------------------------------------------------------+

#property indicator_chart_window

// ---Object name rule
// エントリ矢印                 : ShowDeal_AskSign_[No.1]
// Ask, Bidのエントリ文字       : ShowDeal_AskText_[No.1]
// 隠しエントリ矢印(差益計算用) : ShowDeal_AskSign_[No.1]_Hidden
// イグジットのマーク           : ShowDeal_AskSign_[No.1]_ExitSign_[No.2]
// イグジットまでのライン       : ShowDeal_AskSign_[No.1]_ExitLine_[No.2]
// イグジットに対する差益表示   : ShowDeal_AskSign_[No.1]_ExitText_[No.2]
// [No.1] エントリサインの番号
// [No.2] 複数回決済のための番号

//--- input variable
input int FontSize = 12;             //文字の大きさ
input string FontName = "Arial";    //文字のフォント
input color AskLabelColor = White;    //買いエントリ時の価格ラベルの色
input color BidLabelColor = Aqua;   //売りエントリ時の価格ラベルの色
input color ExitLabelColor = Yellow;   //イグジット時の価格ラベルの色
input bool ShowExitLine = true;     //エントリからイグジットまでラインを描画する／しないの設定
input color EntryExitLineColor = Yellow;  //エントリからイグジットまで描画するラインの色
input int EntryExitLineKind = STYLE_DOT; //エントリからイグジットまで描画するラインの種類
input int LineWidth = 1;            //エントリからイグジットまで描画するラインの幅
input bool ShowTimeFrameM1 = true;  //1分足に表示する／しないの設定
input bool ShowTimeFrameM5 = true;  //5分足に表示する／しないの設定
input bool ShowTimeFrameM15 = true; //15分足に表示する／しないの設定
input bool ShowTimeFrameH1 = true;  //1時間足に表示する／しないの設定
input bool ShowTimeFrameH4 = true;  //4時間足に表示する／しないの設定
input bool ShowTimeFrameD1 = false;  //日足に表示する／しないの設定
input bool ShowTimeFrameW1 = false;  //週足に表示する／しないの設定
input bool ShowAllDeleteButton = true; //オブジェクトを全削除するボタンを表示する／しないの設定
input bool ShowFileImportButton = true; //CSVファイルから取引履歴をインポートするボタンを表示する／しないの設定

//--- global valiable
int MaxObjectNum = 100;       //売買を記録する最大数(売りと買いで別々にカウント）。
int EntryArrowCode = 5;   //エントリ時のサインを示す矢印(ラベル)のコード。
int ExitArrowCode = 6;   //イグジット時のサインを示す矢印(ラベル)のコード。
string ObjectPrefix = "jShowDeal";   //オブジェクトの接頭文字
bool CanReceiveEvent = true;        //イベント受信ステータス
string DealHisoryFilePath = "data.csv"; //取引履歴をインポートするファイルパス
int MaxImportRow = 500; //CSVファイルからImportするときの最大読み込み行数
string TargetPair[] = {"USDJPY", "EURUSD", "EURJPY", "GBPUSD", "GBPJPY", "AUDUSD", "AUDJPY"};

//+------------------------------------------------------------------+
void OnInit()
{
  /*
  //Labelの作成
  if(ObjectFind(0, ObjectPrefix + "_LabelTime") == -1)
    LabelCreate(ObjectPrefix + "_LabelTime", 0, 2*FontSize, 3*FontSize, 2*FontSize, "Time:", FontSize, CORNER_LEFT_UPPER);
  if(ObjectFind(0, ObjectPrefix + "_LabelPrice") == -1)
    LabelCreate(ObjectPrefix + "_LabelPrice", 17*FontSize, 2*FontSize, 4*FontSize, 2*FontSize, "Price:", FontSize, CORNER_LEFT_UPPER);

  //EditBoxの作成
  if(ObjectFind(0, ObjectPrefix + "_Time") == -1)
    EditCreate(ObjectPrefix + "_Time", 4*FontSize, 2*FontSize, 12*FontSize, 2*FontSize, "", FontSize, CORNER_LEFT_UPPER);
  if(ObjectFind(0, ObjectPrefix + "_Price") == -1)
    EditCreate(ObjectPrefix + "_Price", 21*FontSize, 2*FontSize, 8*FontSize, 2*FontSize, "", FontSize, CORNER_LEFT_UPPER);
  
  //Buttonの作成
  //Ask Button
  if(ObjectFind(0, ObjectPrefix + "_ButtonAsk") == -1)
    ButtonCreate(ObjectPrefix + "_ButtonAsk", 0, 4.2*FontSize, 5*FontSize, 2*FontSize, CORNER_LEFT_UPPER, "Ask", FontSize, clrWhite, AskLabelColor);
  //Bid Button
  if(ObjectFind(0, ObjectPrefix + "_ButtonBid") == -1)
    ButtonCreate(ObjectPrefix + "_ButtonBid", 5*FontSize, 4.2*FontSize, 5*FontSize, 2*FontSize, CORNER_LEFT_UPPER, "Bid", FontSize, clrWhite, BidLabelColor);
  //Exit Button
  if(ObjectFind(0, ObjectPrefix + "_ButtonExit") == -1)
    ButtonCreate(ObjectPrefix + "_ButtonExit", 10*FontSize, 4.2*FontSize, 5*FontSize, 2*FontSize, CORNER_LEFT_UPPER, "Exit", FontSize, clrWhite, ExitLabelColor);
  */
  //Import Button(ShowFileImportButtonがtrueのときのみ)
  if(ShowFileImportButton == true && ObjectFind(0, ObjectPrefix + "_ButtonImport") == -1)
    ButtonCreate(ObjectPrefix + "_ButtonImport", 0, 2*FontSize, 8*FontSize, 2*FontSize, CORNER_LEFT_UPPER, "Import", FontSize, clrWhite, clrDarkRed);

  //All Delete Button(ShowAllDeleteButtonがtrueのときのみ)
  if(ShowAllDeleteButton == true && ObjectFind(0, ObjectPrefix + "_ButtonAllDelete") == -1)
    ButtonCreate(ObjectPrefix + "_ButtonAllDelete", 8*FontSize, 2*FontSize, 8*FontSize, 2*FontSize, CORNER_LEFT_UPPER, "Delete", FontSize, clrWhite, clrBlack);

  /* LimitとsStopは、将来、実装するかも
  if(ObjectFind(0, ObjectPrefix + "_LimitButton") == -1)
    ButtonCreate(ObjectPrefix + "_LimitButton", 15*FontSize, 4.2*FontSize, 5*FontSize, 2*FontSize, CORNER_LEFT_UPPER, "Limit", FontSize, clrWhite, clrDarkBlue);
  if(ObjectFind(0, ObjectPrefix + "_StopButton") == -1)
    ButtonCreate(ObjectPrefix + "_StopButton", 20*FontSize, 4.2*FontSize, 5*FontSize, 2*FontSize, CORNER_LEFT_UPPER, "Stop", FontSize, clrWhite, clrDarkRed);
  */
}

//+------------------------------------------------------------------+
void OnDeinit (const int reason)
{
  if(reason != REASON_CHARTCHANGE)
  {
    //チャート上の全ての取引履歴オブジェクトを削除する
    // DeleteDealObjects();
    //Label、Edit、Buttonを削除する
    /*
    ObjectDelete(0, ObjectPrefix + "_LabelTime");
    ObjectDelete(0, ObjectPrefix + "_LabelPrice");
    ObjectDelete(0, ObjectPrefix + "_Time");
    ObjectDelete(0, ObjectPrefix + "_Price");
    ObjectDelete(0, ObjectPrefix + "_ButtonAsk");
    ObjectDelete(0, ObjectPrefix + "_ButtonBid");
    ObjectDelete(0, ObjectPrefix + "_ButtonExit");
    ObjectDelete(0, ObjectPrefix + "_ButtonAllDelete");
    ObjectDelete(0, ObjectPrefix + "_ButtonImport");
    */
  }
}

//+------------------------------------------------------------------+

void OnChartEvent(const int id,
                  const long& lparam,
                  const double& dparam,
                  const string& sparam)
{
  //共通で使用するサイン用オブジェクト名保存用変数
  string sign_obj_name;
  
  if(!CanReceiveEvent)
  {
    CanReceiveEvent = true;
    return;
  }
  
  //--- チャート上でオブジェクトがクリックされた
  if(id == CHARTEVENT_OBJECT_CLICK)
  {
    datetime time_from_box = 0;
    double price_from_box = 0;
    time_from_box = StringToTime(ObjectGetString(0, ObjectPrefix + "_Time", OBJPROP_TEXT));
    price_from_box = StringToDouble(ObjectGetString(0, ObjectPrefix + "_Price", OBJPROP_TEXT));
    
    //オブジェクトがクリックされたときは、以降のイベントを受け入れないようにする
    //オブジェクトをクリックすると、CHARTEVENT_OBJECT_CLICKとCHARTEVENT_CLICKが、
    //それぞれ、１回ずつ発生し、オブジェクトをクリックしたにも関わらず、CHARTEVENT_CLICKも発生してしまう為
    //落としたフラグは、OnCalculateで解除する
    CanReceiveEvent = false;
    
    /*
    // Askボタンを押下
    if(sparam == ObjectPrefix + "_ButtonAsk")
    {
      //ボタンをOffの状態に戻す
      ObjectSetInteger(0, ObjectPrefix + "_ButtonAsk", OBJPROP_STATE, false);

      //EditBoxに設定したprice, timeの位置に矢印を表示する
      int ask_entry_num = RetObjectNumber("", "Ask");
      CreateEntrySign("Ask", ask_entry_num, AskLabelColor, time_from_box, price_from_box);
    }
    
    // Bidボタンを押下
    if(sparam == ObjectPrefix + "_ButtonBid")
    {
      //ボタンをOffの状態に戻す
      ObjectSetInteger(0, ObjectPrefix + "_ButtonBid", OBJPROP_STATE, false);
      
      //EditBoxに設定したprice, timeの位置に矢印とBidの文字を表示する
      int bid_entry_num = RetObjectNumber("", "Bid");
      CreateEntrySign("Bid", bid_entry_num, BidLabelColor, time_from_box, price_from_box);
    }
    
    // Exitボタンを押下
    if(sparam == ObjectPrefix + "_ButtonExit")
    {
      //ボタンをOffの状態に戻す
      ObjectSetInteger(0, ObjectPrefix + "_ButtonExit", OBJPROP_STATE, false);
      
      //EditBoxに設定したprice, timeの位置にイグジットのサインとライン、差益をチャート上に表示する
      CreateExitSign();
    }
    */
    
    // All Deleteボタンを押下
    // ObjectPrefixを含むオブジェクトを全て削除する
    if(sparam == ObjectPrefix + "_ButtonAllDelete")
    {
      DeleteDealObjects();
    }
    
    // Importボタンを押下
    // CSVファイルから取引履歴をインポートする
    if(sparam == ObjectPrefix + "_ButtonImport")
    {
      ShowDealFrom1RowFile();
    }
  }
  
  //--- チャート上でマウスの左ボタンが押された
  if(id == CHARTEVENT_CLICK)
  {
    datetime time = 0;
    double price = 0;
    int sub_window;

    //クリック位置のTimeとPriceを取得
    ChartXYToTimePrice(0, (int)lparam, (int)dparam, sub_window, time, price);

    //Timeのテキストボックスに、クリックした位置のTimeをセット
    ObjectSetString(0, ObjectPrefix + "_Time", OBJPROP_TEXT, TimeToString(time, TIME_DATE) + " " + TimeToString(time, TIME_MINUTES));
    //Priceのテキストボックスに、クリックした位置のPriceをセット
    int digits = 0;
    if(StringFind(Symbol(), "USD") == 3)
    {
      digits = 5;
    }else if(StringFind(Symbol(), "JPY") == 3)
    {
      digits = 3;
    }
    ObjectSetString(0, ObjectPrefix + "_Price", OBJPROP_TEXT, DoubleToString(price, digits));
    
    //Print("time=", time, " price=", price);
  }
}

//+------------------------------------------------------------------+
int OnCalculate (const int rates_total,
                 const int prev_calculated,
                 const datetime& time[],
                 const double& open[],
                 const double& high[],
                 const double& low[],
                 const double& close[],
                 const long& tick_volume[],
                 const long& volume[],
                 const int& spread[]
                )
{
  //チャート上のイベントを受けられるようにする
  return(rates_total);
}

//+------------------------------------------------------------------+
//| CreateEntryExitSign                                              |
//| エントリ時、決済時の売買サインをチャート上に表示する             |
//+------------------------------------------------------------------+
void CreateEntryExitSign(long chart_id, string deal, string kind, int entry_num, datetime time, double price, long timeframe)
{
  //サインの色とオブジェクトの識別文字を設定
  string sign_obj_name = ObjectPrefix + "_" + deal + "Sign_"; //サインのオブジェクト接頭文字
  int clr; //サインの色
  if(kind == "Entry")
  {
    sign_obj_name += "Entry_" + IntegerToString(entry_num);
    if(deal == "B")
    {
      clr = AskLabelColor;
    }else if(deal == "S"){
      clr = BidLabelColor;
    }
  }
  else if(kind == "Exit")
  {
     sign_obj_name += "Exit_" + IntegerToString(entry_num);
     clr = ExitLabelColor;
  }
  
  if(ObjectFind(chart_id, sign_obj_name) == -1)
  {
    // オブジェクト名に重複が無かった場合、
    // EditBoxに設定したprice, timeの位置に矢印を作成する
    ObjectCreate(chart_id, sign_obj_name, OBJ_ARROW, 0, time, price);
  }else{
    // 既存のオブジェクトのprice，time, colorを読み込んだものに変更
    ObjectSetInteger(chart_id, sign_obj_name, OBJPROP_TIME, time);
    ObjectSetDouble(chart_id, sign_obj_name, OBJPROP_PRICE, price);
    ObjectSetInteger(chart_id, sign_obj_name, OBJPROP_COLOR, clr);
  }
  // 価格のラベルをセット
  int arrow_code = EntryArrowCode; //初期値は左側ラベルにしておく
  if(kind == "Exit")
  {
    arrow_code = ExitArrowCode;
  }
  ObjectSetInteger(chart_id, sign_obj_name, OBJPROP_ARROWCODE, arrow_code);
  // サインの色をセット
  ObjectSetInteger(chart_id, sign_obj_name, OBJPROP_COLOR, clr);
  // エントリサインを表示するタイムフレームをセット
  ObjectSetInteger(chart_id, sign_obj_name, OBJPROP_TIMEFRAMES, timeframe);
}

//+------------------------------------------------------------------+
//| CreateDealLine                                                   |
//| エントリから決済までのラインを描画する                           |
//+------------------------------------------------------------------+
void CreateDealLine(long chart_id, string deal, int entry_num, datetime entry_date, double entry_price, datetime exit_date, double exit_price, long timeframe)
{
  //エントリポイントから、エグジットポイントまでラインのオブジェクト名をセット
  string line_obj_name = ObjectPrefix + "_" + deal + "Line_" + IntegerToString(entry_num);

  if(ObjectFind(chart_id, line_obj_name) == -1)
  {
    //オブジェクト名に重複が無かった場合、ラインを新規作成する
    //ラインを描画
    ObjectCreate(chart_id, line_obj_name, OBJ_TREND, 0, entry_date, entry_price, exit_date, exit_price);
  }else{
    //オブジェクト名に重複があった場合、既存のラインの位置を変更する
    ObjectSetInteger(chart_id, line_obj_name, OBJPROP_TIME, 0, entry_date);
    ObjectSetDouble(chart_id, line_obj_name, OBJPROP_PRICE, 0, entry_price);
    ObjectSetInteger(chart_id, line_obj_name, OBJPROP_TIME, 1, exit_date);
    ObjectSetDouble(chart_id, line_obj_name, OBJPROP_PRICE, 1, exit_price);
  }
  //ラインの種類をセット
  ObjectSetInteger(chart_id, line_obj_name, OBJPROP_STYLE, EntryExitLineKind);
  //ラインの幅をセット
  ObjectSetInteger(chart_id, line_obj_name, OBJPROP_WIDTH, LineWidth);
  //ラインの色をセット
  ObjectSetInteger(chart_id, line_obj_name, OBJPROP_COLOR, EntryExitLineColor);
  //ラインは延長線にしない（始点から終点まで描画する）
  ObjectSetInteger(chart_id, line_obj_name, OBJPROP_RAY, false);
  //ラインを表示するタイムフレームをセット
  ObjectSetInteger(chart_id, line_obj_name, OBJPROP_TIMEFRAMES, timeframe);
}

//+-------------------------------------------------------------------------+
//| ShowDealFrom1RowFile                                                    |
//| 1行にEntryとExitが記載されているCSVファイルから取引履歴をインポートする |
//+-------------------------------------------------------------------------+
void ShowDealFrom1RowFile()
{
  ResetLastError();
  int index = 0, time_difference;
  string pair, deal;
  double entry_rate, exit_rate;
  datetime entry_date, exit_date;
  
  // FILE_READを使用せず、1行読み込み、','の数を数えて、形式が正しいかどうかを判別する。
  // その後、','で分割して、各要素に入れる。
  int file_handle = FileOpen(DealHisoryFilePath, FILE_READ);
  
  if(file_handle != INVALID_HANDLE)
  {
    //CSVファイルのカラムデータ
    //pair, deal, entry_date, entry_rate, exit_date, exit_rate, time_difference
    //pairは省略しないで'/'は省いておく
    //dealは、'B' or 'S' B:Buy S:Sell
    //dateは、'/'でも'.'でも、'.'にreplaceするので、どちらでも可
    int column_size = 7;
    string deal_data[];
    ArrayResize(deal_data, column_size);
    while(!FileIsEnding(file_handle))
    {
      string row_data = FileReadString(file_handle);
      int column_num = StringSplit(row_data, ',', deal_data);
      //読み込んだカラム数が、定義と合ってなければ、そこで、読み込み終了
      if(column_num != column_size)
      {
        Print("Column size is not much!");
        break;
      }
      //各要素をデータに変換してセットする
      pair = ConvertPairName(deal_data[0]);
      deal = deal_data[1];

      //deal_date[2]とdeal_date[4]のフォーマットを.区切りにリプレース
      StringReplace(deal_data[2], "/", ".");
      StringReplace(deal_data[4], "/", ".");

      //各変数に変換してセット
      entry_date = StringToTime(deal_data[2]);
      entry_rate = StringToDouble(deal_data[3]);
      exit_date = StringToTime(deal_data[4]);
      exit_rate = StringToDouble(deal_data[5]);
      time_difference = StringToInteger(deal_data[6]);

      //entry_dateとexit_dateにtime_differenceを反映させる
      entry_date = entry_date - 3600 * time_difference;
      exit_date = exit_date - 3600 * time_difference;
      
      // chart_idの取得
      long chart_id = RetCharID(pair);

      //entry_numの採番
      int entry_num = RetObjectNumber(chart_id, deal);
      
      //サインとラインを表示するタイムフレームをセット
      long show_timeframe = 0;
      if(ShowTimeFrameM1 == true ) show_timeframe = show_timeframe | OBJ_PERIOD_M1;
      if(ShowTimeFrameM5 == true ) show_timeframe = show_timeframe | OBJ_PERIOD_M5;
      if(ShowTimeFrameM15 == true ) show_timeframe = show_timeframe | OBJ_PERIOD_M15;
      if(ShowTimeFrameH1 == true ) show_timeframe = show_timeframe | OBJ_PERIOD_H1;
      if(ShowTimeFrameH4 == true ) show_timeframe = show_timeframe | OBJ_PERIOD_H4;
      if(ShowTimeFrameD1 == true ) show_timeframe = show_timeframe | OBJ_PERIOD_D1;
      if(ShowTimeFrameW1 == true ) show_timeframe = show_timeframe | OBJ_PERIOD_W1;

      //Entryサインを描画
      CreateEntryExitSign(chart_id, deal, "Entry", entry_num, entry_date, entry_rate, show_timeframe);
      
      //Exitサインを描画
      CreateEntryExitSign(chart_id, deal, "Exit", entry_num, exit_date, exit_rate, show_timeframe);
      
      //EntryとExitの間のラインを描画
      CreateDealLine(chart_id, deal, entry_num, entry_date, entry_rate, exit_date, exit_rate, show_timeframe);
      
      index++;
      //読み込み行数のチェックを行い、MaxImportRowを超えたら終了
      if(index > MaxImportRow)
      {
        Print("Too many import data.");
        break;
      }
    }
  }else{
    //ファイルハンドルが不正ならメッセージをターミナルに表示して終了
    Print("File does not Open. ", GetLastError());
  }
  FileClose(file_handle);
}

//+------------------------------------------------------------------+
//| RetCharID
//| pairで指定したチャートIDを返却する
//| チャートIDが見つからない場合は-1を返す
//| 引数：
//|   pair : ペア
//+------------------------------------------------------------------+
long RetCharID(string pair)
{
  long chart_id;
  chart_id = ChartFirst();
  while(chart_id != -1)
  {
    if(ChartSymbol(chart_id) == pair)
    {
      break;
    }
    chart_id = ChartNext(chart_id);
  }
  return chart_id;
}

//+------------------------------------------------------------------+
//| RetObjectNumber
//| chart_idで指定したチャート内にあるObjectの最大値を調べ、
//| 次に使用する番号を返す
//| MaxObjectNumまで使用されていれば、
//| 一番、チャート上の日付が古い番号を返す
//| 引数：                                                           |
//|   chart_id : チャートID                                                    |
//|   sign : Ask / Bidのサイン                                       |
//+------------------------------------------------------------------+
int RetObjectNumber(long chart_id, string sign)
{
  //チャート上のEntryのオブジェクト数をセットする
  int i;
  int oldest_obj_num = 0;
  datetime time;
  datetime oldest_time = 0;
  
  //オブジェクトの有無をチェック
  if(ObjectFind(chart_id, ObjectPrefix + "_" + sign + "Sign_Entry_" + IntegerToString(0)) >= 0)
  {
    //オブジェクトが有れば、oldest_timeを記録し、次の探索に進む
   oldest_time = ObjectGetInteger(chart_id, ObjectPrefix + "_" + sign + "Sign_Entry_" + IntegerToString(0), OBJPROP_TIME);
  }else{
    //無ければ、0が使用可能なので、0を返す
    return 0;
  }
  
  //1からMaxObjectNumを調べる
  for(i=1; i<MaxObjectNum; i++)
  {
    if(ObjectFind(chart_id, ObjectPrefix + "_" + sign + "Sign_Entry_" + IntegerToString(i)) < 0)
    {
      //オブジェクトが見つからなければ、使用可能なので、対象番号を返却
      return i;
    }else{
      //オブジェクトが見つかれば、timeを比較、oldest_timeとoldest_obj_numを記録しておき、次のオブジェクトを調べる
      time = ObjectGetInteger(chart_id, ObjectPrefix + "_" + sign + "Sign_Entry_" + IntegerToString(i), OBJPROP_TIME);
      if(time < oldest_time)
      {
        oldest_time = time;
        oldest_obj_num = i;
      }
    }
  }
  
  //全ての番号が埋まっていれば、一番古い時間のオブジェクト番号を返却する
  return oldest_obj_num;
}

//+------------------------------------------------------------------+
//| ConvertPairName
//| 短縮系のペア名を省略しない形に変換する
//| 例：UJ -> USDJPY
//+------------------------------------------------------------------+
string ConvertPairName(string str)
{
  string pair_name = str;
  if(str == "UJ") pair_name = "USDJPY";
  else if(str == "EU") pair_name = "EURUSD";
  else if(str == "EJ") pair_name = "EURJPY";
  else if(str == "GU") pair_name = "GBPUSD";
  else if(str == "GJ") pair_name = "GBPJPY";
  else if(str == "AU") pair_name = "AUDUSD";
  else if(str == "AJ") pair_name = "AUDJPY";
  else if(str == "UC") pair_name = "USDCAD";
  else if(str == "CJ") pair_name = "CADJPY";
  else if(str == "EC") pair_name = "EURCAD";
  else if(str == "EG") pair_name = "EURGBP";
  else if(str == "EA") pair_name = "EURAUD";
  else if(str == "AC") pair_name = "AUDCAD";

  return  pair_name;
}

//+------------------------------------------------------------------+
//| DeleteDealObjects                                                |
//| チャート上にあるObjectPrefixが付いたオブジェクトを削除する       |
//| Show / Hideボタンも含む                                          |
//+------------------------------------------------------------------+
void DeleteDealObjects()
{
  //全ての取引オブジェクトを削除する
  for(int i=0; i<ArraySize(TargetPair); i++)
  {
    // 対象Pairのchart_idの取得
    long chart_id = RetCharID(TargetPair[i]);
    
    // 買いのオブジェクトの削除
    int buy_index = 0;
    string find_buy_object = ObjectPrefix + "_" + "BSign_Entry_" + IntegerToString(buy_index);
    while(ObjectFind(chart_id, find_buy_object) != -1)
    {
      // エントリオブジェクトの削除
      ObjectDelete(chart_id, find_buy_object);
      // イグジットオブジェクトの削除
      ObjectDelete(chart_id, ObjectPrefix + "_" + "BSign_Exit_" + IntegerToString(buy_index));
      // ラインオブジェクトの削除
      ObjectDelete(chart_id, ObjectPrefix + "_" + "BLine_" + IntegerToString(buy_index));
      
      // buy_indexとfind_buy_objectを更新
      buy_index ++;
      find_buy_object = ObjectPrefix + "_" + "BSign_Entry_" + IntegerToString(buy_index);
    }
    
    // 売りのオブジェクトの削除
    int sell_index = 0;
    string find_sell_object = ObjectPrefix + "_" + "SSign_Entry_" + IntegerToString(sell_index);
    while(ObjectFind(chart_id, find_sell_object) != -1)
    {
      // エントリオブジェクトの削除
      ObjectDelete(chart_id, find_sell_object);
      // イグジットオブジェクトの削除
      ObjectDelete(chart_id, ObjectPrefix + "_" + "SSign_Exit_" + IntegerToString(sell_index));
      // ラインオブジェクトの削除
      ObjectDelete(chart_id, ObjectPrefix + "_" + "SLine_" + IntegerToString(sell_index));
      
      // sell_indexとfind_sell_objectを更新
      sell_index ++;
      find_sell_object = ObjectPrefix + "_" + "SSign_Entry_" + IntegerToString(sell_index);
    }
  }
}

//+------------------------------------------------------------------+
//| Create the button                                                |
//+------------------------------------------------------------------+
void ButtonCreate(string name, int x, int y, int width, int height,int corner, string text, int font_size, color clr, color back_clr){

   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT, FontName);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font_size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,back_clr);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrNONE);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,0);
}

//+------------------------------------------------------------------+
//| Create Edit object                                               |
//+------------------------------------------------------------------+
void EditCreate(string name, int x, int y, int width, int height, string text, int font_size, int corner){

   ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT, FontName);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font_size);
   ObjectSetInteger(0,name,OBJPROP_ALIGN, ALIGN_LEFT);
   ObjectSetInteger(0,name,OBJPROP_READONLY,false);
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrSilver);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,0);
}

//+------------------------------------------------------------------+
//| Create Edit object                                               |
//+------------------------------------------------------------------+
void LabelCreate(string name, int x, int y, int width, int height, string text, int font_size, int corner){

   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT, FontName);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font_size);
   ObjectSetInteger(0,name,OBJPROP_ALIGN, ALIGN_LEFT);
   ObjectSetInteger(0,name,OBJPROP_READONLY,true);
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrSilver);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,0);
}
