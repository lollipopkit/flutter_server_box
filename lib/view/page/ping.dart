import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:dart_ping_ios/dart_ping_ios.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/res/color.dart';

class PingPage extends StatefulWidget {
  const PingPage({Key? key}) : super(key: key);

  @override
  _PingPageState createState() => _PingPageState();
}

class _PingPageState extends State<PingPage>
    with AutomaticKeepAliveClientMixin {
  late TextEditingController _textEditingController;
  late TextEditingController _textEditingControllerResult;
  late MediaQueryData _media;
  late String _result;
  late Ping _ping;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: '');
    _textEditingControllerResult = TextEditingController(text: '');
    if (Platform.isIOS) {
      DartPingIOS.register();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: GestureDetector(
        child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Column(children: [
              const SizedBox(height: 13),
              _buildInputTop(),
              _buildControl(),
              _buildResult(),
            ])),
        onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      ),
    );
  }

  void doPing() {
    _result = '';
    _ping = Ping(_textEditingController.text.trim());
    _ping.stream.listen((event) {
      final resp = event.response.toString();
      if (resp == 'null') return;
      _result += '$resp\n';
      _textEditingControllerResult.text = _result;
    });
  }

  Widget _buildControl() {
    return SizedBox(
      height: 57,
      child: Card(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton(
              style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.all(primaryColor)),
              child: Row(
                children: const [
                  Icon(Icons.stop),
                  SizedBox(
                    width: 7,
                  ),
                  Text('Stop')
                ],
              ),
              onPressed: () {
                _ping.stop();
              },
            ),
            TextButton(
              style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.all(primaryColor)),
              child: Row(
                children: const [
                  Icon(Icons.play_arrow),
                  SizedBox(
                    width: 7,
                  ),
                  Text('Start')
                ],
              ),
              onPressed: () {
                try {
                  doPing();
                } catch (e) {
                  showSnackBar(context, Text('Error: \n$e'));
                }
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInputTop() {
    return _buildInput(_textEditingController, maxLines: 1, hint: 'Type here.');
  }

  Widget _buildResult() {
    return SizedBox(
      height: _media.size.height * 0.47,
      child: _buildInput(_textEditingControllerResult, hint: 'Result here.'),
    );
  }

  Widget _buildInput(TextEditingController controller, {int maxLines = 20, String? hint}) {
    return Card(
      child: TextField(
        maxLines: maxLines,
        decoration: InputDecoration(
            fillColor: Theme.of(context).cardColor,
            hintText: hint,
            filled: true,
            border: InputBorder.none),
        controller: controller,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
