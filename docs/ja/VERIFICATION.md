# 品質確認

## 2026-10-15：App Check対応APKビルド12

- [ビルド12 Release](https://github.com/sideus223/Bob-pool/releases/tag/v1.0.0-build.12)はApp Check対応の接続APKと、Firebaseを使わないデモAPKです。配布APKは通常の起動処理を使い、実機確認用のエントリーポイントは含めていません。
- 実機でPlay Integrityトークン、アプリID一致、既存ログイン維持・更新、掲示板のサーバー取得を確認。同じ認証情報のFirestore要求でApp Checkあり200・なし403、同じ架空ログイン要求でApp Checkありの資格情報エラー400・なしのApp Checkエラー401を確認しました。実ユーザーの新規ログイン・登録や全画面の再検査ではありません。
- ユーザー承認後にIdentity Platformへ移行し、AuthenticationとFirestoreにApp Checkを適用しました。Spark無料プランを維持し、認証には日次アクティブユーザー3,000人の制限が適用されます。Firestoreの権限ルールは今回変更していません。
- 既存Flutter106テストとデモ初期化1テスト通過、既存の1スキップを維持。静的解析と接続・デモreleaseビルドが成功。[検証とAPKハッシュ](../evaluations/APP_CHECK_2026-10-15.json)
- 韓国語・日本語のダウンロード先はビルド12です。旧接続APKは更新が必要です。一般的なエミュレーターではデモ、または個別登録した開発用デバッグプロバイダーを使用します。[設定と制限（韓国語）](../APP_CHECK.md)

<br><br><br>





## 自動テスト

- Flutter：107件通過、1件スキップ。スキップは別フラグで実行する原版との大量比較です。
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
