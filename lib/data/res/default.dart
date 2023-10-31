import 'dart:ui';

import 'package:toolbox/data/model/ssh/virtual_key.dart';

class Defaults {
  const Defaults._();

  // default server details page cards order
  static const detailCardOrder = [
    'uptime',
    'cpu',
    'mem',
    'swap',
    'disk',
    'net',
    'temp'
  ];

  static const diskIgnorePath = [
    'udev',
    'tmpfs',
    'devtmpfs',
    'overlay',
    'run',
    'none',
    'shm',
  ];

  static const sshVirtKeys = [
    VirtKey.esc,
    VirtKey.alt,
    VirtKey.home,
    VirtKey.up,
    VirtKey.end,
    VirtKey.sftp,
    VirtKey.snippet,
    VirtKey.tab,
    VirtKey.ctrl,
    VirtKey.left,
    VirtKey.down,
    VirtKey.right,
    VirtKey.clipboard,
    VirtKey.ime,
  ];

  static const primaryColor = Color.fromARGB(255, 145, 58, 31);

  static const launchPageIdx = 0;

  static const updateInterval = 3;

  static const editorTheme = 'a11y-light';
  static const editorDarkTheme = 'monokai';
}
