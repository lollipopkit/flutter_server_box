import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_highlight/themes/monokai.dart';
import 'package:material_ui/material_ui.dart';
import 'package:re_editor/re_editor.dart';
import 'package:server_box/core/utils/editor_lang.dart';

const _kCloseAfterSave = false;

/// The file editor used by local storage, SFTP and raw settings.
///
/// Same as fl_lib's [EditorPage], with a Markdown preview.
class FileEditorPage extends StatefulWidget {
  final EditorPageArgs? args;

  const FileEditorPage({super.key, this.args});

  static const route = AppRoute<void, EditorPageArgs>(
    page: FileEditorPage.new,
    path: '/file-editor',
  );

  @override
  State<FileEditorPage> createState() => _FileEditorPageState();
}

class _FileEditorPageState extends State<FileEditorPage> {
  final _focusNode = FocusNode();

  final _controller = CodeLineEditingController();
  late final CodeFindController _findController;
  late Map<String, TextStyle> _codeTheme;
  late final _modesMap = _parseModesMap;

  var _saved = false;
  var _previewing = false;

  @override
  void dispose() {
    _findController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _findController = CodeFindController(_controller);
    _previewing = _isMarkdown;
    _setupCtrl();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (context.isDark) {
      _codeTheme = widget.args?.darkTheme?.theme ?? monokaiTheme;
    } else {
      _codeTheme = widget.args?.lightTheme?.theme ?? a11yLightTheme;
    }
    if (!_previewing) _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _previewing
          ? Theme.of(context).colorScheme.surface
          : _codeTheme['root']?.backgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return CustomAppBar(
      title: TwoLineText(
        up: widget.args?.title ?? widget.args?.path?.getFileName() ?? libL10n.unknown,
        down: _previewing ? libL10n.preview : libL10n.editor,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: libL10n.exit,
        onPressed: _onPop,
      ),
      actions: [
        if (_isMarkdown)
          IconButton(
            icon: Icon(_previewing ? Icons.edit_outlined : Icons.visibility_outlined),
            tooltip: _previewing ? libL10n.edit : libL10n.preview,
            onPressed: _toggleMarkdownPreview,
          ),
        if (!_previewing)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: libL10n.search,
            onPressed: () => _findController.findMode(),
          ),
        IconButton(
          icon: const Icon(Icons.save),
          tooltip: libL10n.save,
          onPressed: _onSave,
        )
      ],
    );
  }

  Widget _buildBody() {
    if (_previewing) return _buildMarkdownPreview();
    // The family is named even when the user chose none: `re_editor` reads a
    // null family as "start at the fallback list", so the first entry would
    // become the editor's font instead of its last resort.
    final bodyMedium = Theme.of(context).textTheme.bodyMedium;
    return CodeEditor(
      style: CodeEditorStyle(
        fontFamily: widget.args?.fontFamily ?? bodyMedium?.fontFamily,
        fontFamilyFallback: bodyMedium?.fontFamilyFallback,
        codeTheme: CodeHighlightTheme(
          languages: _modesMap,
          theme: _codeTheme,
        ),
      ),
      controller: _controller,
      findController: _findController,
      wordWrap: widget.args?.softWrap ?? false,
      focusNode: _focusNode,
      indicatorBuilder: (context, editingController, chunkController, notifier) {
        return Row(
          children: [
            UIs.width7,
            DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
            ),
            UIs.width7,
          ],
        );
      },
      findBuilder: (context, controller, readOnly) =>
          CodeFindPanelView(controller: controller, readOnly: readOnly),
      toolbarController:
          widget.args?.toolbarController ?? (isMobile ? AdaptiveSelectionToolbarController() : null),
    );
  }

  Widget _buildMarkdownPreview() {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SimpleMarkdown(
          data: _controller.text,
          selectable: true,
        ),
      ),
    );
  }

  Future<void> _setupCtrl() async {
    final path = widget.args?.path;
    final text = widget.args?.text;
    if (path != null) {
      final String? code;
      try {
        code = await Computer.shared.startNoParam(() => _readUtf8(path));
      } catch (e, s) {
        Loggers.app.warning('Editor: read $path', e, s);
        _closeWith(libL10n.fail);
        return;
      }
      if (code == null) {
        _closeWith(libL10n.unsupported);
        return;
      }
      if (!mounted) return;
      _controller.text = code;
      // [SimpleMarkdown] is not a listener of the controller.
      if (_previewing) setState(() {});
    } else if (text != null) {
      _controller.text = text;
    }
  }

  void _toggleMarkdownPreview() {
    setState(() {
      _previewing = !_previewing;
      if (_previewing) {
        _focusNode.unfocus();
      } else {
        _focusNode.requestFocus();
      }
    });
  }
}

extension on _FileEditorPageState {
  void _closeWith(String message) {
    if (!mounted) return;
    Toast.show(message);
    context.pop();
  }

  ProgLang? get _editorLang =>
      widget.args?.lang ?? editorLangFor(widget.args?.path);

  bool get _isMarkdown => editorIsMarkdown(lang: widget.args?.lang, path: widget.args?.path);

  Map<String, CodeHighlightThemeMode> get _parseModesMap {
    return _editorLang?.editorLangs ?? ProgLang.defaultLangModeMap;
  }

  void _onSave() async {
    final path = widget.args?.path;
    if (path != null) {
      final (res, _) = await context.showLoadingDialog(
        fn: () => File(path).writeAsString(_controller.text),
      );
      if (res == null) {
        Toast.error(libL10n.fail);
        return;
      }
      final ret = EditorPageRet(EditorPageRetType.path, path);
      widget.args?.onSave(ret);
      _saved = true;

      final pop_ = widget.args?.closeAfterSave ?? _kCloseAfterSave;
      if (pop_) unawaited(Future.microtask(_pop));
      return;
    }

    final ret = EditorPageRet(EditorPageRetType.text, _controller.text);
    widget.args?.onSave(ret);
    _saved = true;

    final pop_ = widget.args?.closeAfterSave ?? _kCloseAfterSave;
    if (pop_) unawaited(Future.microtask(_pop));
  }

  void _pop() async {
    if (!_saved) {
      final ret = await contextSafe?.showRoundDialog(
        title: libL10n.attention,
        child: Text(libL10n.askContinue(libL10n.exit)),
        actions: Btnx.cancelOk,
      );
      if (ret != true) return;
    }
    contextSafe?.pop();
  }

  void _onPop() async {
    if (_saved) {
      contextSafe?.pop();
      return;
    }

    // `popDialog`, not `pop`. `showRoundDialog` puts the dialog on the root
    // navigator, while this context's nearest navigator is the one holding
    // the *page* — a different one wherever the editor was pushed inside a
    // pane or a tab. Popping that closed the editor and left the dialog on
    // screen over whatever was behind it, with `shouldSave` never completing
    // because the dialog route was still there.
    final shouldSave = await contextSafe?.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(libL10n.actionAndAction(libL10n.save, libL10n.exit)),
      actions: [
        TextButton(
          onPressed: () => contextSafe?.popDialog(false),
          child: Text(libL10n.exitDirectly),
        ),
        TextButton(
          onPressed: () => contextSafe?.popDialog(true),
          child: Text(libL10n.ok),
        ),
      ],
    );
    if (shouldSave == true) {
      _onSave();
    }
    if (shouldSave != null) contextSafe?.pop();
  }
}

/// The file as UTF-8 text, or null when it is not text.
///
/// Top-level so it can run in a worker. Bytes and an explicit decode rather
/// than `readAsString`, so "not text" is an answer instead of the same
/// `FileSystemException` a missing file throws.
String? _readUtf8(String path) {
  final bytes = File(path).readAsBytesSync();
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return null;
  }
}
