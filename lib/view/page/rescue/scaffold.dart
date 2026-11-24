import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';

/// Shared centered, constrained shell for startup rescue pages.
class RescueScaffold extends StatelessWidget {
  const RescueScaffold({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 37),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared icon + title header for startup rescue screens.
class RescueHeader extends StatelessWidget {
  const RescueHeader({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 57,
          color: iconColor ?? Theme.of(context).colorScheme.error,
        ),
        UIs.height13,
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
