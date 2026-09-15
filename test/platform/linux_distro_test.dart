import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/rootfs.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/linux_distros.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

/// What a distribution has to answer, and what the marker on disk means.
///
/// The marker is the part worth locking. It gets one read per launch, it is
/// never rewritten, and a wrong answer is silent: a tree read as the wrong
/// distribution would have `apt` sources written into an Alpine, or an update
/// offered against a version that is not a version of what is installed.
///
/// Its older shapes are locked too, because they exist on devices. A release
/// that wrote a bare version string is what almost every install out there came
/// from, and the day a second distribution ships is the day misreading those
/// starts to matter.
void main() {
  // Every value below now comes from the manifest rather than a switch, and
  // `Rootfs.prepare` is what loads it in the app. A test has no asset bundle,
  // so it reads the same file off disk.
  setUpAll(() {
    LinuxDistros.adopt(
      RootfsManifest.parse(File(LinuxDistros.bundledAsset).readAsStringSync()),
    );
  });

  group('a distribution', () {
    test('answers with a label, a version and a digest', () {
      for (final distro in LinuxDistro.values) {
        expect(distro.label, isNotEmpty, reason: '${distro.id} label');
        expect(distro.version, isNotEmpty, reason: '${distro.id} version');
        expect(distro.releases, isNotEmpty, reason: '${distro.id} releases');
        // Every release, not just the preferred one. A second release is
        // installable the moment the manifest lists it, so an unpinned one is
        // reachable without anything here changing.
        for (final release in distro.releases) {
          final where = '${distro.id} ${release.version}';
          expect(release.version, isNotEmpty, reason: where);
          expect(release.branch, isNotEmpty, reason: '$where branch');
          expect(
            release.source.sha256,
            hasLength(64),
            reason:
                '$where has to pin a sha256 — the tarball is executable '
                'code, and the digest is what makes downloading it different '
                'from running whatever the connection returned',
          );
        }
      }
    });

    test('offers no two releases of one series', () {
      // Two builds of `noble` in the list would be one picker row replacing
      // another, and `newestIn` answering with whichever the manifest happened
      // to put last. The repository publishes one build per series and this is
      // what says so.
      for (final distro in LinuxDistro.values) {
        final branches = distro.releases.map((e) => e.branch).toList();
        expect(branches.toSet(), hasLength(branches.length), reason: distro.id);
        final versions = distro.releases.map((e) => e.version).toList();
        expect(versions.toSet(), hasLength(versions.length), reason: distro.id);
      }
    });

    test('takes its preferred release as the first listed', () {
      // Order in the manifest is the offer: the first is what a plain install
      // gets. Sorting here instead would mean the app deciding which of two
      // releases is newer from their version strings, which is a comparison
      // no two distributions spell the same way.
      for (final distro in LinuxDistro.values) {
        expect(distro.preferred, distro.releases.first, reason: distro.id);
        expect(distro.version, distro.releases.first.version);
      }
    });

    test('has a default mirror that is a URL', () {
      for (final distro in LinuxDistro.values) {
        final url = Uri.tryParse(distro.defaultMirror);
        expect(url?.isScheme('https'), isTrue, reason: distro.id);
        expect(
          distro.defaultMirror.endsWith('/'),
          isFalse,
          reason: 'callers join a path onto this',
        );
      }
    });

    test('builds its tarball URL under the mirror it is given', () {
      for (final distro in LinuxDistro.values) {
        for (final release in distro.releases) {
          if (!release.source.followsMirror) continue;
          expect(
            distro.rootfsUrl('https://mirror.example/x', release: release),
            startsWith('https://mirror.example/x/'),
            reason:
                '${distro.id} ${release.version} must honour a mirror, or '
                'the setting does nothing',
          );
        }
      }
    });

    test('says so when it cannot honour the mirror for its tarball', () {
      // The exception has to be declared rather than discovered. Ubuntu's base
      // tarballs are on cdimage and its packages on archive, so one mirror
      // string cannot name both — and a distribution that quietly ignored the
      // setting would look identical to one that honoured a broken one.
      for (final distro in LinuxDistro.values) {
        for (final release in distro.releases) {
          if (release.source.followsMirror) continue;
          final where = '${distro.id} ${release.version}';
          final url = distro.rootfsUrl(
            'https://mirror.example/x',
            release: release,
          );
          expect(url, isNot(contains('mirror.example')), reason: where);
          expect(Uri.parse(url).isScheme('https'), isTrue, reason: where);
          // The setting still has to reach the packages, which is the half it
          // was actually set for.
          expect(
            distro
                .repositories('https://mirror.example/x', release: release)
                .content,
            contains('https://mirror.example/x'),
            reason: where,
          );
        }
      }
    });

    test('names a repositories file under etc, with something in it', () {
      for (final distro in LinuxDistro.values) {
        final repo = distro.repositories('https://mirror.example/x');
        expect(repo.path, startsWith('etc/'), reason: distro.id);
        expect(repo.path.startsWith('/'), isFalse, reason: 'joined to a root');
        expect(repo.content, contains('https://mirror.example/x'));
        expect(repo.content, endsWith('\n'));
      }
    });

    test('writes the repositories of the release being installed', () {
      // The one thing a second release of a distribution changes that is not
      // just a URL. A system unpacked from `noble` with `resolute` sources in
      // it installs packages built against a different libc version and finds
      // out at the first upgrade.
      for (final distro in LinuxDistro.values) {
        for (final release in distro.releases) {
          expect(
            distro.repositories('https://m.test/x', release: release).content,
            contains(release.branch),
            reason: '${distro.id} ${release.version} → ${release.branch}',
          );
        }
      }
    });

    test("Alpine's is apk's, pinned to its branch", () {
      final repo = LinuxDistro.alpine.repositories('https://m');
      expect(repo.path, 'etc/apk/repositories');
      expect(repo.content, 'https://m/v3.22/main\nhttps://m/v3.22/community\n');
    });

    test('is read back by name', () {
      for (final distro in LinuxDistro.values) {
        expect(LinuxDistro.fromName(distro.id), distro);
      }
    });

    test('falls back to Alpine for a name no build knows', () {
      // A store or a marker written by a build that had more of them. Throwing
      // here would lose an installed system over a string.
      expect(LinuxDistro.fromName('plan9'), LinuxDistro.alpine);
      expect(LinuxDistro.fromName(null), LinuxDistro.alpine);
      expect(LinuxDistro.fromName(''), LinuxDistro.alpine);
    });
  });

  group('what the install dialog is told', () {
    test('the size is never smaller than the download', () {
      // The dialog is answered before anything is fetched, so this number is
      // pinned rather than measured. Measured once, against what the servers
      // report: 3.8, 33.5 and 80.8 MB. Rounding down would understate a
      // download on a metered connection.
      const measured = {
        LinuxDistro.alpine: 3.8,
        LinuxDistro.ubuntu: 33.5,
        LinuxDistro.rocky: 80.8,
      };
      for (final distro in LinuxDistro.values) {
        final actual = measured[distro];
        expect(actual, isNotNull, reason: '${distro.id} has no measured size');
        expect(
          distro.preferred.source.sizeMb,
          greaterThanOrEqualTo(actual!.ceil()),
          reason: distro.id,
        );
      }
    });

    test('every release states its own size', () {
      // Told before anything is fetched, and read off the release the user
      // picked rather than off the distribution. Two releases of one system
      // are not the same download — 24.04 is a third of 26.04 — and a number
      // taken from the preferred one would be wrong for every other row.
      for (final distro in LinuxDistro.values) {
        for (final release in distro.releases) {
          expect(
            release.source.sizeBytes,
            greaterThan(0),
            reason: '${distro.id} ${release.version}',
          );
          expect(release.source.sizeMb, greaterThan(0));
        }
      }
    });

    test('the three sizes are not interchangeable', () {
      // The string used to say "about 3 MB" for whichever was installed, which
      // was true of Alpine alone. If they were all close this would not matter.
      expect(
        LinuxDistro.ubuntu.preferred.source.sizeMb,
        greaterThan(LinuxDistro.alpine.preferred.source.sizeMb * 5),
      );
      expect(
        LinuxDistro.rocky.preferred.source.sizeMb,
        greaterThan(LinuxDistro.ubuntu.preferred.source.sizeMb * 2),
      );
    });

    test('each names the package manager it actually ships', () {
      // Told to someone whose system is about to be replaced, so it has to be
      // the command they have been typing.
      expect(LinuxDistro.alpine.packageManager, 'apk');
      expect(LinuxDistro.ubuntu.packageManager, 'apt');
      expect(LinuxDistro.rocky.packageManager, 'dnf');
    });
  });

  group('how a download is packed', () {
    test('the file name matches the compression each declares', () {
      // These two are read before anything looks at the bytes, so a mismatch
      // is a decoder fed the wrong format rather than a clear failure.
      for (final distro in LinuxDistro.values) {
        for (final release in distro.releases) {
          expect(
            distro.rootfsUrl(distro.defaultMirror, release: release),
            endsWith(switch (release.source.compression) {
              LinuxRootfsCompression.gzip => '.tar.gz',
              LinuxRootfsCompression.xz => '.tar.xz',
            }),
            reason: '${distro.id} ${release.version}',
          );
        }
      }
    });

    test('only Rocky is an image layout', () {
      expect(
        LinuxDistro.alpine.preferred.source.layout,
        LinuxRootfsLayout.plain,
      );
      expect(
        LinuxDistro.ubuntu.preferred.source.layout,
        LinuxRootfsLayout.plain,
      );
      // Rocky publishes no plain rootfs tarball, only an OCI image.
      expect(LinuxDistro.rocky.preferred.source.layout, LinuxRootfsLayout.oci);
      expect(
        LinuxDistro.rocky.preferred.source.compression,
        LinuxRootfsCompression.xz,
      );
    });
  });

  group("Ubuntu's sources", () {
    test('are deb822, which is what 26.04 reads', () {
      // 26.04 ships `sources.list.d/ubuntu.sources` and an empty
      // `sources.list`; writing the one-line form to the old path would leave
      // both in play.
      final repo = LinuxDistro.ubuntu.repositories('https://m.test/ubuntu');
      expect(repo.path, 'etc/apt/sources.list.d/ubuntu.sources');
      expect(repo.content, startsWith('Types: deb\n'));
    });

    test('name the keyring the image already carries', () {
      // Without it apt rejects the release file it just fetched, which reads
      // as a broken mirror rather than a missing setting.
      expect(
        LinuxDistro.ubuntu.repositories('https://m.test/ubuntu').content,
        contains('Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg'),
      );
    });

    test('take security from the mirror too, since it is a pocket of it', () {
      // Derived from the release rather than spelled out: the suite moves
      // whenever the preferred release does, and a hardcoded `resolute` would
      // have to be edited to keep a test passing that is not about which
      // suite it is.
      for (final release in LinuxDistro.ubuntu.releases) {
        expect(
          LinuxDistro.ubuntu
              .repositories('https://m.test/ubuntu', release: release)
              .content,
          contains('${release.branch}-security'),
          reason: release.version,
        );
      }
    });
  });

  group("Rocky's repos", () {
    test('pin a dated build rather than the moving .latest. file', () {
      // The same directory offers `Rocky-9-Container-Base.latest.…`, whose
      // bytes change whenever Rocky rebuilds. The pinned digest does not, so
      // every install would start failing until the app shipped an update.
      final url = LinuxDistro.rocky.rootfsUrl(LinuxDistro.rocky.defaultMirror);
      expect(url, isNot(contains('.latest.')));
      expect(url, contains('9.8-20260525.0'));
    });

    test('leave no dnf variable unexpanded', () {
      // `$basearch` and `$releasever` are dnf's, not Dart's. Written into a
      // Dart string they would either interpolate to nothing or survive
      // verbatim, and a baseurl carrying a literal `$basearch` is a silent 404
      // at the first `dnf install` rather than an error here.
      final repo = LinuxDistro.rocky.repositories('https://m.test/rocky');
      expect(repo.path, 'etc/yum.repos.d/rocky.repo');
      expect(repo.content, isNot(contains(r'$')));
      expect(repo.content, contains('aarch64'));
    });

    test('replace the mirrorlist repos an install pulls from', () {
      final content = LinuxDistro.rocky
          .repositories('https://m.test/rocky')
          .content;
      for (final section in ['[baseos]', '[appstream]', '[crb]']) {
        expect(content, contains(section));
      }
      // Whatever it writes must not reintroduce the service it replaces.
      expect(content, isNot(contains('mirrorlist')));
      // CRB is off by default on Rocky; enabling it here would be a change
      // nobody asked for.
      expect(content, contains('enabled=0'));
    });

    test('keep signature checking against the key in the image', () {
      // The key file is named for the major version, so it is read off the
      // release for the reason Ubuntu's suite is: which one is preferred is
      // not what this test is about.
      for (final release in LinuxDistro.rocky.releases) {
        final content = LinuxDistro.rocky
            .repositories('https://m.test/rocky', release: release)
            .content;
        expect(content, contains('gpgcheck=1'), reason: release.version);
        expect(
          content,
          contains(
            'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-${release.branch}',
          ),
          reason: release.version,
        );
      }
    });
  });

  group('whether a profile is outdated', () {
    LinuxProfile of(LinuxDistro distro, String version, {String branch = ''}) =>
        LinuxProfile(
          id: distro.id,
          distro: distro,
          version: version,
          label: distro.label,
          branch: branch,
        );

    test('it is the version, not the platform, that decides', () {
      // This answered `isAndroid && …` until the gate was found to be residue.
      // It was right when written — IosRootfs.version was a compile-time
      // constant then, so iOS recorded nothing about what was on disk — and
      // wrong ever since profiles started carrying a versioned marker on both
      // platforms. iOS never offered an update for a system that had one.
      //
      // Nothing here is platform-specific, which is the point: the same two
      // fields decide it wherever the test runs.
      for (final distro in LinuxDistro.values) {
        expect(
          Rootfs.isOutdated(of(distro, distro.version)),
          isFalse,
          reason: '${distro.id} matches what would be installed',
        );
        expect(
          Rootfs.isOutdated(of(distro, '0.0.1')),
          isTrue,
          reason: '${distro.id} is older than what would be installed',
        );
      }
    });

    test('a distribution the manifest no longer describes is not outdated', () {
      // A marker outlives any manifest that stops describing its distribution.
      // There is nothing to offer as an update, and asking for a version would
      // throw rather than guess.
      LinuxDistros.adopt(
        RootfsManifest.parse(
          File(
            LinuxDistros.bundledAsset,
          ).readAsStringSync().replaceFirst('"rocky": {', '"rocky-gone": {'),
        ),
      );
      addTearDown(() {
        LinuxDistros.adopt(
          RootfsManifest.parse(
            File(LinuxDistros.bundledAsset).readAsStringSync(),
          ),
        );
      });

      expect(Rootfs.isOutdated(of(LinuxDistro.rocky, '0.0.1')), isFalse);
    });

    test('an older series is not an outdated one', () {
      // The distinction the whole `branch` field exists for. Someone who
      // installed 24.04 chose 24.04; offering them 26.04 as an *update* would
      // destroy everything in the system while calling it a version bump. The
      // newest build of their own series is the only thing that is an update.
      for (final distro in LinuxDistro.values) {
        for (final release in distro.releases) {
          expect(
            Rootfs.isOutdated(
              of(distro, release.version, branch: release.branch),
            ),
            isFalse,
            reason: '${distro.id} ${release.version} is current in its series',
          );
          expect(
            Rootfs.isOutdated(of(distro, '0.0.1', branch: release.branch)),
            isTrue,
            reason: '${distro.id} 0.0.1 is behind ${release.branch}',
          );
        }
      }
    });

    test('a series the manifest no longer carries is not outdated', () {
      // A system installed from a release that has since been dropped. There
      // is no newer build of it to offer, and comparing it against a series it
      // is not in would answer "outdated" for something nothing can update.
      expect(
        Rootfs.isOutdated(of(LinuxDistro.alpine, '3.19.1', branch: 'v3.19')),
        isFalse,
      );
    });
  });

  group('what an install would put on the device', () {
    LinuxProfile of(LinuxDistro distro, String version, String branch) =>
        LinuxProfile(
          id: distro.id,
          distro: distro,
          version: version,
          label: distro.label,
          branch: branch,
        );

    test('a pick is taken as given, distribution and release together', () {
      final release = LinuxDistro.ubuntu.releases.last;
      final target = Rootfs.target(
        picked: (distro: LinuxDistro.ubuntu, release: release),
      )!;

      expect(target.distro, LinuxDistro.ubuntu);
      expect(target.release, same(release));
      // Not the preferred one. Choosing 24.04 and being given 26.04 is the
      // failure this pairing exists to make impossible.
      expect(target.release, isNot(same(LinuxDistro.ubuntu.preferred)));
    });

    test('a replacement stays in the series already installed', () {
      // An install replaces the tree and destroys everything in it, so
      // answering with a different series would be a migration wearing an
      // update's clothes — and it would be doing it to someone who tapped a
      // button labelled "update".
      for (final distro in LinuxDistro.values) {
        for (final release in distro.releases) {
          final target = Rootfs.target(
            into: of(distro, '0.0.1', release.branch),
          )!;

          expect(target.distro, distro);
          expect(target.release.branch, release.branch, reason: distro.id);
          expect(target.release.version, release.version, reason: distro.id);
        }
      }
    });

    test('a replacement ignores what was picked for something else', () {
      // Both can be set: the settings page picks for a new system, and the
      // same function answers for the update button. The profile wins.
      final target = Rootfs.target(
        into: of(LinuxDistro.ubuntu, '24.04.1', 'noble'),
        picked: (
          distro: LinuxDistro.alpine,
          release: LinuxDistro.alpine.preferred,
        ),
      )!;

      expect(target.distro, LinuxDistro.ubuntu);
      expect(target.release.branch, 'noble');
    });

    test('a legacy marker without a series uses the preferred release', () {
      final target = Rootfs.target(into: of(LinuxDistro.alpine, '3.18.0', ''))!;

      expect(target.release, same(LinuxDistro.alpine.preferred));
    });

    test('a system whose series is gone has no replacement target', () {
      final target = Rootfs.target(
        into: of(LinuxDistro.alpine, '3.19.1', 'v3.19'),
      );

      expect(target, isNull);
    });
  });

  group('the marker', () {
    test('round-trips what was installed', () {
      const profile = LinuxProfile(
        id: 'alpine-2',
        distro: LinuxDistro.alpine,
        version: '3.22.5',
        label: 'Build box',
      );
      final read = LinuxProfile.decode(profile.id, profile.encode());

      expect(read.id, 'alpine-2');
      expect(read.distro, LinuxDistro.alpine);
      expect(read.version, '3.22.5');
      expect(read.label, 'Build box');
    });

    test('round-trips every distribution, not just the first one', () {
      // The marker is read by builds later than the one that wrote it, and a
      // tree read as the wrong distribution gets the wrong package manager's
      // files written into it.
      for (final distro in LinuxDistro.values) {
        final profile = LinuxProfile(
          id: 'id-${distro.id}',
          distro: distro,
          version: distro.version,
          label: 'A ${distro.label}',
        );
        final read = LinuxProfile.decode(profile.id, profile.encode());

        expect(read.distro, distro, reason: distro.id);
        expect(read.version, distro.version, reason: distro.id);
        expect(read.label, 'A ${distro.label}', reason: distro.id);
      }
    });

    test('carries the release series it was installed from', () {
      // Written as a fourth line, and read back as the thing that decides
      // whether a later release is an update of this one.
      const profile = LinuxProfile(
        id: 'ubuntu',
        distro: LinuxDistro.ubuntu,
        version: '24.04.4',
        label: 'Ubuntu',
        branch: 'noble',
      );
      final read = LinuxProfile.decode(profile.id, profile.encode());

      expect(read.branch, 'noble');
      expect(read.version, '24.04.4');
      expect(read.label, 'Ubuntu');
    });

    test('reads a three-line marker as a system of no known series', () {
      // What every build before this one wrote. Empty rather than guessed at:
      // the caller reads it as "this one predates the question" and falls back
      // to the preferred release, which is what those builds did.
      final read = LinuxProfile.decode('alpine', 'alpine\n3.22.5\nBuild box\n');

      expect(read.branch, isEmpty);
      expect(read.label, 'Build box');
    });

    test('does not read a newline in a label as a series', () {
      // The label is the one field a user types. Before there was a fourth
      // line a newline in it made the name look truncated; now it would be
      // read as a release series, and the system would compare itself against
      // one that does not exist.
      const profile = LinuxProfile(
        id: 'alpine',
        distro: LinuxDistro.alpine,
        version: '3.22.5',
        label: 'Build\nbox',
        branch: 'v3.22',
      );
      final read = LinuxProfile.decode(profile.id, profile.encode());

      expect(read.label, 'Build box');
      expect(read.branch, 'v3.22');
    });

    test('takes the id from the directory, never from the file', () {
      // The directory *is* the id: two profiles of one distribution differ by
      // nothing else, so a marker that carried one could disagree with where it
      // sits.
      final read = LinuxProfile.decode('alpine-3', 'alpine\n3.22.5\nx\n');

      expect(read.id, 'alpine-3');
    });

    test('falls back to the distribution name for a label', () {
      final read = LinuxProfile.decode('alpine', 'alpine\n3.22.5\n');

      expect(read.label, 'Alpine');
    });

    test('reads a two-line marker, which is what the last build wrote', () {
      final read = LinuxProfile.decode('alpine', 'alpine\n3.22.5\n');

      expect(read.distro, LinuxDistro.alpine);
      expect(read.version, '3.22.5');
    });

    test('reads a bare version as Alpine, which is what wrote it', () {
      // An earlier release wrote the version alone, and Alpine was the only
      // thing installable.
      final read = LinuxProfile.decode('alpine', '3.22.5\n');

      expect(read.distro, LinuxDistro.alpine);
      expect(read.version, '3.22.5');
    });

    test('reads an empty marker as Alpine of no version', () {
      // Older still: the marker was written empty, and its presence alone said
      // "installed".
      final read = LinuxProfile.decode('alpine', '');

      expect(read.distro, LinuxDistro.alpine);
      expect(read.version, isEmpty);
    });

    test('survives trailing whitespace either side of the newline', () {
      final read = LinuxProfile.decode('alpine', '  alpine \n 3.22.5  \n\n');

      expect(read.distro, LinuxDistro.alpine);
      expect(read.version, '3.22.5');
    });
  });

  group('a new profile id', () {
    test('is the distribution name when nothing has taken it', () {
      expect(LinuxProfile.nextId(LinuxDistro.alpine, const []), 'alpine');
    });

    test('counts up, so a second of the same distribution fits beside', () {
      // The whole point of the id being generated: two Alpines are two
      // profiles, and keying the directory by distribution made that
      // impossible.
      expect(LinuxProfile.nextId(LinuxDistro.alpine, ['alpine']), 'alpine-2');
      expect(
        LinuxProfile.nextId(LinuxDistro.alpine, ['alpine', 'alpine-2']),
        'alpine-3',
      );
    });

    test('skips a gap rather than reusing it', () {
      expect(
        LinuxProfile.nextId(LinuxDistro.alpine, ['alpine', 'alpine-3']),
        'alpine-2',
      );
    });
  });
}
