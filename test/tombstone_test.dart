import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/tombstone.dart';

import 'helpers/tombstone_proto.dart';

/// Turning a tombstone into the text that goes in a report.
///
/// Decoding itself is `package:protobuf` reading AOSP's own schema, so what is
/// worth testing is what this repository decides: which thread's stack is
/// printed, what a frame line looks like, when a fault address is meaningful,
/// how much of a runaway stack is kept, and that a record the platform could
/// not hand over whole leaves the app reporting the crash rather than throwing
/// inside the reporter.
void main() {
  group('a native crash', () {
    test('reads as the text a tombstone is usually read as', () {
      final bytes = tombstoneBytes(
        pid: 12345,
        tid: 12360,
        signal: signalOf(
          number: 11,
          name: 'SIGSEGV',
          code: 1,
          codeName: 'SEGV_MAPERR',
          hasFaultAddress: true,
          faultAddress: Int64.ZERO,
        ),
        causes: ['null pointer dereference'],
        threads: {
          12360: threadOf(
            id: 12360,
            name: '1.ui',
            frames: [
              frameOf(
                relPc: 0xa1b2c,
                function: 'sbm_parser::linux::parse_mem',
                offset: 44,
                file: '/data/app/~~x==/tech.lolli.toolbox-1/lib/arm64/libsbm_ffi.so',
                buildId: '0a1b2c3d',
              ),
              frameOf(
                relPc: 0x5f0,
                file: '/apex/com.android.runtime/lib64/bionic/libc.so',
              ),
            ],
          ),
          // A second thread, to prove the crashing one is chosen by tid rather
          // than by being first.
          12345: threadOf(
            id: 12345,
            name: 'main',
            frames: [frameOf(relPc: 0x1, file: '/system/lib64/libutils.so')],
          ),
        },
      );

      final text = Tombstone.decode(bytes);

      expect(text, isNotNull);
      expect(
        text!.split('\n'),
        equals([
          'signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x0000000000000000',
          'Cause: null pointer dereference',
          'pid: 12345, tid: 12360, name: 1.ui',
          '    #00 pc 00000000000a1b2c  '
              '/data/app/~~x==/tech.lolli.toolbox-1/lib/arm64/libsbm_ffi.so '
              '(sbm_parser::linux::parse_mem+44) (BuildId: 0a1b2c3d)',
          '    #01 pc 00000000000005f0  '
              '/apex/com.android.runtime/lib64/bionic/libc.so',
        ]),
      );
    });

    test('an abort prints its message and no fault address', () {
      // `has_fault_address` is false for SIGABRT, and the zero sitting in
      // `fault_address` would read as a null dereference if it were printed.
      // proto3 gives a scalar no presence, so the schema carries that bool for
      // this exact purpose and it is the one field worth asking about.
      final bytes = tombstoneBytes(
        pid: 9,
        tid: 9,
        signal: signalOf(
          number: 6,
          name: 'SIGABRT',
          code: -1,
          codeName: 'SI_QUEUE',
          hasFaultAddress: false,
          faultAddress: Int64.ZERO,
        ),
        abortMessage: 'assertion "ptr != null" failed',
        threads: {
          9: threadOf(id: 9, name: 'main', frames: [frameOf(relPc: 0x10, file: 'libc.so')]),
        },
      );

      final text = Tombstone.decode(bytes)!;

      expect(text, contains('signal 6 (SIGABRT)'));
      expect(text, isNot(contains('fault addr')));
      expect(text, contains("Abort message: 'assertion \"ptr != null\" failed'"));
    });

    test('an address with the top bit set is not printed as negative', () {
      // The schema's addresses are `uint64` and arrive as a signed `Int64`.
      final bytes = tombstoneBytes(
        pid: 1,
        tid: 1,
        signal: signalOf(
          number: 11,
          name: 'SIGSEGV',
          code: 2,
          codeName: 'SEGV_ACCERR',
          hasFaultAddress: true,
          faultAddress: Int64.parseHex('ffffffffffffffff'),
        ),
        threads: {
          1: threadOf(
            id: 1,
            frames: [frameOf(relPc: 0, file: 'libc.so')],
          ),
        },
      );

      final text = Tombstone.decode(bytes)!;

      expect(text, contains('fault addr 0xffffffffffffffff'));
      expect(text, isNot(contains('-')));
    });
  });

  group('a record the decoder has to survive', () {
    test('the parts of a tombstone this app does not read are ignored', () {
      // Most of a real tombstone's bytes are memory dumps, mappings and the
      // tail of the log buffers. None of it belongs in a report, and none of
      // it may get in the way of the part that does.
      final bytes = tombstoneWithBulk(
        pid: 42,
        tid: 43,
        threads: {
          43: threadOf(id: 43, name: 'w', frames: [frameOf(relPc: 0x8, file: 'libz.so')]),
        },
      );

      final text = Tombstone.decode(bytes);

      expect(text, isNotNull);
      expect(text, contains('pid: 42, tid: 43, name: w'));
      expect(text, contains('libz.so'));
    });

    test('a record cut short is refused rather than throwing', () {
      // The tombstone lives in a global circular buffer another app's crash can
      // evict, so a partial record is a thing that happens — and it happens on
      // the launch after a crash, inside the code that exists to report it.
      final full = tombstoneBytes(
        pid: 1,
        tid: 1,
        signal: signalOf(number: 11, name: 'SIGSEGV', code: 1, codeName: 'SEGV_MAPERR'),
        threads: {
          1: threadOf(id: 1, frames: [frameOf(relPc: 0x20, file: 'libfoo.so')]),
        },
      );

      // Every prefix, not one arbitrary cut: which offsets end a length prefix
      // and which end a varint is not worth hand-computing, and a decoder that
      // throws on one of them throws on a user's device.
      for (var len = 1; len < full.length; len++) {
        expect(
          () => Tombstone.decode(Uint8List.sublistView(full, 0, len)),
          returnsNormally,
          reason: 'threw on a $len-byte prefix',
        );
      }
    });

    test('bytes that are not a tombstone at all are refused', () {
      expect(
        Tombstone.decode(Uint8List.fromList([0xff, 0xff, 0xff, 0xff])),
        isNull,
      );
    });

    test('nothing worth printing is no report, not an empty one', () {
      expect(Tombstone.decode(Uint8List(0)), isNull);
      // Valid, and carrying nothing this prints.
      expect(Tombstone.decode(tombstoneWithBulk(pid: 1, tid: 1)), isNull);
    });

    test('a stack with no end is cut, and says so', () {
      final frames = List.generate(
        Tombstone.maxFrames + 5,
        (i) => frameOf(relPc: i, file: 'r.so'),
      );
      final bytes = tombstoneBytes(
        pid: 1,
        tid: 1,
        threads: {1: threadOf(id: 1, frames: frames)},
      );

      final lines = Tombstone.decode(bytes)!.split('\n');

      expect(lines.where((e) => e.contains(' pc ')).length, Tombstone.maxFrames);
      expect(lines.last, '    ... 5 more frames');
    });

    test('a stack is still printed when the crashing thread is missing', () {
      // The map is keyed by tid and the record names one that is not in it.
      // Some stack beats no stack, and the header has to say which.
      final bytes = tombstoneBytes(
        pid: 1,
        tid: 777,
        threads: {
          2: threadOf(id: 2, name: 'other', frames: [frameOf(relPc: 0x30, file: 'libbar.so')]),
        },
      );

      final text = Tombstone.decode(bytes)!;

      expect(text, contains('tid: 2, name: other'));
      expect(text, contains('crashing thread 777 not in the record'));
      expect(text, contains('libbar.so'));
    });

    test('a thread with no stack is not chosen over one with a stack', () {
      final bytes = tombstoneBytes(
        pid: 1,
        tid: 999,
        threads: {
          1: threadOf(id: 1, name: 'idle'),
          2: threadOf(id: 2, name: 'busy', frames: [frameOf(relPc: 0x40, file: 'libbaz.so')]),
        },
      );

      expect(Tombstone.decode(bytes)!, contains('tid: 2, name: busy'));
    });
  });
}
