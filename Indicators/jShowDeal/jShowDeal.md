# jShowDeal
チャート上に.csvファイルから取り込んだ取引履歴を表示するインジケータ。  

## 機能
- チャート上に手動で、取引履歴を表示する
- どれか1つのペアでインジケータを動作させれば、表示されている他のペアのチャートにも履歴が表示される。

## 使用方法
- Filesフォルダに、履歴ファイルをdata.csvとして保存する。
- csvファイルの列データは下記の順序。  
列名はcsvファイルに含めない。  
pair, deal, entry_date, entry_rate, exit_date, exit_rate, time_difference  
pair：2文字の短縮系でも、6文字の非短縮系でも可。/は入れないこと。  
deal：'B' or 'S'  
date：'/'でも'.'でも可  
- "Import"をクリックするとdata.csvを読み込み履歴を表示する。  
どれか1つのペアでインジケータを動作させれば、表示されている他のペアのチャートにも履歴が表示される。
- "Delete"をクリックすると、全てのチャートから履歴が削除される。

## 入力パラメータの説明
|パラメータ|型|説明|デフォルト値|
|---|---|---|---|
|FontSize|int|文字の大きさ|12|
|FontName|string|文字のフォント|”Arial"|
|AskLabelColor|color|ロングエントリ時のプライスラベルの色|White|
|BidLabelColor|color|ショートエントリ時のプライスラベルの色|Aqua|
|ExitLabelColor|color|イグジット時のプライスラベルの色|Yellow|
|ShowExitLine|bool|エントリからイグジットまでラインを描画する／しないの設定|true|
|EntryExitLineColor|color|エントリからイグジットまで描画するラインの色|Yellow|
|EntryExitLineKind|int|エントリからイグジットまで描画するラインの種類|STYLE_DOT|
|LineWidth|int|エントリからイグジットまで描画するラインの幅|1|
|ShowTimeFrameM1|bool|1分足に表示する／しないの設定|true|
|ShowTimeFrameM5|bool|5分足に表示する／しないの設定|true|
|ShowTimeFrameM15|bool|15分足に表示する／しないの設定|true|
|ShowTimeFrameH1|bool|1時間足に表示する／しないの設定|true|
|ShowTimeFrameH4|bool|4時間足に表示する／しないの設定|true|
|ShowTimeFrameD1|bool|日足に表示する／しないの設定|false|
|ShowTimeFrameW1|bool|週足に表示する／しないの設定|false|
|ShowAllDeleteButton|bool|オブジェクトを全削除するボタンを表示する／しないの設定|true|
|ShowFileImportButton|bool|CSVファイルから取引履歴をインポートするボタンを表示する／しないの設定|true|

## 変更履歴
### 1.0

### 1.1