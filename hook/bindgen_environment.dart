import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

/// What bindgen needs to find a system header when cross-compiling.
///
/// `rquickjs-sys` ships pre-generated bindings for sixteen targets, and iOS
/// and Android are not among them — a build for either fails with `couldn't
/// read src/bindings/aarch64-apple-ios.rs`, which names the file rather than
/// the reason. `crates/sbm_plugin` turns on that crate's `bindgen` feature for
/// exactly those two targets, and this supplies the half bindgen cannot work
/// out for itself.
///
/// **The half it cannot work out is the sysroot.** bindgen drives libclang
/// directly rather than the SDK's `clang` wrapper, so nothing has told it
/// where `stdio.h` is; without `-isysroot`/`--sysroot` it fails on the first
/// `#include` in `quickjs.h`. The target triple is passed alongside it because
/// libclang otherwise compiles for the host, and would produce bindings whose
/// pointer widths and struct layouts are the build machine's.
///
/// Empty for every other target, which is the point: where a binding is
/// shipped it is used, and neither libclang nor a sysroot has to exist on the
/// machine doing the build.
Map<String, String> bindgenCrossCompileEnvironment(BuildInput input) {
  // Read here rather than at the call site: `.code` is an extension `hook/`
  // only imports in this file, and the resolution is where it is written.
  final code = input.config.code;
  final args = switch (code.targetOS) {
    OS.iOS => _appleClangArgs(
      // `arm64` rather than `aarch64`: this is clang's spelling, not Rust's,
      // and clang rejects the other one for an Apple target.
      triple:
          '${_appleArch(code.targetArchitecture)}-apple-ios'
          '${code.iOS.targetVersion}'
          '${code.iOS.targetSdk == IOSSdk.iPhoneSimulator ? '-simulator' : ''}',
      sdk: code.iOS.targetSdk.type,
    ),
    OS.android => _androidClangArgs(code),
    _ => null,
  };
  if (args == null || args.isEmpty) return const {};

  // Suffixed with the target rather than bare. The suffixed form is what
  // bindgen consults for the target being built, and leaves a host build of
  // the same crate — which `rquickjs` does when a proc-macro feature pulls it
  // in — reading its own bundled bindings instead of iOS's.
  final suffix = _rustTriple(code).replaceAll('-', '_');
  return {'BINDGEN_EXTRA_CLANG_ARGS_$suffix': args};
}

/// Where the platform's headers are, asked of the toolchain that owns them.
///
/// `xcrun` rather than a path: an SDK is versioned (`iPhoneOS26.5.sdk`) and
/// moves with Xcode, so a literal path here would be a build that breaks on
/// the next Xcode release, on somebody else's machine, or on CI.
String? _appleClangArgs({required String triple, required String sdk}) {
  final sdkPath = _xcrunSdkPath(sdk);
  if (sdkPath == null) return null;
  return '--target=$triple -isysroot $sdkPath';
}

String? _xcrunSdkPath(String sdk) {
  if (!Platform.isMacOS) return null;
  final result = Process.runSync('xcrun', ['--sdk', sdk, '--show-sdk-path']);
  if (result.exitCode != 0) return null;
  final path = (result.stdout as String).trim();
  return path.isEmpty ? null : path;
}

/// The NDK's sysroot, derived from the compiler the build hook was handed.
///
/// Never `ANDROID_NDK_HOME` and never a version in a path: the NDK doing this
/// build is the one whose `clang` is in [CodeConfig.cCompiler], and an
/// environment variable pointing at a second one is how a build links against
/// headers from a version it is not compiling with.
///
/// The layout is `<prebuilt>/bin/<triple><api>-clang` beside
/// `<prebuilt>/sysroot`, which has held across every NDK that uses the unified
/// toolchain (r19 and later; the app's minimum is far above that).
String? _androidClangArgs(CodeConfig code) {
  final compiler = code.cCompiler?.compiler;
  if (compiler == null) return null;
  final sysroot = compiler.resolve('../../sysroot').toFilePath();
  if (!Directory(sysroot).existsSync()) return null;
  // The API level belongs in the triple on Android — it is what selects which
  // symbols the headers declare, and omitting it silently compiles against the
  // newest the NDK has.
  final triple =
      '${_androidArch(code.targetArchitecture)}${code.android.targetNdkApi}';
  return '--target=$triple --sysroot=$sysroot';
}

String _appleArch(Architecture arch) =>
    arch == Architecture.arm64 ? 'arm64' : 'x86_64';

String _androidArch(Architecture arch) => switch (arch) {
  Architecture.arm64 => 'aarch64-linux-android',
  // The only target whose clang triple is not the Rust one: Rust spells it
  // `armv7-linux-androideabi`, clang spells it `armv7a-linux-androideabi`.
  Architecture.arm => 'armv7a-linux-androideabi',
  Architecture.ia32 => 'i686-linux-android',
  _ => 'x86_64-linux-android',
};

/// The Rust target triple, which is what names the environment variable.
String _rustTriple(CodeConfig code) {
  final arch = switch (code.targetArchitecture) {
    Architecture.arm64 => 'aarch64',
    Architecture.arm => 'armv7',
    Architecture.ia32 => 'i686',
    _ => 'x86_64',
  };
  return switch (code.targetOS) {
    OS.iOS =>
      code.iOS.targetSdk == IOSSdk.iPhoneSimulator && arch == 'aarch64'
          ? 'aarch64-apple-ios-sim'
          : '$arch-apple-ios',
    OS.android => arch == 'armv7'
        ? 'armv7-linux-androideabi'
        : '$arch-linux-android',
    _ => arch,
  };
}
