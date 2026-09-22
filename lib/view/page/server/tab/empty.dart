import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';

/// What the page shows with no cards on it, which is three different
/// things.
///
/// A tag with nothing under it is a filter to undo — the servers are still
/// there, and an empty page that does not say so reads as having lost them.
/// A search with no hits is the same again, and the one that would be read
/// most wrongly: with no tag on it used to answer "no servers yet" and offer
/// to add one, on a page whose servers are all still there. No servers at
/// all is the first thing a new install sees, and the one place worth
/// spelling out what to do.
///
/// Each gets a name for what is empty, a sentence saying why, and one way
/// out — in that order, because the way out is what the sentence leads to.
class ServerListEmpty extends StatelessWidget {
  /// Keyed by which of the three it is, rather than by the caller: an
  /// [AnimatedSwitcher] above this tells two children apart by key, and going
  /// from a filtered-out tag to no servers at all is a crossing rather than
  /// one pane updated into the other.
  ServerListEmpty({
    required this.query,
    required this.tag,
    required this.onClearSearch,
    required this.onClearTag,
    required this.onAdd,
  }) : super(
         key: ValueKey(
           query.isNotEmpty
               ? 'empty-search'
               : tag.isNotEmpty
               ? 'empty-tag'
               : 'empty-none',
         ),
       );

  /// What the list is searched for, as it is matched against the servers, or
  /// empty for no search. Shown as the title of an empty search.
  final String query;

  /// The tag the list is narrowed to, or empty for all of them.
  final String tag;

  /// Clears the search, which is the way out of an empty one.
  final VoidCallback onClearSearch;

  /// Goes back to every tag, which is the way out of an empty one.
  final VoidCallback onClearTag;

  /// Starts adding a server, which is the way out of there being none.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (query.isNotEmpty) {
      return EmptyPane(
        icon: Icons.search_off,
        title: query,
        // What was searched, since it is neither everything about a server nor
        // an obvious subset of it: a machine is found by what it is called and
        // where it is, which are the two the editor asks for first.
        label: l10n.searchServerTip,
        action: Btn.text(text: libL10n.clear, onTap: onClearSearch),
      );
    }

    if (tag.isNotEmpty) {
      return EmptyPane(
        icon: MingCute.hashtag_line,
        title: '#$tag',
        // Where tags come from, which is the question an empty one raises and
        // which nothing on this tab answers.
        label: l10n.tagsEmptyTip,
        action: Btn.text(text: libL10n.clear, onTap: onClearTag),
      );
    }

    return EmptyPane(
      icon: BoxIcons.bx_server,
      title: l10n.serverTabEmpty,
      label: l10n.addServerTip,
      action: Btn.text(text: libL10n.add, onTap: onAdd),
    );
  }
}
