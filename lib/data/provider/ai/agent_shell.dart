import 'package:flutter/painting.dart' show Alignment;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/app/float_shell.dart';
import 'package:server_box/data/res/store.dart';

part 'agent_shell.g.dart';

/// Whether the Agent follows you onto the other tabs, and how much of it comes
/// along.
///
/// The conversation is in `agentSessionProvider` and carries on either way —
/// see [FloatShellMode], which the terminal's floating window shares.
@Riverpod(keepAlive: true)
class AgentShell extends _$AgentShell {
  @override
  FloatShellMode build() => agentShellGeometry.storedMode;

  /// Brings it back the way it was left, rather than always fully open: a user
  /// who collapsed it meant to keep it out of the way.
  void show() => _set(
    state == FloatShellMode.collapsed
        ? FloatShellMode.collapsed
        : FloatShellMode.expanded,
  );

  void expand() => _set(FloatShellMode.expanded);

  void collapse() => _set(FloatShellMode.collapsed);

  void hide() => _set(FloatShellMode.hidden);

  void toggle() => _set(
    state == FloatShellMode.hidden
        ? FloatShellMode.expanded
        : FloatShellMode.hidden,
  );

  void _set(FloatShellMode mode) {
    if (state == mode) return;
    state = mode;
    agentShellGeometry.saveMode(mode);
  }
}

/// Where the floating Agent was left.
///
/// A getter rather than a field: [FloatShellGeometry] holds the settings row's
/// properties, and reading `Stores.setting` at import time would resolve the
/// store before `Stores.init` has registered one.
FloatShellGeometry get agentShellGeometry => FloatShellGeometry(
  Stores.setting.agentShell,
  defaultCorner: Alignment.bottomRight,
);
