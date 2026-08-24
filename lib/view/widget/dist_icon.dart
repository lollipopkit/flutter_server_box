import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/provider/server/single.dart';

/// Which distribution a server runs, as a glyph beside its name.
///
/// Taken from the server's *status* rather than from its record: nothing in a
/// `Spi` says what is installed on the far end, and the answer only exists
/// once the machine has been asked. So this watches the server's state, and a
/// row for a server that has never connected draws the fallback — which is
/// also what a distribution with no glyph gets, and what an unrecognised
/// `/etc/os-release` gets.
///
/// Single-colour on purpose. These are redrawn glyphs, not each project's own
/// artwork; see `assets/distro/README.md` for where they come from and why
/// using them here needs nobody's permission.
class DistIcon extends ConsumerWidget {
  const DistIcon(this.serverId, {super.key, this.size = 20, this.color});

  /// `Spi.id`. An id and not a `Dist`, so a caller holding only the record it
  /// is listing does not have to reach for the status itself — which most of
  /// them are, since the pickers list servers that may never have connected.
  final String serverId;

  final double size;

  /// Defaults to the row's own foreground colour, at the weight an icon in a
  /// list is drawn at. Tinting is not a change to the mark: an icon font has
  /// always taken the colour it is set in.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dist = ref
        .watch(serverProvider(serverId))
        .status
        .more[StatusCmdType.sys]
        ?.dist;
    return DistIconOf(dist, size: size, color: color);
  }
}

/// [DistIcon] for a caller that already knows the distribution.
///
/// Split out so a widget test, and any code path that has the `Dist` in hand,
/// does not need a provider scope with a server in it.
class DistIconOf extends StatelessWidget {
  const DistIconOf(this.dist, {super.key, this.size = 20, this.color});

  final Dist? dist;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    // A distribution with no glyph, or a server not yet asked: the generic
    // penguin either way. A row whose icon slot is empty reads as a broken
    // row, and guessing at a distribution would be worse than saying nothing.
    final path = dist?.iconPath ?? kUnknownDistIcon;
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      // Named for the reader that speaks the row aloud: the glyph is the only
      // thing on it that says which distribution.
      semanticsLabel: dist?.name ?? 'linux',
    );
  }
}
