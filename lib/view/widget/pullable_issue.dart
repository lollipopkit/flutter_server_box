import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';

/// A [PageIssueView] the [RefreshIndicator] around a page that failed can
/// still be pulled on: at least the space left, centered in it, and scrolled
/// as a whole when a long [detail] makes it taller.
class PullableIssueView extends StatelessWidget {
  const PullableIssueView({
    super.key,
    required this.title,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.explain,
    this.detail,
  });

  final String title;
  final VoidCallback? onRetry;
  final IconData icon;
  final String? explain;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PageIssueView(
            title: title,
            explain: explain,
            detail: detail,
            icon: icon,
            onRetry: onRetry,
          ),
        ),
      ],
    );
  }
}
