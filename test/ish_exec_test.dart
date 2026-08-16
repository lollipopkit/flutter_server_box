import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ish_exec.dart';

/// The shell the iOS guest is actually asked to run.
///
/// Everything else about that path needs a device and an engine that is not in
/// this repository. This is a string, and it is the string that decides whether
/// the Agent's two streams stay apart — so it is checked here.
void main() {
  String wrap(
    String script, {
    Map<String, String>? env,
    bool readsStdin = false,
  }) => IshExec.wrapScript(
    script,
    out: '/tmp/a.out',
    err: '/tmp/a.err',
    env: env,
    readsStdin: readsStdin,
  );

  test('the streams are separated before anything runs', () {
    final wrapped = wrap('echo hi');

    expect(wrapped.split('\n').first, "exec >'/tmp/a.out' 2>'/tmp/a.err' </dev/null");
    expect(wrapped, endsWith('echo hi'));
  });

  test('a command with input keeps the console as its stdin', () {
    // `/dev/null` would give it end-of-input before the caller had written a
    // word — a sudo password among them.
    expect(wrap('cat', readsStdin: true), isNot(contains('/dev/null')));
  });

  test('the script is left exactly as it was written', () {
    // Not wrapped in braces, which is why this holds: a here-document, a
    // trailing comment and an unbalanced quote inside one all survive.
    const script = "cat <<'EOF'\n}\nEOF\n# done";

    expect(wrap(script), endsWith(script));
  });

  test('an environment value cannot end its own quoting', () {
    // The one that matters: without the `'\\''` dance this would be a command
    // of its own, and the value came from somewhere the guest does not control
    // but this code cannot vouch for either.
    final wrapped = wrap('true', env: {'X': r"a'; rm -rf /; echo '"});

    expect(wrapped, contains(r"""export X='a'\''; rm -rf /; echo '\'''"""));
    // One statement per line, so nothing above escaped into the script.
    final lines = wrapped.split('\n');
    expect(lines.where((l) => l.startsWith('export ')), hasLength(1));
  });

  test('several values are exported before the script', () {
    final lines = wrap('true', env: {'A': '1', 'B': '2'}).split('\n');

    expect(lines[1], "export A='1'");
    expect(lines[2], "export B='2'");
    expect(lines[3], 'true');
  });
}
