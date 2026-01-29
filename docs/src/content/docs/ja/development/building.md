---
title: ビルド
description: 各プラットフォーム向けのビルド手順
---

Flutter Server Box は、クロスプラットフォームビルドのためにカスタムビルドシステム (`fl_build`) を使用しています。

## 前提条件

- Flutter SDK (stable チャネル)
- プラットフォーム固有のツール (iOS 用の Xcode、Android 用の Android Studio)
- Rust ツールチェーン (一部のネイティブ依存関係のため)

## 開発用ビルド

```bash
# 開発モードで実行
flutter run

# 特定のデバイスで実行
flutter run -d <device-id>
```

## 製品用ビルド

プロジェクトではビルドに `fl_build` を使用します。

```bash
# 特定のプラットフォーム向けにビルド
dart run fl_build -p <platform>

# 利用可能なプラットフォーム:
# - ios
# - android
# - macos
# - linux
# - windows
```

## プラットフォーム固有のビルド

### iOS

```bash
dart run fl_build -p ios
```

以下が必要です。
- Xcode がインストールされた macOS
- CocoaPods
- 署名用の Apple Developer アカウント

### Android

```bash
dart run fl_build -p android
```

以下が必要です。
- Android SDK
- Java Development Kit (JDK)
- 署名用のキーストア

### macOS

```bash
dart run fl_build -p macos
```

### Linux

```bash
dart run fl_build -p linux
```

### Windows

```bash
dart run fl_build -p windows
```

Visual Studio がインストールされた Windows が必要です。

## ビルド前/後処理

`make.dart` スクリプトが以下を処理します。

- メタデータの生成
- バージョン文字列の更新
- プラットフォーム固有の構成

## トラブルシューティング

### クリーンビルド

```bash
flutter clean
dart run build_runner build --delete-conflicting-outputs
flutter pub get
```

### バージョンの不一致

すべての依存関係に互換性があることを確認してください。
```bash
flutter pub upgrade
```

## リリースチェックリスト

1. `pubspec.yaml` のバージョンを更新する
2. コード生成を実行する
3. テストを実行する
4. すべてのターゲットプラットフォーム向けにビルドする
5. 実機でテストする
6. GitHub リリースを作成する
