#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// What the generated status script is made of.
///
/// `script.rs` writes the script and `commands.rs` supplies the commands it
/// runs — between them they decide every byte of it, and `script.rs`'s only
/// import from this crate is `commands`. Anything else changing leaves the
/// script identical, which is the whole point of counting these and not the
/// repository.
///
/// It used to count `lib/data/model/app/scripts/cmd_types.dart`, from when the
/// script was generated in Dart. That file is now an enum mirroring the Rust
/// keys: editing it changes no script byte, and editing the Rust changed no
/// version number. So the counter had come loose from the thing it versions.
const scriptSourcePaths = [
  'crates/sbm_parser/src/script.rs',
  'crates/sbm_parser/src/commands.rs',
];

/// Added so the number keeps climbing across the two times its source moved.
///
/// The version is only ever a file name (`srvboxm_v<n>.sh`), so what it has to
/// be is different from what an older app left on the same server — not
/// meaningful in itself. Going *backwards* is the one thing that would defeat
/// that, and a fresh count over different paths lands wherever it lands: with
/// this offset the first count under the Rust paths is 86, against 73 shipped.
const scriptVersionOffset = 65;

const moreBuildDataPath = 'more_build_data.json';

void main(List<String> args) async {
  final cmd = args.firstOrNull;
  print('Running make.dart with command: $cmd');
  switch (cmd) {
    case 'before':
      final scriptModCount =
          await getScriptCommitCount() + scriptVersionOffset;
      final data = {'script': scriptModCount};
      await File(moreBuildDataPath).writeAsString(json.encode(data));
      break;
    default:
      throw 'Invalid argument: $cmd';
  }
}

Future<int> getScriptCommitCount() async {
  for (final path in scriptSourcePaths) {
    if (!await File(path).exists()) {
      print('File not found: $path');
      exit(1);
    }
  }

  // One `git log` over both paths rather than two summed: a commit that
  // touched the manifest and the generator together changed the script once.
  final result = await Process.run('git', [
    'log',
    '--format=format:%h',
    '--',
    ...scriptSourcePaths,
  ]);
  final count = (result.stdout as String)
      .split('\n')
      .where((line) => line.isNotEmpty)
      .length;

  // A shallow clone answers 1 for everything, and a number that small would
  // reuse a file name an older app wrote with different contents. The build
  // jobs use `fetch-depth: 0`; this is what says so when one stops.
  if (count <= 1) {
    print(
      'Only $count commit(s) touch the script sources — this looks like a '
      'shallow clone, and the version derived from it would go backwards. '
      'Fetch the full history (actions/checkout with fetch-depth: 0).',
    );
    exit(1);
  }

  return count;
}
