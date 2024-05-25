#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

const shellScriptPath = 'lib/data/model/app/shell_func.dart';
const moreBuildDataPath = 'more_build_data.json';

void main(List<String> args) async {
  final cmd = args.firstOrNull;
  switch (cmd) {
    case 'before':
      final data = {
        'script': await getScriptCommitCount(),
      };
      await File(moreBuildDataPath).writeAsString(json.encode(data));
      break;
    case 'after':
    // Pass
    default:
      throw 'Invalid argument: $cmd';
  }
}

Future<int> getScriptCommitCount() async {
  if (!await File(shellScriptPath).exists()) {
    print('File not found: $shellScriptPath');
    exit(1);
  }
  final result =
      await Process.run('git', ['log', '--format=format:%h', shellScriptPath]);
  return (result.stdout as String)
      .split('\n')
      .where((line) => line.isNotEmpty)
      .length;
}
