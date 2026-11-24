import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/terminal/terminal_session.dart';
import 'package:server_box/data/terminal/terminal_source.dart';
import 'package:xterm/ui.dart' show TerminalViewState;

final class SshPageArgs {
  /// Where this terminal's shell comes from. A server, or this device — and
  /// what is only true of a server is reached through [spi], which is null for
  /// the other one.
  final TerminalSource source;

  /// The server behind [source], when there is one.
  Spi? get spi => switch (source) {
    ServerSource(:final spi) => spi,
    LocalSource() || ConsoleSource() => null,
  };

  /// Whether there is a link to re-establish by hand: a server's shell or a
  /// guest's console, and not one on this device.
  bool get canReconnect => switch (source) {
    ServerSource(:final spi) => !spi.local,
    ConsoleSource() => true,
    LocalSource() => false,
  };

  final String? initCmd;

  /// Whether [initCmd] is what the shell is for, and so typed again into the
  /// fresh shell a reconnect opens (`TerminalSession.reenter`). A guest's
  /// serial console is; a command run once, such as a service's logs, is not.
  final bool reenter;

  /// Whether [initCmd] starts with sudo, whose prompt is then answered from
  /// the session's sudo password (`TerminalSession.answersSudo`).
  final bool initCmdSudo;
  final Snippet? initSnippet;

  /// What ends the program [initCmd] started without ending the shell under
  /// it — `virsh console`'s escape, Ctrl+]. Given, the bar offers it as
  /// "Disconnect", since the key itself is two presses away on a phone and
  /// nothing on screen says it exists.
  final List<int>? detachInput;

  /// A shell that is already running, to be shown here instead of opening one.
  ///
  /// How a snippet started in a dialog carries on in a tab: the connection and
  /// everything printed into it are the session's, not the page's, so the page
  /// showing them can change without the shell noticing.
  final TerminalSession? session;

  /// Where the session goes when this page does, instead of being closed.
  ///
  /// For a shell that is meant to outlive the page showing it — a guest's text
  /// console, kept running for a while after it is left (`VirtTextConsoles`).
  /// Given the session as it is: still connected, still writing into its
  /// terminal, and with nothing called when its shell ends. Called after the
  /// frame that removed the page, so it may write to a provider.
  final void Function(TerminalSession session)? onLeave;

  /// Given the page's session after its first frame: made here or handed in
  /// as [session]. For a host showing what the session's programs report
  /// without the page being on screen.
  final void Function(TerminalSession session)? onSession;

  /// Brings this terminal on screen in its host, for a tapped notification.
  /// The home tab is switched to [homeTab] before this is called.
  final VoidCallback? onReveal;
  final bool notFromTab;
  final Function()? onSessionEnd;
  final GlobalKey<TerminalViewState>? terminalKey;
  final FocusNode? focusNode;
  final ValueListenable<bool>? visibleListenable;

  /// The home tab a page shown in place ([notFromTab] false) lives in: what
  /// "on screen" is checked against, with [visibleListenable].
  final AppTab homeTab;

  const SshPageArgs({
    required this.source,
    this.initCmd,
    this.reenter = false,
    this.initCmdSudo = false,
    this.initSnippet,
    this.detachInput,
    this.session,
    this.onLeave,
    this.onSession,
    this.onReveal,
    this.notFromTab = true,
    this.onSessionEnd,
    this.terminalKey,
    this.focusNode,
    this.visibleListenable,
    this.homeTab = AppTab.ssh,
  }) : assert(
         notFromTab || visibleListenable != null,
         'visibleListenable is required when notFromTab is false',
       );

  /// These arguments for a page shown in place inside [homeTab] rather than
  /// pushed: no bar of its own, on screen while [visible] says so and the tab
  /// is the one showing, and [onSessionEnd] instead of popping when the shell
  /// ends.
  SshPageArgs embeddedIn(
    AppTab homeTab, {
    required ValueListenable<bool> visible,
    FocusNode? focusNode,
    VoidCallback? onSessionEnd,
  }) => SshPageArgs(
    source: source,
    initCmd: initCmd,
    reenter: reenter,
    initCmdSudo: initCmdSudo,
    initSnippet: initSnippet,
    detachInput: detachInput,
    session: session,
    onLeave: onLeave,
    notFromTab: false,
    onSessionEnd: onSessionEnd,
    terminalKey: terminalKey,
    focusNode: focusNode,
    visibleListenable: visible,
    homeTab: homeTab,
  );
}
