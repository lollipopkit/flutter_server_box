import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/cron.dart';
import 'package:server_box/data/model/server/cron_schedule.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/service/cron_manager.dart';

/// From here a task is one line — what it does, the command, and when it next
/// runs, side by side — and adding one is a button in the toolbar rather than
/// a floating one over the list.
const _kWideWidth = 720.0;

const _kPad = 13.0;

/// How often the page redraws so that "in 4 minutes" stays true. Nothing is
/// fetched; the next run is worked out here.
const _kTick = Duration(seconds: 30);

enum _ScheduledTaskAction { edit, delete }

typedef _TaskEdit = ({String schedule, String command, bool enabled});

/// A task with everything the list shows worked out once: what its schedule
/// says in words, and when the server next runs it.
typedef _Task = ({CronJob job, CronSchedule? schedule, DateTime? nextWall});

final class ScheduledTasksPage extends ConsumerStatefulWidget {
  const ScheduledTasksPage({super.key, required this.args});

  final SpiRequiredArgs args;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: ScheduledTasksPage.new,
    path: '/scheduled-tasks',
  );

  @override
  ConsumerState<ScheduledTasksPage> createState() => _ScheduledTasksPageState();
}

final class _ScheduledTasksPageState extends ConsumerState<ScheduledTasksPage> {
  late final _provider = serverProvider(widget.args.spi.id);
  final _searchCtrl = TextEditingController();

  CronCatalog? _catalog;
  bool _busy = false;
  bool _unsupported = false;
  bool _unavailable = false;
  String? _failure;
  String _query = '';
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
    _ticker = Timer.periodic(_kTick, (_) {
      if (mounted && _catalog != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _rebuild(VoidCallback update) {
    if (mounted) setState(update);
  }

  @override
  Widget build(BuildContext context) {
    final system = ref.watch(_provider.select((state) => state.status.system));
    final supported = system == SystemType.linux;
    final catalog = _catalog;
    final canMutate =
        supported &&
        !_unsupported &&
        !_unavailable &&
        _failure == null &&
        catalog != null;
    final wide = MediaQuery.sizeOf(context).width >= _kWideWidth;

    return Scaffold(
      appBar: CustomAppBar(
        centerTitle: true,
        title: TwoLineText(up: l10n.scheduledTasks, down: widget.args.spi.name),
        actions: [
          if (catalog != null)
            Btn.icon(
              text: l10n.scheduledTaskRaw,
              icon: const Icon(Icons.code, size: 18),
              onTap: () => _showRaw(catalog),
            ),
          if (_busy)
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
      body: _buildBody(wide: wide),
      floatingActionButton: canMutate && !wide
          ? FloatingActionButton(
              tooltip: l10n.scheduledTaskAdd,
              onPressed: _busy ? null : () => _editTask(),
              child: const Icon(Icons.add_alarm),
            )
          : null,
    );
  }
}

// --- Widget builders ---

extension on _ScheduledTasksPageState {
  Widget _buildBody({required bool wide}) {
    if (_unsupported) {
      return _issueBody(
        title: libL10n.unsupported,
        explain: l10n.scheduledTaskLinuxOnly,
        icon: Icons.not_interested,
      );
    }
    if (_unavailable) {
      return _issueBody(
        title: libL10n.unsupported,
        explain: l10n.scheduledTaskUnavailable,
        detail: _failure,
        icon: Icons.timer_off_outlined,
      );
    }
    if (_failure case final failure?) {
      return _issueBody(
        title: libL10n.fail,
        detail: failure,
        icon: Icons.error_outline,
      );
    }
    final catalog = _catalog;
    if (catalog == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 280, child: UIs.centerLoading)],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(catalog, wide: wide),
        if (_busy)
          const LinearProgressIndicator(minHeight: 2)
        else
          Divider(height: 2, color: Hairline.color(context)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: _buildList(catalog, wide: wide),
          ),
        ),
      ],
    );
  }

  Widget _issueBody({
    required String title,
    required IconData icon,
    String? explain,
    String? detail,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: PageIssueView(
            title: title,
            explain: explain,
            detail: detail,
            icon: icon,
            onRetry: _refresh,
          ),
        ),
      ],
    );
  }

  /// Whose crontab this is, how much is in it, and the two ways to narrow it
  /// or add to it. The user is first because it is what every line here
  /// belongs to: a crontab is per account, and the page shows one account's.
  Widget _buildToolbar(CronCatalog catalog, {required bool wide}) {
    final jobs = catalog.document.jobs;
    final enabledCount = jobs.where((job) => job.enabled).length;
    // An account name is as long as someone made it and a translated summary
    // as long as the language makes it, so both give way rather than either
    // pushing the row past the window.
    final summary = Text(
      // Alphabetical, not the order the sentence reads: with no placeholder
      // declared in the ARB, that is the order gen-l10n emits, and both of
      // these are an `Object` the compiler will not tell apart.
      l10n.scheduledTaskSummaryFmt(enabledCount, jobs.length),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: UIs.text12Grey.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    if (!wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(_kPad, 9, _kPad, 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: _buildUserChip(catalog.user)),
            const SizedBox(width: 9),
            Flexible(child: summary),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(_kPad, 9, _kPad, 9),
      child: Row(
        children: [
          // The chip and the filter are one group inside a tight box, so what
          // the chip does not use becomes the gap before the summary instead
          // of slack at the end of the row, which would hold the button off
          // the right edge.
          Expanded(
            child: Row(
              children: [
                Flexible(child: _buildUserChip(catalog.user)),
                const SizedBox(width: 9),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: _buildFilterPill(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: summary,
          ),
          const SizedBox(width: 11),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _editTask(),
            icon: const Icon(Icons.add_alarm, size: 18),
            label: Text(l10n.scheduledTaskAdd),
          ),
        ],
      ),
    );
  }

  Widget _buildUserChip(String user) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              user,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 34,
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
                hintText: l10n.scheduledTaskFilterHint,
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

  /// The enabled tasks, then the disabled ones, each under a count.
  ///
  /// The split is the page's whole shape: a disabled line is a comment in the
  /// file and runs never, so putting it in one list with the rest would make
  /// "when does this run" a per-row question.
  Widget _buildList(CronCatalog catalog, {required bool wide}) {
    final clock = catalog.clock ?? CronClock.device;
    final nowWall = clock.nowWall();
    final all = [
      for (final job in catalog.document.jobs)
        () {
          final schedule = job.parsed;
          return (
            job: job,
            schedule: schedule,
            nextWall: job.enabled ? schedule?.nextRun(nowWall) : null,
          );
        }(),
    ];

    if (catalog.document.jobs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: EmptyMark(
              icon: Icons.alarm_off,
              label: l10n.scheduledTaskEmptyFmt(catalog.user),
              action: Btn.text(
                text: l10n.scheduledTaskAdd,
                onTap: _busy ? null : () => _editTask(),
              ),
            ),
          ),
        ],
      );
    }

    // A filter narrows the page to tasks that match it. The banner and the
    // preserved lines are about the whole file and would answer a question
    // nobody asked — the banner worst of all, since the task it names may be
    // one the filter has just taken off the page.
    final filtering = _query.trim().isNotEmpty;
    final shown = filtering
        ? all.where((task) => _matches(task.job)).toList()
        : all;
    final enabled = shown.where((task) => task.job.enabled).toList();
    final disabled = shown.where((task) => !task.job.enabled).toList();
    final next = filtering
        ? null
        : _nextTask(all.where((task) => task.job.enabled).toList());
    final preserved = filtering
        ? const <String>[]
        : catalog.document.preserved;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (shown.isEmpty)
          SliverToBoxAdapter(
            child: CenterGreyTitle(libL10n.empty).paddingOnly(top: 80),
          ),
        if (next != null)
          SliverToBoxAdapter(
            child: _buildNextRun(next, clock: clock, wide: wide),
          ),
        if (enabled.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionHeader(l10n.scheduledTaskEnabled, enabled.length),
          ),
          SliverList.builder(
            itemCount: enabled.length,
            itemBuilder: (_, i) =>
                _buildTask(enabled[i], clock: clock, wide: wide),
          ),
        ],
        if (disabled.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionHeader(libL10n.disabled, disabled.length),
          ),
          SliverList.builder(
            itemCount: disabled.length,
            itemBuilder: (_, i) =>
                _buildTask(disabled[i], clock: clock, wide: wide),
          ),
        ],
        if (preserved.isNotEmpty)
          SliverToBoxAdapter(child: _buildPreserved(preserved)),
        // Room for the floating button, which is over the end of the list.
        SliverToBoxAdapter(child: SizedBox(height: wide ? 26 : 90)),
      ],
    );
  }

  Widget _sectionHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kPad + 4, 17, _kPad + 4, 7),
      child: Row(
        children: [
          Text(
            '${label.toUpperCase()} · $count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.88,
              color: UIs.textGrey.color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(child: Divider(height: 1, color: Hairline.color(context))),
        ],
      ),
    );
  }

  /// The one thing about a crontab that cannot be read off the file: which of
  /// its lines the server runs next, and how long from now.
  Widget _buildNextRun(
    _Task task, {
    required CronClock clock,
    required bool wide,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final relative = _relativeLabel(task.nextWall!, clock: clock);
    final at = _clockLabel(task.nextWall!, clock.nowWall());
    final expr = Text(
      task.job.schedule,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: scheme.onSurfaceVariant,
      ),
    );
    // Capped so that the rest of the banner keeps a column to be read in: how
    // long "in 2 hours · Sun 04:30" is depends on the language, and on a phone
    // it is the half that can afford to lose a word.
    final when = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: Text(
        '$relative · $at',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: scheme.primary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    final Widget body;
    if (wide) {
      body = Row(
        children: [
          Icon(Icons.alarm, size: 20, color: scheme.primary),
          const SizedBox(width: 11),
          Text(l10n.scheduledTaskNextRun, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 11),
          Container(width: 1, height: 15, color: Hairline.color(context)),
          const SizedBox(width: 11),
          // Capped rather than given a share of the row. A `Flexible` that
          // renders narrower than its share leaves the difference as slack at
          // the end of the row, which is what held the next run off the edge.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: expr,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              task.job.command,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UIs.text12Grey,
            ),
          ),
          const SizedBox(width: 9),
          when,
        ],
      );
    } else {
      body = Row(
        children: [
          Icon(Icons.alarm, size: 20, color: scheme.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.scheduledTaskNextRun, style: UIs.text12Grey),
                Text(
                  '${task.job.schedule} · ${task.job.command}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          when,
        ],
      );
    }

    return CardX(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: body,
      ),
    ).paddingOnly(left: _kPad, right: _kPad, top: 11);
  }

  Widget _buildTask(_Task task, {required CronClock clock, required bool wide}) {
    return CardX(
      child: InkWell(
        onTap: _busy ? null : () => _editTask(task.job),
        child: wide
            ? _buildWideTask(task, clock: clock)
            : _buildNarrowTask(task, clock: clock),
      ),
    ).paddingSymmetric(horizontal: _kPad);
  }

  Widget _buildWideTask(_Task task, {required CronClock clock}) {
    final job = task.job;
    final title = _title(task);
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 7, 9, 7),
      child: Row(
        children: [
          _buildSwitch(job),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: job.enabled ? null : UIs.textGrey.color,
                        ),
                      ),
                    ),
                    if (title != job.schedule) ...[
                      const SizedBox(width: 9),
                      Flexible(child: _buildExprChip(job)),
                    ],
                    if (!job.enabled) ...[
                      const SizedBox(width: 7),
                      _buildCommentedTag(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                _buildCommand(job),
              ],
            ),
          ),
          const SizedBox(width: 11),
          SizedBox(width: 128, child: _buildWhen(task, clock: clock)),
          // The menu is three dots at the end of a line that ends in an
          // ellipsis of its own; without a gap the two read as one.
          const SizedBox(width: 11),
          _buildMenu(job),
        ],
      ),
    );
  }

  Widget _buildNarrowTask(_Task task, {required CronClock clock}) {
    final job = task.job;
    final title = _title(task);
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 5, 9, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: job.enabled ? null : UIs.textGrey.color,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              _buildSwitch(job),
              const SizedBox(width: 7),
              _buildMenu(job),
            ],
          ),
          _buildCommand(job),
          const SizedBox(height: 7),
          // Both halves give way rather than one pushing the other off the
          // card: an expression is as long as someone wrote it, and a next run
          // in words is as long as the language makes it.
          // What the line says on the left, when it next runs on the right,
          // and the space between them. Two groups and `spaceBetween`, not
          // four children and a flex share: a `Flexible` narrower than its
          // share leaves the difference as slack at the end of the row, which
          // holds the right-hand value off the edge.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != job.schedule)
                      Flexible(child: _buildExprChip(job)),
                    if (!job.enabled) ...[
                      const SizedBox(width: 7),
                      Flexible(child: _buildCommentedTag()),
                    ],
                  ],
                ),
              ),
              if (task.nextWall != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 9),
                    child: Text(
                      '${_relativeLabel(task.nextWall!, clock: clock)} · '
                      '${_clockLabel(task.nextWall!, clock.nowWall())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(CronJob job) {
    return Switch(
      value: job.enabled,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: _busy ? null : (enabled) => _setTaskEnabled(job, enabled),
    );
  }

  Widget _buildMenu(CronJob job) {
    return PopupMenu<_ScheduledTaskAction>(
      // A save is one write of the whole file, and [_save] refuses a second
      // one while it is in flight: left on, this would take an edit through
      // the whole sheet and then drop it without saying so.
      enabled: !_busy,
      items: [
        PopupMenuItem(
          value: _ScheduledTaskAction.edit,
          child: Text(libL10n.edit),
        ),
        PopupMenuItem(
          value: _ScheduledTaskAction.delete,
          child: Text(libL10n.delete),
        ),
      ],
      onSelected: (action) => switch (action) {
        _ScheduledTaskAction.edit => _editTask(job),
        _ScheduledTaskAction.delete => _deleteTask(job),
      },
      child: const Icon(Icons.more_horiz, size: 18),
    );
  }

  Widget _buildCommand(CronJob job) {
    final scheme = Theme.of(context).colorScheme;
    final color = job.enabled ? scheme.onSurfaceVariant : UIs.textGrey.color;
    return Row(
      children: [
        Text(
          r'$',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: UIs.textGrey.color,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            job.command,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// The expression itself, beside what it means. It is what the file says and
  /// what another tool will show, so the page never hides it — except when the
  /// title already is it, which is what an unreadable line falls back to.
  Widget _buildExprChip(CronJob job) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: job.enabled
            ? scheme.surfaceContainerHighest
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(7),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      child: Text(
        job.schedule,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: job.enabled ? scheme.onSurfaceVariant : UIs.textGrey.color,
        ),
      ),
    );
  }

  Widget _buildCommentedTag() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(7),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      child: Text(l10n.scheduledTaskCommentedOut, style: UIs.text11Grey),
    );
  }

  Widget _buildWhen(_Task task, {required CronClock clock}) {
    final next = task.nextWall;
    if (next == null) {
      return Text('—', textAlign: TextAlign.right, style: UIs.text13Grey);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _relativeLabel(next, clock: clock),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          _clockLabel(next, clock.nowWall()),
          maxLines: 1,
          style: UIs.text11Grey.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// What is in the crontab that this page does not manage.
  ///
  /// Folded away, because it is not a list of things to do anything to — it is
  /// there so that a crontab written by someone else does not look like this
  /// app lost half of it on the first save.
  Widget _buildPreserved(List<String> lines) {
    return CardX(
      child: ExpandTile(
        leading: Icon(Icons.notes, size: 18, color: UIs.textGrey.color),
        title: Text(
          l10n.scheduledTaskPreserved,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          '${lines.length} · ${l10n.scheduledTaskPreserveTip}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: UIs.text12Grey,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(17, 0, 17, 13),
        children: [
          SelectableText(
            lines.join('\n'),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: UIs.textGrey.color,
            ),
          ),
        ],
      ),
    ).paddingOnly(left: _kPad, right: _kPad, top: 17);
  }
}

// --- Actions ---

extension on _ScheduledTasksPageState {
  Future<void> _refresh() async {
    if (!mounted || _busy) return;
    final system = ref.read(_provider).status.system;
    if (system != SystemType.linux) {
      _rebuild(() {
        _unsupported = true;
        _unavailable = false;
        _failure = null;
        _catalog = null;
      });
      return;
    }

    _rebuild(() {
      _busy = true;
      _unsupported = false;
      _unavailable = false;
      _failure = null;
    });
    try {
      final exec = await ref.read(_provider.notifier).ensureExec();
      final catalog = await CronManager.list(exec);
      if (!mounted) return;
      _rebuild(() => _catalog = catalog);
    } on CronManagerException catch (e, s) {
      Loggers.app.warning('List cron tasks for ${widget.args.spi.id}', e, s);
      if (!mounted) return;
      _rebuild(() {
        _unavailable = e.unavailable;
        _failure = e.message;
      });
    } catch (e, s) {
      Loggers.app.warning('List cron tasks for ${widget.args.spi.id}', e, s);
      if (mounted) _rebuild(() => _failure = '$e');
    } finally {
      if (mounted) _rebuild(() => _busy = false);
    }
  }

  Future<void> _editTask([CronJob? task]) async {
    final catalog = _catalog;
    if (catalog == null) return;
    final edit = await _showEditor(catalog, task);
    if (edit == null || !mounted) return;
    final document = catalog.document.upsert(
      original: task,
      schedule: edit.schedule,
      command: edit.command,
      enabled: edit.enabled,
    );
    await _save(document);
  }

  Future<void> _setTaskEnabled(CronJob task, bool enabled) async {
    final catalog = _catalog;
    if (catalog == null) return;
    await _save(catalog.document.setEnabled(task, enabled));
  }

  Future<void> _deleteTask(CronJob task) async {
    final catalog = _catalog;
    if (catalog == null) return;
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(
        libL10n.delFmt(
          l10n.scheduledTasks,
          '${task.schedule} ${task.command}',
        ),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (confirmed != true || !mounted) return;
    await _save(catalog.document.remove(task));
  }

  Future<void> _save(CronDocument document) async {
    final catalog = _catalog;
    if (catalog == null || _busy) return;
    _rebuild(() => _busy = true);
    try {
      final exec = await ref.read(_provider.notifier).ensureExec();
      await CronManager.save(exec, document);
      if (!mounted) return;
      _rebuild(() {
        _catalog = CronCatalog(
          user: catalog.user,
          document: document,
          clock: catalog.clock,
        );
      });
      Toast.success(libL10n.saved);
    } catch (e, s) {
      Loggers.app.warning('Save cron tasks for ${widget.args.spi.id}', e, s);
      if (mounted) Toast.error(libL10n.saveFailed, body: '$e');
    } finally {
      if (mounted) _rebuild(() => _busy = false);
    }
  }

  /// The file as crond will read it, including the lines this page does not
  /// manage. Read only: every way of changing it is on the page behind it, and
  /// a text box over a running crontab is one paste away from losing all of it.
  Future<void> _showRaw(CronCatalog catalog) async {
    final raw = catalog.document.render();
    final scheme = Theme.of(context).colorScheme;
    await context.showRoundDialog(
      title: l10n.scheduledTaskRaw,
      child: SizedBox(
        // The dialog is as wide as it is allowed to be, which on a phone is
        // the phone: a fixed width would be one that does not fit.
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            maxWidth: 620,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(13),
            ),
            padding: const EdgeInsets.all(11),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  raw.isEmpty ? '#' : raw.trimRight(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [Btn.ok()],
    );
  }

  /// A sheet at every width, capped rather than stretched.
  ///
  /// It is one form with a keyboard in front of it, which is what a sheet is
  /// for; a dialog on a desktop and a sheet on a phone made the same form two
  /// things, and gave the fields a surface the same colour as themselves.
  Future<_TaskEdit?> _showEditor(CronCatalog catalog, CronJob? task) {
    return showModalBottomSheet<_TaskEdit>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 580),
      builder: (_) => _TaskEditor(
        job: task,
        clock: catalog.clock ?? CronClock.device,
      ),
    );
  }
}

// --- Utils ---

extension on _ScheduledTasksPageState {
  bool _matches(CronJob job) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return job.command.toLowerCase().contains(query) ||
        job.schedule.toLowerCase().contains(query) ||
        (job.parsed?.describe()?.toLowerCase().contains(query) ?? false);
  }

  /// The enabled task the server reaches first. `@reboot` has no next time, so
  /// it is never the answer even though it is enabled.
  _Task? _nextTask(List<_Task> enabled) {
    _Task? soonest;
    for (final task in enabled) {
      final next = task.nextWall;
      if (next == null) continue;
      if (soonest == null || next.isBefore(soonest.nextWall!)) soonest = task;
    }
    return soonest;
  }

  String _title(_Task task) => task.schedule?.describe() ?? task.job.schedule;
}

/// How long from now, in the server's clock rather than this device's.
String _relativeLabel(DateTime wall, {required CronClock clock}) {
  final left = clock.toInstant(wall).difference(clock.nowInstant());
  return l10n.scheduledTaskNextInFmt(left.toAgoStr);
}

/// The time on the server's own clock, with the day when it is not today.
String _clockLabel(DateTime wall, DateTime nowWall) {
  final at =
      '${wall.hour.toString().padLeft(2, '0')}:'
      '${wall.minute.toString().padLeft(2, '0')}';
  final days = DateTime.utc(wall.year, wall.month, wall.day)
      .difference(DateTime.utc(nowWall.year, nowWall.month, nowWall.day))
      .inDays;
  if (days <= 0) return at;
  if (days < 7) return '${DateFormat.E(l10n.localeName).format(wall)} $at';
  return '${DateFormat.MMMd(l10n.localeName).format(wall)} $at';
}

/// Adding a task, or changing one.
///
/// The five fields are five boxes rather than one line of text because that is
/// what a cron expression is, and because the box a value goes in is the only
/// thing that says which field it is. Pasting a whole expression into any of
/// them spreads it across the rest.
final class _TaskEditor extends StatefulWidget {
  const _TaskEditor({required this.job, required this.clock});

  final CronJob? job;
  final CronClock clock;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

final class _TaskEditorState extends State<_TaskEditor> {
  /// What the presets offer, in the order the list reads: the boot macro, then
  /// from most often to least. Each is labelled by what it means, so there is
  /// nothing to translate that the list itself does not translate.
  static const _presets = [
    '@reboot',
    '*/5 * * * *',
    '0 * * * *',
    '0 2 * * *',
    '30 4 * * 0',
    '0 0 1 * *',
  ];

  static const _fieldCount = 5;

  late final _commandCtrl = TextEditingController(text: widget.job?.command);
  late final List<TextEditingController> _fieldCtrls;

  /// Non-null when the schedule is one of crond's macros, which is a whole
  /// expression and not five fields.
  String? _macro;

  late bool _enabled = widget.job?.enabled ?? true;

  @override
  void initState() {
    super.initState();
    final schedule = widget.job?.schedule.trim() ?? '0 2 * * *';
    final fields = schedule.startsWith('@')
        ? const ['0', '2', '*', '*', '*']
        : schedule.split(RegExp(r'\s+'));
    _macro = schedule.startsWith('@') ? schedule : null;
    _fieldCtrls = List.generate(
      _fieldCount,
      (i) => TextEditingController(text: i < fields.length ? fields[i] : '*'),
    );
  }

  @override
  void dispose() {
    _commandCtrl.dispose();
    for (final ctrl in _fieldCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String get _expression =>
      _macro ?? _fieldCtrls.map((ctrl) => ctrl.text.trim()).join(' ');

  @override
  Widget build(BuildContext context) {
    final expression = _expression;
    final schedule = CronSchedule.tryParse(expression);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Which crontab this is goes without saying: the page behind the sheet
        // carries the account it belongs to.
        Text(
          widget.job == null ? l10n.scheduledTaskAdd : libL10n.edit,
          style: const TextStyle(fontSize: 21),
        ),
        const SizedBox(height: 13),
        _label(l10n.scheduledTaskSchedule),
        const SizedBox(height: 7),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final preset in _presets) _buildPreset(preset, expression),
          ],
        ),
        const SizedBox(height: 9),
        // The five fields are one thing, and a macro is what stands in place
        // of all five: they change over rather than one appearing where the
        // other was.
        AnimatedSize(
          duration: Durations.short4,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: Durations.short4,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            child: _macro != null
                ? KeyedSubtree(
                    key: const ValueKey('macro'),
                    child: _buildMacroField(),
                  )
                : KeyedSubtree(
                    key: const ValueKey('fields'),
                    child: _buildFields(),
                  ),
          ),
        ),
        const SizedBox(height: 9),
        _buildPreview(schedule, expression),
        const SizedBox(height: 17),
        _label(libL10n.cmd),
        const SizedBox(height: 7),
        _buildCommandField(),
        const SizedBox(height: 13),
        Row(
          children: [
            Switch(
              value: _enabled,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.scheduledTaskEnableNow),
                  Text(l10n.scheduledTaskEnableNowTip, style: UIs.text12Grey),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Divider(height: 1, color: Hairline.color(context)),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(libL10n.cancel),
            ),
            const SizedBox(width: 7),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.job == null ? libL10n.add : libL10n.save),
            ),
          ],
        ),
      ],
    );

    // No surface of its own: the sheet paints one, and it starts under the
    // grip. What it does own is staying above the keyboard.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 0, 17, 17),
          child: body,
        ),
      ),
    );
  }

  /// One surface for everything typed into in this sheet.
  ///
  /// The sheet is already a raised surface, so a box tinted a step above it is
  /// the difference between an input and a line of text — which is what the
  /// five fields read as when they were the sheet's own colour.
  Widget _box({required Widget child, EdgeInsetsGeometry? padding}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: Hairline.color(context)),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: padding,
      child: child,
    );
  }

  /// The command, written the way the list writes it: a `$` and one mono line
  /// that goes on as far as it goes.
  Widget _buildCommandField() {
    return _box(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r'$',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: UIs.textGrey.color,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              controller: _commandCtrl,
              minLines: 2,
              maxLines: 4,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration.collapsed(
                hintText: '/usr/bin/rsync -a /srv /mnt/backup',
                hintStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: UIs.textGrey.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.88,
        color: UIs.textGrey.color,
      ),
    );
  }

  Widget _buildPreset(String preset, String expression) {
    final scheme = Theme.of(context).colorScheme;
    final selected = preset == expression;
    final label = CronSchedule.tryParse(preset)?.describe() ?? preset;
    // Only the chosen one is drawn at all. An outline around each of the
    // others made six boxes of a row that is a list of words.
    //
    // The fill and the label move together and take a moment doing it: which
    // one is chosen is the only thing this row says, and an instant swap of
    // two colours is a change one sees having happened rather than happen.
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _applyPreset(preset),
        child: AnimatedContainer(
          duration: Durations.short3,
          curve: Curves.easeOut,
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: selected ? scheme.secondaryContainer : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          child: AnimatedDefaultTextStyle(
            duration: Durations.short3,
            curve: Curves.easeOut,
            style: DefaultTextStyle.of(context).style.copyWith(
              fontSize: 12,
              color: selected
                  ? scheme.onSecondaryContainer
                  : UIs.textGrey.color,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  Widget _buildFields() {
    final labels = [
      l10n.scheduledTaskFieldMinute,
      l10n.scheduledTaskFieldHour,
      l10n.scheduledTaskFieldDayOfMonth,
      l10n.scheduledTaskFieldMonth,
      l10n.scheduledTaskFieldDayOfWeek,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _fieldCount; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(child: _buildField(i, labels[i])),
        ],
      ],
    );
  }

  Widget _buildField(int index, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _box(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
          child: TextField(
            controller: _fieldCtrls[index],
            textAlign: TextAlign.center,
            onChanged: (value) => _onFieldChanged(index, value),
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            decoration: const InputDecoration.collapsed(hintText: null),
          ),
        ),
        const SizedBox(height: 3),
        // Two lines, because five boxes across a phone leave "day of month"
        // about sixty points and a label clipped to "Day o…" names nothing.
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: UIs.text11Grey,
        ),
      ],
    );
  }

  /// A macro is a whole expression, so it is shown as one and left as it was
  /// found. Clearing it hands the schedule back to the five fields.
  Widget _buildMacroField() {
    return _box(
      padding: const EdgeInsets.fromLTRB(13, 5, 5, 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _macro ?? '',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ),
          Btn.icon(
            text: libL10n.clear,
            icon: const Icon(Icons.close, size: 16),
            onTap: () => setState(() => _macro = null),
          ),
        ],
      ),
    );
  }

  /// What the expression above it means, and when it would next run. It is the
  /// only check there is before saving: crond does not answer, and a line that
  /// is one field out is valid and simply never fires.
  Widget _buildPreview(CronSchedule? schedule, String expression) {
    final scheme = Theme.of(context).colorScheme;
    final next = schedule?.nextRun(widget.clock.nowWall());
    return Container(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(13),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: scheme.onPrimaryContainer),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              schedule?.describe() ?? expression,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            next == null
                ? (schedule?.isReboot == true ? l10n.cronAtBoot : '—')
                : '${_relativeLabel(next, clock: widget.clock)} · '
                      '${_clockLabel(next, widget.clock.nowWall())}',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onPrimaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  void _applyPreset(String preset) {
    setState(() {
      if (preset.startsWith('@')) {
        _macro = preset;
        return;
      }
      _macro = null;
      final fields = preset.split(' ');
      for (var i = 0; i < _fieldCount; i++) {
        _fieldCtrls[i].text = i < fields.length ? fields[i] : '*';
      }
    });
  }

  /// A whole expression pasted into one box is spread over the boxes after it,
  /// which is what someone pasting `0 2 * * *` meant.
  void _onFieldChanged(int index, String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && index + parts.length <= _fieldCount) {
      for (var i = 0; i < parts.length; i++) {
        _fieldCtrls[index + i].text = parts[i];
      }
    }
    setState(() {});
  }

  void _submit() {
    final schedule = _expression.trim();
    final command = _commandCtrl.text.trim();
    final error = CronDocument.validate(schedule: schedule, command: command);
    if (error != null) {
      Toast.error(error.message);
      return;
    }
    Navigator.of(
      context,
    ).pop((schedule: schedule, command: command, enabled: _enabled));
  }
}
