import 'package:flutter/foundation.dart';

/// Puts the shipped marks' terms where the person running the app can read
/// them: Settings → About → License, which is Flutter's `showLicensePage` over
/// [LicenseRegistry].
///
/// Four of the five are under a Creative Commons licence, and every one of
/// those asks for credit "in any reasonable manner based on the medium, means,
/// and context". For an application that is the licence screen it already has.
/// `LicenseRegistry` collects each package's LICENSE file and nothing else, so
/// an asset is invisible to it until something registers one.
///
/// `assets/distro/README.md` carries the same notices and the reasoning; it
/// ships inside the bundle, because the whole directory is declared as an
/// asset, but nothing renders it — a notice nobody can reach is not one.
void registerDistMarkLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks([_package], _preamble);
    yield const LicenseEntryWithLineBreaks([_package], _debian);
    yield const LicenseEntryWithLineBreaks([_package], _gentoo);
    yield const LicenseEntryWithLineBreaks([_package], _nixos);
    yield const LicenseEntryWithLineBreaks([_package], _alpine);
  });
}

/// One heading for all of them, since they are one thing as far as a reader is
/// concerned: the small marks drawn beside a server's name.
const _package = 'Distribution marks (assets/distro)';

const _preamble = '''
Four distribution logos are shipped with this app. They are the ones whose
artwork carries an explicit copyright licence permitting redistribution and
whose owners do not forbid what is done with it here; every other
distribution's mark is fetched from an address the user configures.

Each is used only to refer to the system it identifies, which is nominative
use. Each remains a trademark of its owner, and a copyright licence is not a
trademark licence. The files are shipped as published — including their
metadata, which is where some of them carry their own attribution — except
where a file could not be parsed at all, which is noted with it below.

Changed: all of them are drawn in a single colour, taking the colour of the
text beside them. Each of the licences above permits modification; none of
these four projects' own terms forbid it.''';

const _debian = '''
The Debian Open Use Logo — (c) the Debian Project.
https://www.debian.org/logos/

Dual licensed under the GNU Lesser General Public License version 3 or later,
or the Creative Commons Attribution-ShareAlike 3.0 Unported License
(https://creativecommons.org/licenses/by-sa/3.0/). Used here under the latter.
Debian asks that the image link to https://www.debian.org/ where it is used on
a web page; this is an application, not a page, and the mark is not a link.

Changed: the file as published is an Adobe Illustrator export whose DTD entity
declarations and Adobe namespace attributes stop it being parsed here. Those
were expanded and removed. The drawing is untouched — every path is
byte-identical to the published file.''';

const _gentoo = '''
The Gentoo "g" signet — (c) Gentoo Foundation and Lennart Andre Rolland.
https://www.gentoo.org/inside-gentoo/artwork/gentoo-logo.html

Licensed under the Creative Commons Attribution-ShareAlike 2.5 License
(https://creativecommons.org/licenses/by-sa/2.5/), which is the licence Gentoo
states for the vector versions of its logo.''';

const _nixos = '''
The NixOS logo — by the NixOS Project and contributors (Simon Frankau, Tim
Cuthbertson, Daniel Baker).
https://github.com/NixOS/nixos-artwork

Licensed under the Creative Commons Attribution 4.0 International License
(https://creativecommons.org/licenses/by/4.0/). The authors' consent to that
licence is recorded in NixOS/branding under docs/provenance/.''';

const _alpine = '''
The Alpine Linux mark — Alpine Linux.
https://alpinelinux.org/

No copyright licence, because none is needed: the mark consists only of simple
geometric shapes, which do not meet the threshold of originality for copyright
protection. It is filed as such on Wikimedia Commons
(https://commons.wikimedia.org/wiki/File:Alpine_Linux.svg). It remains a
trademark of the Alpine Linux Development Team.''';
