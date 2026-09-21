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
  Widget _buildNothingYet(ServerState si) {
    final notice = _noticeOf(si);

    return _hosted(
      si,
      Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(26, 26, 26, _kFuncBarInset + 26),
              children: [
                Icon(
                  notice.glyph,
                  size: 56,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                UIs.height13,
                Text(
                  notice.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
                ),
                if (notice.text.isNotEmpty) ...[
                  UIs.height13,
                  Text(
                    notice.text,
                    textAlign: TextAlign.center,
                    style: UIs.textGrey,
                  ),
                ],
                // What the machine said, as it said it. Selectable and in full:
                // an address or an errno is the part someone needs to paste
                // somewhere, and truncating it is what sends them to the logs.
                if (notice.mono.isNotEmpty) ...[
                  UIs.height13,
                  CardX(
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: SelectableText(
                        notice.mono,
                        textAlign: TextAlign.center,
                        style: UIs.text12Grey.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ],
                UIs.height13,
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 9,
                  runSpacing: 9,
                  children: notice.actions,
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
            // Not when the tab is the host: it floats one of its own above
            // this, which is what keeps the row still while the machine on
            // screen changes.
            if (!widget.bare)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ServerFuncBar(
                  spi: si.spi,
                  btns: serverDetailFuncBtns(si).entries,
                ),
              ),
          ],
        ),
    );
  }

  /// Which of the three this is, and what it says.
  ({
    IconData glyph,
    String title,
    String text,
    String mono,
    List<Widget> actions,
    String hint,
  })
  _noticeOf(ServerState si) {
    final err = si.status.err;
    // `connected` counts: the SSH path sits there through system detection and
    // the script install, two round trips during which there is still nothing
    // to show. Reading it as "not busy" put "Empty" and a Retry button in
    // front of a server that was in the middle of connecting — and disagreed
    // with the server card, which has always treated the three as one state.
    final busy = si.conn.busy;

    final retry = Btn.elevated(
      text: libL10n.retry,
      icon: const Icon(Icons.refresh, size: 18),
      // The icon variant lays its row out at max size, so without this the
      // button fills whatever it is given and reads as a list row.
      mainAxisSize: MainAxisSize.min,
      gap: 8,
      onTap: () => _reconnect(si),
    );
    final edit = Btn.text(
      text: libL10n.edit,
      onTap: () => ServerEditPage.route.go(
        context,
        args: SpiRequiredArgs(si.spi),
      ),
    );

    // Asked before the error is read: a connection this app has not been
    // allowed to make has not been tried, so whatever else is on `err` is
    // about an earlier address or an earlier setting.
    final monitor = si.spi.monitorHttp;
    if (monitor != null && monitor.needsInsecureOptIn) {
      return (
        glyph: Icons.no_encryption_gmailerrorred_outlined,
        // What is true, not what the setting is called: nothing has been sent
        // to this address yet, and what the button turns on is the sending.
        title: l10n.plainHttpTitle,
        text: l10n.plainHttpTip,
        mono: monitor.addr,
        actions: [
          Btn.elevated(
            // Says what it does to what: the switch it flips is this server's
            // and not a default, which is the question anyone reading this
            // screen is asking.
            text: l10n.allowForThisServer,
            icon: const Icon(Icons.lock_open, size: 18),
            mainAxisSize: MainAxisSize.min,
            gap: 8,
            onTap: () => _allowInsecure(si),
          ),
          edit,
        ],
        hint: l10n.monitorAllowInsecureHttpTip,
      );
    }

    if (err != null) {
      return (
        glyph: Icons.link_off,
        title: err.solution ?? libL10n.fail,
        text: '',
        mono: err.message ?? '',
        actions: [
          retry,
          // The message above is the error's own line; this is everything
          // around it — what the app was doing, and the copy button a bug
          // report needs.
          Btn.text(
            text: l10n.viewError,
            onTap: () => _showErrDetail(si, err),
          ),
          edit,
        ],
        hint: '',
      );
    }

    return (
      glyph: busy ? Icons.hourglass_empty : Icons.inbox_outlined,
      // "Empty" is what a server that answered and had nothing to say would
      // be. One that has not answered yet is connecting, and saying so is the
      // difference between waiting and wondering.
      title: busy ? l10n.waitConnection : libL10n.empty,
      text: '',
      mono: '',
      actions: busy ? const [] : [retry, edit],
      hint: '',
    );
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
  Future<void> _allowInsecure(ServerState si) async {
    final monitor = si.spi.monitorHttp;
    if (monitor == null) return;
    try {
      await ref
          .read(serversProvider.notifier)
          .updateServer(si.spi, si.spi.copyWith(monitorHttp: monitor.allowingInsecure()));
    } catch (e, s) {
      if (mounted) context.showErrDialog(e, s);
    }
  }

  /// Clears the retry limiter first: the user asking again *is* the new
  /// information, and without this the request is dropped by the backoff that
  /// the previous failures installed.
  void _reconnect(ServerState si) {
    TryLimiter.reset(si.spi.id);
    ref.read(serversProvider.notifier).refresh(spi: si.spi);
  }

  /// That every figure on this page was taken a while ago, and the way to ask
  /// again.
  ///
  /// Above the readings, because it is about all of them. Not shown when the
  /// error card is: that card already says why the numbers stopped, and two
  /// cards saying it in different words is one of them too many.
  Widget? _buildStaleCard(ServerState si) {
    if (si.status.err != null) return null;
    final at = serverStaleSince(si);
    if (at == null) return null;

    return CardX(
      child: Padding(
        // Next to nothing above and below, because the way to ask again
        // brings its own: it is 32 tall round a line of text, and that is
        // already the air this sentence has. It was a `TextButton`, which a
        // phone holds to 48, inside 9 more on each side — 66 points of card
        // for one line of 12pt text, most of it the space over and under it.
        padding: const EdgeInsets.fromLTRB(17, 5, 9, 5),
        child: Row(
          children: [
            const Icon(
              Icons.pause_circle_outline,
              size: 18,
              color: StatePalette.warn,
            ),
            UIs.width13,
            Expanded(
              child: Text(
                l10n.staleSinceFmt(
                  at.toAgoStr(),
                  _clockOf(at.millisecondsSinceEpoch),
                ),
                style: UIs.text13,
              ),
            ),
            UIs.width7,
            Btn.row(
              icon: const Icon(Icons.refresh, size: 17),
              text: libL10n.refresh,
              mainAxisSize: MainAxisSize.min,
              onTap: () => _reconnect(si),
            ),
          ],
        ),
      ),
    );
  }

  /// Why there is no row of things to do, for a server whose agent grants
  /// nothing.
  ///
  /// Only when the agent has answered: `remoteAccess` is null before the first
  /// poll and for an agent too old to have `/capabilities`, and "we have not
  /// asked yet" must not be drawn as "you are not allowed".
  ///
  /// Only for a server reached *only* through an agent. One that also has SSH
  /// has the row anyway, so there is nothing to explain — and a server with no
  /// agent at all is not what this is about.
  ///
  /// Informational, not a warning. Every switch under `[remote_access]` is off
  /// by default and the docs recommend leaving them that way, so most agents
  /// are in this state on purpose and a red card would be nagging the people
  /// who got it right. What was missing was not a warning but an answer to
  /// "why is there nothing here".
  Widget? _buildNoRemoteAccessCard(ServerState si) {
    if (si.spi.monitorHttp == null || si.spi.ssh != null) return null;
    if (si.remoteAccess == null) return null;

    return CardX(
      child: ListTile(
        leading: const Icon(MingCute.lock_line, size: 20),
        title: Text(l10n.monitorNoRemoteAccess, style: UIs.text12Grey),
        trailing: const Icon(Icons.open_in_new, size: 17),
        onTap: Urls.monitorPermissionsDoc.launchUrl,
      ),
    );
  }

  /// Why the status stopped updating. Sits above the cards, which keep
  /// showing the last successful reading — stale data with a visible reason
  /// beats a blank page.
  Widget? _buildErrCard(ServerState si) {
    final err = si.status.err;
    if (err == null) return null;

    final solution = err.solution;
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red, size: 20),
        title: Text(libL10n.error, style: UIs.text15),
        subtitle: Text(
          solution ?? err.message ?? libL10n.unknown,
          style: UIs.text12Grey,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, size: 17),
        onTap: () => _showErrDetail(si, err),
      ),
    );
  }

  /// A server that has reported before shows its failure here rather than on
  /// the empty page, so the same one-tap answer has to be offered in both.
  void _showErrDetail(ServerState si, Err err) {
    final md = _errMarkdown(err);
    context.showRoundDialog(
      title: libL10n.error,
      child: SingleChildScrollView(child: SimpleMarkdown(data: md)),
      actions: [
        if (si.spi.monitorHttp?.needsInsecureOptIn == true)
          TextButton(
            // Closes the dialog itself and leaves the work to the page: an
            // `onPressed` replaces the navigator the button would have
            // resolved on its own — see the dialog rules in CLAUDE.md.
            onPressed: () {
              context.popDialog();
              _allowInsecure(si);
            },
            child: Text(l10n.monitorAllowInsecureHttp),
          ),
        TextButton(onPressed: () => Pfs.copy(md), child: Text(libL10n.copy)),
        TextButton(onPressed: () => context.popDialog(), child: Text(libL10n.close)),
      ],
    );
  }
}
