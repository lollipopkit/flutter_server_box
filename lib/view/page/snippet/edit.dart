import 'package:flutter/material.dart';

class SnippetEditPage extends StatefulWidget {
  const SnippetEditPage({Key? key}) : super(key: key);

  @override
  _SnippetEditPageState createState() => _SnippetEditPageState();
}

class _SnippetEditPageState extends State<SnippetEditPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Snippet Edit'),), body: const Center(child: Text('Developing'),),);
  }
}
