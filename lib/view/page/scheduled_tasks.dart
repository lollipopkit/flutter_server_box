import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/cron.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/service/cron_manager.dart';

enum _ScheduledTaskAction { edit, delete }

final class ScheduledTasksPage extends ConsumerStatefulWidget {
  const ScheduledTasksPage({super.key, required this.args});

  final SpiRequiredArgs args;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: ScheduledTasksPage.new,
    path: '/scheduled-tasks',
  );

  @override
  ConsumerState<ScheduledTasksPage> createState() =>
      _ScheduledTasksPageState();
}

final class _ScheduledTasksPageState
    extends ConsumerState<ScheduledTasksPage> {
  late final _provider = serverProvider(widget.args.spi.id);

  CronCatalog? _catalog;
  bool _busy = false;
  bool _unsupported = false;
  bool _unavailable = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  void _rebuild(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) {
    final system = ref.watch(_provider.select((state) => state.status.system));
    final supported = system == SystemType.linux;
    final canMutate = supported &&
        !_unsupported &&
        !_unavailable &&
        _failure == null &&
        _catalog != null;
    return Scaffold(
      appBar: CustomAppBar(
        centerTitle: true,
        title: TwoLineText(
          up: l10n.scheduledTasks,
          down: widget.args.spi.name,
        ),
        actions: isDesktop
            ? [
                Btn.icon(
                  text: libL10n.refresh,
                  icon: const Icon(Icons.refresh),
                  onTap: _busy ? null : _refresh,
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: _buildBody()),
      floatingActionButton: canMutate
          ? FloatingActionButton(
              tooltip: libL10n.add,
              onPressed: _busy ? null : () => _editTask(),
              child: const Icon(Icons.add_alarm),
            )
          : null,
    );
  }
}

// --- Widget builders ---

extension on _ScheduledTasksPageState {
  Widget _buildBody() {
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

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(catalog)),
        if (_busy)
          const SliverToBoxAdapter(
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (catalog.document.jobs.isEmpty)
          SliverToBoxAdapter(
            child: CenterGreyTitle(libL10n.empty).paddingOnly(top: 80),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _buildTask(catalog.document.jobs[index]),
              childCount: catalog.document.jobs.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
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

  Widget _buildHeader(CronCatalog catalog) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(
            avatar: const Icon(Icons.person_outline, size: 17),
            label: Text('${libL10n.user}: ${catalog.user}'),
          ),
          const SizedBox(height: 4),
          Text(l10n.scheduledTaskPreserveTip, style: UIs.textGrey),
        ],
      ),
    );
  }

  Widget _buildTask(CronJob task) {
    return ListTile(
      leading: Switch(
        value: task.enabled,
        onChanged: _busy
            ? null
            : (enabled) => _setTaskEnabled(task, enabled),
      ),
      title: Text(
        task.schedule,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          task.command,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
      trailing: _busy
          ? null
          : PopupMenu<_ScheduledTaskAction>(
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
                _ScheduledTaskAction.edit => _editTask(task),
                _ScheduledTaskAction.delete => _deleteTask(task),
              },
            ),
    ).cardx.paddingSymmetric(horizontal: 13);
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
    final edit = await _showEditor(task);
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
      child: Text(libL10n.delFmt(l10n.scheduledTasks, task.schedule)),
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
        _catalog = CronCatalog(user: catalog.user, document: document);
      });
      Toast.success(libL10n.saved);
    } catch (e, s) {
      Loggers.app.warning('Save cron tasks for ${widget.args.spi.id}', e, s);
      if (mounted) Toast.error(libL10n.saveFailed, body: '$e');
    } finally {
      if (mounted) _rebuild(() => _busy = false);
    }
  }
}

// --- Utils ---

extension on _ScheduledTasksPageState {
  Future<({String schedule, String command, bool enabled})?> _showEditor(
    CronJob? task,
  ) async {
    final scheduleCtrl = TextEditingController(text: task?.schedule);
    final commandCtrl = TextEditingController(text: task?.command);
    var enabled = task?.enabled ?? true;
    try {
      while (mounted) {
        final submitted = await context.showRoundDialog<bool>(
          title: task == null ? libL10n.add : libL10n.edit,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: StatefulBuilder(
              builder: (context, setDialogState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Input(
                    controller: scheduleCtrl,
                    label: l10n.scheduledTaskSchedule,
                    hint: l10n.scheduledTaskScheduleHint,
                    icon: Icons.schedule,
                    autoFocus: task == null,
                    suggestion: false,
                  ),
                  Input(
                    controller: commandCtrl,
                    label: libL10n.cmd,
                    icon: Icons.terminal,
                    minLines: 2,
                    maxLines: 5,
                    suggestion: false,
                  ),
                  SwitchListTile(
                    value: enabled,
                    title: Text(l10n.enable),
                    onChanged: (value) {
                      setDialogState(() => enabled = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: Btnx.cancelOk,
        );
        if (submitted != true || !mounted) return null;
        final schedule = scheduleCtrl.text.trim();
        final command = commandCtrl.text.trim();
        if (CronDocument.validate(
              schedule: schedule,
              command: command,
            ) !=
            null) {
          Toast.error('${libL10n.invalid}: ${l10n.scheduledTaskSchedule}');
          continue;
        }
        return (schedule: schedule, command: command, enabled: enabled);
      }
      return null;
    } finally {
      scheduleCtrl.dispose();
      commandCtrl.dispose();
    }
  }
}
