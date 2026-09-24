import 'package:archive/archive.dart';

/// Thrown when a decoder writes past the limit it was given.
///
/// Its own type rather than a [FormatException], because the two say different
/// things: bytes that are not the format at all are a bad file, and bytes that
/// expand past their limit are a reason to stop reading, which each caller
/// phrases for what it was reading.
final class OutputLimitExceeded implements Exception {
  const OutputLimitExceeded(this.limit);

  /// What the stream was allowed to hold, in bytes.
  final int limit;

  @override
  String toString() => 'output exceeds $limit bytes';
}

/// An [OutputMemoryStream] that refuses to grow past [limit] bytes.
///
/// For a decoder fed bytes from somewhere else. The limit a caller wants to
/// apply is on what a stream *is* — the files in a tar, the assets in a ZIP —
/// and that can only be measured once the stream is decoded, which is the state
/// a compressed input can be built to never reach. Handing the decoder one of
/// these instead of memory to write into makes the limit the point of the read:
/// the read stops where it is, rather than after the whole thing is in memory
/// and the check that would have refused it finally runs.
final class BoundedOutputStream extends OutputMemoryStream {
  BoundedOutputStream(this.limit) : super(size: 0);

  final int limit;

  void _check(int count) {
    if (count < 0 || length + count > limit) {
      throw OutputLimitExceeded(limit);
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _check(count);
    super.writeBackReference(distance, count);
  }
}
