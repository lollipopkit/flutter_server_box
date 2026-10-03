import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:server_box/data/model/app/motion.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';

/// Whether the app moves less, from the device's accessibility settings and
/// the app's own [MotionPref] over them.
///
/// The answer reaches widgets as [MediaQueryData.disableAnimations], set below
/// the app's `MaterialApp` by [MotionScope] — so `context.motion()`,
/// `context.reduceMotion` and fl_lib's own widgets all read the one value.
///
/// Three platform signals mean "less motion", and Flutter merges none of them:
/// - Android's "Remove animations" is `disableAnimations`, which the framework
///   also acts on by itself — see [AppBinding].
/// - iOS's "Reduce Motion" is `reduceMotion`, a separate flag the framework
///   reads nowhere but one Cupertino menu.
/// - macOS's "Reduce motion" is not passed to Flutter at all, so the runner
///   answers it over its own channel.
abstract final class AppMotion {
  static final _system = ValueNotifier(_platformReduces());

  /// What the device asks for, before the app's preference.
  static ValueListenable<bool> get system => _system;

  /// The app's preference, cached for [AppBinding], which is asked on every
  /// animation start and has to answer before the settings are open.
  static final _pref = ValueNotifier(MotionPref.full);
  static MotionPref get pref => _pref.value;

  /// Either of the two having changed.
  static final Listenable changes = Listenable.merge([_system, _pref]);

  static bool _macReduces = false;
  static bool _started = false;

  /// The macOS runner's: asked once, and it calls back on every change.
  static const _channel = MethodChannel('${Miscs.pkgName}/motion');

  /// Whether motion is reduced now.
  static bool get reduces => _pref.value.reduces(system: _system.value);

  /// Starts following the preference and the device. Once, after the settings
  /// store is open.
  static Future<void> init() async {
    if (_started) return;
    _started = true;
    final prop = Stores.setting.motionPref;
    _pref.value = prop.fetch();
    prop.listenable().addListener(() => _pref.value = prop.fetch());
    if (isMacOS) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'reduceMotionChanged' && call.arguments is bool) {
          _macReduces = call.arguments as bool;
          refreshSystem();
        }
      });
      try {
        _macReduces =
            await _channel.invokeMethod<bool>('reduceMotion') ?? false;
      } catch (e, s) {
        Loggers.app.warning('Reading the reduce motion setting', e, s);
      }
      refreshSystem();
    }
  }

  /// Reads the device's setting again, after the platform said it changed.
  static void refreshSystem() => _system.value = _platformReduces();

  static bool _platformReduces() {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.disableAnimations || features.reduceMotion || _macReduces;
  }
}

/// The binding, so that "full motion" also reaches the framework's own
/// animations.
///
/// Flutter shortens every [AnimationController] to a twentieth of its duration
/// when the device's `disableAnimations` is on (Android's "Remove animations"),
/// asked of [SemanticsBinding.disableAnimations] rather than of `MediaQuery` —
/// so a `MediaQuery` saying otherwise changes nothing there. This is the one
/// place that can say otherwise.
///
/// "Reduce" is not forced through here: that would cut fades to a frame as
/// well, and what less motion asks for is nothing *travelling* — which the
/// app's widgets decide for themselves, reading [MotionScope].
final class AppBinding extends WidgetsFlutterBinding {
  /// In place of `WidgetsFlutterBinding.ensureInitialized`, once, first
  /// thing at launch.
  AppBinding();

  @override
  bool get disableAnimations =>
      AppMotion.pref == MotionPref.full ? false : super.disableAnimations;

  @override
  void handleAccessibilityFeaturesChanged() {
    super.handleAccessibilityFeaturesChanged();
    AppMotion.refreshSystem();
  }
}

/// Hands [AppMotion.reduces] to everything below as
/// [MediaQueryData.disableAnimations].
class MotionScope extends StatelessWidget {
  const MotionScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppMotion.changes,
      child: child,
      // Always wrapped, even when it would say what is already there: a
      // subtree whose parent comes and goes loses its state.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: AppMotion.reduces),
        child: child!,
      ),
    );
  }
}
