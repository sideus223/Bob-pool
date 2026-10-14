# APKのダウンロードと利用方法

[Release](https://github.com/sideus223/Bob-pool/releases/tag/v1.0.0)でサーバー接続版とデモ版を提供します。両方とも同じ推薦アルゴリズムと146特徴の学習モデルを含みます。アプリのUIは韓国語です。

| ファイル | 使い方 | 保存先 |
|---|---|---|
| [サーバー接続版](https://github.com/sideus223/Bob-pool/releases/download/v1.0.0/bob-pool.apk) | アプリで登録・ログイン、インターネット接続が必要 | アカウント別Firestore |
| [デモ版](https://github.com/sideus223/Bob-pool/releases/download/v1.0.0/bob-pool-demo.apk) | ログインなしで推薦・お気に入り・選択・レシピを体験 | 端末内SharedPreferences |

<br><br><br>





## インストール

Android 7.0以上でAPKをダウンロードしてインストールします。接続版にはサーバー設定が含まれるため、利用者によるFirebase設定は不要です。デモは実ログインとサーバー掲示板を使いません。

同じアプリIDのため、2種類を別アプリとして同時にインストールできません。同じ開発用証明書で署名したAPKは既存アプリを削除せず更新できます。Google Play公開用署名ではなく、レビュー用APKです。

<br><br><br>





## ファイルの確認

- バージョン：`1.0.0`、アプリID：`com.babpool.app`、API 24以上。
- アーキテクチャ：arm64-v8a・armeabi-v7a・x86_64。
- 接続版：56,088,478 bytes。デモ：54,299,238 bytes。
- APK Signature Scheme v2署名を確認済みです。
- [SHA256SUMS.txt](https://github.com/sideus223/Bob-pool/releases/download/v1.0.0/SHA256SUMS.txt)でファイルのハッシュを確認できます。

[検証範囲](VERIFICATION.md)
