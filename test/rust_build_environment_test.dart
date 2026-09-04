import 'package:test/test.dart';

import '../hook/rust_build_environment.dart';

void main() {
  const separator = '\u001f';

  group('reproducibleCargoEnvironment', () {
    test('preserves existing encoded flags and remaps build paths', () {
      final result = reproducibleCargoEnvironment(
        environment: const {
          'CARGO_HOME': '/home/runner/.cargo/',
          'CARGO_ENCODED_RUSTFLAGS': '-C${separator}debuginfo=1',
          'RUSTFLAGS': '-C opt-level=0',
        },
        packageRoot: '/home/runner/work/server-box/',
        isWindows: false,
      );

      expect(
        result['CARGO_ENCODED_RUSTFLAGS'],
        [
          '-C${separator}debuginfo=1',
          '--remap-path-prefix=/home/runner/.cargo=/cargo',
          '--remap-path-prefix=/home/runner/work/server-box=/source',
        ].join(separator),
      );
    });

    test('preserves RUSTFLAGS when encoded flags are absent', () {
      final result = reproducibleCargoEnvironment(
        environment: const {
          'HOME': '/home/runner',
          'RUSTFLAGS': '  -C   opt-level=2  ',
        },
        packageRoot: '/build/server-box',
        isWindows: false,
      );

      expect(
        result['CARGO_ENCODED_RUSTFLAGS'],
        [
          '-C${separator}opt-level=2',
          '--remap-path-prefix=/home/runner/.cargo=/cargo',
          '--remap-path-prefix=/build/server-box=/source',
        ].join(separator),
      );
    });

    test('preserves Cargo build rustflags as the final fallback', () {
      final result = reproducibleCargoEnvironment(
        environment: const {
          'HOME': '/home/runner',
          'CARGO_BUILD_RUSTFLAGS': '-C strip=symbols',
        },
        packageRoot: '/build/server-box',
        isWindows: false,
      );

      expect(
        result['CARGO_ENCODED_RUSTFLAGS'],
        [
          '-C${separator}strip=symbols',
          '--remap-path-prefix=/home/runner/.cargo=/cargo',
          '--remap-path-prefix=/build/server-box=/source',
        ].join(separator),
      );
    });

    test('uses the Unix Cargo default when CARGO_HOME is absent', () {
      final result = reproducibleCargoEnvironment(
        environment: const {'HOME': '/home/vagrant'},
        packageRoot: '/build/server-box',
        isWindows: false,
      );

      expect(
        result['CARGO_ENCODED_RUSTFLAGS'],
        [
          '--remap-path-prefix=/home/vagrant/.cargo=/cargo',
          '--remap-path-prefix=/build/server-box=/source',
        ].join(separator),
      );
    });

    test('uses USERPROFILE for the Windows Cargo default', () {
      final result = reproducibleCargoEnvironment(
        environment: const {
          'USERPROFILE': r'C:\Users\builder\',
          'HOME': r'D:\fallback',
        },
        packageRoot: r'C:\src\server-box\',
        isWindows: true,
      );

      expect(
        result['CARGO_ENCODED_RUSTFLAGS'],
        [
          r'--remap-path-prefix=C:\Users\builder\.cargo=/cargo',
          r'--remap-path-prefix=C:\src\server-box=/source',
        ].join(separator),
      );
    });

    test('still remaps the source when no Cargo home can be resolved', () {
      final result = reproducibleCargoEnvironment(
        environment: const {},
        packageRoot: '/source/checkout',
        isWindows: false,
      );

      expect(
        result['CARGO_ENCODED_RUSTFLAGS'],
        '--remap-path-prefix=/source/checkout=/source',
      );
    });
  });
}
