import 'package:server_box/src/rust/api/container.dart' as ffi;

/// What `system df` said: how many images there are, and how much space the
/// prune actions between them would give back.
final class ContainerDiskUsage {
  const ContainerDiskUsage({this.imageCount, this.reclaimableBytes});

  ContainerDiskUsage.fromFfi(ffi.ContainerDiskUsageItem item)
    : imageCount = item.imageCount,
      reclaimableBytes = item.reclaimableBytes;

  /// `null` when the runtime reported no `Images` row.
  final int? imageCount;

  /// Summed over every type the runtime reported; `null` when none said.
  final int? reclaimableBytes;

  bool get isEmpty => imageCount == null && reclaimableBytes == null;

  @override
  bool operator ==(Object other) =>
      other is ContainerDiskUsage &&
      other.imageCount == imageCount &&
      other.reclaimableBytes == reclaimableBytes;

  @override
  int get hashCode => Object.hash(imageCount, reclaimableBytes);

  @override
  String toString() =>
      'ContainerDiskUsage(images: $imageCount, reclaimable: $reclaimableBytes)';
}
