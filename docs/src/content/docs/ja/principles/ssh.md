---
title: SSH 接続
description: SSH 接続の確立と管理の仕組み
---

Server Box における SSH 接続の仕組みについて解説します。

## 接続フロー

```
ユーザー入力 → Spi 構成 → genClient() → SSH クライアント → セッション
```

### ステップ 1: 構成

`Spi` (Server Parameter Info) モデルには以下が含まれます。

```dart
class Spi {
  String name;       // サーバー名
  String ip;         // IP アドレス
  int port;          // SSH ポート (デフォルト 22)
  String user;       // ユーザー名
  String? pwd;       // パスワード (暗号化済み)
  String? keyId;     // SSH キー ID
  String? jumpId;    // 踏み台サーバー ID
  String? alterUrl;  // 代替 URL
}
```

### ステップ 2: クライアントの生成

`genClient(spi)` が SSH クライアントを作成します。

```dart
Future<SSHClient> genClient(Spi spi) async {
  // 1. ソケットを確立
  var socket = await connect(spi.ip, spi.port);

  // 2. 失敗した場合は代替 URL を試行
  if (socket == null && spi.alterUrl != null) {
    socket = await connect(spi.alterUrl, spi.port);
  }

  if (socket == null) {
    throw ConnectionException('Unable to connect');
  }

  // 3. 認証
  final client = SSHClient(
    socket: socket,
    username: spi.user,
    onPasswordRequest: () => spi.pwd,
    onIdentityRequest: () => loadKey(spi.keyId),
  );

  // 4. ホストキーを検証
  await verifyHostKey(client, spi);

  return client;
}
```

### ステップ 3: 踏み台サーバー (設定されている場合)

踏み台サーバーを経由する場合、再帰的に接続します。

```dart
if (spi.jumpId != null) {
  final jumpClient = await genClient(getJumpSpi(spi.jumpId));
  final forwarded = await jumpClient.forwardLocal(
    spi.ip,
    spi.port,
  );
  // 転送されたソケット経由で接続
}
```

## 認証方法

### パスワード認証

```dart
onPasswordRequest: () => spi.pwd
```

- パスワードは Hive に暗号化して保存されます。
- 接続時に復号されます。
- 検証のためにサーバーに送信されます。

### 公開鍵認証

```dart
onIdentityRequest: () async {
  final key = await KeyStore.get(spi.keyId);
  return decyptPem(key.pem, key.password);
}
```

**キーのロードプロセス:**
1. `KeyStore` から暗号化されたキーを取得
2. パスワードを復号 (生体認証または入力)
3. PEM 形式をパース
4. 改行コードを標準化 (LF)
5. 認証用に返却

### キーボードインタラクティブ (Keyboard-Interactive)

```dart
onUserInfoRequest: (instructions) async {
  // チャレンジ・レスポンスを処理
  return responses;
}
```

以下をサポートしています。
- パスワード認証
- OTP トークン
- 二要素認証 (2FA)

## ホストキー検証

### なぜホストキーを検証するのか？

正しいサーバーに接続していることを確認することで、**中間者攻撃 (MITM)** を防ぎます。

### 保存形式

```
{spi.id}::{keyType}
```

例:
```
my-server::ssh-ed25519
my-server::ecdsa-sha2-nistp256
```

### フィンガープリント形式

**MD5 Hex:**
```
aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99
```

**Base64:**
```
SHA256:AbCdEf1234567890...=
```

### 検証フロー

```dart
Future<void> verifyHostKey(SSHClient client, Spi spi) async {
  final key = await client.hostKey;
  final keyType = key.type;
  final fingerprint = md5Hex(key); // または base64

  final stored = SettingStore.sshKnownHostsFingerprints
      ['${spi.id}::$keyType'];

  if (stored == null) {
    // 未知のホスト - ユーザーに確認
    final trust = await promptUser(
      '未知のホスト',
      'フィンガープリント: $fingerprint',
    );
    if (trust) {
      SettingStore.sshKnownHostsFingerprints
          ['${spi.id}::$keyType'] = fingerprint;
    }
  } else if (stored != fingerprint) {
    // 変更されている - ユーザーに警告
    await warnUser(
      'ホストキーが変更されています！',
      '中間者攻撃の可能性があります',
    );
  }
}
```

## セッション管理

### 接続のプーリング

`ServerProvider` でアクティブなクライアントを維持します。

```dart
class ServerProvider {
  final Map<String, SSHClient> _clients = {};

  SSHClient getClient(String spiId) {
    return _clients[spiId] ??= connect(spiId);
  }
}
```

### Keep-Alive

アイドル中の接続を維持します。

```dart
Timer.periodic(
  Duration(seconds: 30),
  (_) => client.sendKeepAlive(),
);
```

### 自動再接続

接続が失われた場合:

```dart
client.onError.listen((error) async {
  await Future.delayed(Duration(seconds: 5));
  reconnect();
});
```

## 接続ライフサイクル

```
┌─────────────┐
│    初期状態 │
└──────┬──────┘
       │ connect()
       ↓
┌─────────────┐
│    接続中   │ ←──┐
└──────┬──────┘   │
       │ 成功     │
       ↓          │ 失敗 (再試行)
┌─────────────┐   │
│   接続済み  │───┘
└──────┬──────┘
       │
       ↓
┌─────────────┐
│   アクティブ│ ──→ コマンド送信
└──────┬──────┘
       │
       ↓ (エラー/切断)
┌─────────────┐
│    切断済み │
└─────────────┘
```

## エラーハンドリング

### 接続タイムアウト

```dart
try {
  await client.connect().timeout(
    Duration(seconds: 30),
  );
} on TimeoutException {
  throw ConnectionException('接続タイムアウト');
}
```

### 認証失敗

```dart
onAuthFail: (error) {
  if (error.contains('password')) {
    return 'パスワードが正しくありません';
  } else if (error.contains('key')) {
    return 'SSH キーが正しくありません';
  }
  return '認証に失敗しました';
}
```

### ホストキーの不一致

```dart
onHostKeyMismatch: (stored, current) {
  showSecurityWarning(
    'ホストキーが変更されています！',
    '中間者攻撃の可能性があります',
  );
}
```

## パフォーマンスに関する考慮事項

### 接続の再利用

- 機能間でクライアントを再利用する
- 不必要に切断・再接続を行わない
- 並行操作のために接続をプーリングする

### 最適な設定

- **タイムアウト**: 30 秒 (調整可能)
- **Keep-alive**: 30 秒ごと
- **再試行遅延**: 5 秒

### ネットワーク効率

- 1 つの接続で複数の操作を行う
- 可能な場合はコマンドをパイプライン化する
- 複数の接続を同時に開くのを避ける
