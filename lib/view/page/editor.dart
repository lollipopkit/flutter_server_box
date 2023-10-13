import 'dart:async';
import 'dart:io';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_highlight/themes/monokai.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/utils/misc.dart';
import 'package:toolbox/data/res/highlight.dart';
import 'package:toolbox/data/res/store.dart';

import '../widget/custom_appbar.dart';
import '../widget/two_line_text.dart';

class EditorPage extends StatefulWidget {
  /// If path is not null, then it's a file editor
  /// If path is null, then it's a text editor
  final String? path;

  /// Only used when path is null
  final String? text;

  /// Code of language, eg: dart, go, etc.
  /// Higher priority than [path]
  final String? langCode;

  final String? title;

  const EditorPage({
    Key? key,
    this.path,
    this.text,
    this.langCode,
    this.title,
  }) : super(key: key);

  @override
  _EditorPageState createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final _focusNode = FocusNode();

  late CodeController _controller;
  late Map<String, TextStyle> _codeTheme;
  late final _textStyle =
      TextStyle(fontSize: Stores.setting.editorFontSize.fetch());

  String? _langCode;

  @override
  void initState() {
    super.initState();

    /// Higher priority than [path]
    if (Stores.setting.editorHighlight.fetch()) {
      _langCode = widget.langCode ?? Highlights.getCode(widget.path);
    }
    _controller = CodeController(
      language: Highlights.all[_langCode],
    );

    /// TODO: This is a temporary solution to avoid the loading stuck
    Future.delayed(const Duration(milliseconds: 377)).then((value) async {
      if (widget.path != null) {
        final code = await File(widget.path!).readAsString();
        _controller.text = code;
      } else if (widget.text != null) {
        _controller.text = widget.text!;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (context.isDark) {
      _codeTheme =
          themeMap[Stores.setting.editorDarkTheme.fetch()] ?? monokaiTheme;
    } else {
      _codeTheme =
          themeMap[Stores.setting.editorTheme.fetch()] ?? a11yLightTheme;
    }
    _focusNode.requestFocus();
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
      backgroundColor: _codeTheme['root']?.backgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return CustomAppBar(
      centerTitle: true,
      title: TwoLineText(
        up: widget.title ?? getFileName(widget.path) ?? l10n.unknown,
        down: l10n.editor,
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.language),
          tooltip: l10n.language,
          onSelected: (value) {
            _controller.language = Highlights.all[value];
            _langCode = value;
          },
          initialValue: _langCode,
          itemBuilder: (BuildContext context) {
            return Highlights.all.keys.map((e) {
              return PopupMenuItem(
                value: e,
                child: Text(e),
              );
            }).toList();
          },
        ),
        IconButton(
          icon: const Icon(Icons.save),
          tooltip: l10n.save,
          onPressed: () async {
            // If path is not null, then it's a file editor
            // save the text and return true to pop the page
            if (widget.path != null) {
              context.showLoadingDialog();
              await File(widget.path!).writeAsString(_controller.text);
              context.pop();
              context.pop(true);
              return;
            }
            // else it's a text editor
            // return the text to the previous page
            context.pop(_controller.text);
          },
        )
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
        child: CodeTheme(
      data: CodeThemeData(
        styles: _codeTheme,
      ),
      child: CodeField(
        focusNode: _focusNode,
        controller: _controller,
        textStyle: _textStyle,
        lineNumberStyle: const LineNumberStyle(
          width: 47,
          margin: 7,
        ),
      ),
    ));
  }
}
