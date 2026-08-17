import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/view/page/storage/file_pane.dart';
import 'package:server_box/view/page/storage/transfer_list.dart';

/// Shows the transfers wherever there is room for them.
///
/// In the file tab's second column, where the rail stays visible beside them —
/// a route drawn over everything covers the way back as well as the list. As a
/// page anywhere else: a narrow window, or a browser opened as its own page,
/// has no column to lend.
///
/// One function because there are three toolbars — this device, a server over
/// SFTP, a server over its agent — and the button means the same thing in all
/// of them.
void showTransfers(BuildContext context) {
  final pane = FilePaneHost.of(context);
  if (pane == null) {
    TransferListPage.route.go(context);
    return;
  }
  pane.open(
    (ctx) => Scaffold(
      appBar: CustomAppBar(
        title: Text(libL10n.mission, style: UIs.text18),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: libL10n.close,
          onPressed: () => FilePaneHost.of(ctx)?.close(),
        ),
      ),
      body: const TransferListView(),
    ),
  );
}
