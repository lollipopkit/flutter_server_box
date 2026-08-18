---
title: SSH 接続
description: SSH 接続の確立と管理の仕組み
---

Server Box における SSH 接続の仕組みについて解説します。

このページは SSH で追加したサーバーについて述べます。サーバーは monitor agent の
HTTP API 経由で追加することもでき、その場合は SSH 認証情報を一切持たないため、
ここに書かれている内容は当てはまりません。

## 接続フロー

```text
ユーザー入力 → Spi 構成 → genClient() → SSH クライアント → セッション
```

### ステップ 1: 構成

`Spi` (Server Parameter Info) モデルには以下が含まれます。

```dart
class Spi {
  String id;                      // 一意の識別子
  String name;                    // サーバー名
  SshCredential? ssh;             // monitor サーバーでは null
  MonitorHttpCredential? monitorHttp;
}

final class SshCredential {
  String ip;              // IP アドレス
  int port;               // SSH ポート (デフォルト 22)
  String user;            // ユーザー名
  String? pwd;            // パスワード (暗号化済み)
  String? keyId;          // SSH キー ID
  String? alterUrl;       // 代替 URL
  List<String>? jumpIds;  // 踏み台サーバーの連鎖
  String? proxyCommand;   // ProxyCommand、デスクトップのみ
}
```

踏み台の連鎖と `ProxyCommand` は排他的で、両方を設定したサーバーは
`Spix.validate()` が拒否します。

### ステップ 2: クライアントの生成

`genClient(spi)` が SSH クライアントを作成します。

```dart
Future<SSHClient> genClient(Spi spi) async {
  final ssh = spi.ssh!;
  // 1. ソケットを確立
  var socket = await connect(ssh.ip, ssh.port);

  // 2. 失敗した場合は代替 URL を試行
  if (socket == null && ssh.alterUrl != null) {
    socket = await connect(ssh.alterUrl, ssh.port);
  }

  if (socket == null) {
    throw ConnectionException('Unable to connect');
  }

  // 3. 認証
  final client = SSHClient(
    socket: socket,
    username: ssh.user,
    onPasswordRequest: () => ssh.pwd,
    onIdentityRequest: () => loadKey(ssh.keyId),
  );

  // 4. ホストキーを検証
  await verifyHostKey(client, spi);

  return client;
}
```

### ステップ 3: ソケットの供給元

`genClient` は 3 つの供給元のいずれかを解決します。`SSHSocket` より上位は
3 つのどの場合でも同一です。

**直接接続** —— 既定の方法。`SSHSocket.connect(ip, port)` を使い、失敗したら
`alterUrl` にフォールバックします。

**踏み台サーバー** —— 再帰的に接続してからローカル転送します。

```dart
for (final jumpId in spi.resolvedJumpIds) {
  final jumpClient = await genClient(getJumpSpi(jumpId));
  return await jumpClient.forwardLocal(ssh.ip, ssh.port);
}
```

**ProxyCommand** —— プロセスを起動するため、デスクトップのみ。

```dart
if (ssh.proxyCommand != null) {
  return await ProxyCommandSocket.connect(
    command: ssh.proxyCommand,
    host: ssh.ip,
    port: ssh.port,
    user: ssh.user,
  );
}
```

## 認証方法

### パスワード認証

```dart
onPasswordRequest: () => ssh.pwd
```

- パスワードは Hive に暗号化して保存されます。
- 接続時に復号されます。
- 検証のためにサーバーに送信されます。

### 公開鍵認証

```dart
onIdentityRequest: () async {
  final key = await PrivateKeyStore.get(ssh.keyId);
  return decyptPem(key.pem, key.password);
}
```

**キーのロードプロセス:**
1. `PrivateKeyStore` から暗号化されたキーを取得
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

```text
{spi.id}::{keyType}
```

例:
```text
my-server::ssh-ed25519
my-server::ecdsa-sha2-nistp256
```

### フィンガープリント形式

**MD5 Hex:**
```text
aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99
```

**Base64:**
```text
SHA256:AbCdEf1234567890...=
```

### 検証フロー

```dart
Future<void> verifyHostKey(SSHClient client, Spi spi) async {
  final key = await client.hostKey;
  final keyType = key.type;
  final fingerprint = md5Hex(key); // または base64

  final stored = SettingStore.sshKnownHostFingerprints
      ['${spi.id}::$keyType'];

  if (stored == null) {
    // 未知のホスト - ユーザーに確認
    final trust = await promptUser(
      '未知のホスト',
      'フィンガープリント: $fingerprint',
    );
    if (trust) {
      SettingStore.sshKnownHostFingerprints
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

```text
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
