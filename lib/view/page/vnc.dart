import 'package:flutter/material.dart';
import 'package:flutter_rfb/flutter_rfb.dart';
import 'package:toolbox/data/res/ui.dart';

class VNCPage extends StatefulWidget {
  const VNCPage({super.key});

  @override
  State<VNCPage> createState() => _VNCPageState();
}

class _VNCPageState extends State<VNCPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: InteractiveViewer(
        constrained: true,
        maxScale: 10,
        child: RemoteFrameBufferWidget(
          hostName: '47.108.212.173',
          onError: (final Object error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $error'),
              ),
            );
          },
          connectingWidget: UIs.centerLoading,
          password: 'Pwd123',
        ),
      ),
    );
  }
}
