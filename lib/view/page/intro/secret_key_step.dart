import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/core/sync/file_log.dart';
import 'package:server_box/core/sync/lkc_log.dart';
import 'package:server_box/core/sync/lkc_prefs.dart';
import 'package:server_box/core/sync/remotes.dart';
import 'package:server_box/core/sync/secret_key_prefs.dart';
import 'package:server_box/core/sync/sync.dart';
import 'package:server_box/view/widget/column_inset.dart';
import 'package:server_box/view/widget/secret_key_widgets.dart';

/// Which Secret Key onboarding/migration flow applies on this launch.
enum SecretKeyIntroMode {
  /// First launch without a key in keychain: generate, import, or skip sync.
  newFresh,

  /// First launch where keychain already holds a secret key (e.g. synced).
  newSynced,

  /// Existing synced user upgrading on their first device (or confirming a
  /// pending key). Keeps existing backup password unchanged.
  upgradeDeviceA,

  /// Existing synced user on a second cross-platform device whose remote is
  /// already 2FA-sealed (`SyncSecretKeyMissing`): import only, with defer option.
  upgradeDeviceB,
}

/// Validation state of the Secret Key import text field.
enum SecretKeyImportStatus {
  empty,
  valid,
  invalid,
  unavailable,
}

/// State and persistence logic for the Secret Key step inside [IntroPage].
final class SecretKeyIntroController {
  SecretKeyIntroController._({
    required SecretKeyIntroMode initialMode,
    required String? initialDisplayKey,
    required bool initialAllowSwitch,
    required this.keyAlreadyStored,
  }) : mode = initialMode.vn,
       displayKey = ValueNotifier<String?>(initialDisplayKey),
       allowSwitchToImport = initialAllowSwitch.vn,
       isGenerateTab = (initialMode != SecretKeyIntroMode.upgradeDeviceB).vn,
       acknowledged = false.vn,
       importedKey = ValueNotifier<String?>(null),
       importStatus = SecretKeyImportStatus.empty.vn,
       rustUnavailable = (initialDisplayKey == null &&
               (initialMode == SecretKeyIntroMode.newFresh ||
                   initialMode == SecretKeyIntroMode.upgradeDeviceA))
           .vn,
       canProceed = (initialMode == SecretKeyIntroMode.newSynced).vn {
    if (initialMode == SecretKeyIntroMode.upgradeDeviceA && !keyAlreadyStored) {
      SyncKeyring.secretKeyMissing.addListener(_onRemoteSecretKeyMissing);
      _listeningMissing = true;
    }
  }

  /// True when [displayKey] is already saved in [SecureStoreProps.syncSecretKey].
  final bool keyAlreadyStored;

  final ValueNotifier<SecretKeyIntroMode> mode;

  /// Key displayed in QR/text when generating or showing a synced/pending key.
  final ValueNotifier<String?> displayKey;

  /// Whether the user can toggle between generate and import on this step.
  final ValueNotifier<bool> allowSwitchToImport;

  final ValueNotifier<bool> isGenerateTab;
  final ValueNotifier<bool> acknowledged;
  final ValueNotifier<String?> importedKey;
  final ValueNotifier<SecretKeyImportStatus> importStatus;
  final ValueNotifier<bool> rustUnavailable;
  final ValueNotifier<bool> canProceed;

  bool _listeningMissing = false;
  bool _disposed = false;

  /// Determines whether the Secret Key step should appear on this launch.
  static Future<SecretKeyIntroController?> detect({required bool firstLaunch}) async {
    final existing = await SecureStoreProps.syncSecretKey.read(limited: false);
    final hasKey = existing != null && existing.isNotEmpty;
    final backupPending = SyncSecretKeyPrefs.backupPending.get();
    final syncEnabled = (isICloudSupported && PrefProps.icloudSync.get()) ||
        PrefProps.webdavSync.get() ||
        (Lkc.enabled && LkcSyncPrefs.enabled.get());

    if (firstLaunch) {
      if (hasKey) {
        return SecretKeyIntroController._(
          initialMode: SecretKeyIntroMode.newSynced,
          initialDisplayKey: existing,
          initialAllowSwitch: false,
          keyAlreadyStored: true,
        );
      }
      final candidate = await _tryGenerateKey();
      return SecretKeyIntroController._(
        initialMode: SecretKeyIntroMode.newFresh,
        initialDisplayKey: candidate,
        initialAllowSwitch: true,
        keyAlreadyStored: false,
      );
    }

    // Existing install: confirm a key that was marked pending backup.
    if (backupPending && hasKey) {
      return SecretKeyIntroController._(
        initialMode: SecretKeyIntroMode.upgradeDeviceA,
        initialDisplayKey: existing,
        initialAllowSwitch: false,
        keyAlreadyStored: true,
      );
    }

    // Pure local user or already synced via platform keychain: skip silently.
    if (!syncEnabled || hasKey) return null;

    // Cross-platform user who chose "Set up later": do not block SSH startup.
    if (SyncSecretKeyPrefs.introDeferred.get()) return null;

    if (SyncKeyring.secretKeyMissing.value) {
      return SecretKeyIntroController._(
        initialMode: SecretKeyIntroMode.upgradeDeviceB,
        initialDisplayKey: null,
        initialAllowSwitch: false,
        keyAlreadyStored: false,
      );
    }

    // Existing synced user upgrading before sync has probed the remote yet:
    // default to Device A upgrade while allowing switch to import, and react
    // immediately if background probing reports that the remote is already 2FA.
    final candidate = await _tryGenerateKey();
    return SecretKeyIntroController._(
      initialMode: SecretKeyIntroMode.upgradeDeviceA,
      initialDisplayKey: candidate,
      initialAllowSwitch: true,
      keyAlreadyStored: false,
    );
  }

  static Future<String?> _tryGenerateKey() async {
    try {
      await FlRust.ensureInitialized();
      return SyncKeyring.generateSecretKey();
    } catch (e, s) {
      Loggers.app.warning('Secret key generation unavailable during intro', e, s);
      return null;
    }
  }

  void _onRemoteSecretKeyMissing() {
    if (_disposed || !SyncKeyring.secretKeyMissing.value) return;
    _switchToImportOnly();
  }

  void _switchToImportOnly() {
    mode.value = SecretKeyIntroMode.upgradeDeviceB;
    allowSwitchToImport.value = false;
    isGenerateTab.value = false;
    _refreshCanProceed();
  }

  /// Called once [FlRust.ensureInitialized] completes on screen to populate a
  /// missing candidate key or re-validate already-typed import input.
  void onRustReady(String currentImportText) {
    if (_disposed) return;
    if (FlRust.ready) {
      rustUnavailable.value = false;
      final needsKey = displayKey.value == null &&
          (mode.value == SecretKeyIntroMode.newFresh ||
              mode.value == SecretKeyIntroMode.upgradeDeviceA);
      if (needsKey) {
        try {
          displayKey.value = SyncKeyring.generateSecretKey();
        } catch (e, s) {
          Loggers.app.warning('Secret key generation retry failed', e, s);
          rustUnavailable.value = true;
        }
      }
      if (currentImportText.trim().isNotEmpty) {
        updateImportInput(currentImportText);
      } else {
        _refreshCanProceed();
      }
    }
  }

  void setGenerateTab(bool generate) {
    if (!allowSwitchToImport.value) return;
    isGenerateTab.value = generate;
    _refreshCanProceed();
  }

  void setAcknowledged(bool value) {
    acknowledged.value = value;
    _refreshCanProceed();
  }

  String? updateImportInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      importedKey.value = null;
      importStatus.value = SecretKeyImportStatus.empty;
      _refreshCanProceed();
      return null;
    }
    if (!FlRust.ready) {
      importedKey.value = null;
      importStatus.value = SecretKeyImportStatus.unavailable;
      _refreshCanProceed();
      return null;
    }
    String? norm;
    try {
      norm = SyncKeyring.normalizeSecretKey(trimmed);
    } catch (e, s) {
      Loggers.app.warning('Secret key validation failed', e, s);
      importedKey.value = null;
      importStatus.value = SecretKeyImportStatus.unavailable;
      _refreshCanProceed();
      return null;
    }
    importedKey.value = norm;
    importStatus.value =
        norm != null ? SecretKeyImportStatus.valid : SecretKeyImportStatus.invalid;
    _refreshCanProceed();
    return norm;
  }

  void _refreshCanProceed() {
    if (mode.value == SecretKeyIntroMode.newSynced) {
      canProceed.value = true;
      return;
    }
    if (isGenerateTab.value && mode.value != SecretKeyIntroMode.upgradeDeviceB) {
      canProceed.value = displayKey.value != null && acknowledged.value;
    } else {
      canProceed.value = importedKey.value != null;
    }
  }

  /// Persists the chosen or confirmed secret key when the user taps Next/Done.
  Future<bool> commit() async {
    if (!canProceed.value) return false;
    final currentMode = mode.value;
    try {
      if (currentMode == SecretKeyIntroMode.newSynced) {
        await SyncSecretKeyPrefs.backupPending.set(false);
        await SyncSecretKeyPrefs.introDeferred.set(false);
        return true;
      }

      final bool isUpgrade = currentMode == SecretKeyIntroMode.upgradeDeviceA ||
          currentMode == SecretKeyIntroMode.upgradeDeviceB;
      final bool generating =
          isGenerateTab.value && currentMode != SecretKeyIntroMode.upgradeDeviceB;

      String? toSave;
      if (generating) {
        if (!acknowledged.value || displayKey.value == null) return false;
        if (!keyAlreadyStored) {
          // If a remote probe discovered an already-2FA remote while the user
          // was on the generate tab, switch to import instead of overwriting.
          if (SyncKeyring.secretKeyMissing.value) {
            _switchToImportOnly();
            return false;
          }
          // Never overwrite a key that arrived via platform keychain sync
          // while this page was open.
          final concurrent = await SecureStoreProps.syncSecretKey.read(limited: false);
          if (concurrent != null && concurrent.isNotEmpty) {
            displayKey.value = concurrent;
            toSave = null;
          } else {
            toSave = displayKey.value;
          }
        }
      } else {
        if (importedKey.value == null) return false;
        toSave = importedKey.value;
      }

      if (toSave != null) {
        await SecureStoreProps.syncSecretKey.write(toSave, limited: false);
      }
      await SyncSecretKeyPrefs.backupPending.set(false);
      await SyncSecretKeyPrefs.introDeferred.set(false);

      if (isUpgrade) {
        if (Lkc.enabled) {
          await Lkc.client.resetPersonalAuth(clearCachedKey: true);
        }
        unawaited(_recheckAndSync());
      }
      return true;
    } catch (e, s) {
      Loggers.app.warning('Failed to commit secret key during intro', e, s);
      Toast.show('$e');
      return false;
    }
  }

  static Future<void> _recheckAndSync() async {
    try {
      await SyncKeyring.recheck();
    } catch (e, s) {
      Loggers.app.warning('SyncKeyring.recheck failed after secret key setup', e, s);
    }
    unawaited(lkcLog.sync());
    unawaited(fileLog.sync());
    bakSync.syncSoon(milliDelay: 0, throttleMilli: 0);
  }

  /// Handles explicit skip (new user) or defer (upgrading device).
  /// Always advances via [IntroPage.nextOf] so any subsequent intro steps
  /// (e.g. diagnostics consent) are never bypassed.
  Future<void> skip(BuildContext context) async {
    if (mode.value != SecretKeyIntroMode.newFresh) {
      await SyncSecretKeyPrefs.introDeferred.set(true);
    }
    if (context.mounted) IntroPage.nextOf(context);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_listeningMissing) {
      SyncKeyring.secretKeyMissing.removeListener(_onRemoteSecretKeyMissing);
      _listeningMissing = false;
    }
    mode.dispose();
    displayKey.dispose();
    allowSwitchToImport.dispose();
    isGenerateTab.dispose();
    acknowledged.dispose();
    importedKey.dispose();
    importStatus.dispose();
    rustUnavailable.dispose();
    canProceed.dispose();
  }
}

/// The Secret Key onboarding and migration page rendered inside [IntroPage].
final class SecretKeyIntroPage extends StatefulWidget {
  const SecretKeyIntroPage({
    super.key,
    required this.controller,
    required this.padTop,
  });

  final SecretKeyIntroController controller;
  final double padTop;

  @override
  State<SecretKeyIntroPage> createState() => _SecretKeyIntroPageState();
}

final class _SecretKeyIntroPageState extends State<SecretKeyIntroPage> {
  final _inputController = TextEditingController();
  final _inputNode = FocusNode();

  SecretKeyIntroController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    // Ensure FlRust is initialized for key generation and live checksum validation.
    unawaited(
      FlRust.ensureInitialized().then(
        (_) {
          if (mounted) _ctrl.onRustReady(_inputController.text);
        },
        onError: (_) {},
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (_, cons) {
          final inset = columnInset(cons.maxWidth);
          return _ctrl.mode.listenVal((currentMode) {
            final lead = switch (currentMode) {
              SecretKeyIntroMode.newFresh => l10n.syncSecretKeyIntroFresh,
              SecretKeyIntroMode.newSynced => l10n.syncSecretKeyIntroSynced,
              SecretKeyIntroMode.upgradeDeviceA => l10n.syncSecretKeyIntroUpgradeA,
              SecretKeyIntroMode.upgradeDeviceB => l10n.syncSecretKeyIntroUpgradeB,
            };
            return ListView(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, 26),
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(13, widget.padTop, 13, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.vpn_key_outlined, size: 24, color: scheme.primary),
                      UIs.height13,
                      Text(
                        l10n.syncSecretKey,
                        style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 9),
                      Text(lead, style: const TextStyle(fontSize: 13, height: 1.5)),
                    ],
                  ),
                ),
                if (currentMode == SecretKeyIntroMode.newSynced)
                  _buildSyncedBody(context)
                else ...[
                  _ctrl.allowSwitchToImport.listenVal(
                    (canSwitch) => canSwitch ? _buildModeSwitch(context) : UIs.placeholder,
                  ),
                  _ctrl.isGenerateTab.listenVal(
                    (isGen) => isGen && currentMode != SecretKeyIntroMode.upgradeDeviceB
                        ? _buildGenerateBody(context)
                        : _buildImportBody(context),
                  ),
                  _buildSkipButton(context, currentMode),
                ],
              ],
            );
          });
        },
      ),
    );
  }

  Widget _buildModeSwitch(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: _ctrl.isGenerateTab.listenVal(
        (isGen) => SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment<bool>(
              value: true,
              label: Text(
                l10n.syncSecretKeyTabGenerate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ButtonSegment<bool>(
              value: false,
              label: Text(
                l10n.syncSecretKeyTabImport,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          selected: {isGen},
          onSelectionChanged: (s) => _ctrl.setGenerateTab(s.first),
        ),
      ),
    );
  }

  Widget _buildSyncedBody(BuildContext context) {
    final l10n = context.l10n;
    return _ctrl.displayKey.listenVal(
      (key) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (key != null) ...[
            SecretKeyQrDisplay(secretKey: key),
            UIs.height13,
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Text(
              l10n.syncSecretKeyIntroSyncedTip,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateBody(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SecretKeyZeroKnowledgeWarning(margin: EdgeInsets.only(bottom: 13)),
        _ctrl.displayKey.listenVal((key) {
          if (key == null) {
            return CardX(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Text(
                  l10n.syncSecretKeyUnavailable,
                  style: TextStyle(fontSize: 13, color: scheme.error),
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SecretKeyQrDisplay(secretKey: key),
              UIs.height13,
              CardX(
                child: _ctrl.acknowledged.listenVal(
                  (checked) => CheckboxListTile(
                    value: checked,
                    onChanged: (v) => _ctrl.setAcknowledged(v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.syncSecretKeyAck, style: UIs.text13),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildImportBody(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SecretKeyZeroKnowledgeWarning(margin: EdgeInsets.only(bottom: 13)),
        CardX(
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Input(
                  label: l10n.syncSecretKey,
                  hint: 'S1-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
                  controller: _inputController,
                  node: _inputNode,
                  suggestion: false,
                  noWrap: true,
                  onChanged: _ctrl.updateImportInput,
                ),
                UIs.height7,
                _ctrl.importStatus.listenVal((status) {
                  return switch (status) {
                    SecretKeyImportStatus.empty => UIs.placeholder,
                    SecretKeyImportStatus.valid => Text(
                      _ctrl.importedKey.value ?? '',
                      style: TextStyle(fontSize: 12, color: scheme.primary),
                    ),
                    SecretKeyImportStatus.invalid => Text(
                      l10n.syncSecretKeyInvalid,
                      style: TextStyle(fontSize: 12, color: scheme.error),
                    ),
                    SecretKeyImportStatus.unavailable => Text(
                      l10n.syncSecretKeyUnavailable,
                      style: TextStyle(fontSize: 12, color: scheme.error),
                    ),
                  };
                }),
                if (isMobile) ...[
                  UIs.height13,
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final scanned = await BarcodeScannerPage.route.go(
                          context,
                          args: const BarcodeScannerPageArgs(),
                        );
                        final text = scanned?.text;
                        if (text == null || !mounted) return;
                        _inputController.text = text.trim();
                        _ctrl.updateImportInput(text);
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: Text(l10n.syncSecretKeyScan),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkipButton(BuildContext context, SecretKeyIntroMode currentMode) {
    final l10n = context.l10n;
    return _ctrl.allowSwitchToImport.listenVal((canSwitch) {
      final label = switch (currentMode) {
        SecretKeyIntroMode.newFresh => l10n.syncSecretKeySkipNew,
        SecretKeyIntroMode.upgradeDeviceB => l10n.syncSecretKeySkipLater,
        SecretKeyIntroMode.upgradeDeviceA when canSwitch => l10n.syncSecretKeySkipLater,
        _ => null,
      };
      if (label == null) return UIs.placeholder;
      return Padding(
        padding: const EdgeInsets.only(top: 9),
        child: Center(
          child: TextButton(
            onPressed: () => unawaited(_ctrl.skip(context)),
            child: Text(label, style: UIs.textGrey),
          ),
        ),
      );
    });
  }
}
