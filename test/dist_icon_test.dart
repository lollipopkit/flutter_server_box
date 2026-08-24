/// That every distribution has a glyph, that the two ways of naming one both
/// reach it, and that they are consulted in the right order.
///
/// Four ways this goes wrong silently. A renamed case or moved file makes the
/// glyph stop loading, and `SvgPicture.asset` on a missing asset draws nothing
/// rather than throwing. A case added to the enum but not to `_matchers` never
/// matches anything, so its glyph is unreachable. A derivative listed *after*
/// what it derives from reads as the parent, because "Kubuntu" contains
/// "ubuntu". And a mistyped `ID=` in `_byOsId` is not a failure but a fall
/// through to the prose match, which usually still answers — with the parent.
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

    test('nor the three withdrawn over their owners reserving the logo', () {
      // Each is an original illustration rather than a shape, so redrawing it
      // leaves the copyright where it was; and each owner reserves *logo* use
      // to written permission while allowing the word referentially. Red Hat:
      // "These Guidelines do not give you any permission to use a Red Hat
      // Logo". Raspberry Pi: the logo is for "the sale or distribution of
      // genuine Raspberry Pi products". OffSec offers no fair-use carve-out.
      for (final dist in [Dist.rhel, Dist.raspbian, Dist.kali]) {
        expect(dist.glyphPath, isNull, reason: 'Dist.${dist.name}');
        expect(_shipped(), isNot(contains('${dist.name}.svg')));
        // Still recognised, still expands in a custom logo URL — only the
        // shipped mark is gone.
        expect(dist.iconPath, kLinuxIcon, reason: 'Dist.${dist.name}');
      }
    });

    /// Every mark that ships has to name where its terms were read.
    ///
    /// The whole justification for drawing sixty trademarks was checked once,
    /// against each owner's own words; without this the next glyph gets added
    /// without anyone reading anything, and the README quietly stops being
    /// true of the directory it describes.
    test('every shipped mark has a source in the README', () {
      final readme = File('assets/distro/README.md').readAsStringSync();
      final rows = {
        for (final line in readme.split('\n'))
          if (line.startsWith('| ') && line.contains('](http'))
            line.split('|')[1].trim().replaceAll('*', ''): line,
      };

      for (final name in _shipped().map((f) => f.replaceAll('.svg', ''))) {
        // `server.svg` is this app's own drawing and refers to nobody.
        if (name == kServerIcon.split('/').last.replaceAll('.svg', '')) continue;
        expect(
          rows.keys,
          contains(name),
          reason:
              '$name.svg ships with no row in the README table — record where '
              'its trademark and licence terms were read before adding it',
        );
      }
    });

    test('a distribution with no glyph is still a distribution', () {
      // The enum names every one it can identify; the glyph set is the subset
      // somebody will be looking at. Removing a case would break `{DIST}` in a
      // user's custom logo URL, so dropping a mark never removes one.
      expect(Dist.values.length, greaterThan(_shipped().length));
      expect('Puppy Linux 9.5'.dist, Dist.puppy);
      expect(resolveDist(osId: 'qubes'), Dist.qubes);
      expect(Dist.puppy.glyphPath, isNull);
      expect(Dist.puppy.iconPath, kLinuxIcon);
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

    /// What `scripts/normalize_distro_svg.dart` exists to remove.
    ///
    /// flutter_svg draws none of it and logs `unhandled element <metadata/>`
    /// once per run for the trouble. Left here because the files are otherwise
    /// verbatim from font-logos, so a glyph added by copying one in brings it
    /// back — and the only symptom is a line in a debug console.
    group('the files are normalised', () {
      final shipped = Directory('assets/distro')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.svg'));

      test('no <metadata>, which describes the wrong work anyway', () {
        // Inherited from whatever document each glyph was traced in, and it
        // does not follow the tracing: `elementary.svg` carried Gentoo's,
        // `voidlinux.svg` carried AOSC's, `artix.svg` claimed CC BY-NC-SA.
        // None of that is the licence this directory rests on — see README.md.
        for (final file in shipped) {
          expect(
            file.readAsStringSync(),
            isNot(contains('<metadata')),
            reason: '${file.path}: run dart run scripts/normalize_distro_svg.dart',
          );
        }
      });

      test('no <defs>, and nothing left pointing into one', () {
        for (final file in shipped) {
          final svg = file.readAsStringSync();
          expect(
            svg,
            isNot(contains('<defs')),
            reason: '${file.path}: run dart run scripts/normalize_distro_svg.dart',
          );
          // The removal is only safe because nothing referenced what was in
          // there. A `url(#…)` surviving it would be a glyph drawing part of
          // itself in the wrong colour, or not at all.
          expect(
            RegExp(r'url\(#|href="#').hasMatch(svg),
            isFalse,
            reason: '${file.path} references an id that is no longer defined',
          );
        }
      });

      test('no CSS, which flutter_svg does not apply', () {
        // `puppy.svg` was the one: a `<style>` block whose `.fil9 {fill:black}`
        // was the only rule any drawn element used, plus four gradients named
        // by classes nothing carried. A `class` with no stylesheet is inert in
        // every renderer, so both go — see the script for the guard that stops
        // a rule with real effect being dropped silently.
        for (final file in shipped) {
          final svg = file.readAsStringSync();
          expect(svg, isNot(contains('<style')), reason: file.path);
          expect(svg, isNot(contains('class="')), reason: file.path);
        }
      });
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

  group('the os-release ids', () {
    // The same table `_byOsId` holds, written the other way round. `_byOsId` is
    // private, so this is what proves an entry is reachable — and a `const` map
    // cannot hold the same key twice, so nothing here can be shadowed.
    const ids = {
      'debian': Dist.debian,
      'ubuntu': Dist.ubuntu,
      'centos': Dist.centos,
      'fedora': Dist.fedora,
      'kali': Dist.kali,
      'alpine': Dist.alpine,
      'rocky': Dist.rocky,
      'deepin': Dist.deepin,
      'coreelec': Dist.coreelec,
      'opensuse': Dist.opensuse,
      'suse': Dist.opensuse,
      'sles': Dist.opensuse,
      'sled': Dist.opensuse,
      'sles_sap': Dist.opensuse,
      'opensuse-microos': Dist.opensuse,
      'opensuse-leap': Dist.leap,
      'opensuse-tumbleweed': Dist.tumbleweed,
      'openwrt': Dist.wrt,
      'lede': Dist.wrt,
      'immortalwrt': Dist.wrt,
      'istoreos': Dist.wrt,
      'rhel': Dist.rhel,
      'almalinux': Dist.almalinux,
      'nobara': Dist.nobara,
      'devuan': Dist.devuan,
      'raspbian': Dist.raspbian,
      'linuxmint': Dist.mint,
      'pop': Dist.popos,
      'elementary': Dist.elementary,
      'zorin': Dist.zorin,
      'mx': Dist.mx,
      'neon': Dist.kdeneon,
      'biglinux': Dist.biglinux,
      'vanilla': Dist.vanilla,
      'arch': Dist.arch,
      'archarm': Dist.arch,
      'manjaro': Dist.manjaro,
      'manjaro-arm': Dist.manjaro,
      'endeavouros': Dist.endeavour,
      'artix': Dist.artix,
      'garuda': Dist.garuda,
      'cachyos': Dist.cachyos,
      'arcolinux': Dist.arcolinux,
      'archcraft': Dist.archcraft,
      'archlabs': Dist.archlabs,
      'xerolinux': Dist.xerolinux,
      'parrot': Dist.parrot,
      'qubes': Dist.qubes,
      'tails': Dist.tails,
      'trisquel': Dist.trisquel,
      'parabola': Dist.parabola,
      'hyperbola': Dist.hyperbola,
      'guix': Dist.guix,
      'gentoo': Dist.gentoo,
      'nixos': Dist.nixos,
      'void': Dist.voidlinux,
      'solus': Dist.solus,
      'slackware': Dist.slackware,
      'mageia': Dist.mageia,
      'mandriva': Dist.mandriva,
      'openmandriva': Dist.mandriva,
      'sabayon': Dist.sabayon,
      'aosc': Dist.aosc,
      'postmarketos': Dist.postmarketos,
      'coreos': Dist.coreos,
      'flatcar': Dist.coreos,
    };

    test('each one resolves to the distribution that sets it', () {
      ids.forEach((id, dist) {
        expect(
          resolveDist(osId: id),
          dist,
          reason: 'ID=$id has to read as Dist.${dist.name}',
        );
      });
    });

    test('an id nothing knows is not answered with a guess', () {
      // Silence here is the point of matching on `ID` at all: it is exact, so
      // there is no near miss to fall into. What happens next is the prose.
      expect(resolveDist(osId: 'frobnix'), isNull);
    });

    test('older Deepin capitalises its own id, and is still Deepin', () {
      // `ID=Deepin` shipped for several releases. os-release restricts the
      // field to lower case; the file does not always agree.
      expect(resolveDist(osId: 'Deepin'), Dist.deepin);
    });

    test('a flavour that ships its parent os-release reads as the parent', () {
      // Kubuntu and LXLE both set `ID=ubuntu`, so nothing here can tell them
      // apart — and inventing an entry for them would be inventing a file.
      expect(resolveDist(osId: 'ubuntu'), Dist.ubuntu);
    });
  });

  group('which of the three sources wins', () {
    test('the id beats the prose', () {
      // The prose is what this used to match on, so a disagreement is the
      // regression to catch: `ID` is the field written to be matched.
      expect(
        resolveDist(osId: 'rhel', sysVersion: 'Red Hat Enterprise Linux 9.4'),
        Dist.rhel,
      );
      expect(
        resolveDist(osId: 'linuxmint', sysVersion: 'Ubuntu 22.04.3 LTS'),
        Dist.mint,
      );
    });

    test('the prose beats ID_LIKE, which names the parent', () {
      // Ubuntu Core: no `ID` this knows, and its base would answer if asked
      // first. The prose names what is actually installed.
      expect(
        resolveDist(
          osId: 'ubuntu-core',
          sysVersion: 'Ubuntu Core 22',
          osIdLike: const ['debian'],
        ),
        Dist.ubuntu,
      );
    });

    test('ID_LIKE answers when nothing else does', () {
      // A derivative nothing here has heard of. Its base is a better mark than
      // the generic penguin, and the intro page says the mark is what the
      // machine *may* be running.
      expect(
        resolveDist(
          osId: 'frobnix',
          sysVersion: 'Frobnix 1.0',
          osIdLike: const ['debian'],
        ),
        Dist.debian,
      );
    });

    test('and the closest base in ID_LIKE is the one taken', () {
      // `ID_LIKE="ubuntu debian"` is ordered nearest-first, and Ubuntu is the
      // more specific of the two.
      expect(
        resolveDist(osId: 'frobnix', osIdLike: const ['ubuntu', 'debian']),
        Dist.ubuntu,
      );
      // An entry nothing knows is skipped rather than ending the search.
      expect(
        resolveDist(osId: 'frobnix', osIdLike: const ['nonesuch', 'debian']),
        Dist.debian,
      );
    });

    test('nothing at all is null, as before', () {
      expect(resolveDist(), isNull);
      expect(resolveDist(osIdLike: const ['nonesuch']), isNull);
    });

    test('a remote with no os-release still reads by its prose alone', () {
      // The `/etc/*-release` fallback, and every `monitor` agent predating the
      // field: `PRETTY_NAME` is the whole of what arrives.
      expect(
        resolveDist(sysVersion: 'Red Hat Enterprise Linux 9.4 (Plow)'),
        Dist.rhel,
      );
      expect(resolveDist(sysVersion: 'iStoreOS 22.03'), Dist.wrt);
    });

    test('Fedora CoreOS is Fedora once it is asked by id', () {
      // A deliberate change of answer, not a regression: it sets `ID=fedora`,
      // with `coreos` only in `VARIANT_ID`. The prose match still reads the
      // name, which is what an agent that sends nothing else falls back to.
      expect(
        resolveDist(osId: 'fedora', sysVersion: 'Fedora CoreOS 40'),
        Dist.fedora,
      );
      expect(resolveDist(sysVersion: 'Fedora CoreOS 40'), Dist.coreos);
      // Flatcar, its successor, has an id of its own and keeps the mark.
      expect(resolveDist(osId: 'flatcar'), Dist.coreos);
    });
  });
}
