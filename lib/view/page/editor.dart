import 'dart:async';
import 'dart:io';

import 'package:code_text_field/code_text_field.dart';
import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_highlight/themes/monokai.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/highlight.dart';
import 'package:server_box/data/res/store.dart';

import 'package:server_box/view/widget/two_line_text.dart';

final class EditorPageRet {
  /// If edit text, this includes the edited result
  final String? result;

  /// Indicates whether it's ok to edit existing file
  final bool? editExistedOk;

  const EditorPageRet({this.result, this.editExistedOk});
}

final class EditorPageArgs {
  /// If path is not null, then it's a file editor
  /// If path is null, then it's a text editor
  final String? path;

  /// Only used when path is null
  final String? text;

  /// Code of language, eg: dart, go, etc.
  /// Higher priority than [path]
  final String? langCode;

  final String? title;

  const EditorPageArgs({
    this.path,
    this.text,
    this.langCode,
    this.title,
  });
}

class EditorPage extends StatefulWidget {
  final EditorPageArgs? args;

  const EditorPage({super.key, this.args});

  static const route = AppRoute<EditorPageRet, EditorPageArgs>(
    page: EditorPage.new,
    path: '/editor',
  );

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final _focusNode = FocusNode();

  late CodeController _controller;
  late Map<String, TextStyle> _codeTheme;
  late final _textStyle =
      TextStyle(fontSize: Stores.setting.editorFontSize.fetch());

  String? _langCode;

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
    _focusNode.dispose();
  }

  @override
  void initState() {
    super.initState();

    /// Higher priority than [path]
    if (Stores.setting.editorHighlight.fetch()) {
      _langCode =
          widget.args?.langCode ?? Highlights.getCode(widget.args?.path);
    }
    _controller = CodeController(
      language: Highlights.all[_langCode],
    );

    if (_langCode == null) {
      _setupCtrl();
    } else {
      Future.delayed(const Duration(milliseconds: 377)).then(
        (value) async => await _setupCtrl(),
      );
    }
  }

  Future<void> _setupCtrl() async {
    final path = widget.args?.path;
    final text = widget.args?.text;
    if (path != null) {
      final code = await Computer.shared.startNoParam(
        () => File(path).readAsString(),
      );
      _controller.text = code;
    } else if (text != null) {
      _controller.text = text;
    }
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
        up: widget.args?.title ??
            widget.args?.path?.getFileName() ??
            l10n.unknown,
        down: l10n.editor,
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.language),
          tooltip: libL10n.language,
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
            final path = widget.args?.path;
            if (path != null) {
              final (res, _) = await context.showLoadingDialog(
                fn: () => File(path).writeAsString(_controller.text),
              );
              if (res == null) {
                context.showSnackBar(libL10n.fail);
                return;
              }
              context.pop(const EditorPageRet(editExistedOk: true));
              return;
            }
            // else it's a text editor
            // return the text to the previous page
            context.pop(EditorPageRet(result: _controller.text));
          },
        )
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
        child: CodeTheme(
      data: CodeThemeData(styles: _codeTheme),
      child: CodeField(
        wrap: Stores.setting.editorSoftWrap.fetch(),
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
