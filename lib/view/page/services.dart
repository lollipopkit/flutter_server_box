import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/provider/services.dart';
import 'package:server_box/view/page/service_detail.dart';

/// Below this the columns leave a unit's name nothing to be read in, and each
/// unit becomes a two-line row.
const _kTableWidth = 780.0;

/// From here a selected unit opens beside the list rather than over it.
const _kSplitWidth = 960.0;
const _kPaneWidth = 440.0;

const _kPad = 13.0;
const _kGap = 13.0;
const _kColType = 76.0;
const _kColScope = 76.0;
const _kColStartup = 92.0;
const _kColMemory = 84.0;
const _kColTime = 100.0;
const _kColActions = 88.0;

/// The counts across the top, each also a filter. Disabled is about startup,
/// not state, which is why it is a filter of its own and not a state.
enum _StatusFilter { failed, running, inactive, disabled }

final class ServicesPage extends ConsumerStatefulWidget {
  const ServicesPage({super.key, required this.args});

  final SpiRequiredArgs args;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: ServicesPage.new,
    path: '/services',
  );

  @override
  ConsumerState<ServicesPage> createState() => _ServicesPageState();
}

final class _ServicesPageState extends ConsumerState<ServicesPage> {
  late final _pro = servicesProvider(widget.args.spi);
  late final _notifier = ref.read(_pro.notifier);
  final _searchCtrl = TextEditingController();

  String _query = '';
  _StatusFilter? _statusFilter;

  /// The unit open in the pane. Only read while the page is wide enough for
  /// one; below that a unit opens as a page of its own.
  String? _selected;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _rebuild(VoidCallback update) {
    if (mounted) setState(update);
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(_pro.select((pro) => pro.manager));
    final isBusy = ref.watch(_pro.select((pro) => pro.isBusy));
    return Scaffold(
      appBar: CustomAppBar(
        centerTitle: true,
        title: TwoLineText(
          up: l10n.services,
          down: [widget.args.spi.name, ?manager?.displayName].join(' · '),
        ),
        actions: [
          if (isBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 11),
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Btn.icon(
              text: libL10n.refresh,
              icon: const Icon(Icons.refresh, size: 18),
              onTap: _refresh,
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final split = constraints.maxWidth >= _kSplitWidth;
          final selected = split && _selected != null
              ? _notifier.unitFor(_selected!)
              : null;
          // Beside an open unit the list only selects, whatever width it
          // has left: the columns would repeat what the pane shows.
          final list = _buildBody(
            table: selected == null && constraints.maxWidth >= _kTableWidth,
            split: split,
          );
          if (selected == null) return list;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: list),
              VerticalDivider(width: 1, color: Hairline.color(context)),
              SizedBox(
                width: _kPaneWidth,
                child: ServiceDetailView(
                  key: ValueKey(selected.key),
                  spi: widget.args.spi,
                  unitKey: selected.key,
                  onClose: () => _rebuild(() => _selected = null),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- Widget builders ---

extension on _ServicesPageState {
  Widget _buildBody({required bool table, required bool split}) {
    final failure = ref.watch(_pro.select((pro) => pro.failure));
    final isBusy = ref.watch(_pro.select((pro) => pro.isBusy));
    if (failure != null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: isBusy ? UIs.centerLoading : _buildFailure(failure),
            ),
          ],
        ),
      );
    }

    final manager = ref.watch(_pro.select((pro) => pro.manager));
    final units = ref.watch(_pro.select((pro) => pro.units));
    ref.watch(_pro.select((pro) => pro.scopeFilter));
    final notice = ref.watch(
      _pro.select((pro) => (pro.notice, pro.noticeDetail)),
    );
    final scoped = _notifier.filteredUnits;
    final visible = _visible(scoped);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(scoped, manager: manager, table: table),
        if (notice.$1 case final value?) _buildNotice(value, notice.$2),
        Divider(height: 1, color: Hairline.color(context)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: units.isEmpty && isBusy
                ? const Center(child: UIs.centerLoading)
                : _buildList(
                    visible,
                    table: table,
                    split: split,
                    showScope: manager?.supportsUserScope == true,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailure(ServiceFailure failure) {
    final (title, explain) = switch (failure.issue) {
      ServiceIssue.unsupported => (
        l10n.serviceManagerUnsupported,
        [
          l10n.serviceManagerUnsupportedTip,
          if (failure.detectedManager case final manager?)
            l10n.serviceManagerFmt(manager),
        ].join(' '),
      ),
      ServiceIssue.listFailed => (l10n.serviceListFailed, null),
      ServiceIssue.unreachable => (l10n.serverUnreachable, null),
    };
    return PageIssueView(
      title: title,
      explain: explain,
      detail: failure.detail,
      icon: failure.issue == ServiceIssue.unsupported
          ? Icons.help_outline
          : Icons.error_outline,
      onRetry: _refresh,
    );
  }

  Widget _buildNotice(ServiceListingNotice notice, String? detail) {
    final (title, explain) = switch (notice) {
      ServiceListingNotice.userScopeUnavailable => (
        l10n.systemdUserScopeMissing,
        l10n.systemdUserScopeMissingTip,
      ),
      ServiceListingNotice.detailsUnavailable => (
        l10n.serviceDetailsUnavailable,
        l10n.serviceDetailsUnavailableTip,
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 15),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TipText(title, explain),
              if (detail != null && detail.isNotEmpty)
                Text(detail, style: UIs.text11Grey),
            ],
          ),
        ),
      ],
    ).paddingSymmetric(horizontal: 17, vertical: 4);
  }

  /// The counts that say whether anything is wrong, which are also the way to
  /// narrow the list to it; then the scope; then search. On a narrow column
  /// search takes a line of its own, and the counts drop their words for
  /// everything but "failed", which is the one worth reading.
  Widget _buildToolbar(
    List<ServiceUnit> units, {
    required ServiceManagerType? manager,
    required bool table,
  }) {
    int count(_StatusFilter filter) => units.where(_matcher(filter)).length;
    final failed = count(_StatusFilter.failed);
    final chips = <Widget>[
      if (failed > 0 || _statusFilter == _StatusFilter.failed)
        _statusChip(_StatusFilter.failed, '$failed failed', failed > 0),
      _statusChip(
        _StatusFilter.running,
        table
            ? '${count(_StatusFilter.running)} running'
            : '${count(_StatusFilter.running)}',
        false,
      ),
      _statusChip(
        _StatusFilter.inactive,
        table
            ? '${count(_StatusFilter.inactive)} inactive'
            : '${count(_StatusFilter.inactive)}',
        false,
      ),
      if (table && count(_StatusFilter.disabled) > 0)
        _statusChip(
          _StatusFilter.disabled,
          '${count(_StatusFilter.disabled)} disabled',
          false,
        ),
    ];
    final scope = manager?.supportsUserScope == true
        ? SegmentedTabs<ServiceScopeFilter>(
            segments: [
              for (final filter in ServiceScopeFilter.values)
                SegmentedTab(value: filter, label: filter.displayName),
            ],
            selected: ref.watch(_pro.select((p) => p.scopeFilter)),
            onSelected: _notifier.setScopeFilter,
          )
        : null;
    final row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips) ...[chip, const SizedBox(width: 7)],
          if (scope != null) ...[
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: Hairline.color(context),
            ),
            scope,
          ],
        ],
      ),
    );

    if (table) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kPad, vertical: 9),
        child: Row(
          children: [
            Expanded(child: row),
            const SizedBox(width: 13),
            SizedBox(width: 240, child: _buildSearchPill()),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kPad, 7, _kPad, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_buildSearchPill(), const SizedBox(height: 9), row],
      ),
    );
  }

  Widget _statusChip(_StatusFilter filter, String label, bool alarming) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _statusFilter == filter;
    final dot = switch (filter) {
      _StatusFilter.failed => ServiceUi.failed,
      _StatusFilter.running => ServiceUi.running,
      _StatusFilter.inactive => ServiceUi.idle,
      _StatusFilter.disabled => null,
    };
    final Color background;
    final BorderSide border;
    if (selected) {
      background = scheme.primaryContainer;
      border = BorderSide.none;
    } else if (alarming) {
      background = ServiceUi.failed.withValues(alpha: 0.12);
      border = BorderSide(color: ServiceUi.failed.withValues(alpha: 0.5));
    } else {
      background = Colors.transparent;
      border = BorderSide(color: scheme.outlineVariant);
    }
    return Material(
      color: background,
      shape: StadiumBorder(side: border),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _rebuild(
          () => _statusFilter = selected ? null : filter,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w500 : null,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPill() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.only(left: 11, right: 4),
      child: Row(
        children: [
          Icon(Icons.search, size: 17, color: UIs.textGrey.color),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) => _rebuild(() => _query = value),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration.collapsed(
                hintText: context.l10n.serviceSearchHint,
                hintStyle: TextStyle(fontSize: 13, color: UIs.textGrey.color),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            Btn.icon(
              text: libL10n.clear,
              icon: const Icon(Icons.close, size: 16),
              onTap: () => _rebuild(() {
                _searchCtrl.clear();
                _query = '';
              }),
            ),
        ],
      ),
    );
  }

  /// Failed and transitioning units first, under a heading of their own, with
  /// everything else below. Once a count has been picked as a filter the list
  /// already is what that heading would say, and it goes.
  Widget _buildList(
    List<ServiceUnit> units, {
    required bool table,
    required bool split,
    required bool showScope,
  }) {
    if (units.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [CenterGreyTitle(libL10n.empty).paddingOnly(top: 80)],
      );
    }
    final grouped = _statusFilter == null;
    final attention = grouped
        ? units.where((u) => u.state.needsAttention).toList()
        : const <ServiceUnit>[];
    final rest = grouped
        ? units.where((u) => !u.state.needsAttention).toList()
        : units;
    final scheme = Theme.of(context).colorScheme;

    Widget row(ServiceUnit unit, {required bool attention}) {
      if (table) {
        return _buildTableRow(unit, attention: attention, showScope: showScope);
      }
      if (attention && unit.state == ServiceState.failed && !split) {
        return _buildFailedCard(unit);
      }
      return _buildStackedRow(unit, attention: attention, split: split);
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (table)
          SliverToBoxAdapter(child: _buildColumnHeader(showScope: showScope)),
        if (attention.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionHeader(
              context.l10n.serviceNeedsAttention,
              color: scheme.error,
              background: scheme.error.withValues(alpha: 0.08),
            ),
          ),
          SliverList.builder(
            itemCount: attention.length,
            itemBuilder: (_, i) => row(attention[i], attention: true),
          ),
          if (rest.isNotEmpty && !table)
            SliverToBoxAdapter(
              child: _sectionHeader(
                context.l10n.serviceOtherUnits(rest.length),
                color: scheme.onSurfaceVariant,
                background: scheme.surfaceContainerLow,
              ),
            ),
        ],
        SliverList.builder(
          itemCount: rest.length,
          itemBuilder: (_, i) => row(rest[i], attention: false),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _sectionHeader(
    String title, {
    required Color color,
    required Color background,
  }) {
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(_kPad, 9, _kPad, 7),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _tableLine({
    required Widget dot,
    required Widget name,
    required Widget type,
    required Widget scope,
    required Widget startup,
    required Widget memory,
    required Widget time,
    required Widget actions,
    required bool showScope,
  }) {
    Widget fixed(double width, Widget child) => Padding(
      padding: const EdgeInsets.only(left: _kGap),
      child: SizedBox(width: width, child: child),
    );
    return Row(
      children: [
        SizedBox(width: 11, child: dot),
        const SizedBox(width: 11),
        Expanded(child: name),
        fixed(_kColType, type),
        if (showScope) fixed(_kColScope, scope),
        fixed(_kColStartup, startup),
        fixed(_kColMemory, memory),
        fixed(_kColTime, time),
        fixed(_kColActions, actions),
      ],
    );
  }

  Widget _buildColumnHeader({required bool showScope}) {
    final scheme = Theme.of(context).colorScheme;
    Widget label(String text) => Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.66,
        color: scheme.onSurfaceVariant,
      ),
    );
    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: _kPad, vertical: 8),
      child: _tableLine(
        showScope: showScope,
        dot: const SizedBox.shrink(),
        name: label(context.l10n.serviceUnit),
        type: label(context.l10n.serviceUnitType),
        scope: label(context.l10n.serviceScope),
        startup: label(context.l10n.serviceStartup),
        memory: label(libL10n.memory),
        time: label(libL10n.uptime),
        actions: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildTableRow(
    ServiceUnit unit, {
    required bool attention,
    required bool showScope,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final dim = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    const body = TextStyle(fontSize: 13);
    Widget cell(String text, {TextStyle style = body}) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
    final canRestart = unit.actions.contains(ServiceAction.restart);
    final startup = unit.startup;
    final time = ServiceUi.timeLabel(context, unit);

    return Hover(
      builder: (hovered) => _rowFrame(
        unit,
        attention: attention,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kPad, vertical: 5),
          child: _tableLine(
            showScope: showScope,
            dot: ServiceStatusDot(unit: unit),
            name: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _nameBlock(unit, attention: attention, fontSize: 14),
            ),
            type: cell(unit.type.name),
            scope: cell(ServiceUi.scopeLabel(unit.scope)),
            startup: cell(
              startup ?? '—',
              style: startup == 'enabled' ? body : dim,
            ),
            memory: cell(
              unit.memoryBytes == null ? '—' : unit.memoryBytes!.bytes2Str,
            ),
            time: cell(
              time ?? '—',
              style: unit.state == ServiceState.running ? body : dim,
            ),
            actions: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canRestart &&
                    (hovered || unit.state == ServiceState.failed))
                  Btn.icon(
                    text: ServiceAction.restart.displayName,
                    icon: Icon(
                      Icons.restart_alt,
                      size: 18,
                      color: scheme.primary,
                    ),
                    onTap: () => _run(unit, ServiceAction.restart),
                  ),
                ServiceUi.unitMenu(context, ref, widget.args.spi, unit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Name over a second line, for a column the table does not fit in.
  ///
  /// [split] is the list beside an open unit: there the row only selects, so
  /// it carries how long the unit has been as it is rather than a menu — the
  /// pane beside it has every action.
  Widget _buildStackedRow(
    ServiceUnit unit, {
    required bool attention,
    required bool split,
  }) {
    final time = ServiceUi.timeLabel(context, unit);
    // A unit that needs attention is tinted already; it does not also need
    // the room a 48pt menu button would give it.
    final compact = attention && !split;
    return _rowFrame(
      unit,
      attention: attention,
      selected: split && _selected == unit.key,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _kPad,
          compact ? 7 : 9,
          split ? _kPad : 4,
          compact ? 7 : 9,
        ),
        child: Row(
          children: [
            ServiceStatusDot(unit: unit),
            const SizedBox(width: 11),
            Expanded(
              child: _nameBlock(
                unit,
                attention: attention,
                fontSize: 14,
                subline: attention ? null : _summary(unit, withTime: !split),
              ),
            ),
            if (split && time != null) ...[
              const SizedBox(width: 9),
              Text(
                time,
                style: UIs.text12Grey.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ] else if (!split)
              Padding(
                padding: EdgeInsets.only(right: compact ? 4 : 0),
                child: ServiceUi.unitMenu(
                  context,
                  ref,
                  widget.args.spi,
                  unit,
                  compact: compact,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// A failed unit on a narrow column: why, and the two things one does about
  /// it — restart it, or read what it said.
  ///
  /// Kept as short as the lines in it allow. The menu sits outside the text
  /// column, top-aligned, so its tap area overlaps the padding instead of
  /// adding a row's worth of height to the name; the buttons are compact for
  /// the same reason, since a card this size is already the loudest thing in
  /// the list.
  Widget _buildFailedCard(ServiceUnit unit) {
    final scheme = Theme.of(context).colorScheme;
    final time = ServiceUi.timeLabel(context, unit);
    final canRestart = unit.actions.contains(ServiceAction.restart);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 11);
    const buttonSize = Size(0, 30);
    final buttonText = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontSize: 13);
    return _rowFrame(
      unit,
      attention: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_kPad, 7, 0, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ServiceStatusDot(unit: unit),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          unit.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    ServiceUi.problemLine(context, unit),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ServiceUi.failed,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _summary(unit, withTime: false),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UIs.text12Grey,
                        ),
                      ),
                      if (time != null) Text(time, style: UIs.text12Grey),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (canRestart) ...[
                        FilledButton.icon(
                          onPressed: () => _run(unit, ServiceAction.restart),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: buttonPadding,
                            minimumSize: buttonSize,
                            textStyle: buttonText,
                            iconSize: 15,
                          ),
                          icon: const Icon(Icons.restart_alt),
                          label: Text(ServiceAction.restart.displayName),
                        ),
                        const SizedBox(width: 7),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => _open(unit),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.onSurface,
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: buttonPadding,
                          minimumSize: buttonSize,
                          textStyle: buttonText,
                          iconSize: 15,
                        ),
                        icon: const Icon(Icons.receipt_long),
                        label: Text(libL10n.logs),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: ServiceUi.unitMenu(
              context,
              ref,
              widget.args.spi,
              unit,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }

  /// A row's tint and rule, and what tapping it does.
  Widget _rowFrame(
    ServiceUnit unit, {
    required bool attention,
    required Widget child,
    bool selected = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final tint = selected
        ? scheme.surfaceContainerHigh
        : attention
        ? ServiceUi.stateColor(unit.state).withValues(alpha: 0.08)
        : null;
    return Material(
      color: tint ?? Colors.transparent,
      child: InkWell(
        onTap: () => _open(unit),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Hairline.color(context))),
          ),
          child: child,
        ),
      ),
    );
  }

  /// The unit's name, and under it either [subline] or, for a unit that needs
  /// attention, why — in the colour of its state.
  Widget _nameBlock(
    ServiceUnit unit, {
    required bool attention,
    required double fontSize,
    String? subline,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final second = attention ? _problemWithTime(unit) : subline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          unit.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: fontSize,
            color: unit.state == ServiceState.stopped
                ? scheme.onSurfaceVariant
                : null,
          ),
        ),
        if (second != null && second.isNotEmpty)
          Text(
            second,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: attention
                  ? ServiceUi.stateColor(unit.state)
                  : UIs.textGrey.color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

// --- Utils ---

extension on _ServicesPageState {
  bool Function(ServiceUnit) _matcher(_StatusFilter filter) => switch (filter) {
    _StatusFilter.failed => (u) => u.state == ServiceState.failed,
    _StatusFilter.running => (u) => u.state == ServiceState.running,
    _StatusFilter.inactive => (u) => u.state == ServiceState.stopped,
    _StatusFilter.disabled => (u) => u.startup == 'disabled',
  };

  List<ServiceUnit> _visible(List<ServiceUnit> units) {
    final filter = _statusFilter;
    final needle = _query.trim().toLowerCase();
    return units
        .where((u) => filter == null || _matcher(filter)(u))
        .where(
          (u) =>
              needle.isEmpty ||
              u.fullName.toLowerCase().contains(needle) ||
              (u.description?.toLowerCase().contains(needle) ?? false),
        )
        .toList(growable: false);
  }

  /// `failed · exit-code · exit status 1`, and for a unit on its way somewhere
  /// how long it has been: `activating · start-pre · 4 s`.
  String _problemWithTime(ServiceUnit unit) {
    final line = ServiceUi.problemLine(context, unit);
    if (unit.state == ServiceState.failed) return line;
    final time = ServiceUi.timeLabel(context, unit);
    return time == null ? line : '$line · $time';
  }

  /// What is worth knowing at a glance, and nothing a unit shares with every
  /// other: `enabled · 494 MB · up 31 d`, `socket · User · up 31 d`.
  String _summary(ServiceUnit unit, {required bool withTime}) {
    final startup = unit.startup;
    return {
      if (unit.type != ServiceUnitType.service) unit.type.name,
      if (unit.state == ServiceState.stopped && unit.since != null) 'inactive',
      if (startup != null && startup != 'transient') startup,
      if (unit.scope == ServiceScope.user) ServiceUi.scopeLabel(unit.scope),
      if (unit.memoryBytes case final bytes?) bytes.bytes2Str,
      if (withTime) ?ServiceUi.timeLabel(context, unit),
    }.join(' · ');
  }
}

// --- Actions ---

extension on _ServicesPageState {
  Future<void> _refresh() => _notifier.getServices();

  /// Beside the list where the page is wide enough, as a page of its own
  /// where it is not.
  void _open(ServiceUnit unit) {
    final width = MediaQuery.sizeOf(context).width;
    final box = context.findRenderObject() as RenderBox?;
    final pageWidth = box?.hasSize == true ? box!.size.width : width;
    if (pageWidth >= _kSplitWidth) {
      _rebuild(() => _selected = unit.key);
      return;
    }
    ServiceDetailPage.route.go(
      context,
      ServiceDetailPageArgs(spi: widget.args.spi, unitKey: unit.key),
    );
  }

  Future<void> _run(ServiceUnit unit, ServiceAction action) =>
      ServiceUi.runAction(context, ref, widget.args.spi, unit, action);
}
