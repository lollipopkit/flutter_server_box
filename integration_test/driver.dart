import 'package:integration_test/integration_test_driver.dart';

/// Lets `flutter drive` run anything beside it.
///
/// Here rather than in a `test_driver/` of its own, which is only the default
/// `flutter drive` looks in when `--driver` is omitted — both invocations that
/// need this pass it explicitly. `flutter test` collects `*_test.dart` and
/// leaves this alone.
///
/// `flutter test` is the shorter way to run those, and covers everything except
/// two cases.
///
/// One is an iOS 17+ device Xcode reaches over the network. `flutter test`
/// hardcodes `disablePortPublication: true`, and `IOSDevice.startApp` refuses
/// to launch on a wirelessly tethered device when it is set — with no flag to
/// turn it off. `flutter drive --publish-port` is the same run with that bit
/// cleared, so it is the only way to run these on such a device.
///
/// The device answers `--publish-port` with the iOS local-network permission
/// dialog on first use, which someone has to allow.
///
/// The other is `ios_bench_test.dart`, which has to run in profile mode —
/// `flutter test` has no `--profile`, and a benchmark measured in debug is
/// measuring the wrong thing. Its own header carries the full command.
Future<void> main() => integrationDriver();
