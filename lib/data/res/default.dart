import 'dart:ui';

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

const defaultPrimaryColor = Color.fromARGB(255, 145, 58, 31);

const defaultLaunchPageIdx = 0;

const defaultUpdateInterval = 3;

const defaultEditorTheme = 'monokai';
