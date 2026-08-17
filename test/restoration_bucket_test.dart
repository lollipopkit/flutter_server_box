import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether a page under `home:` gets Flutter's restoration, measured.
///
/// TODOS.md records that it does not: "`MaterialApp` 上有 `restorationScopeId`,
/// 但页面挂在 `home:` 下,而 `home:` 生成的 route 没有 restoration id". That was
/// written from a debug build on an API 36 emulator where a terminal tab saw
/// `bucket == null`, and three pages still hold `Restorable*` fields on the
/// strength of it.
///
/// These say the opposite, here. Kept as a measurement rather than a claim
/// about the app: a widget test's binding supplies its own restoration data,
/// and a device's comes from the platform, so this narrows where the truth is
/// without settling it. What it does rule out is the stated *cause* — an
/// anonymous `home:` route is not, by itself, what withholds a bucket.
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
    // TODOS.md offers two ways out and picks neither: give the route a
    // restoration id, or move the state to a store as the terminal tab did.
    // Naming the route is the cheap-looking one, and on its own it is not
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
