import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/data/provider/debug.dart';
import 'package:toolbox/data/res/provider.dart';

import '../widget/appbar.dart';

class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text('Logs', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: () => Pros.debug.clear(),
            icon: const Icon(Icons.delete, color: Colors.white),
          ),
        ],
      ),
      body: _buildTerminal(context),
      backgroundColor: Colors.black,
    );
  }

  Widget _buildTerminal(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.black,
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
        ),
        child: ChangeNotifierProvider.value(
          value: Pros.debug,
          child: Consumer<DebugProvider>(
            builder: (_, provider, __) {
              return ListView(
                key: ValueKey(provider.widgets.length),
                reverse: true,
                children: provider.widgets,
              );
            },
          ),
        ),
      ),
    );
  }
}
