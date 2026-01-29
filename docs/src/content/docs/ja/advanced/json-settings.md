---
title: 隠し設定 (JSON)
description: JSON エディタ経由で詳細設定にアクセスする
---

一部の設定は UI 上では非表示になっていますが、JSON エディタからアクセス可能です。

## アクセス方法

サイドメニューの**「設定」**を長押しすると、JSON エディタが開きます。

## よく使われる隠し設定

### serverTabUseOldUI

サーバータブに古い UI を使用します。

```json
{"serverTabUseOldUI": true}
```

**型:** boolean | **デフォルト:** false

### timeout

接続のタイムアウト時間（秒）。

```json
{"timeout": 10}
```

**型:** integer | **デフォルト:** 5 | **範囲:** 1-60

### recordHistory

履歴（SFTP パスなど）を保存します。

```json
{"recordHistory": true}
```

**型:** boolean | **デフォルト:** true

### textFactor

テキストの倍率。

```json
{"textFactor": 1.2}
```

**型:** double | **デフォルト:** 1.0 | **範囲:** 0.8-1.5

## その他の設定を探す

すべての設定は [`setting.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/store/setting.dart) で定義されています。

以下の形式を探してください。
```dart
late final settingName = StoreProperty(box, 'settingKey', defaultValue);
```

## ⚠️ 重要

**編集する前に:**
- **バックアップを作成する** - 設定を間違えるとアプリが起動しなくなる可能性があります。
- **慎重に編集する** - JSON は有効な形式である必要があります。
- **一つずつ変更する** - 各設定を変更するたびにテストしてください。

## 復旧方法

編集後にアプリが起動しなくなった場合:
1. アプリのデータを消去する（最終手段）
2. アプリを再インストールする
3. バックアップから復元する
