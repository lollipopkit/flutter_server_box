import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/provider/snippet.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/input_decoration.dart';

class SnippetEditPage extends StatefulWidget {
  const SnippetEditPage({Key? key, this.snippet}) : super(key: key);

  final Snippet? snippet;

  @override
  _SnippetEditPageState createState() => _SnippetEditPageState();
}

class _SnippetEditPageState extends State<SnippetEditPage>
    with AfterLayoutMixin {
  final nameController = TextEditingController();
  final scriptController = TextEditingController();

  late SnippetProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = locator<SnippetProvider>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit'), actions: [
        widget.snippet != null
            ? IconButton(
                onPressed: () {
                  _provider.del(widget.snippet!);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete))
            : const SizedBox()
      ]),
      body: ListView(
        padding: const EdgeInsets.all(13),
        children: [
          TextField(
            controller: nameController,
            keyboardType: TextInputType.text,
            decoration: buildDecoration('Name', icon: Icons.info),
          ),
          TextField(
            controller: scriptController,
            autocorrect: false,
            minLines: 3,
            maxLines: 10,
            keyboardType: TextInputType.text,
            enableSuggestions: false,
            decoration: buildDecoration('Snippet', icon: Icons.code),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.send),
        onPressed: () {
          final name = nameController.text;
          final script = scriptController.text;
          if (name.isEmpty || script.isEmpty) {
            showSnackBar(context, const Text('Two fields must not be empty.'));
            return;
          }
          final snippet = Snippet(name, script);
          if (widget.snippet != null) {
            _provider.update(widget.snippet!, snippet);
          } else {
            _provider.add(snippet);
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (widget.snippet != null) {
      nameController.text = widget.snippet!.name;
      scriptController.text = widget.snippet!.script;
    }
  }
}
