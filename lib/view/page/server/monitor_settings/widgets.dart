import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_settings.dart';

/// What the settings form and the list pages it opens both draw.
///
/// Shared rather than copied because the two sides have to agree: a row on the
/// form says how many rules there are and the page it opens lists them, and a
/// note under a field on the form has to read the same as the one under the
/// same field on a page.
abstract final class MonitorUi {
  /// One column of a form, centred, the width [PageColumns] gives a column of
  /// its grid.
  ///
  /// The list pages are a single column by nature — a numbered list read across
  /// three columns is a list nobody can follow — but they are opened from a
  /// form that is width-capped, and a page that goes full-bleed after it reads
  /// as a different app. `lib/intro.dart` caps itself the same way.
  static Widget column({required List<Widget> children}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PageColumns.columnWidth),
        child: ListView(
          padding: const EdgeInsets.only(left: 7, right: 7, top: 7, bottom: 27),
          children: children,
        ),
      ),
    );
  }

  /// Marks the field above it when the running agent will not pick it up until
  /// it restarts. Read off what the agent reported rather than a copy here: the
  /// set has changed before, and a wrong answer is one the user only finds out
  /// about by an alert that never comes.
  ///
  /// Nothing is drawn for a field that takes effect on save, which is almost
  /// all of them: saying so under every box put a column of identical grey
  /// lines down the page whose only job was to hide the one line worth reading.
  /// Silence is now the ordinary case and the mark means "not this one".
  ///
  /// The cost is that a `field` this app spells differently from the agent is
  /// not live and not known, and [MonitorSettings.isLive] cannot tell those
  /// apart — `live_fields` lists what is live, not what exists. So a
  /// mistyped name here reads as "takes effect on save" and says nothing about
  /// itself. The names are checked against `live_fields` in the agent's own
  /// `settings` response.
  static Widget effectNote(MonitorSettings settings, String field) {
    if (settings.isLive(field)) return UIs.placeholder;
    return Padding(
      // Padded on both sides: a column of the grid is narrower than the page
      // used to be, and with the right side open the sentence ran into it.
      padding: const EdgeInsets.only(left: 17, right: 17, bottom: 7),
      child: restartNote(),
    );
  }

  /// The marked half of [effectNote], on its own for the push list, which is
  /// told whether it needs a restart by its own endpoint rather than by
  /// `live_fields` — and drew the plain grey sentence, so the one list that
  /// always needs a restart was the one that did not look like it.
  static Widget restartNote() {
    return Row(
      children: [
        const Icon(Icons.restart_alt, size: 15, color: Colors.orange),
        UIs.width7,
        Expanded(
          child: Text(
            l10n.monitorNeedsRestart,
            style: UIs.textGrey.copyWith(color: Colors.orange),
          ),
        ),
      ],
    );
  }

  /// The server editor's add button — an icon beside the label, rather than a
  /// bare text button, which on a page of cards reads as a link.
  static Widget addBtn(void Function() onTap) {
    return Btn.icon(
      icon: const Icon(Icons.add, size: 20),
      text: libL10n.add,
      onTap: onTap,
    );
  }

  /// A row's position in its list.
  ///
  /// The icon that was here was the same on every row — three identical bells
  /// said the rows were notification channels, which the page they are on had
  /// already said. The position is what the rows actually differ by, and for a
  /// notification channel it is also what the agent resolves a withheld
  /// credential against, so a reorder is worth being able to see.
  static Widget index(int idx) {
    return SizedBox.square(
      dimension: 24,
      child: Center(child: Text('${idx + 1}', style: UIs.textGrey)),
    );
  }

  /// The form's row for a list that lives on a page of its own.
  ///
  /// The subtitle is what is inside, which is the server editor's answer for
  /// its environment variables and its disabled commands. A count would say how
  /// many without saying which, and which is what someone came to check.
  static Widget navTile({
    required IconData icon,
    required String title,
    required List<String> names,
    required void Function() onTap,
  }) {
    final filled = names.where((e) => e.isNotEmpty).toList();
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: names.isEmpty
          ? Text(libL10n.empty, style: UIs.textGrey)
          : Text(
              // An unnamed record still has to be counted, or a list of three
              // with two named reads as a list of two.
              [
                ...filled,
                if (filled.length < names.length)
                  '+${names.length - filled.length}',
              ].join(', '),
              style: UIs.textGrey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: onTap,
    ).cardx;
  }
}
