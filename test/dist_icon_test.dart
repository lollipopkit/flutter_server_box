/// That a distribution is recognised, and that the three ways of naming one
/// are consulted in the right order.
///
/// Three ways this goes wrong silently. A case added to the enum but not to
/// `_matchers` never matches anything. A derivative listed *after* what it
/// derives from reads as the parent, because "Kubuntu" contains "ubuntu". And
/// a mistyped `ID=` in `_byOsId` is not a failure but a fall through to the
/// prose match, which usually still answers — with the parent.
///
/// The app ships five marks and fetches the rest from an address; what a
/// recognised distribution turns into is `test/dist_mark_url_test.dart`.
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
  /// Four files, and every one of them a claim that somebody's licence permits
  /// shipping it. The claim is only as good as the record beside it, so the
  /// file, the enum, the README row and the in-app notice all have to agree —
  /// a mark added to four of the five is a mark shipped without one of them.
  group('the shipped marks', () {
    const bundled = {Dist.debian, Dist.gentoo, Dist.nixos, Dist.alpine};

    test('each one names a file that is there', () {
      for (final dist in bundled) {
        expect(dist.markAsset, isNotNull, reason: 'Dist.${dist.name}');
        expect(_shipped(), contains('${dist.name}.svg'));
      }
    });

    test('and every file there is named by one of them', () {
      // A file nothing points at is bundle weight, and — worse here — a logo
      // being redistributed with nothing recording why that is allowed.
      expect(_shipped(), {for (final d in bundled) '${d.name}.svg'});
    });

    test('the set is what `markAsset` answers for, and nothing else', () {
      // The literal set above is deliberate: derived from `Dist.markAsset` it
      // would agree with whatever the code says, including when the code is
      // wrong. This is the direction that catches a file shipped without a
      // licence recorded for it.
      expect(
        {for (final d in Dist.values) if (d.markAsset != null) d},
        bundled,
      );
    });

    test('everything else has no mark and is not meant to', () {
      // Ubuntu, Fedora, Arch and openSUSE are the ones people will ask about.
      // Each permits referring to it and reserves the artwork; see README.md.
      for (final dist in [
        Dist.ubuntu,
        Dist.fedora,
        Dist.arch,
        Dist.opensuse,
        Dist.rhel,
        Dist.kali,
        // Rocky is the one dropped for a different reason: its licence does
        // permit redistribution, and its trademark policy says the mark may
        // not be altered "in any way" — which is what drawing it in one
        // colour is.
        Dist.rocky,
      ]) {
        expect(dist.markAsset, isNull, reason: 'Dist.${dist.name}');
      }
    });

    test('each has a row in the README recording its licence', () {
      final readme = File('assets/distro/README.md').readAsStringSync();
      for (final dist in bundled) {
        expect(
          readme,
          contains('| ${dist.name} |'),
          reason:
              '${dist.name}.svg ships with no row in the README table — record '
              'the licence that permits redistributing it before adding it',
        );
      }
    });

    test('and a notice in the app, which is where attribution is discharged', () {
      // CC BY and CC BY-SA both ask for credit reachable by the recipient of
      // the work. A README inside the bundle that nothing renders is not that.
      final notices = File(
        'lib/data/model/server/dist_license.dart',
      ).readAsStringSync();
      for (final dist in bundled) {
        expect(
          notices.toLowerCase(),
          contains(dist.name),
          reason: 'Dist.${dist.name} has no entry in the licence registry',
        );
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
      // of them would read as the parent.
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
    });

    test('SUSE Linux Enterprise reads as openSUSE', () {
      // There is no separate SLES case, and openSUSE is the closest true one.
      expect('SUSE Linux Enterprise Server 15 SP6'.dist, Dist.opensuse);
    });
  });

  test('something unrecognised is null, and nothing is drawn', () {
    expect('Some Unknown Linux'.dist, isNull);
    expect(''.dist, isNull);
  });

  group('a name that merely spells another one inside it', () {
    // The prose matcher works by looking for a name in a sentence, so the
    // short entries are the dangerous ones. Every case here resolved to the
    // wrong distribution when the match was a plain `contains`, and a wrong
    // mark is worse than none: it is a claim about a machine rather than an
    // absence of one.
    test('is not read as that one', () {
      expect('Details Linux'.dist, isNull, reason: 'de-tails');
      expect('Linguix 1.0'.dist, isNull, reason: 'lin-guix');
      expect('Absolus 3'.dist, isNull, reason: 'ab-solus');
      expect('Retails Server'.dist, isNull, reason: 're-tails');
      expect('Amxinux'.dist, isNull);
    });

    test('while the names themselves still are', () {
      // The other half: a boundary rule that blocked these would be worse
      // than the collisions it prevents.
      expect('Tails 6.6'.dist, Dist.tails);
      expect('Guix System'.dist, Dist.guix);
      expect('Solus 4.5'.dist, Dist.solus);
      // Punctuation counts as a boundary, which is what lets a needle carry
      // its own — `pop!_os` is one word to this.
      expect('Pop!_OS 22.04 LTS'.dist, Dist.popos);
      expect('KDE neon 6.1'.dist, Dist.kdeneon);
    });

    test('and a flavour that spells its base inside itself still resolves', () {
      // The other side of the trade. `xubuntu` no longer contains `ubuntu` as
      // a word, so every flavour that was found that way is named outright —
      // which is more honest anyway, since it says which ones are known.
      expect('Xubuntu 20.04'.dist, Dist.ubuntu);
      expect('Lubuntu 24.04'.dist, Dist.ubuntu);
      expect('Ubuntu MATE 24.04'.dist, Dist.ubuntu);
      // And one that is not listed reads as nothing rather than as Ubuntu.
      expect('Fooubuntu 1.0'.dist, isNull);
    });

    test('and a name spelled inside another is listed in its own right', () {
      // `mandriva` used to be found inside `openmandriva` by accident. Both
      // are needles now, because relying on that was the bug above.
      expect('OpenMandriva Lx 5.0'.dist, Dist.mandriva);
      expect('Mandriva Linux 2011'.dist, Dist.mandriva);
    });
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
