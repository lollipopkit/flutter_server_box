import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/agent_common.dart';

/// The pieces both Agent surfaces share, which neither had a test for while
/// each had its own copy — which is how the two came to disagree.
void main() {
  /// Builds a tree so `describeAgentError` has a `Localizations` to read.
  Future<BuildContext> contextFor(WidgetTester tester, Locale locale) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return ctx;
  }

  group('describeAgentError', () {
    testWidgets('separates missing fields the way the locale reads a list',
        (tester) async {
      // The terminal's copy did this and the tab's did not. `, ` is not how a
      // list is written in either language, and the two surfaces showed the
      // same error differently depending on which one you opened.
      const error = AskAiConfigException(
        missingFields: [AskAiConfigField.baseUrl, AskAiConfigField.apiKey],
      );

      final zh = await contextFor(tester, const Locale('zh'));
      expect(describeAgentError(zh, error), contains('、'));

      final en = await contextFor(tester, const Locale('en'));
      expect(describeAgentError(en, error), contains(', '));
      expect(describeAgentError(en, error), isNot(contains('、')));
    });

    testWidgets('knows the turn that produced nothing', (tester) async {
      // The tab's copy knew this one and the terminal's did not.
      final ctx = await contextFor(tester, const Locale('en'));
      final text = describeAgentError(ctx, const AgentNoResponse());
      expect(text, isNotEmpty);
      expect(text, isNot(contains('Instance of')),
          reason: 'falling through to toString would show the class name');
    });

    testWidgets('an invalid base URL names the URL', (tester) async {
      final ctx = await contextFor(tester, const Locale('en'));
      const error = AskAiConfigException(invalidBaseUrl: 'ht!tp://x');
      expect(describeAgentError(ctx, error), contains('ht!tp://x'));
    });

    testWidgets('anything else is its own message', (tester) async {
      final ctx = await contextFor(tester, const Locale('en'));
      expect(
        describeAgentError(ctx, const AskAiNetworkException(message: 'timed out')),
        'timed out',
      );
      // A String passes through unchanged, which is what lets a surface that
      // stores the sentence rather than the error hand it straight back.
      expect(describeAgentError(ctx, 'already a sentence'), 'already a sentence');
    });
  });

  group('composerKeySends', () {
    KeyEvent down(LogicalKeyboardKey key) => KeyDownEvent(
      logicalKey: key,
      physicalKey: PhysicalKeyboardKey.enter,
      timeStamp: Duration.zero,
    );

    test('only on a key going down', () {
      final up = KeyUpEvent(
        logicalKey: LogicalKeyboardKey.enter,
        physicalKey: PhysicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      );
      expect(composerKeySends(up, composing: false, sendOnEnter: true), isFalse);
    });

    test('only on enter', () {
      expect(
        composerKeySends(down(LogicalKeyboardKey.keyA), composing: false, sendOnEnter: true),
        isFalse,
      );
      // The numeric keypad's enter is the same key to the person pressing it,
      // and was handled in both copies — a test is what keeps it that way.
      expect(
        composerKeySends(down(LogicalKeyboardKey.numpadEnter), composing: false, sendOnEnter: true),
        isTrue,
      );
    });

    test('a bare enter mid-composition belongs to the IME', () {
      // Taking it would send half a word in every language that needs an IME
      // to type at all.
      expect(
        composerKeySends(down(LogicalKeyboardKey.enter), composing: true, sendOnEnter: true),
        isFalse,
      );
    });

    test('and a bare enter with nothing composing sends', () {
      expect(
        composerKeySends(
          down(LogicalKeyboardKey.enter),
          composing: false,
          sendOnEnter: true,
        ),
        isTrue,
      );
    });

    test('with the setting off a bare enter is a new line', () {
      // Neither copy had a test for the off case; the setting governs two
      // fields and one that behaved differently would be a setting nobody
      // could rely on.
      expect(
        composerKeySends(
          down(LogicalKeyboardKey.enter),
          composing: false,
          sendOnEnter: false,
        ),
        isFalse,
      );
    });
  });
}
