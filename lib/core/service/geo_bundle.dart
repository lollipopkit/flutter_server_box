import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/geo.dart';

/// One address family's city-level data, read off disk.
///
/// The whole dataset is downloaded once and every lookup after that is local,
/// so this never touches the network and the endpoint learns nothing about
/// which addresses are asked about — not which, not how many, not when. That
/// is a property of having the file rather than a promise about whoever served
/// it, which is why there is no longer an endpoint setting: there would be
/// nothing for it to improve.
///
/// ## Format
///
/// Big-endian throughout, and the contract with the `ipgeo-shards` repository.
/// Both sides have their own implementation and nothing makes them agree
/// except the vectors in `test/fixtures/geo/`.
///
/// ```text
/// magic "SBGX"          4 B
/// format                1 B   == 1
/// family                1 B   == 4 or 6
/// year u16, month u8    3 B
/// count u32             4 B
/// reserved              3 B   zero, padding the header to 16
/// bucket table  (2^bucketBits + 1) x u32   record index each bucket begins at
/// records       count x (offset + lat i16 + lon i16)
/// ```
///
/// A record covers every address from its own key up to the next record's,
/// which is what makes the file a sorted array a binary search runs on
/// directly. `lat == -32768` means nothing is allocated there — the one value
/// the quantisation cannot produce, and without it an unallocated block would
/// inherit whatever precedes it.
///
/// **Every bucket that has any record begins with one at offset 0**, so an
/// address in the low part of a bucket is always covered. A bucket with no
/// records at all is how a whole /8 or /16 says it is unallocated.
///
/// ## Why it is not read into memory
///
/// The two families come to 52 MB unpacked. What is held here is the header
/// and the bucket table — 1 KB for IPv4, 256 KB for IPv6 — and the records are
/// read from the open file as the search walks them. A lookup touches about
/// fourteen records, eight bytes each, from a file the OS has in its page
/// cache; holding 52 MB resident to save that would be the wrong trade on a
/// phone by a wide margin.
final class GeoBundle {
  GeoBundle._(
    this._file,
    this.family,
    this.year,
    this.month,
    this.count,
    this._table,
    this._recordsAt,
    this._offsetBytes,
    this._bucketBits,
    this._keyBits,
  );

  final RandomAccessFile _file;

  /// 4 or 6. Read from the header rather than inferred from the filename, so
  /// a file renamed or cached under the wrong name is refused instead of read
  /// with the other family's stride — where every record would decode to a
  /// coordinate somewhere plausible.
  final int family;

  /// What the data was built from. The app compares it with the manifest to
  /// decide whether what it holds is the current month.
  final int year;
  final int month;

  final int count;

  /// Where each bucket's records begin, plus a closing entry so the last
  /// bucket needs no special case.
  final Uint32List _table;

  final int _recordsAt;
  final int _offsetBytes;
  final int _bucketBits;
  final int _keyBits;

  static const _magic = [0x53, 0x42, 0x47, 0x58]; // "SBGX"
  static const _format = 1;
  static const _headerBytes = 16;

  /// The one latitude that means "nothing is allocated here".
  static const _noData = -32768;
  static const _quantum = 32767;

  /// Bits of the key each family buckets on, and how wide its key is.
  ///
  /// Read against the header's family rather than assumed, and a family this
  /// build does not know is refused: a wrong stride does not fail, it answers.
  static const _layout = {
    4: (keyBits: 32, bucketBits: 8),
    6: (keyBits: 48, bucketBits: 16),
  };

  /// Opens [path], or null for anything that is not a bundle this build reads.
  ///
  /// Null rather than an exception for every ordinary outcome — a truncated
  /// download, a file from a newer build, a family this does not know. The
  /// caller's next step is the same for all of them: treat the data as absent
  /// and offer to fetch it again.
  ///
  /// **Synchronous, like the reads a lookup makes.** Opening is a 16-byte
  /// header and a table of at most 256 KB from a file this device wrote; there
  /// is no wait worth an `await`. There is also a hazard in the alternative: a
  /// `testWidgets` body runs in a fake-async zone, and a real file read started
  /// there completes on a callback that zone is no longer pumping — so an
  /// async open called from a widget's own resolution pass simply never
  /// returns, which is not a failure any test reports as one.
  static GeoBundle? open(String path) {
    RandomAccessFile? file;
    try {
      final handle = File(path);
      if (!handle.existsSync()) return null;
      file = handle.openSync();

      final header = file.readSync(_headerBytes);
      if (header.length < _headerBytes) return null;
      for (var i = 0; i < _magic.length; i++) {
        if (header[i] != _magic[i]) return null;
      }
      final view = ByteData.sublistView(header);
      if (view.getUint8(4) != _format) return null;
      final family = view.getUint8(5);
      final layout = _layout[family];
      if (layout == null) return null;
      final year = view.getUint16(6);
      final month = view.getUint8(8);
      if (year == 0 || month < 1 || month > 12) return null;
      final count = view.getUint32(9);

      final buckets = 1 << layout.bucketBits;
      final tableBytes = (buckets + 1) * 4;
      final table = file.readSync(tableBytes);
      if (table.length < tableBytes) return null;
      final entries = Uint32List(buckets + 1);
      final tableView = ByteData.sublistView(table);
      var previous = 0;
      for (var i = 0; i <= buckets; i++) {
        final entry = tableView.getUint32(i * 4);
        if (entry < previous || entry > count) return null;
        entries[i] = entry;
        previous = entry;
      }
      // The table is what every lookup indexes with, so a broken one is worth
      // finding here rather than as a read past the end of the file later.
      if (entries[0] != 0 || entries[buckets] != count) return null;

      final offsetBytes = (layout.keyBits - layout.bucketBits) ~/ 8;
      final recordsAt = _headerBytes + tableBytes;
      if (handle.lengthSync() != recordsAt + count * (offsetBytes + 4)) {
        return null;
      }

      final opened = GeoBundle._(
        file,
        family,
        year,
        month,
        count,
        entries,
        recordsAt,
        offsetBytes,
        layout.bucketBits,
        layout.keyBits,
      );
      // Ownership passes to the bundle. Every earlier return leaves [file]
      // non-null so the finally block closes an invalid input.
      file = null;
      return opened;
    } catch (e, s) {
      Loggers.app.warning('Geo bundle $path is unreadable', e, s);
      return null;
    } finally {
      try {
        file?.closeSync();
      } catch (_) {}
    }
  }

  void close() {
    try {
      _file.closeSync();
    } catch (_) {
      // Closing a handle that is already gone is not worth reporting.
    }
  }

  /// Whether [addr] is the family this holds.
  bool covers(InternetAddress addr) =>
      (addr.type == InternetAddressType.IPv6) == (family == 6);

  /// Where [addr] is, or null.
  ///
  /// Null means the same three things it always meant and they are not
  /// distinguished: the bucket holds nothing, the address is in a gap, or it
  /// is the wrong family for this file. A caller does the same in each case.
  GeoCoord? lookup(InternetAddress addr) {
    if (!covers(addr)) return null;
    try {
      final raw = addr.rawAddress;
      // The leading `keyBits` of the address. For IPv6 that is 48 of 128, so
      // a /48 is the finest distinction the file can make.
      var key = 0;
      for (var i = 0; i < _keyBits ~/ 8; i++) {
        key = (key << 8) | raw[i];
      }

      final spanBits = _keyBits - _bucketBits;
      final bucket = key >> spanBits;
      var lo = _table[bucket];
      var hi = _table[bucket + 1];
      if (lo == hi) return null;

      final offset = key & ((1 << spanBits) - 1);
      final stride = _offsetBytes + 4;
      var found = -1;
      while (lo < hi) {
        final mid = lo + ((hi - lo) >> 1);
        if (_startAt(mid, stride) <= offset) {
          found = mid;
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      // Unreachable while every non-empty bucket opens at offset 0, which
      // `open` does not verify per bucket — that is 65,537 reads — so this
      // answers rather than throwing if a file ever breaks it.
      if (found < 0) return null;

      final record = _read(_recordsAt + found * stride + _offsetBytes, 4);
      final view = ByteData.sublistView(record);
      final lat = view.getInt16(0);
      if (lat == _noData) return null;
      return GeoCoord.tryNew(
        lat / _quantum * 90,
        view.getInt16(2) / _quantum * 180,
      );
    } catch (e, s) {
      // A lookup is never worth failing over: the globe simply has no
      // coordinate for this server, which is a state it already draws.
      Loggers.app.warning('Geo bundle lookup failed', e, s);
      return null;
    }
  }

  int _startAt(int index, int stride) {
    final bytes = _read(_recordsAt + index * stride, _offsetBytes);
    var start = 0;
    for (final byte in bytes) {
      start = (start << 8) | byte;
    }
    return start;
  }

  /// Synchronous on purpose.
  ///
  /// A search is about fourteen of these, of eight bytes each, against a file
  /// the OS is holding in its page cache — the cost is a syscall, not a disk.
  /// Made async, every step of the binary search would be a microtask, and a
  /// lookup that is currently microseconds would be spread across frames.
  Uint8List _read(int at, int length) {
    _file.setPositionSync(at);
    return _file.readSync(length);
  }
}
