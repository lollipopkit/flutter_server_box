part of 'view.dart';

/// What a card's chip says about the thing the card names.
///
/// A verdict, not a state: the chip exists so that a card of six S.M.A.R.T.
/// devices can be read without reading the six rows. Colour is never the only
/// carrier — the chip always has words in it, and the rows have their own.
enum _Verdict {
  ok,
  warn,
  bad,

  /// Nothing to say about this one — a RAID set has no SMART data rather than
  /// bad SMART data, and a stopped guest is not a guest with a problem.
  idle;

  Color color(ColorScheme scheme) => switch (this) {
    ok => const Color(0xFF22C55E),
    warn => const Color(0xFFF59E0B),
    bad => scheme.error,
    idle => scheme.outline,
  };
}

/// How wide a column of cards wants to be.
///
/// Under this they stop being readable: a card is a table of a name and a
/// reading, and at half of it the names wrap and the readings ellipsise. The
/// grid takes one column instead, which is what a phone gets.
const _kCardColumnWidth = 340.0;

/// How many rows a card lists before its footer takes over.
///
/// A card is a summary. A host with twenty sensors or fifteen guests has a
/// page for them; what belongs here is enough to recognise the answer, and a
/// last line saying how much was left out.
const _kCardRows = 6;

// --- The cards under the rows ---

extension on _ServerDetailPageState {
  /// One card: a conclusion, a few lines of detail, and a last line saying
  /// what is not on screen.
  ///
  /// Every card below the metric rows is this shape, because what they have in
  /// common is that none of them is a value with a line behind it — a table, a
  /// set of guests, a one-off reading — and what is wanted first from all of
  /// them is the verdict rather than the table.
  ///
  /// The glyph at the end of the title row says what tapping does, and there
  /// are only three answers: `expand_more` opens the detail in place,
  /// `chevron_right` leaves for a page of its own, and nothing at all means
  /// there is nothing to open. [onTap] chooses the second; [rows] with no
  /// [onTap] the first.
  Widget _buildReadoutCard({
    required String cardKey,
    required IconData icon,
    required String title,
    ({String text, _Verdict tone})? verdict,
    ({String value, String note})? headline,
    List<Widget> rows = const [],
    List<Widget> extra = const [],
    String footer = '',
    VoidCallback? onTap,
    bool? initiallyExpanded,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final expandable = onTap == null && (rows.isNotEmpty || extra.isNotEmpty);
    final open =
        expandable &&
        _cardExpanded(cardKey, initiallyExpanded ?? _getInitExpand(rows.length));

    final head = Padding(
      padding: EdgeInsets.fromLTRB(17, 13, 13, headline == null ? 13 : 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 9),
              // One group taking the whole line rather than two flexible
              // children beside a `Spacer`: three things sharing the room
              // equally left the title ellipsised with the space still there.
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (verdict != null) ...[
                      const SizedBox(width: 9),
                      Flexible(child: _buildVerdictChip(verdict, scheme)),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 17, color: UIs.textGrey.color)
              else if (expandable)
                // Turned rather than swapped, so the card says which way it is
                // about to move as well as that it moves.
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: Durations.short3,
                  child: Icon(
                    Icons.expand_more,
                    size: 17,
                    color: UIs.textGrey.color,
                  ),
                ),
            ],
          ),
          if (headline != null) ...[
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  headline.value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (headline.note.isNotEmpty) ...[
                  const SizedBox(width: 9),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        headline.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: UIs.text12Grey,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    return CardX(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onTap != null || expandable)
            InkWell(
              onTap: onTap ?? () => _rebuild(() => _toggleCard(cardKey)),
              child: head,
            )
          else
            head,
          // The rows themselves are already laid out; what animates is how
          // much of them the card shows.
          AnimatedSize(
            duration: Durations.short4,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [...rows.take(_kCardRows), ...extra],
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (footer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 7, 17, 13),
              child: Text(footer, style: UIs.text11Grey),
            ),
        ],
      ),
    );
  }

  Widget _buildVerdictChip(
    ({String text, _Verdict tone}) verdict,
    ColorScheme scheme,
  ) {
    final color = verdict.tone.color(scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        verdict.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }

  /// One line of a card's detail: what it is, what it is at, and — where the
  /// line leads somewhere — that it does.
  ///
  /// The dot is a second carrier for the verdict the value already states in
  /// words ("PASSED", "running"), not the only one.
  Widget _buildReadoutRow({
    required String k,
    required String v,
    String? sub,
    Color? dot,
    VoidCallback? onTap,
  }) {
    final body = Padding(
      padding: EdgeInsets.fromLTRB(17, 7, onTap == null ? 17 : 9, 7),
      child: Row(
        // The room between the two, not at the end of the row: with a loose
        // value beside an `Expanded` name the row's children come to less than
        // its width, and the difference lands after the last of them — which
        // left every reading short of the edge it is supposed to line up on.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (dot != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  k,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UIs.text13,
                  textScaler: _textFactor,
                ),
                if (sub != null)
                  Text(
                    sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: UIs.text11Grey,
                    textScaler: _textFactor,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Flexible(
            child: Text(
              v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: UIs.text13Grey,
              textScaler: _textFactor,
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, size: 17, color: UIs.textGrey.color),
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }

  /// The cards laid out in as many columns as there is room for.
  ///
  /// Round-robin rather than shortest-column-first: a card's height is not
  /// known before it is laid out, and the balanced version moves a card to the
  /// other column when the machine it describes grows a row — which on a page
  /// that refreshes every few seconds is a card that will not stay still.
  Widget _buildCardGrid(List<Widget> cards) {
    if (cards.isEmpty) return UIs.placeholder;
    return LayoutBuilder(
      builder: (_, cons) {
        const gap = 13.0;
        final columns = ((cons.maxWidth + gap) / (_kCardColumnWidth + gap))
            .floor()
            .clamp(1, 2);
        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var col = 0; col < columns; col++) ...[
              if (col > 0) const SizedBox(width: gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = col; i < cards.length; i += columns) cards[i],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// How much of a list is on screen, said whether or not any of it is
  /// missing.
  ///
  /// A card that lists three of six devices and says nothing about the other
  /// three is read as a host with three devices — and one that goes quiet
  /// when it is showing everything leaves the reader counting rows to find
  /// out. [what] is the noun the card is a list of.
  String _countNote(int total, String what) => total <= _kCardRows
      ? l10n.countOfFmt(total, what)
      : l10n.shownOfFmt(_kCardRows, total, what);

  /// The footer line: the parts a card has, in the order it has them.
  String _cardFooter(List<String> parts) =>
      parts.where((e) => e.isNotEmpty).join(' · ');
}
