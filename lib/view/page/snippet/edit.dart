import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/provider.dart';

import '../../../data/model/server/snippet.dart';

class SnippetEditPage extends StatefulWidget {
  const SnippetEditPage({super.key, this.snippet});

  final Snippet? snippet;

  @override
  State<SnippetEditPage> createState() => _SnippetEditPageState();
}

class _SnippetEditPageState extends State<SnippetEditPage>
    with AfterLayoutMixin {
  final _nameController = TextEditingController();
  final _scriptController = TextEditingController();
  final _noteController = TextEditingController();
  final _scriptNode = FocusNode();
  final _autoRunOn = ValueNotifier(<String>[]);
  final _tags = ValueNotifier(<String>[]);

  @override
  void dispose() {
    super.dispose();
    _nameController.dispose();
    _scriptController.dispose();
    _scriptNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.edit, style: UIs.text18),
        actions: _buildAppBarActions(),
      ),
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  List<Widget>? _buildAppBarActions() {
    if (widget.snippet == null) {
      return null;
    }
    return [
      IconButton(
        onPressed: () {
          context.showRoundDialog(
            title: l10n.attention,
            child: Text(l10n.askContinue(
              '${l10n.delete} ${l10n.snippet}(${widget.snippet!.name})',
            )),
            actions: [
              TextButton(
                onPressed: () {
                  Pros.snippet.del(widget.snippet!);
                  context.pop();
                  context.pop();
                },
                child: Text(l10n.ok, style: UIs.textRed),
              ),
            ],
          );
        },
        tooltip: l10n.delete,
        icon: const Icon(Icons.delete),
      )
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
          context.showSnackBar(l10n.fieldMustNotEmpty);
          return;
        }
        final note = _noteController.text;
        final snippet = Snippet(
          name: name,
          script: script,
          tags: _tags.value.isEmpty ? null : _tags.value,
          note: note.isEmpty ? null : note,
          autoRunOn: _autoRunOn.value.isEmpty ? null : _autoRunOn.value,
        );
        if (widget.snippet != null) {
          Pros.snippet.update(widget.snippet!, snippet);
        } else {
          Pros.snippet.add(snippet);
        }
        context.pop();
      },
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(13),
      children: [
        Input(
          autoFocus: true,
          controller: _nameController,
          type: TextInputType.text,
          onSubmitted: (_) => FocusScope.of(context).requestFocus(_scriptNode),
          label: l10n.name,
          icon: Icons.info,
        ),
        Input(
          controller: _noteController,
          minLines: 3,
          maxLines: 3,
          type: TextInputType.multiline,
          label: l10n.note,
          icon: Icons.note,
        ),
        ValBuilder(
          listenable: _tags,
          builder: (vals) {
            return TagEditor(
              tags: _tags.value,
              onChanged: (p0) => setState(() {
                _tags.value = p0;
              }),
              allTags: [...Pros.snippet.tags.value],
              onRenameTag: (old, n) => setState(() {
                Pros.snippet.renameTag(old, n);
              }),
            );
          },
        ),
        Input(
          controller: _scriptController,
          node: _scriptNode,
          minLines: 3,
          maxLines: 10,
          type: TextInputType.multiline,
          label: l10n.snippet,
          icon: Icons.code,
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
              : vals
                  .map((e) => Pros.server.pick(id: e)?.spi.name ?? e)
                  .join(', ');
          return ListTile(
            leading: const Icon(Icons.settings_remote, size: 19),
            title: Text(l10n.autoRun),
            trailing: const Icon(Icons.keyboard_arrow_right),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle,
                    maxLines: 1,
                    style: UIs.textGrey,
                    overflow: TextOverflow.ellipsis,
                  ),
            onTap: () async {
              vals.removeWhere((e) => !Pros.server.serverOrder.contains(e));
              final serverIds = await context.showPickDialog(
                title: l10n.autoRun,
                items: Pros.server.serverOrder,
                name: (e) => Pros.server.pick(id: e)?.spi.name ?? e,
                initial: vals,
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
          data: '''
📌 ${l10n.supportFmtArgs}\n
${Snippet.fmtArgs.keys.map((e) => '`$e`').join(', ')}\n

${Snippet.fmtTermKeys.keys.map((e) => '`$e+?}`').join(', ')}\n
${l10n.forExample}: 
- `\${ctrl+c}` (Control + C)
- `\${ctrl+b}d` (Tmux Detach)
''',
          styleSheet: MarkdownStyleSheet(
            codeblockDecoration: const BoxDecoration(
              color: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    final snippet = widget.snippet;
    if (snippet != null) {
      _nameController.text = snippet.name;
      _scriptController.text = snippet.script;
      if (snippet.note != null) {
        _noteController.text = snippet.note!;
      }

      if (snippet.tags != null) {
        _tags.value = snippet.tags!;
      }

      if (snippet.autoRunOn != null) {
        _autoRunOn.value = snippet.autoRunOn!;
      }
    }
  }
}
