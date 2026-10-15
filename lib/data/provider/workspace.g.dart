// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every workspace, and which one is on screen.
///
/// Kept alive and app-wide rather than in the tab's state: the terminal tab
/// moves a session into one, and quick open lists them, without the workspace
/// tab having been built.

@ProviderFor(Workspaces)
final workspacesProvider = WorkspacesProvider._();

/// Every workspace, and which one is on screen.
///
/// Kept alive and app-wide rather than in the tab's state: the terminal tab
/// moves a session into one, and quick open lists them, without the workspace
/// tab having been built.
final class WorkspacesProvider
    extends $NotifierProvider<Workspaces, WorkspacesState> {
  /// Every workspace, and which one is on screen.
  ///
  /// Kept alive and app-wide rather than in the tab's state: the terminal tab
  /// moves a session into one, and quick open lists them, without the workspace
  /// tab having been built.
  WorkspacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspacesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspacesHash();

  @$internal
  @override
  Workspaces create() => Workspaces();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspacesState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspacesState>(value),
    );
  }
}

String _$workspacesHash() => r'f0bebff649df24d89bc8c15e903e592c56bc5756';

/// Every workspace, and which one is on screen.
///
/// Kept alive and app-wide rather than in the tab's state: the terminal tab
/// moves a session into one, and quick open lists them, without the workspace
/// tab having been built.

abstract class _$Workspaces extends $Notifier<WorkspacesState> {
  WorkspacesState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WorkspacesState, WorkspacesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WorkspacesState, WorkspacesState>,
              WorkspacesState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The saved layouts.

@ProviderFor(WorkspaceTemplates)
final workspaceTemplatesProvider = WorkspaceTemplatesProvider._();

/// The saved layouts.
final class WorkspaceTemplatesProvider
    extends $NotifierProvider<WorkspaceTemplates, List<WsTemplate>> {
  /// The saved layouts.
  WorkspaceTemplatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceTemplatesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceTemplatesHash();

  @$internal
  @override
  WorkspaceTemplates create() => WorkspaceTemplates();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<WsTemplate> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<WsTemplate>>(value),
    );
  }
}

String _$workspaceTemplatesHash() =>
    r'5e99787684dab1d51f9c6b98b897d819fb56de11';

/// The saved layouts.

abstract class _$WorkspaceTemplates extends $Notifier<List<WsTemplate>> {
  List<WsTemplate> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<WsTemplate>, List<WsTemplate>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<WsTemplate>, List<WsTemplate>>,
              List<WsTemplate>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
