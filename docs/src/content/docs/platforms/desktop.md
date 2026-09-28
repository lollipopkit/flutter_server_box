---
title: Desktop Features
description: Platform-specific features for macOS, Linux, and Windows
---

On desktop, Server Box provides more workspace, full keyboard support, and
platform-specific window features.

## macOS

### Menu bar

The macOS menu bar includes:

- **Server Box**: About, Settings (⌘,), and Quit (⌘Q)
- **Navigate**: Switch between home tabs (⌘1 … ⌘9)
- **Info**: Project links

### Window management

The app remembers the window size and position and restores them at the next
launch.

## Linux

- X11 and Wayland support
- System file picker integration
- Distributed as an AppImage

## Windows

- Native window controls
- Distributed as a portable zip package

## Common desktop features

### Themes

- Light
- Dark
- Follow system

AMOLED is a built-in theme. It uses a pure black background in dark mode and
standard light colors in light mode. Existing AMOLED settings migrate to Dark +
AMOLED; Auto AMOLED migrates to System + AMOLED.

Themes declare whether they support light mode, dark mode, or both. A theme
that supports only one mode locks the mode setting and explains why.

### Compared with mobile

- More screen space for viewing multiple metrics
- A full-size keyboard for easier terminal input
- More efficient file transfers and batch operations
- Better support for working with multiple tasks at once
