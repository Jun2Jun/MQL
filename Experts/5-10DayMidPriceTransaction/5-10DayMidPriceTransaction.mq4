//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2018, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

#property strict

bool input_sell_on = true;
bool input_friday_on = true;

enum use_times {
   GMT9, //WindowsPCの時間を使って計算する
   GMT9_BACKTEST, // EAで計算された時間を使う（バックテスト用）
   GMT_KOTEI// サーバータイムがGMT+0で固定されている（バックテスト用）
};

input use_times set_time = GMT9;//時間取得方法
input int natu = 6;//夏加算時間（バックテスト用）
input int huyu = 7;//冬加算時間（バックテスト用）
datetime calculate_time() {

   if(set_time == GMT9) {
      return TimeGMT() + 60 * 60 * 9;
   }
   if(set_time == GMT9_BACKTEST) {
      return getJapanTime();
   }
   if(set_time == GMT_KOTEI) {
      return TimeCurrent() + 60 * 60 * 9;
   }

   return 0;

}

input int MagicNumber =1115111;//マジックナンバー
input int Slippage = 10;//スリッページ
input int Spread = 10;//スプレッド制限
input double input_lot = 0.1;//ロットサイズ
input bool hukuri_on = true;//複利を適応する

bool buy_entry_on = true;
bool sell_entry_on = true;
void OnTick() {

   static datetime prev_time = iTime(NULL,1440,0);
   if(TimeHour(calculate_time())==23)
      if(prev_time != iTime(NULL,1440,0)) {
         prev_time = iTime(NULL,1440,0);
         buy_entry_on = true;
         sell_entry_on = true;
      }

   if(is_buy() && is_spread_ok()&&position_count(0) < 1 && buy_entry_on && !is_nenmatu_nensi()) {
      position_entry(0);
   }

   if(input_sell_on) {
      if(is_sell() && is_spread_ok()&&position_count(1) < 1 && sell_entry_on && !is_nenmatu_nensi()) {
         position_entry(1);
         
      }
   }

   if(!is_buy() && is_spread_ok()&&position_count(0) > 0) {
      position_close(0);
   }
   if(!is_sell() && is_spread_ok()&&position_count(1) > 0) {
      position_close(1);
   }
   
   
   if(position_count(0) > 0){buy_entry_on=false;}
   if(position_count(1) > 0){sell_entry_on=false;}

}

bool is_nenmatu_nensi() {
   bool nenmatu = TimeMonth(calculate_time()) == 12 && (TimeDay(calculate_time()) == 25|| TimeDay(calculate_time()) == 26|| TimeDay(calculate_time()) == 27|| TimeDay(calculate_time()) == 28|| TimeDay(calculate_time()) == 29||TimeDay(calculate_time()) == 30|| TimeDay(calculate_time()) == 31) ;
   bool nensi = TimeMonth(calculate_time()) == 1 && (TimeDay(calculate_time()) == 1|| TimeDay(calculate_time()) == 2|| TimeDay(calculate_time()) == 3|| TimeDay(calculate_time()) == 4||TimeDay(calculate_time()) == 5|| TimeDay(calculate_time()) == 6) ;

   return nenmatu || nensi;
}


bool is_spread_ok() {

   return Ask - Bid < Spread * _Point;
}
void position_entry(int side) {

   int ticket=0;

   double qty = input_lot;
   if(hukuri_on) {
      qty = lot_optimize();
   }

   if(qty > 49) {
      qty=49;
   }
   if(side==0) {
      ticket= OrderSend(NULL,side,qty,Ask,Slippage,0,0,"ゴトー日",MagicNumber,0,clrGreen);
      if(ticket > 0) {
         buy_entry_on  =false;
      }
   }
   if(side==1) {
      ticket= OrderSend(NULL,side,qty,Bid,Slippage,0,0,"ゴトー日",MagicNumber,0,clrRed);
      if(ticket > 0) {
         sell_entry_on  =false;
      }
   }



}
bool is_buy() {
   if(is_gotobi() && is_buy_time() && is_weekday()) {

      return true;
   }

   if(input_friday_on) {
      if(is_friday() && is_buy_time() && is_weekday()) {

         return true;
      }


   }
   return false;
}
bool is_sell() {

int day = TimeDay(calculate_time());


   if(is_gotobi() && is_sell_time() && is_weekday()) {

      return true;
   }

   if(input_friday_on) {
      if(is_friday() && is_sell_time() && is_weekday()) {

         return true;
      }

   }

   return false;
}

// 5-10日の判定
// デフォルトの判定では、5-10日が週末の場合、金曜日を5-10日としている
bool is_gotobi() {
   datetime pc_time = calculate_time();
   int day = TimeDay(pc_time);
   double amari = MathMod(day,5);
   if(amari==0) {
      return true;
   }

   int youbi = TimeDayOfWeek(pc_time);

   if(youbi==FRIDAY && amari==3) {
      return true;
   }
   if(youbi==FRIDAY && amari==4) {
      return true;
   }

   return false;
}

bool is_friday() {

   datetime pc_time = calculate_time();
   int youbi = TimeDayOfWeek(pc_time);
   if(youbi==FRIDAY) {
      return true;
   }


   return false;
}

// 4:25～9:54だとtrueを返す
// デフォルトでは5-10が木曜日の場合、falseを返す
bool is_buy_time() {
   datetime pc_time = calculate_time();
   int hour = TimeHour(pc_time);
   int minute = TimeMinute(pc_time);
   
   if(TimeDayOfWeek(pc_time)==THURSDAY){return false;}

   if(hour==4 && minute > 24) {
      return true;
   }

   for(int i=5; i < 9; i++) {
      if(hour == i) {
         return true;
      }
   }

   if(hour==9 && minute <= 54) {
      return true;
   }
   return false;
}
bool is_sell_time() {
   datetime pc_time = calculate_time();
   int hour = TimeHour(pc_time);
   int minute = TimeMinute(pc_time);

   if(hour==10 && minute <= 25) {
      return true;
   }

   if(hour==9 && minute >= 55) {
      return true;
   }
   return false;
}


bool is_weekday() {

   datetime pc_time = calculate_time();
   int youbi = TimeDayOfWeek(pc_time);

   if(youbi==MONDAY) {
      return true;
   }
   if(youbi==TUESDAY) {
      return true;
   }
   if(youbi==WEDNESDAY) {
      return true;
   }
   if(youbi==THURSDAY) {
      return true;
   }
   if(youbi==FRIDAY) {
      return true;
   }
   return false;
}





double lot_optimize() {
   if(AccountInfoString(ACCOUNT_CURRENCY)=="JPY") {
      return NormalizeDouble(AccountBalance() * 0.01 * 0.01 * 0.04,2);
   }
   return NormalizeDouble(AccountBalance() * 0.01 * 0.04,2);

}

int position_count(int side) {

   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if(OrderType() == side) {
            if(OrderSymbol()==Symbol()) {
               if(OrderMagicNumber()==MagicNumber) {
                  count++;
               }
            }
         }
      }
   }
   return count;
}
void position_close(int side) {

   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if(OrderType() == side) {
            if(OrderSymbol()==Symbol()) {
               if(OrderMagicNumber()==MagicNumber) {
                  bool res= OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),0,clrAliceBlue);
               }
            }
         }
      }
   }
}
// 日本時間の取得
datetime getJapanTime() {
   datetime now = TimeCurrent();
   datetime summer = now + 60 * 60 * natu;
   datetime winter = now + 60 * 60 * huyu;

   if(is_summer()) {
      return summer;
   }
   return winter;
}


// サマータイムなら真を返す関数
bool is_summer() {
   datetime now = TimeCurrent();
   int year = TimeYear(now);
   int month = TimeMonth(now);
   int day = TimeDay(now);
   int dayOfWeek = TimeDayOfWeek(now);
   int hours = TimeHour(now);

   if (month < 3 || month > 11) {
      return false;
   }
   if (month > 3 && month < 11) {
      return true;
   }

   // アメリカのサマータイムは3月の第2日曜日から11月の第1日曜日まで
   if (month == 3) {
      int dstStart = 14 - dayOfWeek;
      if (day >= dstStart) {
         return true;
      } else {
         return false;
      }
   }

   if (month == 11) {
      int dstEnd = 7 - dayOfWeek;
      if (day < dstEnd) {
         return true;
      } else {
         return false;
      }
   }
   return false;
}
//+------------------------------------------------------------------+
