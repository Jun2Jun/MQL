//+------------------------------------------------------------------+
//|                                 OutputRateInfoMultiTimeFrame.mq4 |
//+------------------------------------------------------------------+

#property indicator_chart_window

#define TIME_FRAME_NUMBER 7

//---- buffers

//--- struct
struct CandleSticks
{
  datetime date;
  double open;
  double close;
  double high;
  double low;
};

//---- time series buffers

//--- global variable
string IndicatorName = "OutputRateInfo"; //Indicator Short Name
string InpFileName = "RateInfo.csv";  // ファイル名 
string InpDirectoryName = "Data"; // ディレクトリ名 

string UsePair[] = {"USDJPY", "EURUSD", "EURJPY", "GBPUSD", "GBPJPY", "AUDUSD", "AUDJPY", "XAUUSD"}; // ペアは、ここに追加すれば自動的に対応可能。
// サーバに問い合わせするときの通貨ペアの名称。FXTFの場合、通貨ペアに-cdがつくが、内部のファイルには-cdを付けたくないので、分けて使用する
// RequestPairは、OnInit内で値を入れる。
string RequestPair[] = {};

/*
string UsePair[] = {"USDJPY", "EURUSD", "GBPUSD", "AUDUSD", "USDCAD", "USDCHF", "NZDUSD",
                    "EURJPY", "GBPJPY", "AUDJPY", "CADJPY", "CHFJPY", "NZDJPY",
                    "EURGBP", "EURAUD", "EURCAD", "EURCHF", "EURNZD",
                    "GBPAUD", "GBPCAD", "GBPCHF", "GBPNZD",
                    "AUDCAD", "AUDCHF", "AUDNZD",
                    "CADCHF", "NZDCAD",
                    "NZDCHF"}; // ペアは、ここに追加すれば自動的に対応可能。
*/

bool UseTimeFrame[TIME_FRAME_NUMBER]; //各TimeFrameの使用有無
int TimeFrameSet[TIME_FRAME_NUMBER] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1};

datetime PrevCheckTime = 0; // 前回、価格を取得した日付時刻

//int TargetTimeFrameSetPos;

//------ extern valiab
//RateInfoの出力モード 0:表示している時間足が更新されたらall出力 1:時間足毎に更新されたら出力
//0の場合、表示しているTimeframeで足が更新されても、OnCalculate内で定義するminimum_refresh_bars以上の足が増加しないとRateInfoは出力されない
//例えば、minimum_refresh_barsが1の場合は、表示しているTimeframeで足が更新されても足は増加してないのでRateInfoは更新されない
//input int OutputMode = 0; 

// OutputRateInfoのパラメータ。Initializeで、OutputRateInfo[7]に格納する
input bool OutputRateInfo_Period_M5 = true;
input bool OutputRateInfo_Period_M15 = true;
input bool OutputRateInfo_Period_M30 = true;
input bool OutputRateInfo_Period_H1 = true;
input bool OutputRateInfo_Period_H4 = true;
input bool OutputRateInfo_Period_D1 = true;
input bool OutputRateInfo_Period_W1 = true;

input int RefreshInterval = 5; // 価格の取得間隔(分)
input int GetDataDepth = 950; // サーバから取得するMqlRatesの数。増やすことで欠損が防げるが、処理が重くなる。

input bool DebugMode = true;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
{
  // indicator short name
  IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName);

  // Set OutputRateInfo setting from external parameter
  if(OutputRateInfo_Period_M5) UseTimeFrame[0] = true; else UseTimeFrame[0] = false;
  if(OutputRateInfo_Period_M15) UseTimeFrame[1] = true; else UseTimeFrame[1] = false;
  if(OutputRateInfo_Period_M30) UseTimeFrame[2] = true; else UseTimeFrame[2] = false;
  if(OutputRateInfo_Period_H1) UseTimeFrame[3] = true; else UseTimeFrame[3] = false;
  if(OutputRateInfo_Period_H4) UseTimeFrame[4] = true; else UseTimeFrame[4] = false;
  if(OutputRateInfo_Period_D1) UseTimeFrame[5] = true; else UseTimeFrame[5] = false;
  if(OutputRateInfo_Period_W1) UseTimeFrame[6] = true; else UseTimeFrame[6] = false;
  
  //RequetPairの設定。FXTFの場合、通貨ペアに"-cd"が付く
  for(int i = 0; i < ArraySize(UsePair); i++) RequestPair[i] = UsePair[i] + "-cd";

  /*
  //TargetTimeFrameSetPosを計算しておく
  int period = Period();
  if(period == PERIOD_M1) TargetTimeFrameSetPos = 0;
  else if(period == PERIOD_M5) TargetTimeFrameSetPos = 1;
  else if(period == PERIOD_M15) TargetTimeFrameSetPos = 2;
  else if(period == PERIOD_M30) TargetTimeFrameSetPos = 3;
  else if(period == PERIOD_H1) TargetTimeFrameSetPos = 4;
  else if(period == PERIOD_H4) TargetTimeFrameSetPos = 5;
  else if(period == PERIOD_D1) TargetTimeFrameSetPos = 6;
  else if(period == PERIOD_W1) TargetTimeFrameSetPos = 7;
  */


  // clear Comment
  Comment("");
}
//+------------------------------------------------------------------+
//|                                                                  |
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

  // RefreshInterval毎にチェックするように、time_currentを丸める
  datetime time_current = TimeCurrent() / (RefreshInterval * 60) * (RefreshInterval * 60);
  // Print("time_current = " + time_current + ", PrevCheckTime = " + PrevCheckTime);
  // RefreshInterval経過していれば、MqlRatesを取得してファイルを更新する
  if(time_current > PrevCheckTime)
  {
    PrevCheckTime = time_current;
    MqlRates mql_rates[];
    for(int i = 0; i < ArraySize(UsePair); i++)
    {
      for(int j = 0; j < TIME_FRAME_NUMBER; j++)
      {
        if(UseTimeFrame[j] == true)
        {
          if(DebugMode) Print("Start CopyRates: " + RequestPair[i] + ", " + TimeFrameSet[j] + " at " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));
          // CopyRateがエラーなら飛ばす。自動的にサーバへ価格取得要求をするらしいので、次回更新する。
          ZeroMemory(mql_rates);
          if(CopyRates(RequestPair[i], TimeFrameSet[j], time_current, GetDataDepth, mql_rates) == -1)
            Print("CopyRates Error: " + RequestPair[i] + ", " + TimeFrameSet[j] + " at " + TimeToString(TimeCurrent()));
          else
          {
            if(DebugMode) Print("End CopyRates: " + RequestPair[i] + ", " + TimeFrameSet[j] + " at " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));
            //Get latest year from RateInfo
            int oldest_mql_rates_year = TimeYear(mql_rates[ArraySize(mql_rates)-1].time);
  
            //Get latest year from DataFile
            int search_limit = 10;
            int base_year = oldest_mql_rates_year;
            int latest_file_year= 0;
            for(int k = 0; k < search_limit; k++)
            {
              //search_year = latest_year - i;
              if(FileIsExist(InpDirectoryName + "\\" + IntegerToString(base_year - k) + UsePair[i] + IntegerToString(TimeFrameSet[j]) + InpFileName))
              {
                latest_file_year = base_year - k;
                break;
              }
            }
   
            //Get latest datetime from DataFile and RateInfo from DataFile
            datetime latest_file_datetime = 0;
            CandleSticks write_cs_file[];
            ArrayResize(write_cs_file, 0, 1000);
                 
            //If latest_file_year is not 0, copy write_cs_file from RateInfoFile
            if(latest_file_year != 0)
            {
              int read_file_handle = FileOpen(InpDirectoryName + "\\" + IntegerToString(latest_file_year)
                                     + UsePair[i] + IntegerToString(TimeFrameSet[j]) + InpFileName, FILE_READ | FILE_CSV);
              if(read_file_handle != INVALID_HANDLE)
              {
                // First low is used only getting laest_file_date_time.
                // Others are read but not used. (open, close, high, low)
                CandleSticks cs;
                cs.date = (datetime)FileReadNumber(read_file_handle);
                cs.open = (double)FileReadNumber(read_file_handle);
                cs.close = (double)FileReadNumber(read_file_handle);
                cs.high = (double)FileReadNumber(read_file_handle);
                cs.low = (double)FileReadNumber(read_file_handle);
                latest_file_datetime = cs.date;
             
                // Get RateInfo from DataFile
                // Then these are used to write in DataFile.
                if(DebugMode) Print("Start ReadRateInfo: " + UsePair[i] + ", " + TimeFrameSet[j] + " at " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));
                int l = 0;
                while(!FileIsEnding(read_file_handle) && l<GetDataDepth)
                {
                  ArrayResize(write_cs_file, l+1, 1000);
                  write_cs_file[l].date = (datetime)FileReadNumber(read_file_handle);
                  write_cs_file[l].open = (double)FileReadNumber(read_file_handle);
                  write_cs_file[l].close = (double)FileReadNumber(read_file_handle);
                  write_cs_file[l].high = (double)FileReadNumber(read_file_handle);
                  write_cs_file[l].low = (double)FileReadNumber(read_file_handle);
                  l++;
                }
                FileClose(read_file_handle);
                
                if(DebugMode) Print("End ReadRateInfo: " + UsePair[i] + ", " + TimeFrameSet[j] + " at " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));
              }
            }
   
            //Write Candle Stick's mql_rates to DataFile
            if(DebugMode) Print("Start WriteRateInfo: " + UsePair[i] + ", " + TimeFrameSet[j] + " at " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));
            int seek = ArraySize(mql_rates) - 1;
            int limit = 0;
            int write_pos = 0;
   
            int mql_rates_year = TimeYear(mql_rates[seek].time);
            int write_rateinfo_file_handle = 0;
            
            string write_file_path = InpDirectoryName + "\\" + IntegerToString(mql_rates_year)
                                     + UsePair[i] + IntegerToString(TimeFrameSet[j]) + InpFileName;
            Print(write_file_path);
            if(FileIsExist(write_file_path)) FileDelete(write_file_path);
            write_rateinfo_file_handle = FileOpen(write_file_path, FILE_WRITE|FILE_CSV);
            if(write_rateinfo_file_handle == INVALID_HANDLE)
            {
              Print("LastError=", GetLastError());
              return (-1);
            }
            
            while(seek >= 0)
            {
              //Below sentence is in while statement, seek value is overflow and happend exception.
              //if(mql_rates_year < latest_file_year)
              //{
              //  Print("seek=",seek, ",time=",iTime(_Symbol, TimeFrameSet[i], seek), ",latest_file_datetime=", latest_file_datetime);
              //  break;
              //}
                   
              //If mql_rates's year changed, close file handle.
              //if(mql_rates_year != TimeYear(mql_rates[seek].time) && write_rateinfo_file_handle != 0)
              //{
              //  FileClose(write_rateinfo_file_handle);
              //  mql_rates_year = TimeYear(mql_rates[seek].time);
              //  write_rateinfo_file_handle = 0;
              //}
       
              //if(write_rateinfo_file_handle == 0)
              //{
              //}
       
              //Write task
              FileWrite(write_rateinfo_file_handle, 
                          mql_rates[seek].time,
                          mql_rates[seek].open,
                          mql_rates[seek].close,
                          mql_rates[seek].high,
                          mql_rates[seek].low);
              seek--;
            }
   
            //Write evacuated RateInfo from DataFile
            //int write_cs_size = ArraySize(write_cs_file);
            //for(int m = 0; m < write_cs_size; m++)
            //{
            //  FileWrite(write_rateinfo_file_handle, 
            //  write_cs_file[m].date, write_cs_file[m].open, write_cs_file[m].close, 
            //  write_cs_file[m].high, write_cs_file[m].low);
            //}
            FileClose(write_rateinfo_file_handle);
            
            if(DebugMode) Print("End WriteRateInfo: " + UsePair[i] + ", " + TimeFrameSet[j] + " at " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));
          }
        }
      }
    }
  }



  /*
  int i;
  
  //Set sLastBars
  static int sLastBars[TIME_FRAME_NUMBER]={0, 0, 0, 0, 0, 0, 0, 0};
  
  //Set minimum_refresh_bars: calculate start pos. 0/1
  int minimum_refresh_bars = 1;
  
  //Below alghorism is executed per timeframe
  //Common initialize and setting.
  int total_bars[TIME_FRAME_NUMBER];
  ArrayInitialize(total_bars, 0);

  bool refresh_bars[TIME_FRAME_NUMBER];
  ArrayInitialize(refresh_bars, false);

  int depth[TIME_FRAME_NUMBER];
  ArrayInitialize(depth, 0);
  
  //OutputMode:0のときは、ここでバーの更新を判断
  //OutputMode:1のときは、以下のfor文の中で個別に判断
  if(OutputMode == 0)
  {
    //即時更新のフラグとなるファイルが存在すれば、全てのバーを即時更新する
    //存在しない場合は、minimum_refresh_barsより、バーが増加したかを判定して、更新を判断する
    if(FileIsExist("Update" + _Symbol))
    {
      FileDelete("Update" + _Symbol);
      for(i=0; i<TIME_FRAME_NUMBER; i++)
      {
        refresh_bars[i] = true;
      }
    }else{
      //Calculate total_bars
      total_bars[TargetTimeFrameSetPos] = iBars(_Symbol, _Period);
      depth[TargetTimeFrameSetPos] = total_bars[TargetTimeFrameSetPos] - sLastBars[TargetTimeFrameSetPos];

      //バーが増加したかどうかを保持する変数をセット。
      //OutputMode:0のときの判定。TargetTimeFrameSetPosのdepthだけで判定
      if(depth[TargetTimeFrameSetPos] >= minimum_refresh_bars)
       {
        for(i=0; i<TIME_FRAME_NUMBER; i++)
        {
          refresh_bars[i] = true;
        }
      }else{
        return(0);
      }
    }
  }

  //Calculate total_bars
  for(i=0; i<TIME_FRAME_NUMBER; i++)
  {
    //Print("OutputRateInfo[" , i, "]=", OutputRateInfo[i]);
    if(OutputRateInfo[i])
    {
      //Calculate total_bars
      total_bars[i] = iBars(_Symbol, TimeFrameSet[i]);
        
      //バーが増加したかどうかを保持する変数をセット。
      //OutputMode:1のときの判定
      if(OutputMode == 1)
      {
        //バーが増加したかどうかを保持する変数をセット。マルチタイムなので、depth < base_pos, return(0)とするのではなく、
        //refresh_barsにbool値を格納して、あとで、まとめて判定する
        depth[i] = total_bars[i] - sLastBars[i];
        if(depth[i] >= minimum_refresh_bars) refresh_bars[i] = true;
      }

      //Print("total_bars=", total_bars[i], ",sLastBars=", sLastBars[i]);
  
      if(refresh_bars[i])
      {
        Print("iBars[", i, "]=", iBars(_Symbol, TimeFrameSet[i]), ", TimeFrameSet=", TimeFrameSet[i], ", Close=", iClose(_Symbol, TimeFrameSet[i], 0));
        //Get latest year from RateInfo
        int oldest_rateinfo_year = TimeYear(iTime(_Symbol, TimeFrameSet[i], depth[i]-1));

        //Get latest year from DataFile
        int search_limit = 10;
        int base_year = oldest_rateinfo_year;
        int latest_file_year = 0;
        for(int j=0; j<search_limit; j++)
        {
          //search_year = latest_year - i;
          if(FileIsExist(InpDirectoryName + "\\" + IntegerToString(base_year - j) + _Symbol + IntegerToString(TimeFrameSet[i]) + InpFileName))
          {
            latest_file_year = base_year - j;
            break;
          }
        }
  
        //Get latest datetime from DataFile and RateInfo from DataFile
        datetime latest_file_datetime = 0;
        CandleSticks write_cs_file[];
        ArrayResize(write_cs_file, 0, 1000);
        
        //If latest_file_year is not 0, copy write_cs_file from RateInfoFile
        if(latest_file_year != 0)
        {
          int read_file_handle = FileOpen(InpDirectoryName + "\\" + IntegerToString(latest_file_year)
                                + _Symbol + IntegerToString(TimeFrameSet[i]) + InpFileName, FILE_READ | FILE_CSV);
          if(read_file_handle != INVALID_HANDLE)
          {
            // First low is used only getting laest_file_date_time.
            // Others are read but not used. (open, close, high, low)
            CandleSticks cs;
            cs.date = (datetime)FileReadNumber(read_file_handle);
            cs.open = (double)FileReadNumber(read_file_handle);
            cs.close = (double)FileReadNumber(read_file_handle);
            cs.high = (double)FileReadNumber(read_file_handle);
            cs.low = (double)FileReadNumber(read_file_handle);
            latest_file_datetime = cs.date;
        
            // Get RateInfo from DataFile
            // Then these are used to write in DataFile.
            int k = 0;
            while(!FileIsEnding(read_file_handle))
            {
              ArrayResize(write_cs_file, k+1, 1000);
              write_cs_file[k].date = (datetime)FileReadNumber(read_file_handle);
              write_cs_file[k].open = (double)FileReadNumber(read_file_handle);
              write_cs_file[k].close = (double)FileReadNumber(read_file_handle);
              write_cs_file[k].high = (double)FileReadNumber(read_file_handle);
              write_cs_file[k].low = (double)FileReadNumber(read_file_handle);
              k++;
            }
            FileClose(read_file_handle);
          }
        }
  
        //Write Candle Stick's RateInfo to DataFile
        int seek = 0;
        int limit = 0;
        int write_pos = 0;
  
        int rateinfo_year = TimeYear(iTime(_Symbol, TimeFrameSet[i], seek));
        int write_rateinfo_file_handle = 0;
        while(seek < total_bars[i])
        {
          //Below sentence is in while statement, seek value is overflow and happend exception.
          if(iTime(_Symbol, TimeFrameSet[i], seek) < latest_file_datetime)
          {
            //Print("seek=",seek, ",time=",iTime(_Symbol, TimeFrameSet[i], seek), ",latest_file_datetime=", latest_file_datetime);
            break;
          }
    
          //If rateinfo's year changed, close file handle.
          if(rateinfo_year != TimeYear(iTime(_Symbol, TimeFrameSet[i], seek)) && write_rateinfo_file_handle != 0)
          {
            FileClose(write_rateinfo_file_handle);
            rateinfo_year = TimeYear(iTime(_Symbol, TimeFrameSet[i], seek));
            write_rateinfo_file_handle = 0;
          }
  
          if(write_rateinfo_file_handle == 0)
          {
            write_rateinfo_file_handle = FileOpen(InpDirectoryName + "\\" + IntegerToString(rateinfo_year)
                                          + _Symbol + IntegerToString(TimeFrameSet[i]) + InpFileName, FILE_WRITE|FILE_CSV);
            if(write_rateinfo_file_handle == INVALID_HANDLE)
            {
              Print("LastError=", GetLastError());
              return (-1);
            }
          }
    
          //Write task
          FileWrite(write_rateinfo_file_handle, 
                    iTime(_Symbol, TimeFrameSet[i], seek),
                    iOpen(_Symbol, TimeFrameSet[i], seek),
                    iClose(_Symbol, TimeFrameSet[i], seek),
                    iHigh(_Symbol, TimeFrameSet[i], seek),
                    iLow(_Symbol, TimeFrameSet[i], seek));
          seek ++;
        }

        //Write evacuated RateInfo from DataFile
        int write_cs_size = ArraySize(write_cs_file);
        for(k=0; k<write_cs_size; k++)
        {
          FileWrite(write_rateinfo_file_handle, 
            write_cs_file[k].date, write_cs_file[k].open, write_cs_file[k].close, 
            write_cs_file[k].high, write_cs_file[k].low);
        }
        FileClose(write_rateinfo_file_handle);
      }
    }
    //Refresh sLastBars
    sLastBars[i] = total_bars[i];
  }
  */
  return(0);
}


