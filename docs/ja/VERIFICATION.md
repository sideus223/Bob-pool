# 品質確認

<br><br><br>





## 自動テスト

- Flutter：106件通過、1件スキップ。スキップは別フラグで実行する原版との大量比較です。
- Firestore権限・移行：41件通過。
- Dartフォーマットと静的解析に問題はありません。
- デモAPKのビルドを確認しています。

GitHubでの実行結果は[Actions](https://github.com/sideus223/Bob-pool/actions)で確認できます。

<br><br><br>





## 実機とサーバーの確認範囲

デモではホーム、条件入力、推薦理由、お気に入り、選択、レシピ、再推薦を確認しました。接続版ではログイン維持、掲示板取得、マイページ、お気に入り一覧、推薦、アカウント保存案内を確認しました。

実Firebase SDKで学習・好みの保存、新セッションの再取得、モデル互換動作を確認しています。Mock・Emulatorの結果と、実SDK・画面確認は区別します。

<br><br><br>





## 評価の範囲

[原版との比較](evaluations/ORIGINAL_RECOMMENDATION_COMPARISON.md)と[学習前後比較](evaluations/FEEDBACK_LEARNING_COMPARISON.md)は仮想の好みによる機械的評価です。実ユーザーの満足度や推薦精度とは扱いません。

[掲示板の投稿数別比較](evaluations/BOARD_SERVER_SCALE_COMPARISON.md)は実端末・実サーバーの初回応答測定です。アプリ全体の速度改善率を示すものではありません。

[APKと利用方法](APK.md)
