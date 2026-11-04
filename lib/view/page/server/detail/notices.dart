part of 'view.dart';

// --- A machine with nothing to show, and what went wrong ---

extension on _ServerDetailPageState {
  /// A server with nothing to show, and why.
  ///
  /// One shape for every reason — cannot connect, waiting for permission to
  /// use a plaintext address, answered with nothing: a glyph, a sentence, the
  /// machine's own words underneath, and the actions that change the answer.
  /// The row of things to do stays where it is, greyed: it is not that the
  /// entries went away, it is that nothing can be done through a connection
  /// that is not there, and the positions are worth keeping.
  ///
  /// The words are [ServerCardNotice] at the far end of its movement: a card
  /// that failed draws the same block, and grows it into this — see
  /// [ServerNoticeForm.page]. The actions are this page's own, and come in
  /// under it the way the facts come in beside the readings.
  Widget _buildNothingYet(ServerState srv) {
    final notice = ServerNotice.of(srv);

    return _hosted(
      srv,
      Stack(
        children: [
          ListView(
            // The readings page's inset, so the block a card grows into is
            // in the same box whichever page it finds; the notice's own 26
            // is on the block — see [ServerCardSizes.noticeInset].
            padding: EdgeInsets.fromLTRB(
              13,
              4,
              13,
              _kFuncBarInset + 26 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _handed(
                ServerCardNotice(
                  notice: notice,
                  form: ServerNoticeForm.page,
                  openness: 1,
                ),
                byCard: ServerNotice.onCard(srv) != null,
                from: const Offset(0, 24),
              ),
              _entering(
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      UIs.height13,
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 9,
                        runSpacing: 9,
                        children: _actionsOf(srv, notice),
                      ),
                      if (notice.hint.isNotEmpty) ...[
                        UIs.height13,
                        Text(
                          notice.hint,
                          textAlign: TextAlign.center,
                          style: UIs.text11Grey,
                        ),
                      ],
                    ],
                  ),
                ),
                from: const Offset(0, 24),
              ),
            ],
          ),
          // Not when the tab is the host: it floats one of its own above
          // this, which is what keeps the row still while the machine on
          // screen changes.
          if (!widget.bare)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ServerFuncBar(
                spi: srv.spi,
                btns: serverDetailFuncBtns(srv).entries,
              ),
            ),
        ],
      ),
    );
  }

  /// What changes the answer, for the state [notice] found the machine in.
  List<Widget> _actionsOf(ServerState srv, ServerNotice notice) {
    final retry = Btn.elevated(
      text: libL10n.retry,
      icon: const Icon(Icons.refresh, size: 18),
      // The icon variant lays its row out at max size, so without this the
      // button fills whatever it is given and reads as a list row.
      mainAxisSize: MainAxisSize.min,
      gap: 8,
      onTap: () => _reconnect(srv),
    );
    final edit = Btn.text(
      text: libL10n.edit,
      onTap: () => ServerEditPage.route.go(
        context,
        args: ServerEditArgs(srv.spi),
      ),
    );

    return switch (notice.kind) {
      ServerNoticeKind.plainHttp => [
        Btn.elevated(
          // Says what it does to what: the switch it flips is this server's
          // and not a default, which is the question anyone reading this
          // screen is asking.
          text: l10n.allowForThisServer,
          icon: const Icon(Icons.lock_open, size: 18),
          mainAxisSize: MainAxisSize.min,
          gap: 8,
          onTap: () => _allowInsecure(srv),
        ),
        edit,
      ],
      ServerNoticeKind.failed => [
        retry,
        // The title above is the error's own line; this is everything
        // around it — what the app was doing, and the copy button a bug
        // report needs.
        if (srv.status.err case final err?)
          Btn.text(
            text: l10n.viewError,
            onTap: () => _showErrDetail(srv, err),
          ),
        edit,
      ],
      // Nothing to do about a machine that is still on its way.
      ServerNoticeKind.connecting => const [],
      ServerNoticeKind.empty => [retry, edit],
    };
  }

  /// The error as markdown: what to do about it, then what was actually said.
  String _errMarkdown(Err err) {
    return '''
${err.solution ?? libL10n.unknown}

```sh
${err.message ?? 'null'}
```
''';
  }

  /// Saving is the whole of it: `Spi.shouldReconnect` counts a changed
  /// `monitorHttp` — and `MonitorHttpCredential.==` counts `allowInsecure` —
  /// so `updateServer` clears the retry limiter and refreshes on its own.
  /// Reconnecting here as well would be a second attempt at the same thing.
  Future<void> _allowInsecure(ServerState srv) async {
    final monitor = srv.spi.monitorHttp;
    if (monitor == null) return;
    try {
      await ref
          .read(serversProvider.notifier)
          .updateServer(srv.spi, srv.spi.copyWith(monitorHttp: monitor.allowingInsecure()));
    } catch (e, s) {
      if (mounted) context.showErrDialog(e, s);
    }
  }

  /// Clears the retry limiter first: the user asking again *is* the new
  /// information, and without this the request is dropped by the backoff that
  /// the previous failures installed.
  void _reconnect(ServerState srv) {
    TryLimiter.reset(srv.spi.id);
    ref.read(serversProvider.notifier).refresh(spi: srv.spi);
  }

  /// That every figure on this page was taken a while ago, and the way to ask
  /// again.
  ///
  /// Above the readings, because it is about all of them. Not shown when the
  /// error card is: that card already says why the numbers stopped, and two
  /// cards saying it in different words is one of them too many.
  ///
  /// The line the card in the list draws, at the far end of its movement —
  /// see [ServerCardStale].
  Widget? _buildStaleCard(ServerState srv) {
    if (srv.status.err != null) return null;
    final at = serverStaleSince(srv);
    if (at == null) return null;
    return ServerCardStale(at: at, spi: srv.spi, openness: 1);
  }

  /// Why there is no row of things to do, for a server whose agent refuses
  /// this connection — plaintext HTTP without its `allow_insecure`.
  ///
  /// Only when the agent has answered: `agentAccess` is null before the first
  /// poll, and "we have not asked yet" must not be drawn as "refused".
  ///
  /// Only for a server reached *only* through an agent. One that also has SSH
  /// has the row anyway, so there is nothing to explain — and a server with no
  /// agent at all is not what this is about.
  Widget? _buildNoRemoteAccessCard(ServerState srv) {
    if (srv.spi.monitorHttp == null || srv.spi.ssh != null) return null;
    if (srv.agentAccess == null) return null;

    return CardX(
      child: ListTile(
        leading: const Icon(MingCute.lock_line, size: 20),
        title: Text(l10n.monitorNoRemoteAccess, style: UIs.text12Grey),
        trailing: const Icon(Icons.open_in_new, size: 17),
        onTap: Urls.monitorAccessDoc.launchUrl,
      ),
    );
  }

  /// Why the status stopped updating. Sits above the readings, which keep
  /// showing the last successful one — stale data with a visible reason
  /// beats a blank page.
  ///
  /// The block the card in the list draws, at the far end of its movement —
  /// see [ServerNoticeForm.card]. Pressing it is the way to the whole error.
  Widget? _buildErrCard(ServerState srv) {
    final err = srv.status.err;
    if (err == null) return null;
    return ServerCardNotice(
      notice: ServerNotice.of(srv),
      form: ServerNoticeForm.card,
      openness: 1,
      onTap: () => _showErrDetail(srv, err),
    );
  }

  /// A server that has reported before shows its failure here rather than on
  /// the empty page, so the same one-tap answer has to be offered in both.
  void _showErrDetail(ServerState srv, Err err) {
    final md = _errMarkdown(err);
    context.showRoundDialog(
      title: libL10n.error,
      child: SingleChildScrollView(child: SimpleMarkdown(data: md)),
      actions: [
        if (srv.spi.monitorHttp?.needsInsecureOptIn == true)
          TextButton(
            // Closes the dialog itself and leaves the work to the page: an
            // `onPressed` replaces the navigator the button would have
            // resolved on its own — see the dialog rules in CLAUDE.md.
            onPressed: () {
              context.popDialog();
              _allowInsecure(srv);
            },
            child: Text(l10n.monitorAllowInsecureHttp),
          ),
        TextButton(onPressed: () => Pfs.copy(md), child: Text(libL10n.copy)),
        TextButton(onPressed: () => context.popDialog(), child: Text(libL10n.close)),
      ],
    );
  }
}
