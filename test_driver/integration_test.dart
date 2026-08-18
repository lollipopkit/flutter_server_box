import 'package:integration_test/integration_test_driver.dart';

/// Lets `flutter drive` run anything under `integration_test/`.
///
/// `flutter test` is the shorter way to run those, and works everywhere except
/// one case: an iOS 17+ device Xcode reaches over the network. `flutter test`
/// hardcodes `disablePortPublication: true`, and `IOSDevice.startApp` refuses
/// to launch on a wirelessly tethered device when it is set — with no flag to
/// turn it off. `flutter drive --publish-port` is the same run with that bit
/// cleared, so it is the only way to run these on such a device.
///
/// The device answers `--publish-port` with the iOS local-network permission
/// dialog on first use, which someone has to allow.
Future<void> main() => integrationDriver();
