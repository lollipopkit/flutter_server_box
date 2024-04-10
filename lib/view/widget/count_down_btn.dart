import 'dart:async';

import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';

final class CountDownBtn extends StatefulWidget {
  final int seconds;
  final String text;
  final Color? afterColor;
  final VoidCallback onTap;

  const CountDownBtn({
    super.key,
    required this.onTap,
    this.seconds = 3,
    this.text = 'Go',
    this.afterColor,
  });

  @override
  State<CountDownBtn> createState() => _CountDownBtnState();
}

final class _CountDownBtnState extends State<CountDownBtn> {
  late int _seconds = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountDown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get isCounting => _seconds > 0;

  void _startCountDown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isCounting) {
        _timer?.cancel();
      }
      setState(() {
        _seconds--;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        if (isCounting) return;
        widget.onTap();
      },
      child: Text(
        isCounting ? '$_seconds${l10n.second}' : widget.text,
        style: TextStyle(
          color: _seconds > 0 ? Colors.grey : widget.afterColor,
        ),
      ),
    );
  }
}
