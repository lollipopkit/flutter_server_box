import 'dart:io';

import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_highlight/themes/monokai.dart';
import 'package:material_ui/material_ui.dart';
import 'package:re_editor/re_editor.dart';
import 'package:server_box/core/utils/editor_format.dart';

const _kCloseAfterSave = false;

/// The file editor used by local storage, SFTP and raw settings.
///
/// Same as fl_lib's [EditorPage], with a Format action for JSON and XML.
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
  late final _findController = CodeFindController(_controller);
  late Map<String, TextStyle> _codeTheme;
  late final _modesMap = _parseModesMap;

  var _saved = false;

  @override
  void dispose() {
    _controller.dispose();
    _findController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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
      title: TwoLineText(
        up: widget.args?.title ?? widget.args?.path?.getFileName() ?? libL10n.unknown,
        down: libL10n.editor,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: libL10n.exit,
        onPressed: _onPop,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: libL10n.search,
          onPressed: () => _findController.findMode(),
        ),
        IconButton(
          icon: const Icon(Icons.format_align_left),
          tooltip: libL10n.format,
          onPressed: _onFormat,
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
}

extension on _FileEditorPageState {
  Future<void> _setupCtrl() async {
    final path = widget.args?.path;
    final text = widget.args?.text;
    if (path != null) {
      final String? code;
      try {
        code = await Computer.shared.startNoParam(() => editorReadUtf8(path));
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
    } else if (text != null) {
      _controller.text = text;
    }
  }

  void _closeWith(String message) {
    if (!mounted) return;
    Toast.show(message);
    context.pop();
  }

  Map<String, CodeHighlightThemeMode> get _parseModesMap {
    final lang = widget.args?.lang ?? ProgLang.parseFileName(widget.args?.path);
    return lang?.editorLangs ?? ProgLang.defaultLangModeMap;
  }

  void _onFormat() {
    final text = _controller.text;
    try {
      final formatted = formatEditorText(
        text,
        lang: widget.args?.lang,
        path: widget.args?.path,
      );
      if (formatted == null) {
        Toast.show(libL10n.unsupported);
        return;
      }
      if (formatted == text) return;
      _controller.text = formatted;
      _saved = false;
    } on FormatException catch (e) {
      Toast.error(e.message);
    } catch (e) {
      Toast.error(e.toString());
    }
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
      if (pop_) Future.microtask(_pop);
      return;
    }

    final ret = EditorPageRet(EditorPageRetType.text, _controller.text);
    widget.args?.onSave(ret);
    _saved = true;

    final pop_ = widget.args?.closeAfterSave ?? _kCloseAfterSave;
    if (pop_) Future.microtask(_pop);
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
