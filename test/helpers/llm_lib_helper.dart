import 'dart:io';

import 'package:fl_pi_llm/fl_pi_llm.dart';

/// fl_pi_llm's library as `flutter test` builds it (its build hook).
ExternalLibrary llmNativeLib() => ExternalLibrary.open(switch (Platform.operatingSystem) {
  'macos' => 'build/native_assets/macos/libfl_pi_llm.dylib',
  'windows' => 'build/native_assets/windows/fl_pi_llm.dll',
  _ => 'build/native_assets/linux/libfl_pi_llm.so',
});

/// Loads [llmNativeLib], for a test calling what fl_pi_llm does in Rust
/// (memory, skills, MCP) without starting the Agent.
Future<void> loadLlmLibForTest() => FlPiLlm.loadLibrary(externalLibrary: llmNativeLib());
