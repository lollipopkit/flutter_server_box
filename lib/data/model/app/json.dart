abstract class JsonSerializable<T> {
  /// Convert [this] to json
  Map<String, dynamic> toJson();

  /// Create [this] from json
  T fromJson(Map<String, dynamic> json);
}
