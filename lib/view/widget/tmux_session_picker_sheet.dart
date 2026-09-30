import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_models.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_info.dart';

/// A tmux session as the session picker sees it.
///
/// Discovery and control mode both provide tmux's stable `$id`; the picker is
/// the boundary where their remaining field differences become one shape.
final class TmuxPickerSession {
  final TmuxSessionId id;
  final String name;
  final int windowCount;
  final bool attached;

  const TmuxPickerSession({
    required this.id,
    required this.name,
    required this.windowCount,
    required this.attached,
  });

  factory TmuxPickerSession.fromDiscovery(TmuxSessionInfo session) {
    return TmuxPickerSession(
      id: session.id,
      name: session.name,
      windowCount: session.windows,
      attached: session.attached,
    );
  }

  factory TmuxPickerSession.fromControl(TmuxControlSessionSummary session) {
    return TmuxPickerSession(
      id: session.id,
      name: session.name,
      windowCount: session.windows,
      attached: session.attached,
    );
  }
}

sealed class TmuxSessionPickerResult {
  const TmuxSessionPickerResult();
}

final class TmuxPickExisting extends TmuxSessionPickerResult {
  final TmuxSessionId sessionId;
  final String sessionName;

  const TmuxPickExisting({required this.sessionId, required this.sessionName});
}

final class TmuxPickNew extends TmuxSessionPickerResult {
  final String sessionName;

  const TmuxPickNew(this.sessionName);
}

final class TmuxPickSkip extends TmuxSessionPickerResult {
  const TmuxPickSkip();
}

final class TmuxPickDetach extends TmuxSessionPickerResult {
  const TmuxPickDetach();
}

/// Shows the one session picker used before attach and while already attached.
///
/// Sessions are choices in a bottom sheet; windows are deliberately absent.
/// A window is a property of an attached session and is already represented by
/// the persistent window bar, so showing another drill-down here would make the
/// same state editable in two places with two different controls.
Future<TmuxSessionPickerResult?> showTmuxSessionPickerSheet(
  BuildContext context, {
  required List<TmuxPickerSession> sessions,
  required String defaultSessionName,
  TmuxSessionId? selectedSessionId,
  bool showSkip = false,
  bool showDetach = false,
}) {
  final existingNames = {for (final session in sessions) session.name};
  final suggestedName = _uniqueTmuxSessionName(
    defaultSessionName,
    existingNames,
  );
  return showModalBottomSheet<TmuxSessionPickerResult>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 17),
        children: [
          _TmuxNewSessionRow(
            suggestedSessionName: suggestedName,
            existingNames: existingNames,
          ),
          if (sessions.isNotEmpty) const Divider(height: 1),
          for (final session in sessions)
            _TmuxSessionTile(
              session: session,
              selected: session.id == selectedSessionId,
              onTap: () => Navigator.of(sheetContext).pop(
                TmuxPickExisting(
                  sessionId: session.id,
                  sessionName: session.name,
                ),
              ),
            ),
          if (showDetach) ...[
            const Divider(height: 1),
            SheetChoiceTile(
              icon: Icons.link_off_outlined,
              title: context.l10n.disconnect,
              selected: false,
              onTap: () =>
                  Navigator.of(sheetContext).pop(const TmuxPickDetach()),
            ),
          ],
          if (showSkip) ...[
            const Divider(height: 1),
            SheetChoiceTile(
              icon: Icons.close_outlined,
              title: context.l10n.tmuxSkip,
              selected: false,
              onTap: () => Navigator.of(sheetContext).pop(const TmuxPickSkip()),
            ),
          ],
        ],
      ),
    ),
  );
}

final class _TmuxSessionTile extends StatelessWidget {
  final TmuxPickerSession session;
  final bool selected;
  final VoidCallback onTap;

  const _TmuxSessionTile({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final details = [
      l10n.tmuxWindowCount(session.windowCount),
      if (session.attached) l10n.tmuxAttached,
    ];

    return ListTile(
      selected: selected,
      leading: Icon(session.attached ? Icons.link : Icons.link_outlined),
      title: Text(session.name),
      subtitle: Text(details.join(' · '), style: UIs.text11Grey),
      trailing: selected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

final class _TmuxNewSessionRow extends StatelessWidget {
  final String suggestedSessionName;
  final Set<String> existingNames;

  const _TmuxNewSessionRow({
    required this.suggestedSessionName,
    required this.existingNames,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.add),
      title: Text(l10n.tmuxNewSession),
      subtitle: Text(
        suggestedSessionName.isEmpty
            ? l10n.tmuxSessionName
            : suggestedSessionName,
        style: UIs.text11Grey,
      ),
      onTap: () => _showNameDialog(context),
    );
  }

  Future<void> _showNameDialog(BuildContext sheetContext) async {
    // The text field can still be attached while the dialog route animates out,
    // so let the route dispose the controller and the name notifier together.
    final controller = TextEditingController(text: suggestedSessionName);
    final name = ValueNotifier<String>(suggestedSessionName);

    bool isValid(String value) {
      final trimmed = value.trim();
      return trimmed.isNotEmpty && !existingNames.contains(trimmed);
    }

    final result = await sheetContext.showRoundDialog<String>(
      title: sheetContext.l10n.tmuxNewSession,
      childBuilder: (dialogContext) => DisposeWith(
        notifiers: [controller, name],
        child: ValueListenableBuilder<String>(
          valueListenable: name,
          builder: (context, value, _) {
            final trimmed = value.trim();
            return Input(
              controller: controller,
              hint: dialogContext.l10n.tmuxSessionName,
              label: dialogContext.l10n.tmuxNewSession,
              action: TextInputAction.done,
              suggestion: false,
              autoFocus: true,
              errorText: existingNames.contains(trimmed)
                  ? context.l10n.nameAlreadyExistsFmt(trimmed)
                  : null,
              onChanged: (text) => name.value = text,
              onSubmitted: (text) {
                name.value = text;
                if (isValid(text)) {
                  Navigator.of(dialogContext).pop(text.trim());
                }
              },
            );
          },
        ),
      ),
      actionsBuilder: (dialogContext) => [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(libL10n.cancel),
        ),
        ValueListenableBuilder<String>(
          valueListenable: name,
          builder: (context, value, _) => TextButton(
            onPressed: isValid(value)
                ? () => Navigator.of(dialogContext).pop(value.trim())
                : null,
            child: Text(libL10n.ok),
          ),
        ),
      ],
    );
    // The dialog is on the root navigator and can outlive the sheet.
    if (result == null || result.isEmpty || !sheetContext.mounted) return;
    Navigator.of(sheetContext).pop(TmuxPickNew(result));
  }
}

String _uniqueTmuxSessionName(String preferred, Set<String> existingNames) {
  final name = preferred.trim();
  if (name.isEmpty || !existingNames.contains(name)) return name;

  for (var suffix = 2; ; suffix++) {
    final candidate = '$name-$suffix';
    if (!existingNames.contains(candidate)) return candidate;
  }
}
