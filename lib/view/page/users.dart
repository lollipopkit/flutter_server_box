import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/system_user.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/service/user_manager.dart';
import 'package:server_box/view/page/user_detail.dart';

enum _UserFilter { all, regular, system, disabled }

enum _UserSort { uid, name }

enum _UserAction { edit, delete }

/// Below this the Status column is dropped and the mono line loses the group,
/// which is the narrow layout the design draws at 393pt.
const _kWideWidth = 600.0;

/// Groups that make an account an administrator on the distributions this app
/// talks to. Shown as a badge because it is the one thing about an account
/// that the shell and home path do not say.
const _kAdminGroups = {'sudo', 'wheel', 'admin'};

final class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key, required this.args});

  final SpiRequiredArgs args;

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: UsersPage.new,
    path: '/users',
  );

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

final class _UsersPageState extends ConsumerState<UsersPage> {
  late final _provider = serverProvider(widget.args.spi.id);
  final _searchCtrl = TextEditingController();

  ServerUserCatalog? _catalog;
  _UserFilter _filter = _UserFilter.all;
  _UserSort _sort = _UserSort.uid;
  bool _searching = false;
  String _query = '';
  bool _systemExpanded = true;
  bool _busy = false;
  bool _unsupported = false;
  String? _failure;

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

  void _rebuild(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) {
    final system = ref.watch(_provider.select((state) => state.status.system));
    final supported = system == SystemType.linux;
    final canMutate =
        supported && !_unsupported && _failure == null && _catalog != null;
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: l10n.systemUsers, down: widget.args.spi.name),
        actions: _buildActions(canMutate),
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: _buildBody()),
      floatingActionButton: canMutate
          ? FloatingActionButton(
              tooltip: libL10n.add,
              onPressed: _busy ? null : () => _editUser(),
              child: const Icon(Icons.person_add_alt_1),
            )
          : null,
    );
  }
}

// --- Widget builders ---

extension on _UsersPageState {
  List<Widget> _buildActions(bool canMutate) {
    return [
      Btn.icon(
        text: libL10n.search,
        icon: Icon(_searching ? Icons.search_off : Icons.search, size: 18),
        onTap: canMutate ? _toggleSearch : null,
      ),
      PopupMenuButton<_UserSort>(
        tooltip: libL10n.sort,
        enabled: canMutate,
        icon: const Icon(Icons.sort, size: 18),
        initialValue: _sort,
        itemBuilder: (_) => [
          PopupMenuItem(value: _UserSort.uid, child: Text(l10n.userUid)),
          PopupMenuItem(value: _UserSort.name, child: Text(libL10n.sortByName)),
        ],
        onSelected: (sort) => _rebuild(() => _sort = sort),
      ),
      if (isDesktop)
        Btn.icon(
          text: libL10n.refresh,
          icon: const Icon(Icons.refresh, size: 18),
          onTap: _busy ? null : _refresh,
        ),
    ];
  }

  Widget _buildBody() {
    if (_unsupported) {
      return _issueBody(
        title: libL10n.unsupported,
        explain: l10n.userManagerLinuxOnly,
        icon: Icons.not_interested,
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

    return LayoutBuilder(
      builder: (_, constraints) {
        final wide = constraints.maxWidth >= _kWideWidth;
        final users = _visibleUsers(catalog);
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildSearchField()),
            SliverToBoxAdapter(child: _buildFilters(catalog, wide: wide)),
            if (_busy)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (users.isEmpty)
              SliverToBoxAdapter(
                child: CenterGreyTitle(libL10n.empty).paddingOnly(top: 80),
              )
            else
              ..._buildSections(catalog, users, wide: wide),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        );
      },
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

  /// Grows and shrinks rather than appearing, so the list below it is seen to
  /// move down for the field instead of jumping.
  ///
  /// The field is built only while searching, which is what keeps its autofocus
  /// honest and keeps a hidden text field out of the focus order. [AnimatedSize]
  /// animates the swap either way, so nothing has to be kept in the tree for
  /// the sake of the exit.
  Widget _buildSearchField() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _searching
          ? SizedBox(
              height: 40,
              child: InlineSearchField(
                controller: _searchCtrl,
                onChanged: (value) => _rebuild(() => _query = value),
                onClose: _toggleSearch,
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }

  /// The same segmented control the Container page switches tabs with: these
  /// are four views of one list, and a row of chips read as four independent
  /// toggles when only one of them can be on.
  ///
  /// Narrow offers three segments, not four — Disabled is the filter whose
  /// answer the Status column gave, and narrow has no Status column. One
  /// chosen while wide is still offered after a rotation, or there would be no
  /// way back out of it.
  ///
  /// No current-account segment at either width: that account's row is
  /// highlighted and carries its own badge, so it would repeat on every screen
  /// what one row already says.
  Widget _buildFilters(ServerUserCatalog catalog, {required bool wide}) {
    final filters = _UserFilter.values
        .where(
          (filter) =>
              wide || filter != _UserFilter.disabled || _filter == filter,
        )
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      child: SegmentedTabs<_UserFilter>(
        expand: true,
        segments: [
          for (final filter in filters)
            SegmentedTab(
              value: filter,
              label: '${_filterLabel(filter)} ${_filterCount(catalog, filter)}',
            ),
        ],
        selected: _filter,
        onSelected: (filter) => _rebuild(() => _filter = filter),
      ),
    );
  }

  /// One card per section, so the System block can collapse without leaving a
  /// gap inside a card that is still drawing its own background.
  List<Widget> _buildSections(
    ServerUserCatalog catalog,
    List<ServerUser> users, {
    required bool wide,
  }) {
    // Sections say what a filter has already said, so they only earn their
    // place when everything is on screen.
    if (_filter != _UserFilter.all) {
      return [_buildSectionCard(catalog, null, users, wide: wide)];
    }

    final regular = users
        .where((user) => !user.isSystem(catalog.uidMin))
        .toList(growable: false);
    final system = users
        .where((user) => user.isSystem(catalog.uidMin))
        .toList(growable: false);

    return [
      if (regular.isNotEmpty)
        _buildSectionCard(
          catalog,
          _SectionSpec(title: l10n.userRegularAccount, users: regular),
          regular,
          wide: wide,
        ),
      if (system.isNotEmpty)
        _buildSectionCard(
          catalog,
          _SectionSpec(
            title: libL10n.system,
            users: system,
            collapsible: true,
            expanded: _systemExpanded,
          ),
          _systemExpanded ? system : const [],
          wide: wide,
        ),
    ];
  }

  Widget _buildSectionCard(
    ServerUserCatalog catalog,
    _SectionSpec? section,
    List<ServerUser> users, {
    required bool wide,
  }) {
    final theme = Theme.of(context);
    final cardColor =
        theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow;
    const radius = BorderRadius.all(Radius.circular(13));

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(color: cardColor, borderRadius: radius),
        sliver: SliverMainAxisGroup(
          slivers: [
            if (wide) SliverToBoxAdapter(child: _buildColumnHeader()),
            if (section != null)
              SliverToBoxAdapter(
                child: _buildSectionHeader(section, rounded: !wide),
              ),
            SliverList.builder(
              itemCount: users.length,
              itemBuilder: (_, index) => _buildUser(
                users[index],
                catalog,
                wide: wide,
                last: index == users.length - 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnHeader() {
    final style = UIs.text11Grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _hairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(l10n.userUid, textAlign: TextAlign.end, style: style),
          ),
          const SizedBox(width: 13),
          Expanded(child: Text(libL10n.user, style: style)),
          const SizedBox(width: 13),
          SizedBox(width: 150, child: Text(l10n.userLoginStatus, style: style)),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(_SectionSpec section, {required bool rounded}) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = section.users.where((user) => user.loginDisabled).length;
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: rounded
            ? const BorderRadius.vertical(top: Radius.circular(13))
            : null,
      ),
      child: Row(
        children: [
          Text(
            '${section.title} · ${section.users.length}',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          if (disabled > 0) ...[
            const SizedBox(width: 7),
            Text('$disabled ${libL10n.disabled}', style: UIs.text11Grey),
          ],
          const Spacer(),
          if (section.collapsible)
            Icon(
              section.expanded ? Icons.expand_less : Icons.expand_more,
              size: 15,
              color: UIs.textGrey.color,
            ),
        ],
      ),
    );
    if (!section.collapsible) return header;
    return InkWell(
      onTap: () => _rebuild(() => _systemExpanded = !_systemExpanded),
      child: header,
    );
  }

  Widget _buildUser(
    ServerUser user,
    ServerUserCatalog catalog, {
    required bool wide,
    required bool last,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = user.name == catalog.currentUser;
    final isSystem = user.isSystem(catalog.uidMin);
    final nameColor = isSystem && !user.isRoot ? scheme.onSurfaceVariant : null;

    final row = Container(
      decoration: BoxDecoration(
        color: isCurrent ? scheme.surfaceContainerHigh : null,
        border: last
            ? null
            : Border(bottom: BorderSide(color: _hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: wide ? 44 : 38,
            child: Text(
              '${user.uid}',
              textAlign: TextAlign.end,
              style: _monoStyle(12),
            ),
          ),
          SizedBox(width: wide ? 13 : 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserTitle(user, isCurrent: isCurrent, color: nameColor),
                const SizedBox(height: 2),
                Text(
                  _detailLine(user, wide: wide),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _monoStyle(11),
                ),
              ],
            ),
          ),
          if (wide) ...[
            const SizedBox(width: 13),
            SizedBox(
              width: 150,
              child: Text(
                user.loginDisabled ? libL10n.disabled : l10n.userLoginEnabled,
                style: TextStyle(
                  fontSize: 12,
                  color: user.loginDisabled
                      ? UIs.textGrey.color
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (wide)
            _buildUserMenu(user, isCurrent: isCurrent)
          else
            SizedBox(
              width: 24,
              child: Icon(
                Icons.chevron_right,
                size: 17,
                color: UIs.textGrey.color,
              ),
            ),
        ],
      ),
    );

    if (wide) return row;
    return InkWell(
      key: ValueKey('user-row-${user.uid}'),
      onTap: () => _openDetail(user, catalog),
      child: row,
    );
  }

  Widget _buildUserTitle(
    ServerUser user, {
    required bool isCurrent,
    required Color? color,
  }) {
    final adminGroup = user.supplementaryGroups.firstWhereOrNull(
      (group) => _kAdminGroups.contains(group.toLowerCase()),
    );
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 7,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          user.name,
          style: TextStyle(fontWeight: FontWeight.w500, color: color),
        ),
        if (user.isRoot)
          _tag('root', scheme.onErrorContainer, scheme.errorContainer),
        if (isCurrent)
          _tag(
            l10n.userCurrentAccount,
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
          ),
        if (adminGroup != null)
          _tag(
            adminGroup,
            scheme.onSurfaceVariant,
            scheme.surfaceContainerHighest,
          ),
      ],
    );
  }

  Widget _buildUserMenu(ServerUser user, {required bool isCurrent}) {
    if (!UserManager.validName(user.name) || _busy) {
      return const SizedBox(width: 24);
    }
    return SizedBox(
      width: 24,
      child: PopupMenu<_UserAction>(
        items: [
          PopupMenuItem(value: _UserAction.edit, child: Text(libL10n.edit)),
          if (!user.isRoot && !isCurrent)
            PopupMenuItem(
              value: _UserAction.delete,
              child: Text(libL10n.delete),
            ),
        ],
        onSelected: (action) => switch (action) {
          _UserAction.edit => _editUser(user),
          _UserAction.delete => _deleteUser(user),
        },
      ),
    );
  }

  Widget _tag(String text, Color foreground, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: foreground)),
    );
  }

  TextStyle _monoStyle(double size) => TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    color: UIs.textGrey.color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  Color get _hairline =>
      Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35);
}

// --- Utils ---

extension on _UsersPageState {
  void _openDetail(ServerUser user, ServerUserCatalog catalog) {
    UserDetailPage.route.go(
      context,
      UserDetailPageArgs(
        spi: widget.args.spi,
        user: user,
        catalog: catalog,
        onEdit: _editUser,
        onDelete: _deleteUser,
      ),
    );
  }

  void _toggleSearch() {
    _rebuild(() {
      _searching = !_searching;
      if (!_searching) {
        _searchCtrl.clear();
        _query = '';
      }
    });
  }

  String _filterLabel(_UserFilter filter) => switch (filter) {
    _UserFilter.all => libL10n.all,
    _UserFilter.regular => l10n.userRegularAccount,
    _UserFilter.system => libL10n.system,
    _UserFilter.disabled => libL10n.disabled,
  };

  int _filterCount(ServerUserCatalog catalog, _UserFilter filter) {
    return switch (filter) {
      _UserFilter.all => catalog.users.length,
      _UserFilter.regular => catalog.users
          .where((user) => !user.isSystem(catalog.uidMin))
          .length,
      _UserFilter.system => catalog.users
          .where((user) => user.isSystem(catalog.uidMin))
          .length,
      _UserFilter.disabled => catalog.users
          .where((user) => user.loginDisabled)
          .length,
    };
  }

  List<ServerUser> _visibleUsers(ServerUserCatalog catalog) {
    final filtered = switch (_filter) {
      _UserFilter.all => catalog.users,
      _UserFilter.regular => catalog.users
          .where((user) => !user.isSystem(catalog.uidMin))
          .toList(),
      _UserFilter.system => catalog.users
          .where((user) => user.isSystem(catalog.uidMin))
          .toList(),
      _UserFilter.disabled => catalog.users
          .where((user) => user.loginDisabled)
          .toList(),
    };

    final query = _query.trim().toLowerCase();
    final matched = query.isEmpty
        ? [...filtered]
        : filtered
              .where(
                (user) =>
                    user.name.toLowerCase().contains(query) ||
                    '${user.uid}'.contains(query),
              )
              .toList();

    matched.sort(switch (_sort) {
      _UserSort.uid => (a, b) => a.uid.compareTo(b.uid),
      _UserSort.name => (a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    });
    return matched;
  }

  /// `group · home · shell` on wide, `home · shell` on narrow — the group is
  /// what the Status column's width buys back.
  ///
  /// A disabled account's shell is shown as its basename: every one of them is
  /// some path ending in `nologin`, and the paths differ between distributions
  /// without the difference meaning anything.
  String _detailLine(ServerUser user, {required bool wide}) {
    final shell = user.loginDisabled
        ? user.shell.split('/').last
        : user.shell;
    final parts = [
      if (wide) user.primaryGroup ?? '${user.gid}',
      user.home,
      shell,
    ];
    return parts.join(' · ');
  }
}

final class _SectionSpec {
  const _SectionSpec({
    required this.title,
    required this.users,
    this.collapsible = false,
    this.expanded = true,
  });

  final String title;
  final List<ServerUser> users;
  final bool collapsible;
  final bool expanded;
}

// --- Actions ---

extension on _UsersPageState {
  Future<void> _refresh() async {
    if (!mounted || _busy) return;
    final system = ref.read(_provider).status.system;
    if (system != SystemType.linux) {
      _rebuild(() {
        _unsupported = true;
        _failure = null;
        _catalog = null;
      });
      return;
    }

    _rebuild(() {
      _busy = true;
      _unsupported = false;
      _failure = null;
    });
    try {
      final exec = await ref.read(_provider.notifier).ensureExec();
      final catalog = await UserManager.list(exec);
      if (!mounted) return;
      _rebuild(() => _catalog = catalog);
    } catch (e, s) {
      Loggers.app.warning('List users for ${widget.args.spi.id}', e, s);
      if (mounted) _rebuild(() => _failure = '$e');
    } finally {
      if (mounted) _rebuild(() => _busy = false);
    }
  }

  Future<bool> _editUser([ServerUser? user]) async {
    final draft = await _showEditor(user);
    if (draft == null || !mounted) return false;
    final script = user == null
        ? UserManager.createScript(draft)
        : UserManager.editScript(user, draft);
    if (!await _runMutation(script)) return false;
    await _refresh();
    return true;
  }

  Future<bool> _deleteUser(ServerUser user) async {
    var removeHome = false;
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(libL10n.delFmt(libL10n.user, user.name)),
            CheckboxListTile(
              value: removeHome,
              title: Text(l10n.userRemoveHome),
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setDialogState(() => removeHome = value ?? false);
              },
            ),
          ],
        ),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (confirmed != true || !mounted) return false;
    final script = UserManager.deleteScript(user, removeHome: removeHome);
    if (!await _runMutation(script)) return false;
    await _refresh();
    return true;
  }

  Future<bool> _runMutation(String script) async {
    if (_busy) return false;
    _rebuild(() => _busy = true);
    try {
      final exec = await ref.read(_provider.notifier).ensureExec();
      var result = await PrivilegedExec.run(
        exec,
        script,
        isRoot: widget.args.spi.isRoot || _catalog?.currentUser == 'root',
      );
      if (result.exitCode == kSudoPasswordRejected) {
        if (!mounted) return false;
        final password = await context.showPwdDialog(
          title: libL10n.sudoPassword,
          label: widget.args.spi.ssh?.user ?? _catalog?.currentUser ?? '',
          id: '${widget.args.spi.id}_sudo_users',
        );
        if (password == null || password.isEmpty) return false;
        result = await PrivilegedExec.run(
          exec,
          script,
          isRoot: false,
          password: password,
        );
      }
      if (!result.succeeded) {
        if (mounted) {
          final detail = result.combined.trim();
          Toast.error(libL10n.fail, body: detail.isEmpty ? null : detail);
        }
        return false;
      }
      if (mounted) Toast.success(libL10n.success);
      return true;
    } catch (e, s) {
      Loggers.app.warning('Change user on ${widget.args.spi.id}', e, s);
      if (mounted) Toast.error('$e');
      return false;
    } finally {
      if (mounted) _rebuild(() => _busy = false);
    }
  }
}

// --- Editor ---

extension on _UsersPageState {
  Future<ServerUserDraft?> _showEditor(ServerUser? user) async {
    final catalog = _catalog;
    if (catalog == null) return null;
    final nameCtrl = TextEditingController(text: user?.name);
    final commentCtrl = TextEditingController(text: user?.comment);
    final homeCtrl = TextEditingController(text: user?.home);
    final shellCtrl = TextEditingController(text: user?.shell ?? '/bin/bash');
    final primaryGroupCtrl = TextEditingController(text: user?.primaryGroup);
    final groupsCtrl = TextEditingController(
      text: user?.supplementaryGroups.join(','),
    );
    final passwordCtrl = TextEditingController();
    var createHome = true;
    var moveHome = false;
    var systemAccount = user?.isSystem(catalog.uidMin) ?? false;

    try {
      while (mounted) {
        final submitted = await context.showRoundDialog<bool>(
          title: user == null ? libL10n.add : libL10n.edit,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) => SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Input(
                      controller: nameCtrl,
                      label: libL10n.user,
                      icon: Icons.person_outline,
                      enabled: user == null,
                      autoFocus: user == null,
                      suggestion: false,
                    ),
                    Input(
                      controller: commentCtrl,
                      label: l10n.userComment,
                      icon: Icons.badge_outlined,
                    ),
                    Input(
                      controller: homeCtrl,
                      label: l10n.homeDir,
                      hint: '/home/${nameCtrl.text}',
                      icon: Icons.home_outlined,
                      suggestion: false,
                    ),
                    Input(
                      controller: shellCtrl,
                      label: l10n.userLoginShell,
                      hint: '/bin/bash',
                      icon: Icons.terminal,
                      suggestion: false,
                    ),
                    Input(
                      controller: primaryGroupCtrl,
                      label: l10n.userPrimaryGroup,
                      icon: Icons.group_outlined,
                      suggestion: false,
                    ),
                    Input(
                      controller: groupsCtrl,
                      label: l10n.userSupplementaryGroups,
                      hint: 'docker,wheel',
                      icon: Icons.groups_outlined,
                      suggestion: false,
                    ),
                    Input(
                      controller: passwordCtrl,
                      label: libL10n.pwd,
                      icon: Icons.password,
                      obscureText: true,
                      suggestion: false,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Text(
                        user == null
                            ? l10n.userPasswordCreateTip
                            : l10n.userPasswordEditTip,
                        style: UIs.textGrey,
                      ),
                    ),
                    if (user == null)
                      SwitchListTile(
                        value: systemAccount,
                        title: Text(l10n.userSystemAccount),
                        onChanged: (value) {
                          setDialogState(() {
                            systemAccount = value;
                            if (value) createHome = false;
                          });
                        },
                      ),
                    if (user == null)
                      SwitchListTile(
                        value: createHome,
                        title: Text(l10n.userCreateHome),
                        onChanged: (value) {
                          setDialogState(() => createHome = value);
                        },
                      ),
                    if (user != null)
                      SwitchListTile(
                        value: moveHome,
                        title: Text(l10n.userMoveHome),
                        onChanged: (value) {
                          setDialogState(() => moveHome = value);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: Btnx.cancelOk,
        );
        if (submitted != true || !mounted) return null;

        final groups = groupsCtrl.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final password = passwordCtrl.text;
        final draft = ServerUserDraft(
          name: nameCtrl.text.trim(),
          comment: commentCtrl.text.trim(),
          home: homeCtrl.text.trim(),
          shell: shellCtrl.text.trim(),
          primaryGroup: primaryGroupCtrl.text.trim(),
          supplementaryGroups: groups,
          createHome: createHome,
          moveHome: moveHome,
          system: systemAccount,
          password: password.isEmpty ? null : password,
        );
        final duplicate =
            user == null &&
            catalog.users.any((existing) => existing.name == draft.name);
        final validation = UserManager.validateDraft(draft);
        if (validation != null || duplicate) {
          Toast.error(validation ?? l10n.nameAlreadyExistsFmt(draft.name));
          continue;
        }
        return draft;
      }
      return null;
    } finally {
      nameCtrl.dispose();
      commentCtrl.dispose();
      homeCtrl.dispose();
      shellCtrl.dispose();
      primaryGroupCtrl.dispose();
      groupsCtrl.dispose();
      passwordCtrl.dispose();
    }
  }
}
