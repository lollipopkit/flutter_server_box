---
title: カスタムサーバーロゴ
description: サーバーカードにカスタム画像を使用する
---

画像の URL を使用して、サーバーカードにカスタムロゴを表示します。

## 設定

1. サーバー設定 → カスタムロゴ
2. 画像の URL を入力

## URL プレースホルダー

### {DIST} - Linux ディストリビューション

検出されたディストリビューションに自動的に置換されます。

```
https://example.com/{DIST}.png
```

例: `debian.png`、`ubuntu.png`、`arch.png` など。

### {BRIGHT} - テーマ

現在のテーマに自動的に置換されます。

```
https://example.com/{BRIGHT}.png
```

例: `light.png` または `dark.png`。

### 両方を組み合わせる

```
https://example.com/{DIST}-{BRIGHT}.png
```

例: `debian-light.png`、`ubuntu-dark.png` など。

## ヒント

- PNG または SVG 形式を使用してください。
- 推奨サイズ: 64x64 〜 128x128 ピクセル。
- HTTPS の URL を使用してください。
- ファイルサイズは小さく保ってください。

## サポートされているディストリビューション

debian, ubuntu, centos, fedora, opensuse, kali, alpine, arch, rocky, deepin, armbian, wrt

全リスト: [`dist.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/model/server/dist.dart)
