import 'dart:ui' show lerpDouble;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/arrival.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/metric_row.dart';
import 'package:server_box/view/page/server/reading_text.dart';

// --- The states that are not a body ---
//
// Connecting is not one of them. The height does not move and the spinner
// in [ServerCardConnAction]'s slot says something is happening; a line under
// the title as well was the same answer twice, which is what a line in the
// list already declines to do by giving up its spinner for the one across
// its middle.
//
// Not a skeleton either. A skeleton grows to the height of a success first
// and has to shrink back when the answer is that there is nothing — which
// is the one movement a list of cards cannot afford.

/// Which of the states with nothing to show a machine is in.
enum ServerNoticeKind {
  /// A monitor agent at a plaintext address this app has not been allowed to
  /// talk to yet.
  plainHttp,

  /// Reaching it failed, and the machine said why.
  failed,

  /// Nothing yet, and something on its way.
  connecting,

  /// It answered, with nothing.
  empty,
}

/// A machine with nothing to show, and what to say about it: a glyph, a
/// sentence, the machine's own words, and what the page adds around them.
///
/// One set of words for the card in the list and for the page it opens
/// into, because the block that says them is one widget at two sizes — see
/// [ServerCardNotice]. The actions are the page's alone: they act on the
/// machine, and a card has nowhere to put them.
class ServerNotice {
  const ServerNotice({
    required this.kind,
    required this.glyph,
    required this.title,
    this.text = '',
    this.mono = '',
    this.hint = '',
  });

  final ServerNoticeKind kind;

  final IconData glyph;

  /// What went wrong, in this app's words.
  final String title;

  /// A sentence under the title, which the page has room for and a card has
  /// not.
  final String text;

  /// What the machine said, as it said it — the only part a search engine
  /// or a bug report can use.
  final String mono;

  /// A line under the page's actions.
  final String hint;

  /// Which state this machine is in, and what to say about it.
  static ServerNotice of(ServerState srv) {
    // Asked before the error is read: a connection this app has not been
    // allowed to make has not been tried, so whatever else is on `err` is
    // about an earlier address or an earlier setting.
    final monitor = srv.spi.monitorHttp;
    if (monitor != null && monitor.needsInsecureOptIn) {
      return ServerNotice(
        kind: ServerNoticeKind.plainHttp,
        glyph: Icons.no_encryption_gmailerrorred_outlined,
        // What is true, not what the setting is called: nothing has been sent
        // to this address yet, and what the page's button turns on is the
        // sending.
        title: l10n.plainHttpTitle,
        text: l10n.plainHttpTip,
        mono: monitor.addr,
        hint: l10n.monitorAllowInsecureHttpTip,
      );
    }
    final err = srv.status.err;
    if (err != null) {
      return ServerNotice(
        kind: ServerNoticeKind.failed,
        glyph: Icons.link_off,
        title: err.solution ?? libL10n.fail,
        mono: err.message ?? '',
      );
    }
    // `connected` counts as busy: the SSH path sits there through system
    // detection and the script install, two round trips during which there
    // is still nothing to show. Read as "not busy" it put "Empty" and a
    // Retry button in front of a server that was in the middle of
    // connecting — and disagreed with the card, which has always treated the
    // three as one state.
    //
    // "Empty" is what a server that answered and had nothing to say would
    // be. One that has not answered yet is connecting, and saying so is the
    // difference between waiting and wondering.
    if (srv.conn.busy) {
      return ServerNotice(
        kind: ServerNoticeKind.connecting,
        glyph: Icons.hourglass_empty,
        title: l10n.waitConnection,
      );
    }
    return ServerNotice(
      kind: ServerNoticeKind.empty,
      glyph: Icons.inbox_outlined,
      title: libL10n.empty,
    );
  }

  /// What the card in the list says about this machine, or null when it says
  /// nothing.
  ///
  /// Only a failure it has seen. Waiting is said by the spinner beside the
  /// name, and a machine that answered with nothing is a name with nothing
  /// under it. A prompt from the far end is not a failure to report either:
  /// the card offers a lock rather than a retry — see
  /// `ServerStateUi.needsInteractiveAuth`.
  ///
  /// The page asks this too, of the block it holds room for: what the card
  /// draws, the page paints only at the handover; what the card does not,
  /// the page brings in itself — see `ServerDetailPage.readingsShowing`.
  static ServerNotice? onCard(ServerState srv) {
    if (srv.status.err == null || srv.needsInteractiveAuth) return null;
    return of(srv);
  }
}

/// What the page draws a notice as, which is where a card's block is going.
///
/// Decided from where the card is going rather than from where it is, the
/// same way `ServerCard.pageWidth` decides the facts column: what the card
/// looks like at each point of the movement is a lerp towards the one form
/// the page has for this machine, and the page has two.
enum ServerNoticeForm {
  /// The whole page, for a machine with nothing else to show: centred, the
  /// glyph above, the page's actions under. See `_buildNothingYet`.
  page,

  /// A card above the readings, for a machine that answered before it
  /// failed: the last figures are still the most recent thing known about
  /// it, and the page keeps them under a line saying why they stopped.
  card,
}

/// What went wrong, and what was actually said.
///
/// Both, because the first is this app's guess and the second is the only
/// thing a search engine or a bug report can use.
///
/// One widget on the card in the list and on the page that card grows into,
/// because the card *becomes* the page — see `ServerCard.openness`. At 0 it
/// is a block inside the card; at 1 it is laid out exactly as the page draws
/// it, in one of two [ServerNoticeForm]s, which is what lets the page take
/// over without anything moving. Every measurement that differs between the
/// two ends is a lerp on [openness].
class ServerCardNotice extends StatelessWidget {
  const ServerCardNotice({
    super.key,
    required this.notice,
    required this.form,
    this.openness = 0,
    this.onTap,
  });

  final ServerNotice notice;

  /// What this is on its way to being — see [ServerNoticeForm].
  final ServerNoticeForm form;

  /// How far the card is on its way to the page — see `ServerCard.openness`.
  final double openness;

  /// What a press does once this is the page's, in the
  /// [ServerNoticeForm.card] form: the whole error, with what the app was
  /// doing and the copy button a bug report needs. Null on a card, where the
  /// card's own tap is the one that counts.
  final VoidCallback? onTap;

  /// Around the block at rest.
  static const _pad = EdgeInsets.symmetric(horizontal: 11, vertical: 9);
  static const _radius = BorderRadius.all(Radius.circular(9));

  /// Both ends of each style that differs, as whole styles, with the line
  /// height stated at both: [TextStyle.lerp] switches a height that only one
  /// end states at the halfway point, which is a jump in the middle of the
  /// movement.
  static const _title = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: StatePalette.warn,
  );
  static const _mono = TextStyle(
    fontSize: 11,
    height: 1.4,
    color: Colors.grey,
    fontFamily: 'monospace',
  );
  static const _pageMono = TextStyle(
    fontSize: 12,
    height: 1.4,
    color: Colors.grey,
    fontFamily: 'monospace',
  );

  @override
  Widget build(BuildContext context) {
    final t = openness.clamp(0.0, 1.0);
    return switch (form) {
      ServerNoticeForm.page => _page(context, t),
      ServerNoticeForm.card => _card(context, t),
    };
  }

  /// The page with nothing else on it: the words leave the block and spread
  /// out under the glyph, and the machine's own words get a card of their
  /// own.
  Widget _page(BuildContext context, double t) {
    final scheme = Theme.of(context).colorScheme;
    // From the left of a card's block to the middle of the page. The lines
    // of a title that wraps follow at the halfway point, by which the card is
    // wide enough that none does.
    final align = Alignment.lerp(Alignment.centerLeft, Alignment.center, t)!;
    final textAlign = t < 0.5 ? TextAlign.start : TextAlign.center;
    final pageTitle = TextStyle(
      fontSize: 21,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
    );

    final title = Align(
      alignment: align,
      child: Text(
        notice.title,
        textAlign: textAlign,
        style: TextStyle.lerp(_title, pageTitle, t),
        // Two lines on a card; the page has room for all of it.
        maxLines: t < 1 ? 2 : null,
        overflow: t < 1 ? TextOverflow.ellipsis : null,
      ),
    );

    final monoText = Text(
      notice.mono,
      textAlign: textAlign,
      style: TextStyle.lerp(_mono, _pageMono, t),
      // Three lines on a card; the page shows the whole of it. An address or
      // an errno is the part someone needs to paste somewhere, and truncating
      // it is what sends them to the logs.
      maxLines: t < 1 ? 3 : null,
      overflow: t < 1 ? TextOverflow.ellipsis : null,
    );
    final mono = notice.mono.isEmpty
        ? null
        : CardX(
            // A card of its own at the far end, in before the block's own
            // surface starts going — see [blockSurfaceAt].
            color: Color.lerp(
              Colors.transparent,
              cardColorOf(context),
              blockSurfaceAt(t),
            ),
            radius: BorderRadius.lerp(_radius, CardX.borderRadius, t),
            margin: EdgeInsets.lerp(
              EdgeInsets.zero,
              const EdgeInsets.all(4),
              t,
            ),
            child: Padding(
              padding: EdgeInsets.lerp(
                EdgeInsets.zero,
                const EdgeInsets.all(13),
                t,
              )!,
              // Selectable once it is the page's, and laid out the same either
              // way: a `SelectableText` wraps a caret's width earlier than the
              // `Text` it would be taking over from.
              child: t < 1 ? monoText : SelectionArea(child: monoText),
            ),
          );

    final block = Container(
      padding: EdgeInsets.lerp(_pad, EdgeInsets.zero, t),
      // The block's one surface goes as the words spread out of it — over
      // with in the movement's first fifth, along with the card's own, see
      // [cardSurfaceAt] — and the machine's words get a surface of their own.
      decoration: BoxDecoration(
        color: Color.lerp(
          Colors.transparent,
          scheme.surfaceContainerLowest,
          cardSurfaceAt(t),
        ),
        borderRadius: _radius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          // The page's sentence under the title, which a card has no room
          // for: it grows in from nothing, so what is under it travels
          // rather than arriving lower by its height.
          if (notice.text.isNotEmpty)
            ServerCardReveal(
              shown: t,
              child: Padding(
                padding: const EdgeInsets.only(top: 13),
                child: Text(
                  notice.text,
                  textAlign: textAlign,
                  style: UIs.textGrey,
                ),
              ),
            ),
          if (mono != null) ...[
            SizedBox(height: lerpDouble(3, 13, t)),
            mono,
          ],
        ],
      ),
    );

    return Padding(
      // At rest, a gap under the card's title. At the end, what the page with
      // nothing to show insets its notice by over the page's own inset — see
      // [ServerCardSizes.noticeInset].
      padding: EdgeInsets.lerp(
        const EdgeInsets.only(top: ServerCardSizes.gap),
        ServerCardSizes.noticeInset,
        t,
      )!,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Above the words, growing in from nothing: a card has no room for
          // a glyph the height of three lines, and the page has it over the
          // title. There at rest too, at no height, so the block under it is
          // the same child of the same column on every frame.
          ServerCardReveal(
            shown: t,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Icon(
                notice.glyph,
                size: 56,
                color: scheme.outlineVariant,
              ),
            ),
          ),
          block,
        ],
      ),
    );
  }

  /// The card above the readings: the block at the page's size, with the
  /// page's own inset and a way into the whole error at its right.
  ///
  /// The words are the same at both ends on purpose — a line that grew as
  /// the card did would be a second thing moving.
  Widget _card(BuildContext context, double t) {
    final scheme = Theme.of(context).colorScheme;
    final words = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notice.title,
          style: _title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (notice.mono.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            notice.mono,
            style: _mono,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
    final body = Padding(
      padding: EdgeInsets.lerp(_pad, ServerCardSizes.focusPad, t)!,
      child: Row(
        children: [
          Expanded(child: words),
          // The page's card is a way in as well as a line, and says so. On
          // a card there is no room to say it and nothing it would lead to
          // that tapping the card does not.
          SizedBox(width: 9 * t),
          SizedBox(
            width: 17 * t,
            child: Opacity(
              opacity: t,
              child: const Icon(
                Icons.chevron_right,
                size: 17,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
    final surface = CardX(
      // The block's own surface becomes the page's card colour, in before
      // the card's own surface starts going — see [blockSurfaceAt].
      color: Color.lerp(
        scheme.surfaceContainerLowest,
        cardColorOf(context),
        blockSurfaceAt(t),
      ),
      radius: BorderRadius.lerp(_radius, CardX.borderRadius, t),
      margin: EdgeInsets.lerp(EdgeInsets.zero, const EdgeInsets.all(4), t),
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
    return Padding(
      // A gap under the card's title, which has gone by the time this is the
      // page's.
      padding: EdgeInsets.only(top: lerpDouble(ServerCardSizes.gap, 0, t)!),
      child: surface,
    );
  }
}

/// The connection is up and the numbers have stopped.
///
/// The numbers stay exactly as they were: the last reading is still the most
/// recent thing known about the machine, and falling back to the connecting
/// state would throw that away. What changes is that the chart goes grey and
/// this says how old they are.
///
/// One widget on the card and on the page it grows into — see
/// [ServerCardNotice] for the rule. At rest a line inside the card; at 1 the
/// page's own card above the readings, with the way to ask again at its
/// right. The two ends say it differently — a card has room for how long
/// ago, the page for the clock as well — so both sentences are drawn,
/// crossing over on the way, in the one style that is a lerp of the two.
class ServerCardStale extends StatelessWidget {
  const ServerCardStale({
    super.key,
    required this.at,
    required this.spi,
    this.openness = 0,
  });

  /// When the last sample landed.
  final DateTime at;

  /// Whose numbers, for the way to ask again.
  final Spi spi;

  /// How far the card is on its way to the page — see `ServerCard.openness`.
  final double openness;

  static const _pad = EdgeInsets.symmetric(horizontal: 9, vertical: 5);

  /// Next to nothing above and below on the page, because the way to ask
  /// again brings its own: it is 32 tall round a line of text, and that is
  /// already the air this sentence has. It was a `TextButton`, which a phone
  /// holds to 48, inside 9 more on each side — 66 points of card for one line
  /// of 12pt text, most of it the space over and under it.
  static const _pagePad = EdgeInsets.fromLTRB(17, 5, 9, 5);
  static const _radius = BorderRadius.all(Radius.circular(9));

  /// The near end of the one style, the line height stated at both ends —
  /// see [ServerCardNotice] for why.
  static const _text = TextStyle(
    fontSize: 11,
    height: 1,
    color: StatePalette.warn,
  );

  /// The card's sentence goes first and the page's arrives after, overlapping
  /// in the middle. Faded in step they would both be at half strength through
  /// the whole movement, which reads as a smear rather than a change.
  static const _gone = Interval(0, 0.4, curve: Curves.easeOut);
  static const _arrived = Interval(0.25, 1, curve: Curves.easeIn);

  @override
  Widget build(BuildContext context) {
    final t = openness.clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle.lerp(
      _text,
      TextStyle(fontSize: 13, height: 1.2, color: scheme.onSurface),
      t,
    );

    final words = Stack(
      alignment: Alignment.centerLeft,
      children: [
        if (t < 1)
          Opacity(
            opacity: 1 - _gone.transform(t),
            child: Text(
              l10n.lastSampleFmt(at.toAgoStr()),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (t > 0)
          Opacity(
            opacity: _arrived.transform(t),
            child: Text(
              l10n.staleSinceFmt(
                at.toAgoStr(),
                ReadingFmt.clock(at.millisecondsSinceEpoch),
              ),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );

    final row = Padding(
      padding: EdgeInsets.lerp(_pad, _pagePad, t)!,
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: lerpDouble(15, 18, t),
            color: StatePalette.warn,
          ),
          SizedBox(width: lerpDouble(7, 13, t)),
          Expanded(child: words),
          // The way to ask again is the page's: a card has one beside its
          // name already. It grows in from the right, in both directions, so
          // the line is as tall as the sentence until there is a button to
          // be as tall as — and is not built at all at rest, where it would
          // be a control per card that nothing can reach.
          if (t > 0)
            ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: t,
                heightFactor: t,
                child: Opacity(
                  opacity: t,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: _StaleRefresh(spi: spi),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return CardX(
      // The line's own tint becomes the page's card colour, in before the
      // card's own surface starts going — see [blockSurfaceAt].
      color: Color.lerp(
        scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        cardColorOf(context),
        blockSurfaceAt(t),
      ),
      radius: BorderRadius.lerp(_radius, CardX.borderRadius, t),
      margin: EdgeInsets.lerp(
        const EdgeInsets.only(bottom: ServerCardSizes.gap),
        const EdgeInsets.all(4),
        t,
      ),
      child: row,
    );
  }
}

/// The way to ask again, on the page's stale card.
///
/// Its own widget with its own `ref`, so the card in the list — which has
/// none — draws at the far end of its movement the same control the page
/// draws. Clears the retry limiter first: the user asking again *is* the new
/// information, and without this the request is dropped by the backoff the
/// previous failures installed.
class _StaleRefresh extends ConsumerWidget {
  const _StaleRefresh({required this.spi});

  final Spi spi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Btn.row(
      icon: const Icon(Icons.refresh, size: 17),
      text: libL10n.refresh,
      mainAxisSize: MainAxisSize.min,
      onTap: () {
        TryLimiter.reset(spi.id);
        ref.read(serversProvider.notifier).refresh(spi: spi);
      },
    );
  }
}

/// The one thing worth saying about this machine, or nothing.
///
/// Drawn only when a reading is over the line: a footer that is always there
/// is a line of text on every card that nobody reads, and this one has to be
/// read the once it appears.
class ServerCardFoot extends StatelessWidget {
  const ServerCardFoot({super.key, required this.over});

  /// The first reading that is over its line, which is what this says.
  final ServerMetric over;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ServerCardSizes.rowGap),
      child: Row(
        children: [
          Container(
            width: ServerCardSizes.dot,
            height: ServerCardSizes.dot,
            decoration: const BoxDecoration(
              color: StatePalette.warn,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '${over.label} ${over.value} · ${over.note}',
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: StatePalette.warn,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
