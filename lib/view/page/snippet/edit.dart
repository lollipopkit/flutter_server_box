import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/snippet.dart';

final class SnippetEditPageArgs {
  final Snippet? snippet;
  const SnippetEditPageArgs({this.snippet});
}

class SnippetEditPage extends ConsumerStatefulWidget {
  final SnippetEditPageArgs? args;

  const SnippetEditPage({super.key, this.args});

  @override
  ConsumerState<SnippetEditPage> createState() => _SnippetEditPageState();

  static const route = AppRoute(page: SnippetEditPage.new, path: '/snippets/edit');
}

class _SnippetEditPageState extends ConsumerState<SnippetEditPage> with AfterLayoutMixin {
  final _nameController = TextEditingController();
  final _scriptController = TextEditingController();
  final _noteController = TextEditingController();
  final _scriptNode = FocusNode();
  final _autoRunOn = ValueNotifier(<String>[]);
  final _tags = <String>{}.vn;

  @override
  void dispose() {
    super.dispose();
    _nameController.dispose();
    _scriptController.dispose();
    _noteController.dispose();
    _scriptNode.dispose();
    _autoRunOn.dispose();
    _tags.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(libL10n.edit), actions: _buildAppBarActions()),
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  List<Widget>? _buildAppBarActions() {
    final snippet = widget.args?.snippet;
    if (snippet == null) return null;
    return [
      IconButton(
        onPressed: () {
          context.showRoundDialog(
            title: libL10n.attention,
            child: Text(libL10n.askContinue('${libL10n.delete} ${libL10n.snippet}(${snippet.name})')),
            actions: Btn.ok(
              onTap: () {
                ref.read(snippetProvider.notifier).del(snippet);
                context.pop();
                context.pop();
              },
              red: true,
            ).toList,
          );
        },
        tooltip: libL10n.delete,
        icon: const Icon(Icons.delete),
      ),
    ];
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      heroTag: 'snippet',
      child: const Icon(Icons.save),
      onPressed: () {
        final name = _nameController.text;
        final script = _scriptController.text;
        if (name.isEmpty || script.isEmpty) {
          context.showSnackBar(libL10n.empty);
          return;
        }
        final note = _noteController.text;
        final snippet = Snippet(
          name: name,
          script: script,
          tags: _tags.value.isEmpty ? null : _tags.value.toList(),
          note: note.isEmpty ? null : note,
          autoRunOn: _autoRunOn.value.isEmpty ? null : _autoRunOn.value,
        );
        final oldSnippet = widget.args?.snippet;
        final notifier = ref.read(snippetProvider.notifier);
        if (oldSnippet != null) {
          notifier.update(oldSnippet, snippet);
        } else {
          notifier.add(snippet);
        }
        context.pop();
      },
    );
  }

  Widget _buildBody() {
    return AutoMultiList(
      children: [
        Input(
          autoFocus: true,
          controller: _nameController,
          type: TextInputType.text,
          onSubmitted: (_) => FocusScope.of(context).requestFocus(_scriptNode),
          label: libL10n.name,
          icon: Icons.info,
          suggestion: true,
        ),
        Input(
          controller: _noteController,
          minLines: 3,
          maxLines: 3,
          type: TextInputType.multiline,
          label: libL10n.note,
          icon: Icons.note,
          suggestion: true,
        ),
        Consumer(
          builder: (_, ref, _) {
            final tags = ref.watch(snippetProvider.select((p) => p.tags));
            return TagTile(tags: _tags, allTags: tags).cardx;
          },
        ),
        Input(
          controller: _scriptController,
          node: _scriptNode,
          minLines: 3,
          maxLines: 10,
          type: TextInputType.multiline,
          label: libL10n.snippet,
          icon: Icons.code,
          suggestion: false,
        ),
        _buildAutoRunOn(),
        _buildTip(),
      ],
    );
  }

  Widget _buildAutoRunOn() {
    return CardX(
      child: ValBuilder(
        listenable: _autoRunOn,
        builder: (vals) {
          final subtitle = vals.isEmpty
              ? null
              : vals.map((e) => ref.read(serversProvider).servers[e]?.name ?? e).join(', ');
          return ListTile(
            leading: const Padding(
              padding: EdgeInsets.only(left: 5),
              child: Icon(Icons.settings_remote, size: 19),
            ),
            title: Text(l10n.autoRun),
            trailing: const Icon(Icons.keyboard_arrow_right),
            subtitle: subtitle == null
                ? null
                : Text(subtitle, maxLines: 1, style: UIs.textGrey, overflow: TextOverflow.ellipsis),
            onTap: () async {
              // Create a filtered copy for the dialog, don't modify the original
              final validServerIds = vals.where((e) => ref.read(serversProvider).serverOrder.contains(e)).toList();
              final serverIds = await context.showPickDialog(
                title: l10n.autoRun,
                items: ref.read(serversProvider).serverOrder,
                display: (e) => ref.read(serversProvider).servers[e]?.name ?? e,
                initial: validServerIds,
                clearable: true,
              );
              if (serverIds != null) {
                _autoRunOn.value = serverIds;
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildTip() {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: SimpleMarkdown(
          data:
              '''
📌 ${l10n.supportFmtArgs}\n
${SnippetX.fmtArgs.keys.map((e) => '`$e`').join(', ')}\n

${SnippetX.fmtTermKeys.keys.map((e) => '`$e+?}`').join(', ')}\n
${libL10n.example}: 
- `\${ctrl+c}` (Control + C)
- `\${ctrl+b}d` (Tmux Detach)
''',
          styleSheet: MarkdownStyleSheet(codeblockDecoration: const BoxDecoration(color: Colors.transparent)),
        ),
      ),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    final snippet = widget.args?.snippet;
    if (snippet != null) {
      _nameController.text = snippet.name;
      _scriptController.text = snippet.script;
      if (snippet.note != null) {
        _noteController.text = snippet.note!;
      }

      if (snippet.tags != null) {
        _tags.value = snippet.tags!.toSet();
      }

      if (snippet.autoRunOn != null) {
        _autoRunOn.value = snippet.autoRunOn!;
      }
    }
  }
}
