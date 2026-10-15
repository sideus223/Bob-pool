# APKのダウンロードと利用方法

[Release](https://github.com/sideus223/Bob-pool/releases/tag/v1.0.0-build.12)でサーバー接続版とデモ版を提供します。両方とも同じ推薦アルゴリズムと146特徴の学習モデルを含みます。アプリのUIは韓国語です。

| ファイル | 使い方 | 保存先 |
|---|---|---|
| [サーバー接続版](https://github.com/sideus223/Bob-pool/releases/download/v1.0.0-build.12/bob-pool.apk) | アプリで登録・ログイン、インターネット接続が必要 | アカウント別Firestore |
| [デモ版](https://github.com/sideus223/Bob-pool/releases/download/v1.0.0-build.12/bob-pool-demo.apk) | ログインなしで推薦・お気に入り・選択・レシピを体験 | 端末内SharedPreferences |

<br><br><br>





## App Check

接続版はPlay IntegrityでApp Checkトークンを取得し、AuthenticationとFirestoreに送信します。旧接続APKは更新が必要です。一般的なエミュレーターではデモ版、または個別登録した開発用デバッグプロバイダーを使用します。

## インストール

Android 7.0以上でAPKをダウンロードしてインストールします。接続版にはサーバー設定が含まれるため、利用者によるFirebase設定は不要です。デモは実ログインとサーバー掲示板を使いません。

同じアプリIDのため、2種類を別アプリとして同時にインストールできません。同じ開発用証明書で署名したAPKは既存アプリを削除せず更新できます。Google Play公開用署名ではなく、レビュー用APKです。

<br><br><br>





## ファイルの確認

- バージョン：`1.0.0+12`、アプリID：`com.babpool.app`、API 24以上。
- アーキテクチャ：arm64-v8a・armeabi-v7a・x86_64。
- 接続版：56,137,830 bytes。デモ：54,315,822 bytes。
- APK Signature Scheme v2署名を確認済みです。
- [SHA256SUMS.txt](https://github.com/sideus223/Bob-pool/releases/download/v1.0.0-build.12/SHA256SUMS.txt)でファイルのハッシュを確認できます。

[検証範囲](VERIFICATION.md)
