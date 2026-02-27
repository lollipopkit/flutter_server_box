import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

@immutable
class AiContextSnapshot {
  const AiContextSnapshot({
    required this.title,
    required this.scenario,
    required this.blocks,
    this.spiId,
    this.updatedAtMs,
  });

  final String title;
  final String scenario;
  final List<String> blocks;
  final String? spiId;
  final int? updatedAtMs;

  AiContextSnapshot copyWith({
    String? title,
    String? scenario,
    List<String>? blocks,
    String? spiId,
    int? updatedAtMs,
  }) {
    return AiContextSnapshot(
      title: title ?? this.title,
      scenario: scenario ?? this.scenario,
      blocks: blocks ?? this.blocks,
      spiId: spiId ?? this.spiId,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }
}

final aiContextProvider = NotifierProvider<AiContextNotifier, AiContextSnapshot>(AiContextNotifier.new);

class AiContextNotifier extends Notifier<AiContextSnapshot> {
  @override
  AiContextSnapshot build() {
    return const AiContextSnapshot(
      title: 'Ask AI',
      scenario: 'general',
      blocks: [],
      updatedAtMs: 0,
    );
  }

  void setContext({
    required String title,
    required String scenario,
    required List<String> blocks,
    String? spiId,
  }) {
    state = AiContextSnapshot(
      title: title,
      scenario: scenario,
      blocks: blocks,
      spiId: spiId,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
