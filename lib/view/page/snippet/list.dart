import 'package:flutter/material.dart';

class SnippetListPage extends StatefulWidget {
  const SnippetListPage({Key? key}) : super(key: key);

  @override
  _SnippetListPageState createState() => _SnippetListPageState();
}

class _SnippetListPageState extends State<SnippetListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Snippet List'),), body: const Center(child: Text('Developing'),),);
  }
}
