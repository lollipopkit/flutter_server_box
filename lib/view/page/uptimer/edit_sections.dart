import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/uptimer/common.dart';
import 'package:server_box/view/page/uptimer/detail_sections.dart';
import 'package:server_box/view/page/uptimer/edit_validator.dart';
import 'package:server_box/view/widget/group_title.dart';

/// Opens the group selection / custom-group entry bottom sheet.
Future<String?> showUptimerGroupPicker(
  BuildContext context, {
  required String current,
  required List<String> existingGroups,
}) {
  final customCtrl = TextEditingController(text: current);
  return context.showSheet<String>(
    title: l10n.uptimerGroup,
    childBuilder: (ctx) => DisposeWith(
      notifiers: [customCtrl],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                current.isEmpty
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(libL10n.none),
              onTap: () => ctx.popSheet(''),
            ),
            for (final g in existingGroups)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  current == g
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(g),
                onTap: () => ctx.popSheet(g),
              ),
            const SizedBox(height: 8),
            Input(
              controller: customCtrl,
              label: libL10n.custom,
              hint: 'BASE / SERVICE',
              icon: Icons.folder_outlined,
              autoCorrect: false,
              onSubmitted: (v) => ctx.popSheet(v.trim()),
            ),
          ],
        ),
      ),
    ),
    actionsBuilder: (ctx) => [
      TextButton(
        onPressed: () => ctx.popSheet(),
        child: Text(libL10n.cancel),
      ),
      TextButton(
        onPressed: () => ctx.popSheet(customCtrl.text.trim()),
        child: Text(libL10n.ok),
      ),
    ],
  );
}

/// Centered error state shown when loading an existing monitor config fails.
final class UptimerEditLoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const UptimerEditLoadError({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 32, color: StatePalette.failed),
              UIs.height13,
              Text(
                uptimerErrorMessage(error),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: StatePalette.failed),
              ),
              UIs.height13,
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(libL10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Target protocol & address section for [UptimerEditPage].
final class UptimerTargetSection extends StatelessWidget {
  final bool isEditing;
  final bool saving;
  final UptimerMonitorType type;
  final TextEditingController targetCtrl;
  final ValueChanged<UptimerMonitorType> onTypeChanged;
  final VoidCallback onRotatePushUrl;

  const UptimerTargetSection({
    super.key,
    required this.isEditing,
    required this.saving,
    required this.type,
    required this.targetCtrl,
    required this.onTypeChanged,
    required this.onRotatePushUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupTitle(l10n.uptimerTarget, right: isEditing ? type.shortLabel : null),
        if (!isEditing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SegmentedTabs<UptimerMonitorType>(
              expand: true,
              segments: [
                for (final t in UptimerMonitorType.values)
                  SegmentedTab(
                    value: t,
                    icon: uptimerTypeIcon(t),
                    label: t.shortLabel,
                  ),
              ],
              selected: type,
              onSelected: onTypeChanged,
            ),
          ),
        if (type != UptimerMonitorType.heartbeat)
          Input(
            controller: targetCtrl,
            label: l10n.uptimerTarget,
            hint: type == UptimerMonitorType.http
                ? 'https://example.com/health'
                : 'example.com:443',
            icon: Icons.link,
            autoCorrect: false,
            suggestion: false,
            type: TextInputType.url,
          )
        else
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.uptimerPushUrl),
            subtitle: Text(
              isEditing ? l10n.uptimerRotatePushUrl : l10n.uptimerPushUrlOnce,
              style: UIs.textGrey,
            ),
            trailing: isEditing
                ? (saving
                      ? kUptimerCircularLoading
                      : const Icon(Icons.keyboard_arrow_right))
                : null,
            onTap: isEditing && !saving ? onRotatePushUrl : null,
          ).cardx,
      ],
    );
  }
}

/// Polling interval and timeout / grace-period section for [UptimerEditPage].
final class UptimerScheduleSection extends StatelessWidget {
  final UptimerMonitorType type;
  final int minInterval;
  final bool customInterval;
  final TextEditingController intervalCtrl;
  final TextEditingController graceCtrl;
  final TextEditingController timeoutCtrl;
  final ValueChanged<int> onPresetSelected;
  final VoidCallback onCustomSelected;
  final VoidCallback onCustomIntervalChanged;
  final VoidCallback onFieldChanged;

  const UptimerScheduleSection({
    super.key,
    required this.type,
    required this.minInterval,
    required this.customInterval,
    required this.intervalCtrl,
    required this.graceCtrl,
    required this.timeoutCtrl,
    required this.onPresetSelected,
    required this.onCustomSelected,
    required this.onCustomIntervalChanged,
    required this.onFieldChanged,
  });

  String _summary() {
    final iv = int.tryParse(intervalCtrl.text.trim());
    final ivStr = iv != null && iv > 0 ? formatDurationSec(iv) : '—';
    if (type == UptimerMonitorType.heartbeat) {
      final g = int.tryParse(graceCtrl.text.trim());
      final gStr = g != null && g >= 0 ? formatDurationSec(g) : '—';
      return '$ivStr · $gStr';
    }
    final ms = int.tryParse(timeoutCtrl.text.trim());
    final tStr = ms != null && ms > 0 ? formatLatencyMs(ms) : '—';
    return '$ivStr · $tStr';
  }

  @override
  Widget build(BuildContext context) {
    final presets = [
      for (final p in kUptimerIntervalPresets)
        if (p >= minInterval) p,
    ];
    final currentInterval = int.tryParse(intervalCtrl.text.trim());
    final isPreset =
        !customInterval &&
        currentInterval != null &&
        presets.contains(currentInterval);
    final intervalLabel = isPreset
        ? formatDurationSec(currentInterval)
        : (currentInterval != null && currentInterval > 0
              ? formatDurationSec(currentInterval)
              : libL10n.custom);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupTitle(l10n.uptimerSchedule, right: _summary()),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: Text(l10n.uptimerInterval),
          trailing: ContextMenuButton(
            actions: () => [
              for (final preset in presets)
                ContextMenuAction(
                  text: formatDurationSec(preset),
                  checked: isPreset && currentInterval == preset,
                  onTap: () => onPresetSelected(preset),
                ),
              ContextMenuAction(
                text: '${libL10n.custom}…',
                checked: !isPreset,
                onTap: onCustomSelected,
              ),
            ],
            child: ContextMenuButton.value(Text(intervalLabel)),
          ),
        ).cardx,
        if (customInterval || !isPreset)
          Input(
            controller: intervalCtrl,
            label: '${l10n.uptimerInterval} (${l10n.second})',
            hint: l10n.uptimerMinIntervalHint(minInterval),
            icon: Icons.schedule,
            type: TextInputType.number,
            suggestion: false,
            onChanged: (_) => onCustomIntervalChanged(),
          ),
        if (type == UptimerMonitorType.heartbeat)
          Input(
            controller: graceCtrl,
            label: '${l10n.uptimerGracePeriod} (${l10n.second})',
            hint: '60',
            icon: Icons.hourglass_bottom,
            type: TextInputType.number,
            suggestion: false,
            onChanged: (_) => onFieldChanged(),
          )
        else
          Input(
            controller: timeoutCtrl,
            label: '${l10n.uptimerTimeout} (ms)',
            hint: '10000',
            icon: Icons.av_timer,
            type: TextInputType.number,
            suggestion: false,
            onChanged: (_) => onFieldChanged(),
          ),
      ],
    );
  }
}

/// Public visibility, active/paused toggle, and display URL section for
/// [UptimerEditPage].
final class UptimerBehaviourSection extends StatelessWidget {
  final bool isEditing;
  final bool saving;
  final bool showOnStatusPage;
  final ValueChanged<bool> onShowOnStatusPageChanged;
  final VoidCallback onToggleShowOnStatusPage;
  final bool isActive;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onToggleActive;
  final TextEditingController displayUrlCtrl;

  const UptimerBehaviourSection({
    super.key,
    required this.isEditing,
    required this.saving,
    required this.showOnStatusPage,
    required this.onShowOnStatusPageChanged,
    required this.onToggleShowOnStatusPage,
    required this.isActive,
    required this.onActiveChanged,
    required this.onToggleActive,
    required this.displayUrlCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupTitle(l10n.behaviour),
        ListTile(
          leading: const Icon(Icons.public),
          title: Text(l10n.uptimerPublic),
          trailing: SwitchX(
            value: showOnStatusPage,
            onChanged: onShowOnStatusPageChanged,
          ),
          onTap: onToggleShowOnStatusPage,
        ).cardx,
        if (isEditing)
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(l10n.uptimerActive),
            trailing: SwitchX(
              value: isActive,
              onChanged: saving ? null : onActiveChanged,
            ),
            onTap: saving ? null : onToggleActive,
          ).cardx,
        Input(
          controller: displayUrlCtrl,
          label: l10n.uptimerDisplayUrl,
          hint: 'https://status.example.com',
          icon: Icons.open_in_new,
          autoCorrect: false,
          suggestion: false,
          type: TextInputType.url,
        ),
      ],
    );
  }
}
