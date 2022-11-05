import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

part 'snippet.g.dart';

@HiveType(typeId: 2)
class Snippet {
  @HiveField(0)
  late String name;
  @HiveField(1)
  late String script;
  Snippet(this.name, this.script);

  Snippet.fromJson(Map<String, dynamic> json) {
    name = json['name'].toString();
    script = json['script'].toString();
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['name'] = name;
    data['script'] = script;
    return data;
  }
}

List<Snippet> getSnippetList(dynamic data) {
  List<Snippet> ss = [];
  if (data is String) {
    data = json.decode(data);
  }
  for (var t in data) {
    ss.add(Snippet.fromJson(t));
  }

  return ss;
}
