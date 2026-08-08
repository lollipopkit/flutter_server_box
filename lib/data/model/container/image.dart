import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/container/type.dart';

abstract final class ContainerImg {
  final String? repository = null;
  final String? tag = null;
  final String? id = null;
  String? get sizeMB;
  int? get containersCount;

  /// Whether the image has no repository/tag (e.g. `<none>:<none>`).
  bool get isDangling;

  /// Whether this image is known to have no container references.
  ///
  /// Some Docker versions report `N/A` instead of a reference count. That is
  /// treated as unknown rather than unused to avoid a misleading cleanup badge.
  bool get isUnused;

  factory ContainerImg.fromRawJson(String s, ContainerType typ) => typ.img(s);
}

/// Counts tagged images that are known to be unused.
///
/// Returns `null` when at least one tagged image has an unknown container
/// reference count and cannot be matched to the current container list. This
/// prevents an unknown Docker `N/A` count from being presented as zero.
int? countUnusedTaggedImages(
  Iterable<ContainerImg> images,
  Iterable<String?> containerImageReferences,
) {
  final usedMarkers = _containerImageMarkers(containerImageReferences);
  var unused = 0;
  var hasUnknown = false;

  for (final image in images) {
    if (image.isDangling) continue;
    final count = image.containersCount;
    if (count != null) {
      if (count == 0) unused++;
      continue;
    }
    if (!_imageMarkers(image).any(usedMarkers.contains)) {
      hasUnknown = true;
    }
  }
  return hasUnknown ? null : unused;
}

Set<String> _containerImageMarkers(Iterable<String?> references) {
  final markers = <String>{};
  for (final reference in references) {
    _addRuntimeImageReference(markers, reference);
  }
  return markers;
}

Set<String> _imageMarkers(ContainerImg image) {
  final markers = <String>{};
  _addImageId(markers, image.id);

  final repository = image.repository?.trim();
  if (repository == null || repository.isEmpty || repository == '<none>') {
    return markers;
  }
  final shortRepository = repository.split('/').last;
  final tag = image.tag?.trim();
  final hasTag = tag != null && tag.isNotEmpty && tag != '<none>';
  if (hasTag) {
    markers.add('$repository:$tag');
    markers.add('$shortRepository:$tag');
    if (tag == 'latest') {
      markers.add(repository);
      markers.add(shortRepository);
    }
  } else {
    markers.add(repository);
    markers.add(shortRepository);
    markers.add('$repository:latest');
    markers.add('$shortRepository:latest');
  }
  return markers;
}

void _addRuntimeImageReference(Set<String> markers, String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return;
  final withoutDigest = value.split('@').first.trim();
  if (_addImageId(markers, withoutDigest)) return;

  markers.add(withoutDigest);
  final shortReference = withoutDigest.split('/').last;
  markers.add(shortReference);
  if (!shortReference.contains(':')) {
    markers.add('$withoutDigest:latest');
    markers.add('$shortReference:latest');
  }
}

bool _addImageId(Set<String> markers, String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return false;
  final bare = value.startsWith('sha256:') ? value.substring(7) : value;
  if (!RegExp(r'^[a-fA-F0-9]{12,64}$').hasMatch(bare)) return false;
  markers.add(value);
  markers.add(bare);
  if (bare.length >= 12) markers.add(bare.substring(0, 12));
  return true;
}

final class PodmanImg implements ContainerImg {
  @override
  final String? repository;
  @override
  final String? tag;
  @override
  final String? id;
  final int? created;
  final int? size;
  final int? containers;

  PodmanImg({
    this.repository,
    this.tag,
    this.id,
    this.created,
    this.size,
    this.containers,
  });

  @override
  String? get sizeMB => size?.bytes2Str;

  @override
  int? get containersCount => containers;

  @override
  bool get isDangling {
    final repo = repository?.trim() ?? '';
    final t = tag?.trim() ?? '';
    return repo.isEmpty ||
        repo == '<none>' ||
        t.isEmpty ||
        t == '<none>';
  }

  @override
  bool get isUnused {
    if (isDangling) return true;
    final count = containersCount;
    return count != null && count == 0;
  }

  factory PodmanImg.fromRawJson(String str) =>
      PodmanImg.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PodmanImg.fromJson(Map<String, dynamic> json) => PodmanImg(
    repository: _asString(json['repository']),
    tag: _asString(json['tag']),
    id: _asString(json['Id']),
    created: _asInt(json['Created']),
    size: _asInt(json['Size']),
    containers: _asInt(json['Containers']),
  );

  Map<String, dynamic> toJson() => {
    'repository': repository,
    'tag': tag,
    'Id': id,
    'Created': created,
    'Size': size,
    'Containers': containers,
  };
}

final class DockerImg implements ContainerImg {
  final String containers;
  final String createdAt;
  @override
  final String id;
  @override
  final String repository;
  final String size;
  @override
  final String? tag;

  DockerImg({
    required this.containers,
    required this.createdAt,
    required this.id,
    required this.repository,
    required this.size,
    required this.tag,
  });

  @override
  String? get sizeMB => size;

  @override
  int? get containersCount =>
      containers == 'N/A' ? null : int.tryParse(containers);

  @override
  bool get isDangling {
    final repo = repository.trim();
    final t = (tag ?? '').trim();
    return repo.isEmpty ||
        repo == '<none>' ||
        t.isEmpty ||
        t == '<none>';
  }

  @override
  bool get isUnused {
    if (isDangling) return true;
    final count = containersCount;
    return count != null && count == 0;
  }

  factory DockerImg.fromRawJson(String str) =>
      DockerImg.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory DockerImg.fromJson(Map<String, dynamic> json) {
    final containers = switch (json['Containers']) {
      final String a => a,
      final Object? a => a.toString(),
    };
    final repo = _firstNonEmpty([
      switch (json['Repository']) {
        final String a => _nonEmptyOrNull(a),
        final Object? a => _nonEmptyOrNull(a?.toString()),
      },
      switch (json['Names']) {
        final List a => _firstNonEmptyFromList(a),
        final Object? a => _nonEmptyOrNull(a?.toString()),
      },
    ]);
    final size = switch (json['Size']) {
      final String a => a,
      final int a => a.bytes2Str,
      final Object? a => a.toString(),
    };
    return DockerImg(
      containers: containers,
      createdAt: json['CreatedAt'],
      id: json['ID'] ?? json['Id'] ?? '',
      repository: repo,
      size: size,
      tag: json['Tag'],
    );
  }

  Map<String, dynamic> toJson() => {
    'Containers': containers,
    'CreatedAt': createdAt,
    'ID': id,
    'Repository': repository,
    'Size': size,
    'Tag': tag,
  };
}

String? _asString(dynamic val) {
  if (val == null) return null;
  if (val is String) return val;
  return val.toString();
}

String? _nonEmptyOrNull(String? val) {
  if (val == null || val.trim().isEmpty) return null;
  return val.trim();
}

String? _firstNonEmptyFromList(List list) {
  for (final e in list) {
    final val = _nonEmptyOrNull(e?.toString());
    if (val != null) return val;
  }
  return null;
}

String _firstNonEmpty(List<String?> candidates) {
  for (final c in candidates) {
    if (c != null && c.isNotEmpty) return c;
  }
  return '<none>';
}

int? _asInt(dynamic val) {
  if (val == null) return null;
  if (val is int) return val;
  if (val is double) return val.toInt();
  return int.tryParse(val.toString());
}
