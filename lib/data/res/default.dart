import 'dart:ui';

import 'package:toolbox/data/model/ssh/virtual_key.dart';

// default server details page cards order
const defaultDetailCardOrder = [
  'uptime',
  'cpu',
  'mem',
  'swap',
  'disk',
  'net',
  'temp'
];

const defaultDiskIgnorePath = [
  'udev',
  'tmpfs',
  'devtmpfs',
  'overlay',
  'run',
  'none',
];

const defaultSSHVirtKeys = [
  VirtKey.esc,
  VirtKey.alt,
  VirtKey.home,
  VirtKey.up,
  VirtKey.end,
  VirtKey.file,
  VirtKey.snippet,
  VirtKey.tab,
  VirtKey.ctrl,
  VirtKey.left,
  VirtKey.down,
  VirtKey.right,
  VirtKey.paste,
  VirtKey.ime,
];

const defaultPrimaryColor = Color.fromARGB(255, 145, 58, 31);

const defaultLaunchPageIdx = 0;

const defaultUpdateInterval = 3;

const defaultEditorTheme = 'monokai';
