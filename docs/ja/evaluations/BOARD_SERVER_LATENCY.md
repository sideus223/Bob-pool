# Android実機での掲示板取得時間

運用投稿4件での現在の方式の単独測定です。[1,000件の比較](BOARD_SERVER_COMPARISON.md)と[20・100・500件の追加比較](BOARD_SERVER_SCALE_COMPARISON.md)とはデータ条件が異なります。

2026-10-14にUSB接続したAndroid端末でサーバー接続profile版を実行し、実際のログインセッションで最初のページを繰り返し取得しました。合成データやEmulatorによる結果とは区別します。

<br><br><br>





## 環境

| 項目 | 条件 |
|---|---|
| 端末 | Samsung SM-S931N、Android 16 / API 36 |
| アプリ | Flutter profile、Android arm64、`1.0.0+6` |
| 接続 | `DEMO_MODE=false`、実Firebase Authenticationセッション |
| クエリ | 有効投稿、作成時刻・文書IDで整列、初回最大20件 |
| 取得元 | `GetOptions(source: Source.server)` |
| 返却文書 | 全34回が4件、キャッシュ応答0回 |
| 反復 | 初回1回、ウォームアップ3回、測定30回。取得後のFlutterフレーム完了から1秒間隔 |
| サーバー変更 | 投稿の作成・変更・削除、ルール配布は行わず |

既存APKをローカルに保存し、署名の一致を確認して`adb install -r`で更新しました。アプリデータを消さずログインを維持しました。ネットワーク帯域やほかのアプリは統制していません。

<br><br><br>





## 結果

| 項目 | 初回1回 | ウォームアップ後30回の中央値 | ウォームアップ後30回のp95 |
|---|---:|---:|---:|
| サーバー取得要求からSDK結果受信まで | 2,412.793ms | 524.526ms | 547.677ms |
| 一覧取得開始からFlutterフレーム完了コールバックまで | 2,420.483ms | 531.306ms | 559.274ms |

SDK応答は最小422.164ms、最大602.893msでした。モデル変換の中央値は0.068ms、一覧読み込み完了からフレームコールバックまでは9.512msでした。異なる指標の中央値を加減して別の中央値とは解釈しません。

30値を並べて中央値を計算し、p95は`ceil(30 × 0.95)`番目の値としました。初回と次の3回は統計から除外しました。初回が遅い理由を接続・認証・SDK準備に分けて測定したわけではありません。

<br><br><br>





## 意味と限界

- SDK取得時間はネットワークとSDK処理を含む端末から見た時間です。
- フレーム時間は`addPostFrameCallback`で測定し、GPU描画完了や実際の表示時点までは測定していません。
- 返却は4文書で、ローカルの1,000件初回取得量比較とは条件が異なります。
- 同じ端末・1セッションの30反復であり、全ユーザーや別ネットワークを代表しません。
- この単独測定では旧版の実サーバー時間を測っていないため、**前後の改善率は算出していません。** 無制限取得は運用ルールで拒否され、後続比較は別パスの限定した一時読み取り権限を使いました。
- 時間、文書数、キャッシュ状態だけを保存し、本文・アカウント識別子・メール・トークンは除外しました。

<br><br><br>





## 再現とコード

`BOARD_LATENCY_PROBE=true`の測定ビルドだけで自動反復とログが有効になります。掲示板を一度開き、完了まで画面移動や追加更新を行いません。

```powershell
flutter build apk --profile --target-platform android-arm64 --dart-define=DEMO_MODE=false --dart-define=BOARD_LATENCY_PROBE=true --build-number=6 --no-pub
./tools/summarize_board_latency.ps1 -InputPath <log-path> -OutputPath <result-json-path>
```

取得34件とフレーム34件のログを集計します。キャッシュ、ID欠落・重複、取得エラー、クエリと画面の文書数不一致があれば集計を中止します。

- [測定概要・APK SHA-256](../../evaluations/board-server-latency-2026-10-14.json)
- [個人情報を除いた68イベント](../../evaluations/board-server-latency-events-2026-10-14.json)
- [測定スイッチとログ](../../../lib/services/board_latency_probe.dart)
- [取得・モデル変換時間](../../../lib/services/post_service.dart)
- [一覧と最初のフレーム](../../../lib/widgets/board/board_paged_list.dart)
- [集計スクリプト](../../../tools/summarize_board_latency.ps1)

測定コードの静的解析に問題はなく、掲示板ウィジェット・ページ取得の既存テスト10件が通過しました。集計の中央値とp95は既知の入力で確認しました。測定後はスイッチなしの同じprofile版を再インストールし、ログイン・正常表示を維持し、測定ログが出ないことを確認しました。

---

[掲示板の非同期状態管理に戻る](../contributions/board-async-state.md)
