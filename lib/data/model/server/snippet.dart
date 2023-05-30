import 'package:hive_flutter/hive_flutter.dart';

part 'snippet.g.dart';

@HiveType(typeId: 2)
class Snippet {
  @HiveField(0)
  late String name;
  @HiveField(1)
  late String script;
  @HiveField(2)
  List<String>? tags;
  Snippet(this.name, this.script, {this.tags});

  Snippet.fromJson(Map<String, dynamic> json) {
    name = json['name'].toString();
    script = json['script'].toString();
    tags = json['tags'].cast<String>();
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['name'] = name;
    data['script'] = script;
    data['tags'] = tags;
    return data;
  }
}
