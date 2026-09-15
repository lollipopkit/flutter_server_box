import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether a page under `home:` gets Flutter's restoration, measured.
///
/// It had been recorded that the bucket never arrived, and that the cause was
/// an anonymous `home:` route having no restoration id — written from a debug
/// build on an API 36 emulator where a terminal tab saw `bucket == null`, and
/// four places held `Restorable*` fields on the strength of it.
///
/// These say something narrower and worse. The bucket *is* handed down, and
/// what is written to it does not survive a restart — so a page looks
/// restorable, works all session, and loses everything only on a real relaunch.
/// That also rules out the stated cause: naming the route changes nothing.
///
/// Kept as a measurement rather than a claim about the app: a widget test's
/// binding supplies its own restoration data and a device's comes from the
/// platform. What settled it for this app was moving the state to stores,
/// which survives being swiped out of the recents list too — something
/// restoration never covered.
void main() {
  setUp(() => _seen.clear());

  testWidgets('a page under `home:` is handed one', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(restorationScopeId: 'serverbox', home: _Probe()),
    );
    await tester.pumpAndSettle();

    expect(_seen, [true], reason: 'no bucket reached a page under `home:`');
  });

  testWidgets('but nothing written to it survives a restart', (tester) async {
    // The bucket is there and is still the wrong bucket: the route `home:`
    // builds is not itself restorable, so on relaunch the navigator makes a
    // fresh one rather than handing back what was saved. A page sees a
    // non-null bucket either way, which is why this went unnoticed — there is
    // nothing to check that is false until a real restart happens.
    await tester.pumpWidget(
      const MaterialApp(restorationScopeId: 'serverbox', home: _Probe()),
    );
    await tester.pumpAndSettle();

    tester.state<_ProbeState>(find.byType(_Probe)).value.value = '/etc';
    await tester.pumpAndSettle();

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(
      tester.state<_ProbeState>(find.byType(_Probe)).value.value,
      '',
      reason: 'it came back — `home:` restores after all, and the three pages '
          'still holding `Restorable*` fields would start working',
    );
  });

  testWidgets('and a named route does not fix it either', (tester) async {
    // Naming the route is the cheap-looking way out, and on its own it is not
    // enough — measured, not argued. Whatever the first route needs, `routes:`
    // instead of `home:` does not supply it.
    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'serverbox',
        routes: {'/': (_) => const _Probe()},
      ),
    );
    await tester.pumpAndSettle();

    tester.state<_ProbeState>(find.byType(_Probe)).value.value = '/etc';
    await tester.pumpAndSettle();

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(
      tester.state<_ProbeState>(find.byType(_Probe)).value.value,
      '',
      reason: 'naming the route was enough after all — then that is the fix, '
          'and it is one line',
    );
  });

  testWidgets('without a scope id on the app, nothing is restored', (
    tester,
  ) async {
    // The control. Something has to be able to turn this off, or the two above
    // are measuring the test harness rather than the app's configuration.
    await tester.pumpWidget(const MaterialApp(home: _Probe()));
    await tester.pumpAndSettle();

    expect(_seen, [false]);
  });

  test('nothing in lib/ relies on it any more', () {
    // The three pages that did now keep their state where it survives: the
    // terminal and file tabs in `Stores.history`, the home tab index beside
    // them, and the terminal page's tmux fields as plain fields — they never
    // persisted, so plain is what they always were.
    //
    // A scan rather than a list, because the failure this guards against is
    // somebody reaching for `RestorableInt` again and finding that it appears
    // to work.
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.contains('/generated/') || file.path.contains('/src/rust/')) {
        continue;
      }
      for (final line in file.readAsLinesSync()) {
        final code = line.trim();
        if (code.startsWith('///') || code.startsWith('//')) continue;
        if (code.contains('RestorationMixin') ||
            code.contains('registerForRestoration') ||
            RegExp(r'\bRestorable(String|Int|Bool|Double|Num)N?\b').hasMatch(code)) {
          offenders.add('${file.path}: $code');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}

/// Whether a bucket reached the probe, once per `restoreState`.
final _seen = <bool>[];

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with RestorationMixin {
  final value = RestorableString('');

  @override
  String get restorationId => 'probe';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(value, 'value');
    _seen.add(bucket != null);
  }

  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}