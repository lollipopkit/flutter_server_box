extension EnumListX<T> on List<T> {
  T fromIndex(int index, [T? defaultValue]) {
    try {
      return this[index];
    } catch (e) {
      if (defaultValue != null) {
        return defaultValue;
      }
      throw Exception('Invalid index: $index');
    }
  }
}
