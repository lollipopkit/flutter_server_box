import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

final class RWX {
  final bool r;
  final bool w;
  final bool x;

  const RWX({
    required this.r,
    required this.w,
    required this.x,
  });

  RWX copyWith({bool? r, bool? w, bool? x}) {
    return RWX(r: r ?? this.r, w: w ?? this.w, x: x ?? this.x);
  }

  int get value {
    return (r ? 4 : 0) + (w ? 2 : 0) + (x ? 1 : 0);
  }
}

final class UnixPerm {
  final RWX user;
  final RWX group;
  final RWX other;

  const UnixPerm({
    required this.user,
    required this.group,
    required this.other,
  });

  UnixPerm copyWith({RWX? user, RWX? group, RWX? other}) {
    return UnixPerm(
      user: user ?? this.user,
      group: group ?? this.group,
      other: other ?? this.other,
    );
  }

  /// eg.: 744
  String get perm {
    return '${user.value}${group.value}${other.value}';
  }

  static UnixPerm get empty => const UnixPerm(
        user: RWX(r: false, w: false, x: false),
        group: RWX(r: false, w: false, x: false),
        other: RWX(r: false, w: false, x: false),
      );
}

final class UnixPermEditor extends StatefulWidget {
  final UnixPerm perm;
  final void Function(UnixPerm) onChanged;
  const UnixPermEditor(
      {super.key, required this.perm, required this.onChanged});

  @override
  State<UnixPermEditor> createState() => _UnixPermEditorState();
}

final class _UnixPermEditorState extends State<UnixPermEditor> {
  late UnixPerm perm;

  @override
  void initState() {
    super.initState();
    perm = widget.perm;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text('R'),
            Text('W'),
            Text('X'),
          ],
        ).paddingOnly(left: 13),
        UIs.height7,
        _buildRow('U', perm.user),
        _buildRow('G', perm.group),
        _buildRow('O', perm.other),
      ],
    );
  }

  Widget _buildRow(String title, RWX rwx) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(width: 7, child: Text(title)),
        _buildSwitch(rwx.r, (v) {
          setState(() {
            perm = perm.copyWith(user: rwx.copyWith(r: v));
          });
          widget.onChanged(perm);
        }),
        _buildSwitch(rwx.w, (v) {
          setState(() {
            perm = perm.copyWith(user: rwx.copyWith(w: v));
          });
          widget.onChanged(perm);
        }),
        _buildSwitch(rwx.x, (v) {
          setState(() {
            perm = perm.copyWith(user: rwx.copyWith(x: v));
          });
          widget.onChanged(perm);
        }),
      ],
    );
  }

  Widget _buildSwitch(bool value, void Function(bool) onChanged) {
    return Switch(
      value: value,
      onChanged: onChanged,
    );
  }
}
