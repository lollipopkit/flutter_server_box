import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';

/// One thing the walkthrough has to say, and which keys it is about.
///
/// [group] null means the step is about the terminal rather than the row, and
/// nothing in the row is singled out.
///
/// A [GuideStep] plus that group. The scrim and the card are [GuideView]'s,
/// and the group is not something it could know: the keys are the `Scaffold`'s
/// bottom bar, outside what the guide covers, and dimming the ones this step
/// is not about is the page's own job.
///
/// Three kinds of key and not seventeen keys. A step each would be a tour
/// nobody finishes, and what is worth knowing is which of them type, which
/// move the cursor, and which leave the terminal altogether.
final class VirtKeyIntroStep {
  const VirtKeyIntroStep({
    required this.title,
    required this.body,
    this.group,
  });

  final String title;
  final String body;
  final VirtKeyGroup? group;

  /// No `spot`: what this points at is outside the area the guide covers, so
  /// there is nothing to cut a hole for.
  GuideStep get guide => GuideStep(title: title, body: body);

  /// Read where they are shown, not once at startup: the app's locale can
  /// change while a terminal is open, and a list built at launch would still
  /// be in the language it launched in.
  static List<VirtKeyIntroStep> of(BuildContext context) {
    final l10n = context.l10n;
    return [
      VirtKeyIntroStep(
        title: context.libL10n.terminal,
        body: l10n.virtKeyIntroSelect,
      ),
      VirtKeyIntroStep(
        title: l10n.virtKeyIntroModifiers,
        body: l10n.virtKeyIntroModifiersTip,
        group: VirtKeyGroup.modifiers,
      ),
      VirtKeyIntroStep(
        title: l10n.virtKeyIntroNav,
        body: l10n.virtKeyIntroNavTip,
        group: VirtKeyGroup.navigation,
      ),
      VirtKeyIntroStep(
        title: l10n.virtKeyIntroActions,
        body: l10n.virtKeyIntroActionsTip,
        group: VirtKeyGroup.shortcuts,
      ),
      VirtKeyIntroStep(
        title: l10n.editVirtKeys,
        body: l10n.virtKeyIntroCustomizeTip,
      ),
    ];
  }
}
