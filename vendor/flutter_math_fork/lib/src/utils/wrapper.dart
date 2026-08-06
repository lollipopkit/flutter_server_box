class Wrapper<T> {
  final T value;

  const Wrapper(
    this.value,
  );

  @override
  bool operator ==(Object o) {
    if (identical(this, o)) return true;

    return o is Wrapper<T> && o.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Wrapper($value)';
}
