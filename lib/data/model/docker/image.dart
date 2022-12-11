final _dockerImageReg = RegExp(r'(\S+) +(\S+) +(\S+) +(.+) +(\S+)');

class DockerImage {
  final String repo;
  final String tag;
  final String id;
  final String created;
  final String size;

  static final Map<String, DockerImage> _cache = <String, DockerImage>{};

  DockerImage({
    required this.repo,
    required this.tag,
    required this.id,
    required this.created,
    required this.size,
  });

  Map<String, dynamic> toJson() {
    return {
      'repo': repo,
      'tag': tag,
      'id': id,
      'created': created,
      'size': size,
    };
  }

  factory DockerImage.fromRawStr(String raw) {
    return _cache.putIfAbsent(raw, () => _parse(raw));
  }

  static DockerImage _parse(String raw) {
    final match = _dockerImageReg.firstMatch(raw);
    if (match == null) {
      throw Exception('Invalid docker image: $raw');
    }
    return DockerImage(
      repo: match.group(1)!,
      tag: match.group(2)!,
      id: match.group(3)!,
      created: match.group(4)!,
      size: match.group(5)!,
    );
  }
}
