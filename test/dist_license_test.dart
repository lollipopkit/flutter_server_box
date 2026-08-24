/// That the three marks carrying a licence condition say so somewhere the
/// person running the app can read.
///
/// `assets/distro/README.md` is where the terms were worked out, and it ships
/// inside the bundle because the whole directory is an asset — but nothing
/// renders it, so on its own it is an acknowledgement no user can reach. CC BY
/// 4.0 (NixOS) and CC-BY-SA-3.0 (Debian) both ask for credit "in any
/// reasonable manner based on the medium", and for an application the medium
/// is the licence screen it already has: Settings -> About -> License, which
/// is `showLicensePage` over `LicenseRegistry`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/dist_license.dart';

void main() {
  late List<LicenseEntry> entries;

  setUpAll(() async {
    registerDistMarkLicenses();
    entries = await LicenseRegistry.licenses
        .where((e) => e.packages.any((p) => p.contains('assets/distro')))
        .toList();
  });

  String textOf(LicenseEntry e) => e.paragraphs.map((p) => p.text).join('\n');

  test('the registry carries them at all', () {
    expect(entries, isNotEmpty, reason: 'registerDistMarkLicenses did nothing');
  });

  test('Tux names its author, which is the whole of the condition', () {
    // "provided you acknowledge me lewing@isc.tamu.edu and The GIMP if
    // someone asks" — both names have to be in there, not just the penguin.
    final all = entries.map(textOf).join('\n');
    expect(all, contains('Larry Ewing'));
    expect(all, contains('lewing@isc.tamu.edu'));
    expect(all, contains('The GIMP'));
  });

  test('NixOS gets credit, a licence link and a note of changes', () {
    // The three things CC BY 4.0 asks for. Dropping any one of them is the
    // failure mode this exists to catch, and it is silent.
    final nixos = entries.map(textOf).firstWhere((t) => t.contains('NixOS'));
    expect(nixos, contains('CC BY 4.0'));
    expect(nixos, contains('creativecommons.org/licenses/by/4.0'));
    expect(nixos, contains('Changed:'));
  });

  test('Debian says which of its two licences is being relied on', () {
    // Dual licensed LGPL-3+ or CC-BY-SA-3.0. Naming both without picking one
    // leaves the share-alike question unanswered.
    final debian = entries.map(textOf).firstWhere((t) => t.contains('Debian'));
    expect(debian, contains('CC BY-SA 3.0').or(contains('Attribution-ShareAlike 3.0')));
    expect(debian, contains('Changed:'));
  });

  test('font-logos and the trademark note are there too', () {
    final all = entries.map(textOf).join('\n');
    expect(all, contains('font-logos'));
    expect(all, contains('Unlicense'));
    // The sentence that keeps the whole arrangement honest.
    expect(all, contains('trademark of its respective owner'));
  });
}

extension _Or on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
