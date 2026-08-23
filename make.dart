#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Version embedded in the remote script filename (`srvboxm_v<n>.sh`).
///
/// It must only increase when the generated script changes. It used to be a
/// Git-history count, whose result varied with the source paths and whether a
/// build used `fl_build` at all; that made different platform artifacts reuse
/// a name for different script contents. Keep this explicit and bump it with
/// every script change instead.
const scriptVersion = 74;

const moreBuildDataPath = 'more_build_data.json';

void main(List<String> args) async {
  final cmd = args.firstOrNull;
  print('Running make.dart with command: $cmd');
  switch (cmd) {
    case 'before':
      final data = {'script': scriptVersion};
      await File(moreBuildDataPath).writeAsString(json.encode(data));
      break;
    default:
      throw 'Invalid argument: $cmd';
  }
}
