import 'package:server_box/src/rust/api/container.dart' as ffi;

/// One image, as `sbm_parser::container` read it from either runtime.
final class ContainerImg {
  ContainerImg.fromFfi(this._item);

  ContainerImg({
    String repository = '<none>',
    String? tag,
    String? id,
    String? digest,
    String? size,
    int? containers,
    String? createdAt,
    int? created,
    bool dangling = false,
    bool unused = false,
  }) : _item = ffi.ContainerImageItem(
         repository: repository,
         tag: tag,
         id: id,
         digest: digest,
         size: size,
         containers: containers,
         createdAt: createdAt,
         created: created,
         dangling: dangling,
         unused: unused,
       );

  final ffi.ContainerImageItem _item;

  /// `<none>` when the runtime named no repository.
  String get repository => _item.repository;
  String? get tag => _item.tag;
  String? get id => _item.id;
  String? get digest => _item.digest;

  /// The runtime's own size text, or one rendered from Podman's byte count.
  String? get size => _item.size;

  /// How many containers use it; `null` is unknown, never zero.
  int? get containersCount => _item.containers;

  /// Docker's creation text, passed through as it printed it.
  String? get createdAt => _item.createdAt;

  /// Podman's creation time, in Unix seconds.
  int? get created => _item.created;

  /// `<none>:<none>`: nothing to lose by removing it.
  bool get isDangling => _item.dangling;

  /// Dangling, or known to have no container referencing it.
  bool get isUnused => _item.unused;
}

/// The tagged images known to have nothing referencing them, or `null` when
/// one's use could not be confirmed against [containerImageReferences].
int? countUnusedTaggedImages(
  Iterable<ContainerImg> images,
  Iterable<String?> containerImageReferences,
) => ffi.containerCountUnusedTaggedImages(
  images: [for (final image in images) image._item],
  containerImages: [
    for (final reference in containerImageReferences) ?reference,
  ],
);
