#property indicator_chart_window
#property strict

int OnCalculate (const int rates_total,      // size of input time series 
                 const int prev_calculated,  // bars handled in previous call 
                 const datetime& time[],     // Time 
                 const double& open[],       // Open 
                 const double& high[],       // High 
                 const double& low[],        // Low 
                 const double& close[],      // Close 
                 const long& tick_volume[],  // Tick Volume 
                 const long& volume[],       // Real Volume 
                 const int& spread[]         // Spread 
               )
{
   static datetime prev_time = iTime(NULL, PERIOD_M1, 0);
   if(prev_time != iTime(NULL, PERIOD_M1, 0))
   {
      prev_time = iTime(NULL, PERIOD_M1, 0);

      // ファイルを開く
      string filename = _Symbol + "_Spread.csv";
      int hfile = FileOpen(filename, FILE_WRITE | FILE_CSV, ",");
      // ファイルが存在しない場合はヘッダー行を追加
      if(!FileIsExist(filename))
      {
         FileWrite(hfile, "DateTime,Spread\n");
      }
      // データを追記
      string data = TimeToString(time[0], TIME_SECONDS) + "," + IntegerToString(spread[0]) + "\n";
      FileWrite(hfile, data);
   }

   return(0);
}

