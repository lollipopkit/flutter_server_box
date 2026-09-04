part of '../entry.dart';

/// The globe's settings: whether it exists, and whether its data is installed.
///
/// Two questions rather than one switch. [SettingStore.globeEnabled] is
/// whether the feature is offered at all — off removes the button from the
/// server tab and stops every lookup. Whether a server can be *placed* is a
/// separate matter: it needs about 25 MB downloaded, and until that has
/// happened the globe draws servers only where a coordinate was typed by hand.
///
/// **There is no "may it download" switch any more, because the download is
/// the whole feature.** It used to fetch one shard per lookup, which is why
/// there was a switch to consent to those requests. Now it is one download,
/// nothing after it leaves the device, and having the data *is* the consent —
/// F-Droid's Tracking anti-feature wants opt-in and off by default, and a
/// feature that does nothing until someone accepts a 25 MB download is both.
extension _Globe on _AppSettingsPageState {
  Widget _buildGlobe() {
    return ExpandTile(
      leading: const Icon(Icons.public, size: _kIconSize),
      title: Text(l10n.globe),
      initiallyExpanded: false,
      children: [_buildGlobeEnabled(), const _GeoDataTile()],
    );
  }

  Widget _buildGlobeEnabled() {
    return ListTile(
      title: TipText(l10n.globe, l10n.globeEnabledTip),
      trailing: StoreSwitch(
        prop: _setting.globeEnabled,
        callback: (on) async {
          Diag.crumb(SbDiag.globe, on ? 'enabled' : 'disabled');
          // Turning it on with nothing installed leaves a feature that draws
          // only hand-typed coordinates, so the download is offered here rather
          // than left to be found in the row below.
          //
          // Reaches few people on purpose: the switch is on by default, so this
          // is the path of somebody who turned it off and changed their mind.
          // What covers the rest is the globe itself — see [GeoDataInstall].
          if (!on || GeoData.installed() != null) return;
          if (!mounted) return;
          await GeoDataInstall.run(context);
        },
      ),
    );
  }

  // There is no third row emptying what was worked out rather than downloaded.
  // It counted two stores, and one of them no longer exists: where each host
  // was is looked up fresh every time now, so there is nothing held that could
  // be wrong. What is still remembered is the address each server reported for
  // itself — see [SelfAddrStore]. Once it is seven days old, a later extended
  // status poll can refresh it without a separate settings action.
}

/// The city data: whether it is here, how big it is, and how to change that.
///
/// Stateful because installing is a download with a progress bar, and because
/// what the tile says depends on three things it has to find out for itself —
/// what is installed, what the endpoint is offering, and how much is on disk.
class _GeoDataTile extends StatefulWidget {
  const _GeoDataTile();

  @override
  State<_GeoDataTile> createState() => _GeoDataTileState();
}

class _GeoDataTileState extends State<_GeoDataTile> {
  GeoManifest? _installed;
  int _onDisk = 0;
  bool _loading = true;

  /// Bytes received and expected while a download is running, or null.
  (int, int)? _progress;

  @override
  void initState() {
    super.initState();
    // The switch above can install too, and the globe can install while this
    // page is not even built. Without this the row went on saying "Not
    // downloaded" over 52 MB of data.
    GeoData.revision.addListener(_onRevision);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    GeoData.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() => unawaited(_refresh());

  Future<void> _refresh() async {
    final installed = GeoData.installed();
    final onDisk = await GeoData.sizeOnDisk();
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _onDisk = onDisk;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (progress != null) {
      final (got, total) = progress;
      return ListTile(
        title: Text(l10n.geoData),
        subtitle: Text(
          '${got.bytes2Str} / ${total.bytes2Str}',
          style: UIs.textGrey,
        ),
        trailing: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            // Determinate, because the manifest gives a denominator before the
            // first byte arrives. A spinner for a 25 MB download says nothing
            // about whether it is nearly done.
            value: total == 0 ? null : got / total,
          ),
        ),
      );
    }

    final installed = _installed;
    return ListTile(
      title: TipText(l10n.geoData, l10n.geoDataTip),
      subtitle: Text(
        _loading
            ? libL10n.loadingEllipsis
            : installed == null
            ? l10n.geoDataMissing
            : '${installed.generated} · ${_onDisk.bytes2Str}',
        style: UIs.textGrey,
      ),
      // Named actions rather than a row that does something when tapped.
      // Checking for a newer month used to be the row's own `onTap`, which is
      // an affordance nothing announces — the visible button said "Delete", so
      // the way to update the data was to guess.
      //
      // Not checked on build: that is a request, and a settings page reaching
      // the network every time it opened would be asking a question nobody
      // asked.
      trailing: _loading
          ? null
          : installed == null
          ? Btn.text(text: libL10n.download, onTap: _install)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Btn.text(text: libL10n.update, onTap: _install),
                Btn.text(text: libL10n.delete, onTap: _remove),
              ],
            ),
    );
  }

  /// Downloads, drawing the progress in this row rather than over the page.
  ///
  /// The flow itself is [GeoDataInstall], shared with the switch above and with
  /// the globe. What is local to the tile is only *where* the progress goes: a
  /// settings row has space for it, and a modal dialog over a page the user is
  /// already looking at would be the app taking the screen to say something the
  /// row could say quietly.
  Future<void> _install() async {
    setState(() => _progress = (0, 0));
    await GeoDataInstall.run(
      context,
      onProgress: (got, total) {
        if (mounted) setState(() => _progress = (got, total));
      },
    );
    if (!mounted) return;
    setState(() => _progress = null);
    // Not conditional on the install having succeeded: a failure removes what
    // was there, so the row is wrong either way until it re-reads.
    await _refresh();
  }

  Future<void> _remove() async {
    final ok = await context.showRoundDialog<bool>(
      title: l10n.geoData,
      child: Text(libL10n.askContinue(libL10n.delete)),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;
    final removed = await GeoData.remove();
    Diag.crumb(SbDiag.globe, removed ? 'data removed' : 'data remove failed');
    await _refresh();
    if (!removed && mounted) {
      await context.showRoundDialog(
        title: libL10n.fail,
        child: Text(l10n.geoDataRemoveFailed),
        actions: Btnx.oks,
      );
    }
  }
}
