---
title: ターミナルの実装
description: SSH ターミナルの内部的な仕組み
---

SSH ターミナルは、カスタマイズされた xterm.dart フォークをベースに構築された、最も複雑な機能の一つです。

## アーキテクチャの概要

```
┌─────────────────────────────────────────────┐
│          ターミナル UI レイヤー             │
│  - タブ管理                                 │
│  - 仮想キーボード                           │
│  - テキスト選択                             │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│         xterm.dart エミュレータ             │
│  - PTY (擬似ターミナル)                     │
│  - VT100/ANSI エミュレーション              │
│  - レンダリングエンジン                     │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          SSH クライアントレイヤー           │
│  - SSH セッション                           │
│  - チャネル管理                             │
│  - データストリーミング                     │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│            リモートサーバー                 │
│  - シェルプロセス                           │
│  - コマンド実行                             │
└─────────────────────────────────────────────┘
```

## ターミナルセッションのライフサイクル

### 1. セッションの作成

```dart
Future<TerminalSession> createSession(Spi spi) async {
  // 1. SSH クライアントを取得
  final client = await genClient(spi);

  // 2. PTY を開く
  final pty = await client.openPty(
    term: 'xterm-256color',
    cols: 80,
    rows: 24,
  );

  // 3. ターミナルエミュレータを初期化
  final terminal = Terminal(
    backend: PtyBackend(pty),
  );

  // 4. リサイズハンドラを設定
  terminal.onResize.listen((size) {
    pty.resize(size.cols, size.rows);
  });

  return TerminalSession(
    terminal: terminal,
    pty: pty,
    client: client,
  );
}
```

### 2. ターミナルエミュレーション

xterm.dart フォークは以下を提供します。

**VT100/ANSI エミュレーション:**
- カーソル移動
- カラー（256 色対応）
- テキスト属性（太字、アンダーラインなど）
- スクロール領域
- 代替画面バッファ

**レンダリング:**
- 行ベースのレンダリング
- 双方向テキストのサポート
- Unicode/Emoji 対応
- 描画の最適化

### 3. データフロー

```
ユーザー入力
    ↓
仮想キーボード / 物理キーボード
    ↓
ターミナルエミュレータ (キー → エスケープシーケンス)
    ↓
SSH チャネル (送信)
    ↓
リモート PTY
    ↓
リモートシェル
    ↓
コマンド出力
    ↓
SSH チャネル (受信)
    ↓
ターミナルエミュレータ (ANSI コードのパース)
    ↓
画面へのレンダリング
```

## マルチタブシステム

### タブ管理

タブは画面遷移の間も状態を維持します。
- SSH 接続の維持
- ターミナル状態の保存
- スクロールバッファの保持
- 入力履歴の保持

## 仮想キーボード

仮想キーボードは全プラットフォーム共通の Flutter widget で、ターミナルの上に
表示されます(利用可能なキーは `lib/data/model/ssh/virtual_key.dart` で定義)。
モバイルではシステムキーボードと同時に表示されます。

### キーボードボタン

| ボタン | 動作 |
|--------|--------|
| **Esc / Tab / Home / End / PgUp / PgDn / 矢印キー** | 対応するキーを送信 |
| **Ctrl / Alt / Shift** | 次のキーに修飾キーを付加 |
| **IME** | システムキーボードの表示/非表示 |
| **クリップボード** | コンテキストに応じたコピー/貼り付け |
| **SFTP** | 現在のディレクトリを SFTP ブラウザで開く |
| **スニペット** | スニペットを選択して実行 |
| **記号** | `/ \ _ + = - ( ) [ ] { } < >` など |

キーの構成と順序は設定でカスタマイズできます。

## テキスト選択

1. **長押し**: 選択モードに入る
2. **ドラッグ**: 選択範囲を広げる
3. **離す**: クリップボードにコピー

## フォントと寸法

### サイズ計算

```dart
class TerminalDimensions {
  static Size calculate(double fontSize, Size screenSize) {
    final charWidth = fontSize * 0.6;  // 等幅フォントのアスペクト比
    final charHeight = fontSize * 1.2;

    final cols = (screenSize.width / charWidth).floor();
    final rows = (screenSize.height / charHeight).floor();

    return Size(cols.toDouble(), rows.toDouble());
  }
}
```

### ピンチズーム

```dart
GestureDetector(
  onScaleStart: () => _baseFontSize = currentFontSize,
  onScaleUpdate: (details) {
    final newFontSize = _baseFontSize * details.scale;
    resize(newFontSize);
  },
)
```

## カラースキーム

- **ライト (Light)**: 明るい背景、暗いテキスト
- **ダーク (Dark)**: 暗い背景、明るいテキスト
- **AMOLED**: 真っ黒な背景

## パフォーマンス

xterm.dart フォークはカスタム painter で描画し、ターミナル内容の更新時のみ
再描画します。出力はバッファリングして結合してからエミュレータに渡されます。

## 特別な機能

### スニペットの実行

スニペットを選択すると、その内容がターミナルに貼り付けられ、改行を送って実行されます。

### SFTP クイックアクセス

**SFTP** 仮想キーで、現在の作業ディレクトリを SFTP ブラウザで開きます。

### キープアライブ

接続は SSH プロトコル層で維持されます([SSH 接続](/docs/principles/ssh/) を参照)。
ターミナルへバイトを注入する方式ではありません。
