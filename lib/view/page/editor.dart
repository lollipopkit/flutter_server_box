import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_highlight/themes/monokai.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/data/res/highlight.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/locator.dart';

class EditorPage extends StatefulWidget {
  final String? initCode;
  final String? fileName;
  const EditorPage({Key? key, this.initCode, this.fileName}) : super(key: key);

  @override
  _EditorPageState createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late CodeController _controller;
  late final _focusNode = FocusNode();
  final _setting = locator<SettingStore>();
  late Map<String, TextStyle> _codeTheme;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _controller = CodeController(
      text: widget.initCode,
      language: widget.fileName.highlight,
    );
    _codeTheme = themeMap[_setting.editorTheme.fetch()] ?? monokaiTheme;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _codeTheme['root']!.backgroundColor,
      appBar: AppBar(
        title: Text(widget.fileName ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.done),
            onPressed: () {
              context.pop(_controller.text);
            },
          ),
        ],
      ),
      body: CodeTheme(
        data: CodeThemeData(styles: _codeTheme),
        child: CodeField(
          controller: _controller,
          textStyle: const TextStyle(fontFamily: 'SourceCode'),
        ),
      ),
    );
  }
}
