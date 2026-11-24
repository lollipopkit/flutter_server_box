import 'dart:convert';

import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';

/// The stored rules as `fl_pi_llm::redact::Settings` JSON, the switch aside.
String redactRulesJson({
  List<String>? off,
  List<String>? allow,
  List<Map<String, Object?>>? custom,
}) => jsonEncode({
  'enabled': true,
  'off': off ?? Stores.setting.agentRedactOff.fetch(),
  'allow': allow ?? Stores.setting.agentRedactAllow.fetch(),
  'custom': custom ?? Stores.setting.agentRedactRules.fetch(),
});

/// This app's redaction rules, as [RedactPage] reads and writes them. The
/// switch is its own setting (`agentRedact`), so the page shows the rules
/// while it is off.
final class LocalRedactSource implements RedactSource {
  @override
  Future<String?> load() async => redactRulesJson();

  @override
  Future<String?> save(String? settings) async {
    final s = settings == null
        ? const <String, Object?>{}
        : (jsonDecode(settings) as Map).cast<String, Object?>();
    final off = SettingStore.stringList(s['off']);
    final allow = SettingStore.stringList(s['allow']);
    final custom = [
      for (final r in (s['custom'] as List?) ?? const [])
        if (r is Map) r.map((k, v) => MapEntry(k.toString(), v)),
    ];
    // Checked with the switch off too: what is stored runs once it is on.
    final err = await Llm.redactError(
      redactRulesJson(off: off, allow: allow, custom: custom),
    );
    if (err != null) return err;
    await Stores.setting.agentRedactOff.set(off);
    await Stores.setting.agentRedactAllow.set(allow);
    // Each reaches the engine through its listener.
    await Stores.setting.agentRedactRules.set(custom);
    return null;
  }

  @override
  bool get enabled => Stores.setting.agentRedact.fetch();

  @override
  Future<void> setEnabled(bool on) async {
    await Stores.setting.agentRedact.set(on);
  }
}
