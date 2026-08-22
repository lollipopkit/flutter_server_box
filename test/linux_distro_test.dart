import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/linux_distro.dart';

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
  group('a distribution', () {
    test('answers with a label, a version and a digest', () {
      for (final distro in LinuxDistro.values) {
        expect(distro.label, isNotEmpty, reason: '${distro.id} label');
        expect(distro.version, isNotEmpty, reason: '${distro.id} version');
        expect(
          distro.sha256,
          hasLength(64),
          reason: '${distro.id} has to pin a sha256 — the tarball is '
              'executable code, and the digest is what makes downloading it '
              'different from running whatever the connection returned',
        );
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
        if (!distro.rootfsFollowsMirror) continue;
        expect(
          distro.rootfsUrl('https://mirror.example/x'),
          startsWith('https://mirror.example/x/'),
          reason: '${distro.id} must honour a mirror, or the setting does '
              'nothing',
        );
      }
    });

    test('says so when it cannot honour the mirror for its tarball', () {
      // The exception has to be declared rather than discovered. Ubuntu's base
      // tarballs are on cdimage and its packages on archive, so one mirror
      // string cannot name both — and a distribution that quietly ignored the
      // setting would look identical to one that honoured a broken one.
      for (final distro in LinuxDistro.values) {
        if (distro.rootfsFollowsMirror) continue;
        final url = distro.rootfsUrl('https://mirror.example/x');
        expect(url, isNot(contains('mirror.example')), reason: distro.id);
        expect(Uri.parse(url).isScheme('https'), isTrue, reason: distro.id);
        // The setting still has to reach the packages, which is the half it
        // was actually set for.
        expect(
          distro.repositories('https://mirror.example/x').content,
          contains('https://mirror.example/x'),
          reason: distro.id,
        );
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
          distro.approxDownloadMb,
          greaterThanOrEqualTo(actual!.ceil()),
          reason: distro.id,
        );
      }
    });

    test('the three sizes are not interchangeable', () {
      // The string used to say "about 3 MB" for whichever was installed, which
      // was true of Alpine alone. If they were all close this would not matter.
      expect(LinuxDistro.ubuntu.approxDownloadMb,
          greaterThan(LinuxDistro.alpine.approxDownloadMb * 5));
      expect(LinuxDistro.rocky.approxDownloadMb,
          greaterThan(LinuxDistro.ubuntu.approxDownloadMb * 2));
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
        expect(
          distro.rootfsUrl(distro.defaultMirror),
          endsWith(switch (distro.compression) {
            LinuxRootfsCompression.gzip => '.tar.gz',
            LinuxRootfsCompression.xz => '.tar.xz',
          }),
          reason: distro.id,
        );
      }
    });

    test('only Rocky is an image layout', () {
      expect(LinuxDistro.alpine.layout, LinuxRootfsLayout.plain);
      expect(LinuxDistro.ubuntu.layout, LinuxRootfsLayout.plain);
      // Rocky publishes no plain rootfs tarball, only an OCI image.
      expect(LinuxDistro.rocky.layout, LinuxRootfsLayout.oci);
      expect(LinuxDistro.rocky.compression, LinuxRootfsCompression.xz);
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
      expect(
        LinuxDistro.ubuntu.repositories('https://m.test/ubuntu').content,
        contains('resolute-security'),
      );
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
      final content = LinuxDistro.rocky
          .repositories('https://m.test/rocky')
          .content;
      expect(content, contains('gpgcheck=1'));
      expect(
        content,
        contains('gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9'),
      );
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
