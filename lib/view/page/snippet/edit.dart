import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/view/widget/input_field.dart';

import '../../../data/model/server/snippet.dart';
import '../../../data/res/ui.dart';
import '../../widget/custom_appbar.dart';
import '../../widget/tag.dart';

class SnippetEditPage extends StatefulWidget {
  const SnippetEditPage({Key? key, this.snippet}) : super(key: key);

  final Snippet? snippet;

  @override
  _SnippetEditPageState createState() => _SnippetEditPageState();
}

class _SnippetEditPageState extends State<SnippetEditPage>
    with AfterLayoutMixin {
  final _nameController = TextEditingController();
  final _scriptController = TextEditingController();
  final _noteController = TextEditingController();
  final _scriptNode = FocusNode();

  List<String> _tags = [];

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
        title: Text(l10n.edit, style: UIs.textSize18),
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
            title: Text(l10n.attention),
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
          tags: _tags.isEmpty ? null : _tags,
          note: note.isEmpty ? null : note,
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
        TagEditor(
          tags: _tags,
          onChanged: (p0) => setState(() {
            _tags = p0;
          }),
          allTags: [...Pros.server.tags],
          onRenameTag: (old, n) => setState(() {
            Pros.server.renameTag(old, n);
          }),
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
      ],
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (widget.snippet != null) {
      _nameController.text = widget.snippet!.name;
      _scriptController.text = widget.snippet!.script;
      if (widget.snippet!.note != null) {
        _noteController.text = widget.snippet!.note!;
      }

      if (widget.snippet!.tags != null) {
        _tags = widget.snippet!.tags!;
        setState(() {});
      }
    }
  }
}
