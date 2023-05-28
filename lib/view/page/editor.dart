import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/java.dart';
import 'package:toolbox/core/extension/navigator.dart';

class EditorPage extends StatefulWidget {
  final String? initCode;
  const EditorPage({Key? key, this.initCode}) : super(key: key);

  @override
  _EditorPageState createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late CodeController _controller;
  late final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _controller = CodeController(
  text: widget.initCode,
  language: java,
  analyzer: const DefaultLocalAnalyzer(),
);
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
      backgroundColor: monokaiSublimeTheme['root']!.backgroundColor,
      appBar: AppBar(
        title: const Text('Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done),
            onPressed: () {
              context.pop(_controller.fullText);
            },
          ),
        ],
      ),
      body: CodeTheme(
        data: CodeThemeData(styles: monokaiSublimeTheme),
        child: SingleChildScrollView(
          child: CodeField(
            controller: _controller,
            gutterStyle: const GutterStyle(
              width: 37,
              showLineNumbers: false,
            ),
          ),
        ),
      ),
    );
  }
}
