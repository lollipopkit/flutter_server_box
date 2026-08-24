/// That every distribution has a glyph, a matcher, and that the matchers are
/// in an order that lets the specific ones win.
///
/// Three ways this goes wrong silently. A renamed case or moved file makes the
/// glyph stop loading, and `SvgPicture.asset` on a missing asset draws nothing
/// rather than throwing. A case added to the enum but not to `_matchers` never
/// matches anything, so its glyph is unreachable. And a derivative listed
/// *after* what it derives from reads as the parent, because "Kubuntu"
/// contains "ubuntu".
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/dist.dart';

/// Read off disk: a test binary has no asset bundle, and the point is what is
/// in the directory rather than what the manifest says about it.
Set<String> _shipped() => {
  for (final f in Directory('assets/distro').listSync())
    if (f.path.endsWith('.svg')) f.uri.pathSegments.last,
};

void main() {
  group('the glyphs', () {
    test('every one a distribution names is actually there', () {
      final shipped = _shipped();
      for (final dist in Dist.values) {
        final path = dist.glyphPath;
        if (path == null) continue;
        expect(
          shipped,
          contains('${dist.name}.svg'),
          reason: '$path is named by Dist.${dist.name} and has to exist',
        );
      }
    });

    test('and every file there is named by a distribution', () {
      // The other direction: a file nothing points at is dead weight in the
      // bundle, and usually a rename done on one side only.
      final named = {
        kLinuxIcon.split('/').last,
        kServerIcon.split('/').last,
        for (final dist in Dist.values)
          if (dist.glyphPath != null) '${dist.name}.svg',
      };
      expect(_shipped(), named);
    });

    test('both fallbacks are shipped too', () {
      // One or the other is reached by every server that has not connected
      // yet, which on a first run is all of them.
      expect(_shipped(), contains(kLinuxIcon.split('/').last));
      expect(_shipped(), contains(kServerIcon.split('/').last));
    });

    test('the ones with no mark of their own say so', () {
      // Two have no glyph in font-logos; the rest are a decision. See
      // Dist.glyphPath and assets/distro/README.md.
      for (final dist in [
        Dist.armbian,
        Dist.coreelec,
        Dist.freebsd,
        Dist.openbsd,
        Dist.netbsd,
        Dist.macos,
        Dist.windows,
      ]) {
        expect(dist.glyphPath, isNull, reason: 'Dist.${dist.name}');
      }
    });

    test('and Apple and Microsoft marks are not shipped at all', () {
      // Apple: the logo may not be used "for any other purpose except
      // pursuant to an express written trademark license". Microsoft requires
      // a licence for any Windows logo. Neither is a fair-use question.
      expect(_shipped(), isNot(contains('macos.svg')));
      expect(_shipped(), isNot(contains('windows.svg')));
      expect(_shipped(), isNot(contains('apple.svg')));
      // Nor the BSD characters, which are copyrighted rather than geometric.
      expect(_shipped(), isNot(contains('freebsd.svg')));
      expect(_shipped(), isNot(contains('openbsd.svg')));
    });

    test('a non-Linux falls back to the machine, not the penguin', () {
      for (final dist in [Dist.freebsd, Dist.openbsd, Dist.macos, Dist.windows]) {
        expect(dist.iconPath, kServerIcon, reason: 'Dist.${dist.name}');
        expect(dist.isLinux, isFalse);
      }
      // And a Linux with no glyph still gets the penguin.
      expect(Dist.armbian.iconPath, kLinuxIcon);
      expect(Dist.coreelec.iconPath, kLinuxIcon);
    });

    test('every case has something to draw', () {
      for (final dist in Dist.values) {
        expect(dist.iconPath, startsWith('assets/distro/'));
      }
    });
  });

  group('the matchers', () {
    // `_matchers` is private, so coverage is proven the way it matters: every
    // case has to be reachable from a name a real machine reports. A case with
    // no matcher, or one shadowed by an earlier entry, fails here.
    test('every case is reachable from some real name', () {
      // One `PRETTY_NAME` per case, written the way the distribution writes
      // it. Anything unreachable here is a matcher that is missing, spelled
      // wrong, or shadowed by an earlier entry.
      const names = {
        Dist.debian: 'Debian GNU/Linux 12 (bookworm)',
        Dist.ubuntu: 'Ubuntu 24.04.1 LTS',
        Dist.centos: 'CentOS Stream 9',
        Dist.fedora: 'Fedora Linux 40 (Server Edition)',
        Dist.opensuse: 'SUSE Linux Enterprise Server 15 SP6',
        Dist.kali: 'Kali GNU/Linux Rolling',
        Dist.wrt: 'OpenWrt 23.05.3',
        Dist.armbian: 'Armbian 24.5.1 bookworm',
        Dist.arch: 'Arch Linux',
        Dist.alpine: 'Alpine Linux v3.20',
        Dist.rocky: 'Rocky Linux 9.4 (Blue Onyx)',
        Dist.deepin: 'Deepin 23',
        Dist.coreelec: 'CoreELEC 21.1',
        Dist.rhel: 'Red Hat Enterprise Linux 9.4 (Plow)',
        Dist.almalinux: 'AlmaLinux 9.4 (Seafoam Ocelot)',
        Dist.nobara: 'Nobara Linux 40',
        Dist.devuan: 'Devuan GNU/Linux 5 (daedalus)',
        Dist.raspbian: 'Raspbian GNU/Linux 11 (bullseye)',
        Dist.mint: 'Linux Mint 21.3',
        Dist.popos: 'Pop!_OS 22.04 LTS',
        Dist.elementary: 'elementary OS 7.1',
        Dist.zorin: 'Zorin OS 17',
        Dist.mx: 'MX Linux 23',
        Dist.kubuntu: 'Kubuntu 24.04',
        Dist.kdeneon: 'KDE neon 6.1',
        Dist.biglinux: 'BigLinux 24',
        Dist.locos: 'LocOS Linux 24',
        Dist.lxle: 'LXLE 18.04',
        Dist.vanilla: 'Vanilla OS 2',
        Dist.manjaro: 'Manjaro Linux',
        Dist.endeavour: 'EndeavourOS',
        Dist.artix: 'Artix Linux',
        Dist.garuda: 'Garuda Linux',
        Dist.cachyos: 'CachyOS',
        Dist.arcolinux: 'ArcoLinux',
        Dist.archcraft: 'Archcraft',
        Dist.archlabs: 'ArchLabs Linux',
        Dist.xerolinux: 'XeroLinux',
        Dist.leap: 'openSUSE Leap 15.6',
        Dist.tumbleweed: 'openSUSE Tumbleweed',
        Dist.parrot: 'Parrot Security 6.1',
        Dist.qubes: 'Qubes OS 4.2',
        Dist.tails: 'Tails 6.6',
        Dist.trisquel: 'Trisquel GNU/Linux 11',
        Dist.parabola: 'Parabola GNU/Linux-libre',
        Dist.hyperbola: 'Hyperbola GNU/Linux-libre 0.4',
        Dist.guix: 'Guix System',
        Dist.gentoo: 'Gentoo Linux',
        Dist.nixos: 'NixOS 24.05 (Uakari)',
        Dist.voidlinux: 'Void Linux',
        Dist.solus: 'Solus 4.5',
        Dist.slackware: 'Slackware 15.0',
        Dist.mageia: 'Mageia 9',
        Dist.mandriva: 'OpenMandriva Lx 5.0',
        Dist.puppy: 'Puppy Linux 9.5',
        Dist.sabayon: 'Sabayon Linux 19.03',
        Dist.aosc: 'AOSC OS',
        Dist.postmarketos: 'postmarketOS 24.06',
        Dist.coreos: 'Fedora CoreOS 40',
        Dist.freebsd: '14.1-RELEASE FreeBSD',
        Dist.openbsd: '7.5 OpenBSD',
        Dist.netbsd: '10.0 NetBSD',
        Dist.illumos: 'OpenIndiana Hipster 2024.04',
        Dist.macos: 'Darwin 24.0.0',
        Dist.windows: 'Microsoft Windows Server 2022',
      };

      for (final dist in Dist.values) {
        expect(
          names.containsKey(dist),
          isTrue,
          reason: 'Dist.${dist.name} has no sample name here',
        );
        expect(
          names[dist]!.dist,
          dist,
          reason: '"${names[dist]}" has to read as Dist.${dist.name}',
        );
      }
    });
  });

  group('the order the derivatives are asked in', () {
    test('a flavour is not read as the base it contains', () {
      // Each of these contains its parent's name. Listed after it, every one
      // of them would draw the parent's glyph.
      expect('Kubuntu 24.04'.dist, Dist.kubuntu);
      expect('Linux Mint 21.3'.dist, Dist.mint);
      expect('openSUSE Leap 15.6'.dist, Dist.leap);
      expect('openSUSE Tumbleweed'.dist, Dist.tumbleweed);
      expect('Archcraft'.dist, Dist.archcraft);
      expect('ArchLabs Linux'.dist, Dist.archlabs);
      expect('ArcoLinux'.dist, Dist.arcolinux);
    });

    test('and the base is still read as itself', () {
      expect('Ubuntu 24.04.1 LTS'.dist, Dist.ubuntu);
      expect('openSUSE 13.2 (Harlequin)'.dist, Dist.opensuse);
      expect('Arch Linux'.dist, Dist.arch);
    });

    test('Fedora CoreOS is CoreOS, not Fedora', () {
      // Both names are in it, and what it runs like is CoreOS.
      expect('Fedora CoreOS 40'.dist, Dist.coreos);
    });
  });

  group('names that never contain the enum name', () {
    test('which is why matching on that alone was dropped', () {
      // Every one of these read as null before the matchers existed.
      expect('Red Hat Enterprise Linux 9.4 (Plow)'.dist, Dist.rhel);
      expect('Linux Mint 21.3'.dist, Dist.mint);
      expect('Pop!_OS 22.04 LTS'.dist, Dist.popos);
      expect('MX Linux 23'.dist, Dist.mx);
      expect('KDE neon 6.1'.dist, Dist.kdeneon);
      expect('Qubes OS 4.2'.dist, Dist.qubes);
      expect('OpenMandriva Lx 5.0'.dist, Dist.mandriva);
      expect('OpenIndiana Hipster 2024.04'.dist, Dist.illumos);
    });

    test('and the OpenWrt downstreams that carry neither name', () {
      expect('iStoreOS 22.03'.dist, Dist.wrt);
      expect('ImmortalWrt 23.05'.dist, Dist.wrt);
      expect('LEDE Reboot 17.01'.dist, Dist.wrt);
      expect(Dist.wrt.glyphPath, isNotNull);
    });

    test('SUSE Linux Enterprise reads as openSUSE, which is its glyph', () {
      // No separate SLES glyph exists, and the chameleon is the right mark.
      expect('SUSE Linux Enterprise Server 15 SP6'.dist, Dist.opensuse);
    });
  });

  test('something unrecognised is null, which draws the penguin', () {
    expect('Some Unknown Linux'.dist, isNull);
    expect(''.dist, isNull);
  });
}
