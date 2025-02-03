//+------------------------------------------------------------------+
//|                                                 jAlertLine24.mq4 |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Indicator Name : jAlertLine                                      |
//| Version : 2.4.1031                                               |
//| Last Update : 2018.10.31                                         |
//| Description : チャート上にトレンドラインを表示し、                   |
//|               ラインを抜けたらアラートを出す                        |
//| Version 2.1                                                      |
//| - ファイルを読み込み、アラートラインを表示／編集する機能を追加        |
//| - アラートのボタンと入力ボックスをフラグにより表示／非表示が、        |
//|   切り替えられるように設定化                                     |
//| Version 2.2                                                      |
//| - アラート時に、LINEへメッセージを送る機能を追加                 |
//| Version 2.3                                                      |
//| - アラートを表示、通知するタイミングのデフォルトを即時に変更     |
//| - ファイルを読み込んでアラートラインを表示／編集した時と、       |
//|   アラートを出した後に、現在のアラート状況を示す                 |
//|   AlertLine_[pair].csvを出力するように処理を追加                 |
//| Version 2.3                                                      |
//| - アラートを表示、通知するタイミングのデフォルトを即時に変更     |
//| Version 2.4                                                      |
//| - アラートラインを外部から消すために、                           |
//|   csvファイルのプライスが0であれば、ラインを削除するように変更   |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window

#define SW_SHOW 5
#define SW_HIDE 0
#import "shell32.dll"
int ShellExecuteW(int hWnd, int lpVerb, string lpFile, string lpParameters, string lpDirectory, int nCmdShow);
#import

//#import "mystdlib.ex4"
//  void sendMyMail(string subject, string comment, bool sendmail);
//#import

enum notifyTime
{
  Off = 0, //即時
  On = 1,  //Bar確定時
};

input color resistanceColor = clrRoyalBlue;  //レジスタンスの色
input color supportColor = clrCrimson;       //サポートの色
input int size = 8;                          //文字の大きさ
input int Yaxis = 0;                         //表示位置
input int Width_Line = 2;                    //ラインの太さ
input bool snooze = false;                   //スヌーズ機能(Alert_span[sec]の間、アラートラインを超えてもAlertを出さない)
input notifyTime AlertMode = 0;              //アラートを出すタイミング
input bool showAlertEdit = false;            //アラートを編集するButton、Editの表示切替
input int ReadFileSpan = 1;                  //外部からアラート表示を指示するファイルを確認する時間間隔 [min]。1から60の範囲。
input bool sendLINE = true;                  //LINEへのアラート送信フラグ

string indiName = "AlertLine";
datetime timelock;
int Alert_span = 60;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(){
  int bars_count = WindowBarsPerChart();
  string highest = DoubleToStr(High[iHighest(NULL, 0, MODE_HIGH, bars_count, 0)], _Digits);
  string lowest = DoubleToStr(Low[iLowest(NULL, 0, MODE_LOW, bars_count, 0)], _Digits);

  //水平ライン用のButton作成
  if(ObjectFind(0, indiName+"_RButton") == -1) ButtonCreate(indiName+"_RButton", size*15, size*6+Yaxis, size*5, size*3, CORNER_RIGHT_LOWER, "OFF", size, clrWhite, clrDarkGray);
  if(ObjectFind(0, indiName+"_SButton") == -1) ButtonCreate(indiName+"_SButton", size*15, size*3+Yaxis, size*5, size*3, CORNER_RIGHT_LOWER, "OFF", size, clrWhite, clrDarkGray);
  //水平ライン用のEdit作成
  if(ObjectFind(0, indiName+"_REdit") == -1) EditCreate(indiName+"_REdit", size*10, size*6+Yaxis, size*10, size*3, highest, size, CORNER_RIGHT_LOWER);
  if(ObjectFind(0, indiName+"_SEdit") == -1) EditCreate(indiName+"_SEdit", size*10, size*3+Yaxis, size*10, size*3, lowest, size, CORNER_RIGHT_LOWER);
  
  //showAlertEditがfalseであれば、各オブジェクト非表示にする
  if(!showAlertEdit)
  {
    ObjectSetInteger(0, indiName+"_RButton", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    ObjectSetInteger(0, indiName+"_SButton", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    ObjectSetInteger(0, indiName+"_REdit", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    ObjectSetInteger(0, indiName+"_SEdit", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
  }
  
  //オブジェクト削除のイベント通知を設定
  ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);

  return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){

   if(_UninitReason == REASON_REMOVE || _UninitReason == REASON_PARAMETERS) objDelete(indiName);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]){
   
   //分単位でアラートをセットするファイルの有無をチェック
   static bool file_read_flg = false;
   static int prev_minute = 0;
   int minute = Minute();
   if(minute%ReadFileSpan== 0 && minute!=prev_minute)
   {
     //ファイルからアラートを設定
     ShowLineFromFile();
     //AlertLine_[pair].csvを更新
     UpdateAlertLineFile();
     prev_minute = minute;
   }
   
   //Bar更新時に、レジスタンス／サポートのトレンドラインの価格を再計算する
   static int sLastBars=0;
   int total_bars = Bars(_Symbol, _Period);
   int base_pos = 1;
   int depth = total_bars - sLastBars;
   //Print(total_bars, ",", sLastBars);
   //AlertModeによって、ラインを超えたかどうかの判定を変える
   if(depth < AlertMode)
   {
     return 0;
   }
   
   //レジスタンスとサポートを取得
   double ResistancePrice = StringToDouble(ObjectGetString(0, indiName+"_REdit", OBJPROP_TEXT));
   double SupportPrice = StringToDouble(ObjectGetString(0, indiName+"_SEdit", OBJPROP_TEXT));
   
   //Priceがレジスタンスを超えた場合の処理
   if(close[0] >= ResistancePrice && 
      ObjectGetInteger(0, indiName+"_RButton", OBJPROP_STATE, true) &&
      TimeLocal() > timelock){
      
      if(snooze) timelock = TimeLocal() + Alert_span;
      else{
         ObjectSetInteger(0, indiName+"_RButton", OBJPROP_STATE, false);
         ObjectSetInteger(0, indiName+"_RButton", OBJPROP_BGCOLOR, clrDarkGray);
         ObjectSetString(0, indiName+"_RButton", OBJPROP_TEXT, "OFF");
         
         int bars_count = WindowBarsPerChart();
         double highest = High[iHighest(NULL, 0, MODE_HIGH, bars_count, 0)];
         ObjectSetString(0, indiName+"_REdit", OBJPROP_TEXT, DoubleToStr(highest, _Digits));
         
         ObjectDelete(indiName+"_RLine");
      }
      
      Alert(_Symbol, " High Alert at ", close[0]);
      SendLINE(_Symbol + " HighAlert " + DoubleToString(close[0], _Digits));
      //sendMyMail("H" + (string)close[0] + Symbol(), (string)close[0], true);
      UpdateAlertLineFile();
   }

   //Priceがサポートを割った場合の処理
   if(close[0] <= SupportPrice && 
      ObjectGetInteger(0, indiName+"_SButton", OBJPROP_STATE, true) &&
      TimeLocal() > timelock){
      
      if(snooze) timelock = TimeLocal() + Alert_span;
      else{
         ObjectSetInteger(0, indiName+"_SButton", OBJPROP_STATE, false);
         ObjectSetInteger(0, indiName+"_SButton", OBJPROP_BGCOLOR, clrDarkGray);
         ObjectSetString(0, indiName+"_SButton", OBJPROP_TEXT, "OFF");
         
         int bars_count = WindowBarsPerChart();
         double lowest = Low[iLowest(NULL, 0, MODE_LOW, bars_count, 0)];
         ObjectSetString(0, indiName+"_SEdit", OBJPROP_TEXT, DoubleToStr(lowest, _Digits));
         
         ObjectDelete(indiName+"_SLine");
      }
      
      Alert(_Symbol, "  Low Alert at ", close[0]);
      SendLINE(_Symbol + " LowAlert " + DoubleToString(close[0], _Digits));
      //sendMyMail("L" + (string)close[0] + Symbol(), (string)close[0], true)
      UpdateAlertLineFile();
   }
   sLastBars = total_bars;
   return(rates_total);
}


//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam){

   if(id == CHARTEVENT_OBJECT_CLICK){
   
      if(sparam == indiName+"_RButton"){

         if(ObjectGetInteger(0, indiName+"_RButton", OBJPROP_STATE, false)){    
              
            ObjectSetInteger(0, indiName+"_RButton", OBJPROP_BGCOLOR, resistanceColor);
            ObjectSetString(0, indiName+"_RButton", OBJPROP_TEXT, "ON");
            
            double ResistancePrice = StringToDouble(ObjectGetString(0, indiName+"_REdit", OBJPROP_TEXT));
            HLine(indiName+"_RLine", ResistancePrice, Width_Line, resistanceColor);
         }
         else{
            ObjectSetInteger(0, indiName+"_RButton", OBJPROP_BGCOLOR, clrDarkGray);    
            ObjectSetString(0, indiName+"_RButton", OBJPROP_TEXT, "OFF");
                    
            ObjectDelete(indiName+"_RLine");
         }
      }

      if(sparam == indiName+"_SButton"){

         if(ObjectGetInteger(0, indiName+"_SButton", OBJPROP_STATE, false)){     
             
            ObjectSetInteger(0, indiName+"_SButton", OBJPROP_BGCOLOR, supportColor);
            ObjectSetString(0, indiName+"_SButton", OBJPROP_TEXT, "ON");
            
            double ResistancePrice = StringToDouble(ObjectGetString(0, indiName+"_SEdit", OBJPROP_TEXT));
            HLine(indiName+"_SLine", ResistancePrice, Width_Line, supportColor);            
         }
         else{
            ObjectSetInteger(0, indiName+"_SButton", OBJPROP_BGCOLOR, clrDarkGray);
            ObjectSetString(0, indiName+"_SButton", OBJPROP_TEXT, "OFF");
            
            ObjectDelete(indiName+"_SLine");
         }
      }
      
      int chart_num = WindowBarsPerChart();
      double low_price = iLowest(NULL, 0, MODE_LOW, chart_num);
      double high_price = iHighest(NULL, 0, MODE_LOW, chart_num);
      //レジスタンスのトレンドラインを押下
      if(sparam == indiName+"_RTButton"){

         if(ObjectGetInteger(0, indiName+"_RTButton", OBJPROP_STATE, false)){    
              
            ObjectSetInteger(0, indiName+"_RTButton", OBJPROP_BGCOLOR, resistanceColor);
            ObjectSetString(0, indiName+"_RTButton", OBJPROP_TEXT, "RT ON");
            
            TLine(indiName+"_RTLine", Time[chart_num-1], high_price, Time[0], (high_price - Close[0]) / 2, Width_Line, resistanceColor);
         }
         else{
            ObjectSetInteger(0, indiName+"_RTButton", OBJPROP_BGCOLOR, clrDarkGray);    
            ObjectSetString(0, indiName+"_RTButton", OBJPROP_TEXT, "RT OFF");
                    
            ObjectDelete(indiName+"_RTLine");
         }
      }
   }

   if(id == CHARTEVENT_OBJECT_DRAG){
   
      if(sparam == indiName+"_RLine"){
      
         double RLinePrice = ObjectGetDouble(0, indiName+"_RLine", OBJPROP_PRICE);
         
         ObjectSetString(0, indiName+"_REdit", OBJPROP_TEXT, DoubleToStr(RLinePrice, _Digits));
      
      }
            
      if(sparam == indiName+"_SLine"){
      
         double SLinePrice = ObjectGetDouble(0, indiName+"_SLine", OBJPROP_PRICE);
         
         ObjectSetString(0, indiName+"_SEdit", OBJPROP_TEXT, DoubleToStr(SLinePrice, _Digits));
      
      }
   }

   if(id == CHARTEVENT_OBJECT_DELETE){
   
      if(sparam == indiName+"_RLine"){
         
         ObjectSetInteger(0, indiName+"_RButton", OBJPROP_STATE, false);
         ObjectSetInteger(0, indiName+"_RButton", OBJPROP_BGCOLOR, clrDarkGray);
         ObjectSetString(0, indiName+"_RButton", OBJPROP_TEXT, "OFF");
      
      }
            
      if(sparam == indiName+"_SLine"){
      
         ObjectSetInteger(0, indiName+"_SButton", OBJPROP_STATE, false);
         ObjectSetInteger(0, indiName+"_SButton", OBJPROP_BGCOLOR, clrDarkGray);
         ObjectSetString(0, indiName+"_SButton", OBJPROP_TEXT, "OFF");
      
      }
   }


   if(id == CHARTEVENT_OBJECT_ENDEDIT){
   
      if(sparam == indiName+"_REdit"){
      
         double REdit = StringToDouble(ObjectGetString(0, indiName+"_REdit", OBJPROP_TEXT));
         
         if(REdit == 0){
         
            int bars_count = WindowBarsPerChart();
            string highest = DoubleToStr(High[iHighest(NULL, 0, MODE_HIGH, bars_count, 0)], _Digits);

            ObjectSetString(0, indiName+"_REdit", OBJPROP_TEXT, highest);
            
            REdit = StringToDouble(highest);
            
         }
         
         if(ObjectGetInteger(0, indiName+"_RButton", OBJPROP_STATE, true)) HLine(indiName+"_RLine", REdit, Width_Line, resistanceColor);

      }

      if(sparam == indiName+"_SEdit"){
      
         double SEdit = StringToDouble(ObjectGetString(0, indiName+"_SEdit", OBJPROP_TEXT));
   
         if(SEdit == 0){
         
            int bars_count = WindowBarsPerChart();
            string lowest = DoubleToStr(Low[iLowest(NULL, 0, MODE_LOW, bars_count, 0)], _Digits);

            ObjectSetString(0, indiName+"_SEdit", OBJPROP_TEXT, lowest);
            
            SEdit = StringToDouble(lowest);
            
         }
         
         if(ObjectGetInteger(0, indiName+"_SButton", OBJPROP_STATE, true)) HLine(indiName+"_SLine", SEdit, Width_Line, supportColor);

      }
   }
   
}

//+------------------------------------------------------------------+

void HLine(string Line_name, double price, int Line_width, color Line_color){
   
   if (ObjectFind(0, Line_name) != 0) {
   
      ObjectCreate(0, Line_name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, Line_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, Line_name, OBJPROP_WIDTH, Line_width);
      ObjectSetInteger(0, Line_name, OBJPROP_COLOR, Line_color);
      ObjectSetInteger(0, Line_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, Line_name, OBJPROP_HIDDEN, true);
      
   }
   else{
      ObjectMove(Line_name, 0, 0, price);
   }
   
   ChartRedraw();
}

void TLine(string Line_name, datetime dt1, double price1, datetime dt2, double price2, int Line_width, color Line_color)
{
  if(ObjectFind(0, Line_name) != 0)
  {
    ObjectCreate(0, Line_name, OBJ_TREND, 0, dt1, price1, dt2, price2);
    ObjectSetInteger(0, Line_name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, Line_name, OBJPROP_WIDTH, Line_width);
    ObjectSetInteger(0, Line_name, OBJPROP_COLOR, Line_color);
    ObjectSetInteger(0, Line_name, OBJPROP_BACK, true);
    ObjectSetInteger(0, Line_name, OBJPROP_HIDDEN, true);
  }else{
    ObjectSetInteger(0, Line_name, OBJPROP_TIME, 0, dt1);
    ObjectSetInteger(0, Line_name, OBJPROP_TIME, 1, dt2);
    ObjectSetDouble(0, Line_name, OBJPROP_PRICE, 0, price1);
    ObjectSetDouble(0, Line_name, OBJPROP_PRICE, 1, price2);
 }
 ChartRedraw();
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
   ObjectSetString(0,name,OBJPROP_FONT, "Arial");
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
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font_size);
   ObjectSetInteger(0,name,OBJPROP_ALIGN, ALIGN_CENTER);
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


void objDelete(string basicName){

   for(int i=ObjectsTotal();i>=0;i--){
      string ObjName = ObjectName(i);
      if(StringFind(ObjName, basicName) >=0) ObjectDelete(ObjName);
   }
}

//+------------------------------------------------------------------+
//| DrawAlertLineFromFile                                            |
//| CSVファイルから取引履歴をインポートする                          |
//+------------------------------------------------------------------+
void ShowLineFromFile()
{
  ResetLastError();
  string filepath = "DrawAlertLine\\DrawAlertLine_" + _Symbol + ".csv";
  double s_price = 0.0; //support lineのプライス
  double r_price = 0.0; //resistance lineのプライス
  bool set_s = false; //supportの変更有無
  bool set_r = false; //resistanceの変更有無
  
  // FILE_READを使用せず、1行読み込み、','の数を数えて、形式が正しいかどうかを判別する。
  // その後、','で分割して、各要素に入れる。
  int file_handle = FileOpen(filepath, FILE_READ);
  
  if(file_handle != INVALID_HANDLE)
  {
    //最後の行まで読む。途中で重複があれば、新しい方で上書き
    while(!FileIsEnding(file_handle))
    {
      //CSVファイルのカラムデータ
      //kind(Resistance or Support), price
      string row_data = FileReadString(file_handle);
      string column_data[];
      //読み込んだ行データを分割
      int column_num = StringSplit(row_data, ',', column_data);
    
      //読み込んだカラム数が、定義と合ってなければ、そこで終了
      if(column_num != 2)
      {
        Print("Column size is not much!");
        Print("Column size = " + IntegerToString(column_num) + ", row_data =" + row_data);
        break;
      }
      //ラインの種別とpriceをセット
      string kind = column_data[0];
      if(kind == "R")
      {
        set_r = true;
        if(column_data[1] == "") r_price = 0.0;
        else r_price = StringToDouble(column_data[1]);
      }
      else if(kind == "S")
      {
        set_s = true;
        if(column_data[1] == "") s_price = 0.0;
        else s_price = StringToDouble(column_data[1]);
      }
    }

    //ラインを描画し、ボタンをON、EDITにプライスをセットする
    int bars_count;
    if(set_r == true)
    {
      if(r_price != 0.0)
      {
        HLine(indiName+"_RLine", r_price, Width_Line, resistanceColor);
        ObjectSetInteger(0, indiName+"_RButton", OBJPROP_STATE, true);
        ObjectSetInteger(0, indiName+"_RButton", OBJPROP_BGCOLOR, resistanceColor);
        ObjectSetString(0, indiName+"_RButton", OBJPROP_TEXT, "ON");
        ObjectSetString(0, indiName+"_REdit", OBJPROP_TEXT, DoubleToStr(r_price, _Digits));
      }else{
        //0.0であれば、ボタンをOFFにしてラインを消去
        ObjectSetInteger(0, indiName+"_RButton", OBJPROP_STATE, false);
        ObjectSetInteger(0, indiName+"_RButton", OBJPROP_BGCOLOR, clrDarkGray);
        ObjectSetString(0, indiName+"_RButton", OBJPROP_TEXT, "OFF");
         
        bars_count = WindowBarsPerChart();
        double highest = High[iHighest(NULL, 0, MODE_HIGH, bars_count, 0)];
        ObjectSetString(0, indiName+"_REdit", OBJPROP_TEXT, DoubleToStr(highest, _Digits));
        ObjectDelete(indiName+"_RLine");
      }
    }
    if(set_s == true)
    {
      if(s_price != 0.0)
      {
        HLine(indiName+"_SLine", s_price, Width_Line, supportColor);
        ObjectSetInteger(0, indiName+"_SButton", OBJPROP_STATE, true);
        ObjectSetInteger(0, indiName+"_SButton", OBJPROP_BGCOLOR, supportColor);
        ObjectSetString(0, indiName+"_SButton", OBJPROP_TEXT, "ON");
        ObjectSetString(0, indiName+"_SEdit", OBJPROP_TEXT, DoubleToStr(s_price, _Digits));
      }else{
        ObjectSetInteger(0, indiName+"_SButton", OBJPROP_STATE, false);
        ObjectSetInteger(0, indiName+"_SButton", OBJPROP_BGCOLOR, clrDarkGray);
        ObjectSetString(0, indiName+"_SButton", OBJPROP_TEXT, "OFF");
        
        bars_count = WindowBarsPerChart();
        double lowest = Low[iLowest(NULL, 0, MODE_LOW, bars_count, 0)];
        ObjectSetString(0, indiName+"_SEdit", OBJPROP_TEXT, DoubleToStr(lowest, _Digits));
        
        ObjectDelete(indiName+"_SLine");
      }
    }
  }else{
    //File does not exist.
    return;
  }
  FileClose(file_handle);
  FileDelete(filepath);
}

//+------------------------------------------------------------------+
//| UpdateAlertLineFile                                              |
//| 記載のアラートラインの状況を示す、AlertLineState_[pair].csvを更新|
//+------------------------------------------------------------------+
void UpdateAlertLineFile()
{
  ResetLastError();
  string filepath = "DrawAlertLine\\AlertLineState_" + _Symbol + ".csv";
  
  //AlertLineState_[pair].csvを削除して、作成する
  FileDelete(filepath);
  int file_handle = FileOpen(filepath, FILE_WRITE | FILE_CSV, ',');
  
  //レジスタンスとサポートを取得
  double ResistancePrice = StringToDouble(ObjectGetString(0, indiName+"_REdit", OBJPROP_TEXT));
  double SupportPrice = StringToDouble(ObjectGetString(0, indiName+"_SEdit", OBJPROP_TEXT));
  string ResistanceAlertState = ObjectGetString(0, indiName+"_RButton", OBJPROP_TEXT);
  string SupportAlertState = ObjectGetString(0, indiName+"_SButton", OBJPROP_TEXT);
  
  //AlertLineState_[pair].csvに書き込む
  if(ResistanceAlertState == "ON") FileWrite(file_handle, "R", ResistancePrice);
  if(SupportAlertState == "ON") FileWrite(file_handle, "S", SupportPrice);
  
  FileClose(file_handle);
}

void SendLINE(string msg)
{
  string send_line_exe = "C:\\Program Files (x86)\\NotifyByLine\\NotifyByLine.exe";
  string send_line_param = "-m=\"" + msg + "\"";
  ShellExecuteW(0, 0, send_line_exe, send_line_param, "", SW_SHOW);
}