import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/ai/ai_context.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/widget/ai/ai_assist_sheet.dart';

class AiFabOverlay extends ConsumerStatefulWidget {
  const AiFabOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AiFabOverlay> createState() => _AiFabOverlayState();
}

class _AiFabOverlayState extends ConsumerState<AiFabOverlay> {
  Offset? _offsetPx;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_offsetPx != null) return;

    final media = MediaQuery.of(context);
    final size = media.size;
    final x = Stores.setting.aiFabOffsetX.fetch().clamp(0.0, 1.0);
    final y = Stores.setting.aiFabOffsetY.fetch().clamp(0.0, 1.0);

    _offsetPx = Offset(size.width * x, size.height * y);
  }

  void _persistOffset(Offset px) {
    final size = MediaQuery.of(context).size;
    if (size.width <= 0 || size.height <= 0) return;

    final nx = (px.dx / size.width).clamp(0.0, 1.0);
    final ny = (px.dy / size.height).clamp(0.0, 1.0);

    Stores.setting.aiFabOffsetX.put(nx);
    Stores.setting.aiFabOffsetY.put(ny);
  }

  Offset _clampToBounds(Offset px) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final padding = media.padding;

    const fabSize = 56.0;
    const margin = 8.0;

    final minX = margin;
    final maxX = (size.width - fabSize - margin).clamp(minX, size.width);

    final topInset = padding.top;
    final bottomInset = padding.bottom;

    final minY = topInset + margin;
    final maxY = (size.height - fabSize - bottomInset - margin).clamp(minY, size.height);

    return Offset(px.dx.clamp(minX, maxX), px.dy.clamp(minY, maxY));
  }

  Future<void> _onTapFab() async {
    final snapshot = ref.read(aiContextProvider);

    final localeHint = Localizations.maybeLocaleOf(context)?.toLanguageTag();

    final scenario = AskAiScenarioX.tryParse(snapshot.scenario) ?? AskAiScenario.general;

    final applyBehavior = snapshot.spiId != null ? AiApplyBehavior.openSsh : AiApplyBehavior.copy;

    await showAiAssistSheet(
      context,
      AiAssistArgs(
        title: snapshot.title,
        contextBlocks: snapshot.blocks,
        scenario: scenario,
        localeHint: localeHint,
        applyLabel: applyBehavior == AiApplyBehavior.openSsh ? libL10n.ok : libL10n.copy,
        applyBehavior: applyBehavior,
        onOpenSsh: (cmd) {
          final spiId = snapshot.spiId;
          if (spiId == null) return;
          final spi = Stores.server.get<Spi>(spiId);
          if (spi == null) return;
          final args = SshPageArgs(spi: spi, initCmd: cmd);
          SSHPage.route.go(context, args);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offset = _offsetPx;
    if (offset == null) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: offset.dx,
          top: offset.dy,
          child: Draggable(
            feedback: _buildFab(context, dragging: true),
            childWhenDragging: const SizedBox.shrink(),
            onDragEnd: (details) {
              if (!mounted) return;
              final next = _clampToBounds(details.offset);
              setState(() {
                _offsetPx = next;
              });
              _persistOffset(next);
            },
            child: _buildFab(context),
          ),
        ),
      ],
    );
  }

  Widget _buildFab(BuildContext context, {bool dragging = false}) {
    return FloatingActionButton(
      heroTag: dragging ? null : 'ai_fab',
      onPressed: _onTapFab,
      child: const Icon(LineAwesome.robot_solid),
    );
  }
}
