import 'dart:async';
import 'dart:io';

import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_highlight/themes/monokai.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/highlight.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import 'package:server_box/view/widget/two_line_text.dart';
import 'package:re_editor/re_editor.dart';

enum EditorPageRetType { path, text }

final class EditorPageRet {
  final EditorPageRetType typ;
  final String val;

  const EditorPageRet(this.typ, this.val);
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

  final void Function(BuildContext, EditorPageRet) onSave;

  const EditorPageArgs({
    this.path,
    this.text,
    this.langCode,
    this.title,
    required this.onSave,
  });
}

class EditorPage extends StatefulWidget {
  final EditorPageArgs? args;

  const EditorPage({super.key, this.args});

  static const route = AppRoute<void, EditorPageArgs>(
    page: EditorPage.new,
    path: '/editor',
  );

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final _focusNode = FocusNode();

  late CodeLineEditingController _controller;
  late Map<String, TextStyle> _codeTheme;

  String? _langCode;
  var _saved = false;

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
    _focusNode.dispose();
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (context.isDark) {
      _codeTheme = themeMap[Stores.setting.editorDarkTheme.fetch()] ?? monokaiTheme;
    } else {
      _codeTheme = themeMap[Stores.setting.editorTheme.fetch()] ?? a11yLightTheme;
    }
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        _pop();
      },
      child: Scaffold(
        backgroundColor: _codeTheme['root']?.backgroundColor,
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return CustomAppBar(
      centerTitle: true,
      title: TwoLineText(
        up: widget.args?.title ?? widget.args?.path?.getFileName() ?? l10n.unknown,
        down: l10n.editor,
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.language),
          tooltip: libL10n.language,
          onSelected: (value) {
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
          onPressed: _onSave,
        )
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      color: _EditorReTheme.getBackground(_codeTheme),
      child: CodeEditor(
        controller: _controller,
        wordWrap: Stores.setting.editorSoftWrap.fetch(),
        focusNode: _focusNode,
        indicatorBuilder: (context, editingController, chunkController, notifier) {
          return Row(
            children: [
              DefaultCodeLineNumber(
                controller: editingController,
                notifier: notifier,
              ),
            ],
          );
        },
        // findBuilder: (context, controller, readOnly) => CodeFindPanelView(controller: controller, readOnly: readOnly),
        // toolbarController: const ContextMenuControllerImpl(),
      ),
    );
  }
}

extension on _EditorPageState {
  Future<void> _init() async {
    /// Higher priority than [path]
    if (Stores.setting.editorHighlight.fetch()) {
      _langCode = widget.args?.langCode ?? Highlights.getCode(widget.args?.path);
    }
    _controller = CodeLineEditingController();
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

  void _onSave() async {
    // If path is not null, then it's a file editor
    final path = widget.args?.path;
    if (path != null) {
      final (res, _) = await context.showLoadingDialog(
        fn: () => File(path).writeAsString(_controller.text),
      );
      if (res == null) {
        context.showSnackBar(libL10n.fail);
        return;
      }
      final ret = EditorPageRet(EditorPageRetType.path, path);
      widget.args?.onSave(context, ret);
      _saved = true;

      final pop_ = SettingStore.instance.closeAfterSave.fetch();
      if (pop_) _pop();
      return;
    }
    // it's a text editor
    final ret = EditorPageRet(EditorPageRetType.text, _controller.text);
    widget.args?.onSave(context, ret);
    _saved = true;

    final pop_ = SettingStore.instance.closeAfterSave.fetch();
    if (pop_) _pop();
  }

  void _pop() async {
    if (!_saved) {
      final ret = await context.showRoundDialog(
        title: libL10n.attention,
        child: Text(libL10n.askContinue(libL10n.exit)),
        actions: Btnx.cancelOk,
      );
      if (ret != true) return;
    }
    context.pop();
  }
}

class _EditorReTheme {
  static Color? getBackground(Map<String, TextStyle> codeTheme) {
    return codeTheme['root']?.backgroundColor;
  }

  // static TextStyle? getTextStyle(Map<String, TextStyle> codeTheme) {
  //   return codeTheme['root'];
  // }
}
