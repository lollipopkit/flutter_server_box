import 'package:json_annotation/json_annotation.dart';

part 'agent_shell_config.g.dart';

/// Where the floating Agent sits on a desktop window, and how big it is.
///
/// A negative offset means "never placed", which the shell reads as its
/// default corner: a first run has no position to restore, and 0,0 is a real
/// position somebody may have dragged it to.
@JsonSerializable()
class AgentShellWindow {
  const AgentShellWindow({
    this.left = -1.0,
    this.top = -1.0,
    this.width = 400.0,
    this.height = 560.0,
  });

  factory AgentShellWindow.fromJson(Map<String, dynamic> json) =>
      _$AgentShellWindowFromJson(json);

  final double left;
  final double top;
  final double width;
  final double height;

  Map<String, dynamic> toJson() => _$AgentShellWindowToJson(this);

  AgentShellWindow copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
  }) => AgentShellWindow(
    left: left ?? this.left,
    top: top ?? this.top,
    width: width ?? this.width,
    height: height ?? this.height,
  );

  @override
  bool operator ==(Object other) =>
      other is AgentShellWindow &&
      left == other.left &&
      top == other.top &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

/// How the collapsed Agent sits on a phone.
@JsonSerializable()
class AgentShellPill {
  const AgentShellPill({
    this.onRight = true,
    this.y = 0.62,
    this.sheetHeight = 0.62,
  });

  factory AgentShellPill.fromJson(Map<String, dynamic> json) =>
      _$AgentShellPillFromJson(json);

  /// Which edge the collapsed pill clings to.
  final bool onRight;

  /// How far down that edge, as a fraction of the screen.
  final double y;

  /// How much of the screen the expanded Agent takes, as a fraction.
  final double sheetHeight;

  Map<String, dynamic> toJson() => _$AgentShellPillToJson(this);

  AgentShellPill copyWith({bool? onRight, double? y, double? sheetHeight}) =>
      AgentShellPill(
        onRight: onRight ?? this.onRight,
        y: y ?? this.y,
        sheetHeight: sheetHeight ?? this.sheetHeight,
      );

  @override
  bool operator ==(Object other) =>
      other is AgentShellPill &&
      onRight == other.onRight &&
      y == other.y &&
      sheetHeight == other.sheetHeight;

  @override
  int get hashCode => Object.hash(onRight, y, sheetHeight);
}

/// Everything about the floating Agent, as one stored value.
///
/// Eight `kv` rows before this — `agentShellMode`, `agentShellLeft`,
/// `agentShellTop` and so on — which is eight rows in a backup, eight entries
/// in the sync timestamps, and eight lines in the raw settings editor for what
/// is one piece of state.
///
/// Nested rather than flat because the halves are answers to different
/// questions: [window] is a desktop window's rectangle and [pill] is a phone's
/// layout, and no device reads both. [mode] is above them since both do read
/// that.
///
/// Hand-written `toJson`, like the rest of the models here that have one:
/// `SqliteStore.set` encodes with it and answers `false` rather than throwing
/// when it is missing, so a model without one is dropped silently on every
/// write.
@JsonSerializable()
class AgentShellConfig {
  const AgentShellConfig({
    this.mode = 'hidden',
    this.window = const AgentShellWindow(),
    this.pill = const AgentShellPill(),
  });

  factory AgentShellConfig.fromJson(Map<String, dynamic> json) =>
      _$AgentShellConfigFromJson(json);

  /// Whether the Agent follows you onto the other tabs, and how much of it
  /// comes along. One of `AgentShellMode`'s names.
  ///
  /// By name, never by index: an index silently changes meaning when a case is
  /// inserted, and this outlives the build that wrote it.
  final String mode;

  final AgentShellWindow window;
  final AgentShellPill pill;

  Map<String, dynamic> toJson() => _$AgentShellConfigToJson(this);

  AgentShellConfig copyWith({
    String? mode,
    AgentShellWindow? window,
    AgentShellPill? pill,
  }) => AgentShellConfig(
    mode: mode ?? this.mode,
    window: window ?? this.window,
    pill: pill ?? this.pill,
  );

  @override
  bool operator ==(Object other) =>
      other is AgentShellConfig &&
      mode == other.mode &&
      window == other.window &&
      pill == other.pill;

  @override
  int get hashCode => Object.hash(mode, window, pill);
}
