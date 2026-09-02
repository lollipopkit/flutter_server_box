import 'package:device_info_plus/device_info_plus.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:sentry/sentry.dart' as sentry;
import 'package:server_box/data/res/build_data.dart';

/// Describes the machine a report came from.
///
/// `sentry_flutter` fills the `device` and `os` contexts from a native layer
/// this app deliberately does not have — see [DiagnosticsUpload] for why it is
/// the pure-Dart SDK. Without them every report reads "Unknown Device" with no
/// OS version, which is the first thing asked about a crash and the one thing
/// a reporter cannot supply after the fact.
///
/// `dart:io` alone does not close this: `Platform.operatingSystemVersion` is
/// `ro.build.description` on Android and something else in every other shape,
/// and none of them carry a model name at all.
///
/// **What is deliberately not sent, which is the decision this file exists to
/// make.** `device_info_plus` also hands over a stable identifier on four of
/// the five platforms — `identifierForVendor`, `systemGUID`, `deviceId`,
/// `machineId` — and on three of them a name the user typed. None of it is
/// here, and the omissions are not incidental:
///
/// - **An identifier is what makes a report linkable**, which is the exact
///   claim `PrivacyInfo.xcprivacy` makes the other way (`Linked` false,
///   `Tracking` false) and the exact thing F-Droid's Tracking anti-feature is
///   about. A crash is about a build and a code path; the SDK already
///   generates its own per-install id for grouping and it does not have to be
///   one the device also answers to elsewhere.
/// - **A name is a person.** `IosDeviceInfo.name` and macOS `computerName`
///   default to `<first name>'s iPhone`, Windows `userName` and
///   `registeredOwner` are the account, and macOS `hostName` leaks onto every
///   network the machine joins. A model name answers "what hardware was this"
///   without any of that.
/// - Android `host` names the machine that built the ROM and `Windows`
///   `productId` is a licence key. Neither says anything about the crash.
///
/// So what goes is the hardware and the OS release: enough to tell an
/// arm64 phone on Android 16 from an x86 desktop on Windows 11, and no more.
abstract final class DiagnosticsPlatform {
  /// Attaches the contexts to the current Sentry scope.
  ///
  /// Best effort by construction. Every platform channel here can fail on a
  /// device that is unusual in some way, and a report with no device section
  /// is worth incomparably more than no report — so a failure is logged and
  /// swallowed rather than propagated into the caller, which is the code path
  /// that has just finished starting crash reporting.
  ///
  /// Awaited by its caller rather than fired off, so that an error arriving
  /// moments after launch is already described. It is one platform call.
  static Future<void> describe() async {
    try {
      final plugin = DeviceInfoPlugin();
      final described = switch (Pfs.type) {
        Pfs.android => await _android(plugin),
        Pfs.ios => await _ios(plugin),
        Pfs.macos => await _macos(plugin),
        Pfs.linux => await _linux(plugin),
        Pfs.windows => await _windows(plugin),
        // web, fuchsia, unknown: nothing here knows what to ask, and the SDK's
        // own `os.name` is already better than a guess.
        _ => null,
      };
      if (described == null) return;
      final (device, os) = described;
      sentry.Sentry.configureScope((scope) {
        scope.setContexts(sentry.SentryDevice.type, device);
        scope.setContexts(sentry.SentryOperatingSystem.type, os);
      });
    } catch (e, s) {
      Loggers.app.warning('DiagnosticsPlatform.describe', e, s);
    }
  }

  /// A `User-Agent` for a destination that reads one, or null on a platform
  /// this cannot describe.
  ///
  /// **Why an app sends a browser-shaped string.** OpenPanel derives the
  /// device and the *session* from this header, through `ua-parser-js`, and
  /// treats anything it cannot parse as server-to-server traffic: such an
  /// event is stored but opens no session, so `device_id` and `session_id` are
  /// written empty. Its dashboard counts visitors out of the `sessions` table,
  /// which means a client sending dio's default `Dart/3.x (dart:io)` reports
  /// events and zero users — data that looks like a consent bug and is not
  /// one. The `Mozilla/5.0 (...)` prefix is what the parser needs to find the
  /// platform; the `ServerBox/<build>` suffix is what says this is not a
  /// browser, and both halves are read.
  ///
  /// **The same boundary as the rest of this file**: a token here names the
  /// hardware and the OS release and nothing that identifies a person or an
  /// install. That is narrower than a real browser's UA, which is why the
  /// forms below are shorter than the ones they imitate.
  ///
  /// Every form is verified against `ua-parser-js` rather than assumed, and
  /// two near misses are the reason the fallbacks look the way they do: a bare
  /// `(iPad)` parses to nothing at all and would be read as a server, and
  /// dropping only the digits from the iOS form leaves `os.version` as the
  /// literal string `like`.
  static Future<String?> userAgent() async {
    final platform = await _uaPlatform();
    if (platform == null) return null;
    return 'Mozilla/5.0 ($platform) ${BuildData.name}/${BuildData.build}';
  }

  static Future<String?> _uaPlatform() async {
    try {
      final plugin = DeviceInfoPlugin();
      return switch (Pfs.type) {
        Pfs.android => await _uaAndroid(plugin),
        Pfs.ios => await _uaIos(plugin),
        Pfs.macos => await _uaMacos(plugin),
        // Neither needs a platform call: `device_info_plus` reads
        // `/etc/os-release` on Linux, which describes a distribution the
        // parser mostly does not know, and the Windows form below is what
        // every browser on Windows still sends.
        Pfs.linux => _uaLinux,
        Pfs.windows => _uaWindows,
        _ => null,
      };
    } catch (e, s) {
      Loggers.app.warning('DiagnosticsPlatform.userAgent', e, s);
      return _uaUnversioned;
    }
  }

  static const _uaLinux = 'X11; Linux x86_64';

  /// `NT 10.0` on Windows 11 as well — the kernel version never moved, and a
  /// browser reports it the same way. The real release is in the Sentry
  /// context, which is a different dataset and a different question.
  static const _uaWindows = 'Windows NT 10.0; Win64; x64';

  /// What is left when the platform call fails: enough for the parser to place
  /// the OS, no version, no model.
  static String? get _uaUnversioned => switch (Pfs.type) {
    Pfs.android => 'Linux; Android',
    // Not `iPad`, which parses to nothing. An iPad reaching here is counted as
    // a generic iPhone; the alternative is being counted as a server.
    Pfs.ios => 'iPhone',
    Pfs.macos => 'Macintosh',
    Pfs.linux => _uaLinux,
    Pfs.windows => _uaWindows,
    _ => null,
  };

  /// Strips what would break the header's own structure — a `;` or a `)` in a
  /// vendor's model name would end the token or the whole platform section.
  static String _uaToken(String raw) =>
      raw.replaceAll(RegExp(r'[^\w .+-]'), '').trim();

  static Future<String> _uaAndroid(DeviceInfoPlugin plugin) async {
    final info = await plugin.androidInfo;
    final release = _uaToken(info.version.release);
    if (release.isEmpty) return 'Linux; Android';
    final model = _uaToken(info.model);
    if (model.isEmpty) return 'Linux; Android $release';
    return 'Linux; Android $release; $model';
  }

  static Future<String> _uaIos(DeviceInfoPlugin plugin) async {
    final info = await plugin.iosInfo;
    // `18.5` is written `18_5` here, which is the form the parser reads.
    final version = _uaToken(info.systemVersion).replaceAll('.', '_');
    if (version.isEmpty) return 'iPhone';
    // `model` is the generic family, `iPhone` or `iPad` — not `modelName`,
    // which is the marketing name and belongs in the Sentry context instead.
    return info.model.contains('iPad')
        ? 'iPad; CPU OS $version like Mac OS X'
        : 'iPhone; CPU iPhone OS $version like Mac OS X';
  }

  static Future<String> _uaMacos(DeviceInfoPlugin plugin) async {
    final info = await plugin.macOsInfo;
    // `Intel` on Apple Silicon too: Safari says so, and it is what the parser
    // matches on. The actual architecture is in the Sentry device context.
    return 'Macintosh; Intel Mac OS X '
        '${info.majorVersion}_${info.minorVersion}';
  }

  static Future<(sentry.SentryDevice, sentry.SentryOperatingSystem)> _android(
    DeviceInfoPlugin plugin,
  ) async {
    final info = await plugin.androidInfo;
    return (
      sentry.SentryDevice(
        manufacturer: info.manufacturer,
        brand: info.brand,
        model: info.model,
        // `supportedAbis` is ordered best-first, so the head is what this
        // process is actually running as — which is the question a native
        // stack frame raises.
        arch: info.supportedAbis.firstOrNull,
        simulator: !info.isPhysicalDevice,
        lowMemory: info.isLowRamDevice,
      ),
      sentry.SentryOperatingSystem(
        name: 'Android',
        version: info.version.release,
        // The API level, which is what a platform behaviour is keyed on and
        // what `ApplicationExitInfo` availability follows.
        build: '${info.version.sdkInt}',
      ),
    );
  }

  static Future<(sentry.SentryDevice, sentry.SentryOperatingSystem)> _ios(
    DeviceInfoPlugin plugin,
  ) async {
    final info = await plugin.iosInfo;
    return (
      sentry.SentryDevice(
        manufacturer: 'Apple',
        // `modelName` is "iPhone 15 Pro"; `model` is the generic "iPhone".
        model: info.modelName,
        // The hardware identifier, `iPhone16,1`. Not a device identifier —
        // every unit of that model answers the same string.
        modelId: info.utsname.machine,
        arch: info.utsname.machine,
        simulator: !info.isPhysicalDevice,
      ),
      sentry.SentryOperatingSystem(
        name: info.systemName,
        version: info.systemVersion,
        kernelVersion: info.utsname.release,
      ),
    );
  }

  static Future<(sentry.SentryDevice, sentry.SentryOperatingSystem)> _macos(
    DeviceInfoPlugin plugin,
  ) async {
    final info = await plugin.macOsInfo;
    return (
      sentry.SentryDevice(
        manufacturer: 'Apple',
        model: info.modelName,
        modelId: info.model,
        arch: info.arch,
        processorCount: info.activeCPUs,
        memorySize: info.memorySize,
      ),
      sentry.SentryOperatingSystem(
        name: 'macOS',
        version:
            '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}',
        kernelVersion: info.kernelVersion,
        build: info.osRelease,
      ),
    );
  }

  static Future<(sentry.SentryDevice, sentry.SentryOperatingSystem)> _linux(
    DeviceInfoPlugin plugin,
  ) async {
    final info = await plugin.linuxInfo;
    return (
      // There is no model to report: this reads `/etc/os-release`, which
      // describes the distribution and knows nothing about the hardware.
      sentry.SentryDevice(),
      sentry.SentryOperatingSystem(
        name: info.name,
        version: info.versionId,
        build: info.buildId,
        // "Ubuntu 24.04.1 LTS", which is what a user would say they run and
        // is not reconstructable from the fields above.
        rawDescription: info.prettyName,
      ),
    );
  }

  static Future<(sentry.SentryDevice, sentry.SentryOperatingSystem)> _windows(
    DeviceInfoPlugin plugin,
  ) async {
    final info = await plugin.windowsInfo;
    return (
      sentry.SentryDevice(
        processorCount: info.numberOfCores,
        memorySize: info.systemMemoryInMegabytes * 1024 * 1024,
      ),
      sentry.SentryOperatingSystem(
        name: 'Windows',
        // `productName` is "Windows 10 Pro" even on Windows 11; the build
        // number is what actually tells the two apart, so both are kept.
        version: info.displayVersion,
        build: '${info.buildNumber}',
        rawDescription: info.productName,
      ),
    );
  }
}
