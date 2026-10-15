import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart' as sentry;
import 'package:server_box/core/service/diagnostics_upload.dart';

/// A range error's message carries its numbers, and GlitchTip groups by title:
/// the terminal buffer's one out-of-range read arrived as hundreds of issues.
void main() {
  sentry.SentryEvent event(Object error, List<(String, String)> calls) =>
      sentry.SentryEvent(
        throwable: error,
        exceptions: [
          sentry.SentryException(
            type: '${error.runtimeType}',
            value: '$error',
            stackTrace: sentry.SentryStackTrace(
              frames: [
                // Oldest first; the throw last, in dart:core.
                for (final (fn, file) in calls.reversed)
                  sentry.SentryStackFrame(
                    function: fn,
                    fileName: file,
                    package: 'xterm',
                    inApp: true,
                  ),
                sentry.SentryStackFrame(
                  function: 'RangeError.checkValueInInterval',
                  fileName: 'errors.dart',
                  inApp: false,
                ),
              ],
            ),
          ),
        ],
      );

  List<String>? group(sentry.SentryEvent e) =>
      DiagnosticsUpload.groupByCallSite(e).fingerprint;

  const currentLine = [
    ('IndexAwareCircularBuffer.[]', 'circular_buffer.dart'),
    ('Buffer.currentLine', 'buffer.dart'),
    ('Buffer._clusterTarget', 'buffer.dart'),
  ];

  test('the same call site groups whatever the numbers', () {
    final a = group(event(RangeError.range(649, 0, 634), currentLine));
    final b = group(event(RangeError.range(23, 0, 18), currentLine));
    expect(a, isNotNull);
    expect(a, b);
  });

  test('another caller of the same buffer read is another issue', () {
    final anchor = group(
      event(RangeError.range(20, 0, 18), const [
        ('IndexAwareCircularBuffer.[]', 'circular_buffer.dart'),
        ('Buffer.createAnchorFromOffset', 'buffer.dart'),
      ]),
    );
    expect(anchor, isNot(group(event(RangeError.range(1, 0, 0), currentLine))));
  });

  test('an index error is grouped the same way', () {
    expect(
      group(event(IndexError.withLength(5, 3), currentLine)),
      group(event(RangeError.range(9, 0, 2), currentLine)),
    );
  });

  test('other errors keep the default grouping', () {
    expect(group(event(StateError('x'), currentLine)), isNull);
  });
}
