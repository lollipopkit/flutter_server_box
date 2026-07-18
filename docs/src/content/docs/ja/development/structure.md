---
title: プロジェクト構造
description: Server Box のコードベースを理解する
---

Server Box プロジェクトは、関心の分離を明確にしたモジュール式のアーキテクチャを採用しています。

## Monorepo レイアウト

```
flutter_server_box/
├── lib/               # Flutter アプリ(下記参照)
├── crates/
│   ├── sbm_parser/    # 共有ステータス解析ライブラリ(単一の情報源。
│   │                  # アプリは FFI 経由、monitor は直接依存)
│   └── sbm_ffi/       # flutter_rust_bridge バインディング crate + cargokit
│                      # Flutter プラグインシェル(同一ディレクトリ)
├── monitor/           # サーバーサイド監視(Rust サービス + React フロントエンド)
├── packages/          # ベンダリングした Dart フォーク(path 依存)
├── docs/              # このドキュメントサイト(Astro Starlight)
├── website/           # プロジェクトサイト
└── Cargo.toml         # Rust workspace ルート
```

## アプリのディレクトリ構造

```
lib/
├── core/              # コアユーティリティとエクステンション
├── data/              # データ層
│   ├── model/         # 機能別のデータモデル
│   ├── provider/      # Riverpod Provider
│   └── store/         # ローカルストレージ (Hive)
├── view/              # UI 層
│   ├── page/          # 主要なページ
│   └── widget/        # 再利用可能なウィジェット
├── generated/         # 生成されたローカライズファイル
├── l10n/              # ローカライズ用 ARB ファイル
└── hive/              # Hive アダプター
```

## コア層 (`lib/core/`)

ユーティリティ、エクステンション、およびルーティング構成が含まれます。

- **Extensions**: 一般的な型に対する Dart のエクステンション
- **Routes**: アプリのルーティング構成
- **Utils**: 共有ユーティリティ関数

## データ層 (`lib/data/`)

### モデル (`lib/data/model/`)

機能ごとに整理されています。

- `server/` - サーバー接続およびステータスモデル
- `container/` - Docker コンテナモデル
- `ssh/` - SSH セッションモデル
- `sftp/` - SFTP ファイルモデル
- `app/` - アプリ固有のモデル

### Provider (`lib/data/provider/`)

依存関係の注入と状態管理のための Riverpod Provider。

- サーバー関連の Provider
- UI 状態の Provider
- サービス関連の Provider

### ストア (`lib/data/store/`)

Hive ベースのローカルストレージ。

- サーバー情報の保存
- 設定情報の保存
- キャッシュ情報の保存

## UI 層 (`lib/view/`)

### ページ (`lib/view/page/`)

アプリケーションのメイン画面。

- `server/` - サーバー管理ページ
- `ssh/` - SSH ターミナルページ
- `container/` - コンテナ管理ページ
- `setting/` - 設定ページ
- `storage/` - SFTP ページ
- `snippet/` - スニペットページ

### ウィジェット (`lib/view/widget/`)

再利用可能な UI コンポーネント。

- サーバーカード
- ステータスチャート
- 入力コンポーネント
- ダイアログ

## 生成されたファイル

- `lib/generated/l10n/` - 自動生成されたローカライズコード
- `*.g.dart` - 生成されたコード (json_serializable, freezed, hive, riverpod)
- `*.freezed.dart` - Freezed による不変クラス

## パッケージディレクトリ (`/packages/`)

依存関係のカスタムフォークが含まれています。

- `dartssh2/` - SSH ライブラリ
- `xterm/` - ターミナルエミュレータ
- `fl_lib/` - 共有ユーティリティ
- `fl_build/` - ビルドシステム

## Rust 側

- `crates/sbm_parser/` - コマンドの生出力を構造化されたサーバーステータスに解析。
  アプリ(FFI 経由)と monitor が共用し、両者の解析は常に一致します。
- `crates/sbm_ffi/` - `sbm_parser` の薄い flutter_rust_bridge ラッパー。
  生成された Dart 側は `lib/src/rust/` にあります。
- `monitor/` - 独立した監視サービス。ドキュメントは `monitor/README.md`。
