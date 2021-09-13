import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/page/debug.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late TextEditingController _textEditingController;
  late TextEditingController _textEditingControllerResult;
  late MediaQueryData _media;
  late ThemeData _theme;

  static const List<String> _typeOption = [
    'base64 decode',
    'base64 encode',
    'URL encode',
    'URL decode'
  ];
  int _typeOptionIndex = 0;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController();
    _textEditingControllerResult = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _theme = Theme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () => AppRoute(const DebugPage(), 'Debug Page').go(context),
          child: Text(widget.title),
        ),
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Column(
            children: [
              const SizedBox(height: 13),
              _buildInputTop(),
              _buildTypeOption(),
              _buildResult(),
            ],
          )),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _textEditingControllerResult.text = doConvert();
        },
        tooltip: 'convert',
        child: const Icon(Icons.send),
      ),
    );
  }

  String doConvert() {
    final text = _textEditingController.text;
    switch (_typeOptionIndex) {
      case 0:
        return utf8.decode(base64.decode(text));
      case 1:
        return base64.encode(utf8.encode(text));
      case 2:
        return Uri.encodeFull(text);
      case 3:
        return Uri.decodeFull(text);
      default:
        return '未知编码';
    }
  }

  Widget _buildInputTop() {
    return SizedBox(
      height: _media.size.height * 0.33,
      child: _buildInput(_textEditingController),
    );
  }

  Widget _buildTypeOption() {
    return Card(
      child: ExpansionTile(
        title: Text(
          _typeOption[_typeOptionIndex],
          style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
        ),
        children: _typeOption
            .map((e) => ListTile(
                  title: Text(
                    e,
                    style: TextStyle(
                        color:
                            _theme.textTheme.bodyText2!.color!.withAlpha(177)),
                  ),
                  trailing: _buildRadio(_typeOption.indexOf(e)),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildResult() {
    return SizedBox(
      height: _media.size.height * 0.33,
      child: _buildInput(_textEditingControllerResult),
    );
  }

  Widget _buildInput(TextEditingController controller) {
    return Card(
      child: TextField(
        maxLines: 20,
        decoration: InputDecoration(
            fillColor: Theme.of(context).cardColor,
            filled: true,
            border: InputBorder.none),
        controller: controller,
      ),
    );
  }

  Radio _buildRadio(int index) {
    return Radio<int>(
      value: index,
      groupValue: _typeOptionIndex,
      onChanged: (int? value) {
        setState(() {
          _typeOptionIndex = value!;
        });
      },
    );
  }
}
