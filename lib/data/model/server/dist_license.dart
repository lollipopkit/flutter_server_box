import 'package:flutter/foundation.dart';

/// Puts the distribution marks' terms where the person running the app can
/// read them: Settings → About → License, which is Flutter's `showLicensePage`
/// over [LicenseRegistry].
///
/// `assets/distro/README.md` is where these were worked out, and it ships
/// inside the bundle because the whole directory is declared as an asset — but
/// nothing renders it, so it is not an acknowledgement anyone can reach. Three
/// of the shipped glyphs carry a licence condition, and two of those conditions
/// are the sort that has to reach the recipient of the work:
///
/// - **CC BY 4.0** (`nixos.svg`) asks for credit, a link to the licence and a
///   note of changes, "in any reasonable manner based on the medium, means,
///   and context" — for an application, the licence screen it already has.
/// - **CC-BY-SA-3.0** (`debian.svg`, the other option being LGPL-3+) is the
///   same shape.
/// - **Tux** is conditional — "if someone asks" — so a file in the repository
///   would arguably do. It is here anyway, because the person most likely to
///   ask is looking at the penguin.
///
/// Registered rather than written into a page of its own: the app already has
/// exactly one place users look for this, and a second one would be the place
/// nobody checks.
void registerDistMarkLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks([_package], _fontLogos);
    yield const LicenseEntryWithLineBreaks([_package], _tux);
    yield const LicenseEntryWithLineBreaks([_package], _nixos);
    yield const LicenseEntryWithLineBreaks([_package], _debian);
  });
}

/// One heading for all four, since they are one thing as far as a reader is
/// concerned: the small marks drawn beside each server.
const _package = 'Distribution marks (assets/distro)';

const _fontLogos = '''
The glyphs in assets/distro are taken from font-logos
(https://github.com/lukas-w/font-logos), released into the public domain under
the Unlicense. They are single-colour redraws, further stripped of their
<metadata> and <defs> blocks, and are tinted at the point of drawing.

Each mark is a trademark of its respective owner and is used here only to refer
to the system it identifies. assets/distro/README.md records, per mark, where
each owner's terms were read.''';

const _tux = '''
Tux — the penguin drawn for a Linux whose distribution is not recognised.

Created by Larry Ewing <lewing@isc.tamu.edu> using The GIMP.

  "Permission to use and/or modify this image is granted provided you
   acknowledge me lewing@isc.tamu.edu and The GIMP if someone asks."''';

const _nixos = '''
The NixOS logo — by the NixOS Project and contributors (Simon Frankau, Tim
Cuthbertson, Daniel Baker), from https://github.com/NixOS/branding, licensed
CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).

Changed: this is font-logos' single-colour redraw, further stripped of
<metadata> and <defs>, and tinted by the app at the point of drawing.''';

const _debian = '''
The Debian Open Use Logo — (c) the Debian Project,
https://www.debian.org/logos/, dual licensed under the GNU Lesser General
Public License version 3 or later, or the Creative Commons
Attribution-ShareAlike 3.0 Unported License
(https://creativecommons.org/licenses/by-sa/3.0/). Used here under the latter.

Changed: as above.''';
