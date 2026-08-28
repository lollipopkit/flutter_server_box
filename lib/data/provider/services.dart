import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/service/detector.dart';
import 'package:server_box/data/service/openrc.dart';
import 'package:server_box/data/service/procd.dart';
import 'package:server_box/data/service/service_manager.dart';
import 'package:server_box/data/service/systemd.dart';

part 'services.freezed.dart';
part 'services.g.dart';

enum ServiceIssue {
  unsupported,
  listFailed,
  unreachable,
}

final class ServiceFailure {
  const ServiceFailure(
    this.issue, {
    this.detail,
    this.detectedManager,
  });

  final ServiceIssue issue;
  final String? detail;
  final String? detectedManager;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceFailure &&
          other.issue == issue &&
          other.detail == detail &&
          other.detectedManager == detectedManager;

  @override
  int get hashCode => Object.hash(issue, detail, detectedManager);
}

@freezed
abstract class ServicesState with _$ServicesState {
  const factory ServicesState({
    @Default(false) bool isBusy,
    @Default(<ServiceUnit>[]) List<ServiceUnit> units,
    @Default(ServiceScopeFilter.all) ServiceScopeFilter scopeFilter,
    ServiceManagerType? manager,
    ServiceListingNotice? notice,
    String? noticeDetail,
    ServiceFailure? failure,
  }) = _ServicesState;
}

@riverpod
class ServicesNotifier extends _$ServicesNotifier {
  late final Spi _spi;
  ServiceManagerBackend? _manager;

  @override
  ServicesState build(Spi spi) {
    _spi = spi;
    return const ServicesState();
  }

  List<ServiceUnit> get filteredUnits {
    switch (state.scopeFilter) {
      case ServiceScopeFilter.all:
        return state.units;
      case ServiceScopeFilter.system:
        return state.units
            .where((unit) => unit.scope == ServiceScope.system)
            .toList();
      case ServiceScopeFilter.user:
        return state.units
            .where((unit) => unit.scope == ServiceScope.user)
            .toList();
    }
  }

  void setScopeFilter(ServiceScopeFilter filter) {
    state = state.copyWith(scopeFilter: filter);
  }

  String? commandFor(ServiceUnit unit, ServiceAction action) {
    return _manager?.commandFor(unit, action, isRoot: _spi.isRoot);
  }

  Future<void> getServices() async {
    state = state.copyWith(isBusy: true);

    final ServerExec exec;
    try {
      exec = await ref.read(serverProvider(_spi.id).notifier).ensureExec();
    } catch (e, s) {
      dprint('Services exec', e, s);
      state = state.copyWith(
        isBusy: false,
        failure: ServiceFailure(ServiceIssue.unreachable, detail: '$e'),
      );
      return;
    }

    try {
      final probe = await ServiceManagerDetector.probe(exec);
      final type = probe.type;
      if (type == null) {
        _manager = null;
        state = state.copyWith(
          units: const [],
          manager: null,
          notice: null,
          noticeDetail: null,
          failure: ServiceFailure(
            ServiceIssue.unsupported,
            detectedManager: probe.description.isEmpty
                ? null
                : probe.description,
          ),
        );
        return;
      }

      final manager = _managerFor(type);
      final listing = await manager.list(exec);
      _manager = manager;
      state = state.copyWith(
        units: listing.units,
        scopeFilter: type.supportsUserScope
            ? state.scopeFilter
            : ServiceScopeFilter.all,
        manager: type,
        notice: listing.notice,
        noticeDetail: listing.detail,
        failure: null,
      );
    } catch (e, s) {
      dprint('Services refresh', e, s);
      state = state.copyWith(
        units: const [],
        notice: null,
        noticeDetail: null,
        failure: ServiceFailure(ServiceIssue.listFailed, detail: '$e'),
      );
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  ServiceManagerBackend _managerFor(ServiceManagerType type) {
    return switch (type) {
      ServiceManagerType.systemd => const SystemdServiceManager(),
      ServiceManagerType.procd => const ProcdServiceManager(),
      ServiceManagerType.openrc => const OpenRcServiceManager(),
    };
  }
}
