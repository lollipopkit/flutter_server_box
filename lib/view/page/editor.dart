import 'dart:io';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_highlight/themes/monokai.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/core/utils/misc.dart';
import 'package:toolbox/data/res/highlight.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/locator.dart';

import '../widget/two_line_text.dart';

class EditorPage extends StatefulWidget {
  final String? path;
  final String? initCode;
  const EditorPage({Key? key, this.path, this.initCode}) : super(key: key);

  @override
  _EditorPageState createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late CodeController _controller;
  late final _focusNode = FocusNode();
  final _setting = locator<SettingStore>();
  late Map<String, TextStyle> _codeTheme;
  late S _s;
  late String? _langCode;

  @override
  void initState() {
    super.initState();
    _langCode = widget.path.highlightCode;
    _controller = CodeController(
      text: widget.initCode,
      language: suffix2HighlightMap[_langCode ?? 'plaintext'],
    );
    _codeTheme = themeMap[_setting.editorTheme.fetch()] ?? monokaiTheme;
    if (widget.initCode == null && widget.path != null) {
      File(widget.path!)
          .readAsString()
          .then((value) => _controller.text = value);
    }
    _focusNode.requestFocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
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
        title: TwoLineText(up: getFileName(widget.path) ?? '', down: _s.editor),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.language),
            onSelected: (value) {
              _controller.language = suffix2HighlightMap[value];
            },
            initialValue: _langCode,
            itemBuilder: (BuildContext context) {
              return suffix2HighlightMap.keys.map((e) {
                return PopupMenuItem(
                  value: e,
                  child: Text(e),
                );
              }).toList();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: CodeTheme(
          data: CodeThemeData(styles: _codeTheme),
          child: CodeField(
            focusNode: _focusNode,
            controller: _controller,
            textStyle: const TextStyle(fontFamily: 'SourceCode'),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.done),
        onPressed: () {
          context.pop(_controller.text);
        },
      ),
    );
  }
}
