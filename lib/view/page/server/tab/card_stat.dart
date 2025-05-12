part of 'tab.dart';

typedef _CardNotifier = ValueNotifier<_CardStatus>;

class _CardStatus {
  final bool flip;
  final bool? diskIO;
  final NetViewType? net;

  const _CardStatus({
    this.flip = false,
    this.diskIO,
    this.net,
  });

  _CardStatus copyWith({
    bool? flip,
    bool? diskIO,
    NetViewType? net,
  }) {
    return _CardStatus(
      flip: flip ?? this.flip,
      diskIO: diskIO ?? this.diskIO,
      net: net ?? this.net,
    );
  }
}
