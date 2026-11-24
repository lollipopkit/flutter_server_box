import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// AppBar metadata and body rendered by [StatusDetailShell] while the entity is
/// active.
typedef StatusDetailView = ({
  String title,
  String subtitle,
  VoidCallback? onRefresh,
  VoidCallback onEdit,
  Widget body,
});

/// Shared detail-page shell for Status-tab entities (`BmcDetailPage`,
/// `UptimerDetailPage`): pops the pushed route if the entity disappears from
/// its store, and only mounts [builder] (and its Riverpod watches) while the
/// entity is active so detail providers auto-dispose promptly upon deletion.
final class StatusDetailShell extends StatefulWidget {
  final Object entityKey;
  final bool bare;
  final bool existsInStore;
  final StatusDetailView Function(BuildContext context, WidgetRef ref) builder;

  const StatusDetailShell({
    super.key,
    required this.entityKey,
    required this.bare,
    required this.existsInStore,
    required this.builder,
  });

  @override
  State<StatusDetailShell> createState() => _StatusDetailShellState();
}

final class _StatusDetailShellState extends State<StatusDetailShell> {
  var _everInStore = false;
  var _popScheduled = false;

  @override
  void didUpdateWidget(covariant StatusDetailShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entityKey != widget.entityKey) {
      _everInStore = false;
      _popScheduled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.existsInStore) {
      _everInStore = true;
      _popScheduled = false;
    } else if (_everInStore) {
      if (!widget.bare && !_popScheduled) {
        _popScheduled = true;
        final scheduledKey = widget.entityKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              widget.bare ||
              widget.existsInStore ||
              widget.entityKey != scheduledKey) {
            return;
          }
          final route = ModalRoute.of(context);
          if (route == null || !route.isActive) return;
          if (route.isCurrent) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).removeRoute(route);
          }
        });
      }
      return widget.bare ? UIs.placeholder : const Scaffold();
    }

    return Consumer(
      builder: (context, ref, _) {
        final view = widget.builder(context, ref);
        if (widget.bare) return view.body;
        return Scaffold(
          appBar: CustomAppBar(
            title: TwoLineText(up: view.title, down: view.subtitle),
            actions: [
              Btn.icon(
                text: libL10n.refresh,
                icon: const Icon(Icons.refresh),
                onTap: view.onRefresh,
              ),
              Btn.icon(
                text: libL10n.edit,
                icon: const Icon(Icons.edit_outlined),
                onTap: view.onEdit,
              ),
            ],
          ),
          body: view.body,
        );
      },
    );
  }
}
