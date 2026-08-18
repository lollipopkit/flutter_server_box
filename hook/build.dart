import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

/// Builds `crates/sbm_ffi` and hands the result to the Dart/Flutter SDK as a
/// code asset.
///
/// This replaces cargokit, which drove cargo from a CocoaPods `script_phase` on
/// Apple platforms, a CMake step on Linux and Windows, and a gradle plugin on
/// Android — four integrations, one per platform, and the Apple one had no
/// Swift Package Manager equivalent: a SwiftPM build tool plugin runs in a
/// sandbox that denies writes to the project directory, so cargo cannot write
/// `target/` or `~/.cargo` from one. That mattered because CocoaPods' registry
/// goes read-only on 2026-12-02 and Flutter's fallback to it is removed some
/// time after.
///
/// A build hook sidesteps the question rather than answering it: it is neither
/// a pod nor a Swift package, so it produces no `.podspec` and no
/// `Package.swift`, and the same file covers all five platforms.
void main(List<String> args) async {
  await build(args, (input, output) async {
    await const FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'crates/sbm_ffi',
    ).run(input: input, output: output);
  });
}
