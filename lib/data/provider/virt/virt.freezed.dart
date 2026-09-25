// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'virt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VirtProbe {

 VirtProbeStatus get status;/// libvirt's version, when found and readable.
 String? get version;/// `pveversion`'s line, for [VirtProbeStatus.pve].
 String? get pve;/// The container type (`lxc`, `docker`, …), for [VirtProbeStatus.absent].
 String? get container; VirtErr? get error;
/// Create a copy of VirtProbe
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtProbeCopyWith<VirtProbe> get copyWith => _$VirtProbeCopyWithImpl<VirtProbe>(this as VirtProbe, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtProbe&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version)&&(identical(other.pve, pve) || other.pve == pve)&&(identical(other.container, container) || other.container == container)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,status,version,pve,container,error);

@override
String toString() {
  return 'VirtProbe(status: $status, version: $version, pve: $pve, container: $container, error: $error)';
}


}

/// @nodoc
abstract mixin class $VirtProbeCopyWith<$Res>  {
  factory $VirtProbeCopyWith(VirtProbe value, $Res Function(VirtProbe) _then) = _$VirtProbeCopyWithImpl;
@useResult
$Res call({
 VirtProbeStatus status, String? version, String? pve, String? container, VirtErr? error
});




}
/// @nodoc
class _$VirtProbeCopyWithImpl<$Res>
    implements $VirtProbeCopyWith<$Res> {
  _$VirtProbeCopyWithImpl(this._self, this._then);

  final VirtProbe _self;
  final $Res Function(VirtProbe) _then;

/// Create a copy of VirtProbe
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? version = freezed,Object? pve = freezed,Object? container = freezed,Object? error = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as VirtProbeStatus,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,pve: freezed == pve ? _self.pve : pve // ignore: cast_nullable_to_non_nullable
as String?,container: freezed == container ? _self.container : container // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as VirtErr?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtProbe].
extension VirtProbePatterns on VirtProbe {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtProbe value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtProbe() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtProbe value)  $default,){
final _that = this;
switch (_that) {
case _VirtProbe():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtProbe value)?  $default,){
final _that = this;
switch (_that) {
case _VirtProbe() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VirtProbeStatus status,  String? version,  String? pve,  String? container,  VirtErr? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtProbe() when $default != null:
return $default(_that.status,_that.version,_that.pve,_that.container,_that.error);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VirtProbeStatus status,  String? version,  String? pve,  String? container,  VirtErr? error)  $default,) {final _that = this;
switch (_that) {
case _VirtProbe():
return $default(_that.status,_that.version,_that.pve,_that.container,_that.error);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VirtProbeStatus status,  String? version,  String? pve,  String? container,  VirtErr? error)?  $default,) {final _that = this;
switch (_that) {
case _VirtProbe() when $default != null:
return $default(_that.status,_that.version,_that.pve,_that.container,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _VirtProbe implements VirtProbe {
  const _VirtProbe({required this.status, this.version, this.pve, this.container, this.error});
  

@override final  VirtProbeStatus status;
/// libvirt's version, when found and readable.
@override final  String? version;
/// `pveversion`'s line, for [VirtProbeStatus.pve].
@override final  String? pve;
/// The container type (`lxc`, `docker`, …), for [VirtProbeStatus.absent].
@override final  String? container;
@override final  VirtErr? error;

/// Create a copy of VirtProbe
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtProbeCopyWith<_VirtProbe> get copyWith => __$VirtProbeCopyWithImpl<_VirtProbe>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtProbe&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version)&&(identical(other.pve, pve) || other.pve == pve)&&(identical(other.container, container) || other.container == container)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,status,version,pve,container,error);

@override
String toString() {
  return 'VirtProbe(status: $status, version: $version, pve: $pve, container: $container, error: $error)';
}


}

/// @nodoc
abstract mixin class _$VirtProbeCopyWith<$Res> implements $VirtProbeCopyWith<$Res> {
  factory _$VirtProbeCopyWith(_VirtProbe value, $Res Function(_VirtProbe) _then) = __$VirtProbeCopyWithImpl;
@override @useResult
$Res call({
 VirtProbeStatus status, String? version, String? pve, String? container, VirtErr? error
});




}
/// @nodoc
class __$VirtProbeCopyWithImpl<$Res>
    implements _$VirtProbeCopyWith<$Res> {
  __$VirtProbeCopyWithImpl(this._self, this._then);

  final _VirtProbe _self;
  final $Res Function(_VirtProbe) _then;

/// Create a copy of VirtProbe
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? version = freezed,Object? pve = freezed,Object? container = freezed,Object? error = freezed,}) {
  return _then(_VirtProbe(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as VirtProbeStatus,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,pve: freezed == pve ? _self.pve : pve // ignore: cast_nullable_to_non_nullable
as String?,container: freezed == container ? _self.container : container // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as VirtErr?,
  ));
}


}

/// @nodoc
mixin _$VirtHostsState {

/// Virtualization hosts in the server list's order, with their kind.
 Map<String, VirtHostKind> get hosts;/// The other servers, in order: not probed yet, probed and not a host,
/// or not reachable. The host switcher offers them under "Check this
/// server" ([VirtHosts.probe]).
 List<String> get others;/// Host probe results by server id, this session's.
 Map<String, VirtProbe> get probes;
/// Create a copy of VirtHostsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHostsStateCopyWith<VirtHostsState> get copyWith => _$VirtHostsStateCopyWithImpl<VirtHostsState>(this as VirtHostsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHostsState&&const DeepCollectionEquality().equals(other.hosts, hosts)&&const DeepCollectionEquality().equals(other.others, others)&&const DeepCollectionEquality().equals(other.probes, probes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(hosts),const DeepCollectionEquality().hash(others),const DeepCollectionEquality().hash(probes));

@override
String toString() {
  return 'VirtHostsState(hosts: $hosts, others: $others, probes: $probes)';
}


}

/// @nodoc
abstract mixin class $VirtHostsStateCopyWith<$Res>  {
  factory $VirtHostsStateCopyWith(VirtHostsState value, $Res Function(VirtHostsState) _then) = _$VirtHostsStateCopyWithImpl;
@useResult
$Res call({
 Map<String, VirtHostKind> hosts, List<String> others, Map<String, VirtProbe> probes
});




}
/// @nodoc
class _$VirtHostsStateCopyWithImpl<$Res>
    implements $VirtHostsStateCopyWith<$Res> {
  _$VirtHostsStateCopyWithImpl(this._self, this._then);

  final VirtHostsState _self;
  final $Res Function(VirtHostsState) _then;

/// Create a copy of VirtHostsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hosts = null,Object? others = null,Object? probes = null,}) {
  return _then(_self.copyWith(
hosts: null == hosts ? _self.hosts : hosts // ignore: cast_nullable_to_non_nullable
as Map<String, VirtHostKind>,others: null == others ? _self.others : others // ignore: cast_nullable_to_non_nullable
as List<String>,probes: null == probes ? _self.probes : probes // ignore: cast_nullable_to_non_nullable
as Map<String, VirtProbe>,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtHostsState].
extension VirtHostsStatePatterns on VirtHostsState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHostsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHostsState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHostsState value)  $default,){
final _that = this;
switch (_that) {
case _VirtHostsState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHostsState value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHostsState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, VirtHostKind> hosts,  List<String> others,  Map<String, VirtProbe> probes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHostsState() when $default != null:
return $default(_that.hosts,_that.others,_that.probes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, VirtHostKind> hosts,  List<String> others,  Map<String, VirtProbe> probes)  $default,) {final _that = this;
switch (_that) {
case _VirtHostsState():
return $default(_that.hosts,_that.others,_that.probes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, VirtHostKind> hosts,  List<String> others,  Map<String, VirtProbe> probes)?  $default,) {final _that = this;
switch (_that) {
case _VirtHostsState() when $default != null:
return $default(_that.hosts,_that.others,_that.probes);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHostsState extends VirtHostsState {
  const _VirtHostsState({final  Map<String, VirtHostKind> hosts = const <String, VirtHostKind>{}, final  List<String> others = const <String>[], final  Map<String, VirtProbe> probes = const <String, VirtProbe>{}}): _hosts = hosts,_others = others,_probes = probes,super._();
  

/// Virtualization hosts in the server list's order, with their kind.
 final  Map<String, VirtHostKind> _hosts;
/// Virtualization hosts in the server list's order, with their kind.
@override@JsonKey() Map<String, VirtHostKind> get hosts {
  if (_hosts is EqualUnmodifiableMapView) return _hosts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_hosts);
}

/// The other servers, in order: not probed yet, probed and not a host,
/// or not reachable. The host switcher offers them under "Check this
/// server" ([VirtHosts.probe]).
 final  List<String> _others;
/// The other servers, in order: not probed yet, probed and not a host,
/// or not reachable. The host switcher offers them under "Check this
/// server" ([VirtHosts.probe]).
@override@JsonKey() List<String> get others {
  if (_others is EqualUnmodifiableListView) return _others;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_others);
}

/// Host probe results by server id, this session's.
 final  Map<String, VirtProbe> _probes;
/// Host probe results by server id, this session's.
@override@JsonKey() Map<String, VirtProbe> get probes {
  if (_probes is EqualUnmodifiableMapView) return _probes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_probes);
}


/// Create a copy of VirtHostsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHostsStateCopyWith<_VirtHostsState> get copyWith => __$VirtHostsStateCopyWithImpl<_VirtHostsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHostsState&&const DeepCollectionEquality().equals(other._hosts, _hosts)&&const DeepCollectionEquality().equals(other._others, _others)&&const DeepCollectionEquality().equals(other._probes, _probes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_hosts),const DeepCollectionEquality().hash(_others),const DeepCollectionEquality().hash(_probes));

@override
String toString() {
  return 'VirtHostsState(hosts: $hosts, others: $others, probes: $probes)';
}


}

/// @nodoc
abstract mixin class _$VirtHostsStateCopyWith<$Res> implements $VirtHostsStateCopyWith<$Res> {
  factory _$VirtHostsStateCopyWith(_VirtHostsState value, $Res Function(_VirtHostsState) _then) = __$VirtHostsStateCopyWithImpl;
@override @useResult
$Res call({
 Map<String, VirtHostKind> hosts, List<String> others, Map<String, VirtProbe> probes
});




}
/// @nodoc
class __$VirtHostsStateCopyWithImpl<$Res>
    implements _$VirtHostsStateCopyWith<$Res> {
  __$VirtHostsStateCopyWithImpl(this._self, this._then);

  final _VirtHostsState _self;
  final $Res Function(_VirtHostsState) _then;

/// Create a copy of VirtHostsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hosts = null,Object? others = null,Object? probes = null,}) {
  return _then(_VirtHostsState(
hosts: null == hosts ? _self._hosts : hosts // ignore: cast_nullable_to_non_nullable
as Map<String, VirtHostKind>,others: null == others ? _self._others : others // ignore: cast_nullable_to_non_nullable
as List<String>,probes: null == probes ? _self._probes : probes // ignore: cast_nullable_to_non_nullable
as Map<String, VirtProbe>,
  ));
}


}

/// @nodoc
mixin _$VirtHostState {

 String get serverId;/// Null only for a server that no longer exists.
 VirtHostKind? get kind;/// The last successful load. Kept while [error] is set, so the list does
/// not blank on one failed refresh.
 VirtSnapshot? get data;/// Why the last refresh failed; null after a success.
 VirtErr? get error;/// A refresh someone asked for is running (an automatic one is not
/// announced).
 bool get loading;/// Guests with a power action in flight, and which.
 Map<String, VirtPowerAction> get busy;/// Guests with a snapshot operation in flight, and which. A guest in
/// either map takes no other action until it is out.
 Map<String, VirtSnapshotOp> get snapshotOps;/// Guests being deleted.
 Set<String> get deleting;/// Guests with a hardware change in flight.
 Set<String> get editing;/// This session's readings per guest, oldest first, capped at
/// [VirtHostNotifier.sampleLimit] — the chart for a host without
/// `storedHistory`, and the live tail for one with it.
 Map<String, List<VirtStats>> get samples; DateTime? get updatedAt;
/// Create a copy of VirtHostState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHostStateCopyWith<VirtHostState> get copyWith => _$VirtHostStateCopyWithImpl<VirtHostState>(this as VirtHostState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHostState&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.data, data) || other.data == data)&&(identical(other.error, error) || other.error == error)&&(identical(other.loading, loading) || other.loading == loading)&&const DeepCollectionEquality().equals(other.busy, busy)&&const DeepCollectionEquality().equals(other.snapshotOps, snapshotOps)&&const DeepCollectionEquality().equals(other.deleting, deleting)&&const DeepCollectionEquality().equals(other.editing, editing)&&const DeepCollectionEquality().equals(other.samples, samples)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,serverId,kind,data,error,loading,const DeepCollectionEquality().hash(busy),const DeepCollectionEquality().hash(snapshotOps),const DeepCollectionEquality().hash(deleting),const DeepCollectionEquality().hash(editing),const DeepCollectionEquality().hash(samples),updatedAt);

@override
String toString() {
  return 'VirtHostState(serverId: $serverId, kind: $kind, data: $data, error: $error, loading: $loading, busy: $busy, snapshotOps: $snapshotOps, deleting: $deleting, editing: $editing, samples: $samples, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $VirtHostStateCopyWith<$Res>  {
  factory $VirtHostStateCopyWith(VirtHostState value, $Res Function(VirtHostState) _then) = _$VirtHostStateCopyWithImpl;
@useResult
$Res call({
 String serverId, VirtHostKind? kind, VirtSnapshot? data, VirtErr? error, bool loading, Map<String, VirtPowerAction> busy, Map<String, VirtSnapshotOp> snapshotOps, Set<String> deleting, Set<String> editing, Map<String, List<VirtStats>> samples, DateTime? updatedAt
});


$VirtSnapshotCopyWith<$Res>? get data;

}
/// @nodoc
class _$VirtHostStateCopyWithImpl<$Res>
    implements $VirtHostStateCopyWith<$Res> {
  _$VirtHostStateCopyWithImpl(this._self, this._then);

  final VirtHostState _self;
  final $Res Function(VirtHostState) _then;

/// Create a copy of VirtHostState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serverId = null,Object? kind = freezed,Object? data = freezed,Object? error = freezed,Object? loading = null,Object? busy = null,Object? snapshotOps = null,Object? deleting = null,Object? editing = null,Object? samples = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtHostKind?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as VirtSnapshot?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as VirtErr?,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as Map<String, VirtPowerAction>,snapshotOps: null == snapshotOps ? _self.snapshotOps : snapshotOps // ignore: cast_nullable_to_non_nullable
as Map<String, VirtSnapshotOp>,deleting: null == deleting ? _self.deleting : deleting // ignore: cast_nullable_to_non_nullable
as Set<String>,editing: null == editing ? _self.editing : editing // ignore: cast_nullable_to_non_nullable
as Set<String>,samples: null == samples ? _self.samples : samples // ignore: cast_nullable_to_non_nullable
as Map<String, List<VirtStats>>,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of VirtHostState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtSnapshotCopyWith<$Res>? get data {
    if (_self.data == null) {
    return null;
  }

  return $VirtSnapshotCopyWith<$Res>(_self.data!, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [VirtHostState].
extension VirtHostStatePatterns on VirtHostState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHostState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHostState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHostState value)  $default,){
final _that = this;
switch (_that) {
case _VirtHostState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHostState value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHostState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serverId,  VirtHostKind? kind,  VirtSnapshot? data,  VirtErr? error,  bool loading,  Map<String, VirtPowerAction> busy,  Map<String, VirtSnapshotOp> snapshotOps,  Set<String> deleting,  Set<String> editing,  Map<String, List<VirtStats>> samples,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHostState() when $default != null:
return $default(_that.serverId,_that.kind,_that.data,_that.error,_that.loading,_that.busy,_that.snapshotOps,_that.deleting,_that.editing,_that.samples,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serverId,  VirtHostKind? kind,  VirtSnapshot? data,  VirtErr? error,  bool loading,  Map<String, VirtPowerAction> busy,  Map<String, VirtSnapshotOp> snapshotOps,  Set<String> deleting,  Set<String> editing,  Map<String, List<VirtStats>> samples,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _VirtHostState():
return $default(_that.serverId,_that.kind,_that.data,_that.error,_that.loading,_that.busy,_that.snapshotOps,_that.deleting,_that.editing,_that.samples,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serverId,  VirtHostKind? kind,  VirtSnapshot? data,  VirtErr? error,  bool loading,  Map<String, VirtPowerAction> busy,  Map<String, VirtSnapshotOp> snapshotOps,  Set<String> deleting,  Set<String> editing,  Map<String, List<VirtStats>> samples,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _VirtHostState() when $default != null:
return $default(_that.serverId,_that.kind,_that.data,_that.error,_that.loading,_that.busy,_that.snapshotOps,_that.deleting,_that.editing,_that.samples,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _VirtHostState extends VirtHostState {
  const _VirtHostState({required this.serverId, this.kind, this.data, this.error, this.loading = false, final  Map<String, VirtPowerAction> busy = const <String, VirtPowerAction>{}, final  Map<String, VirtSnapshotOp> snapshotOps = const <String, VirtSnapshotOp>{}, final  Set<String> deleting = const <String>{}, final  Set<String> editing = const <String>{}, final  Map<String, List<VirtStats>> samples = const <String, List<VirtStats>>{}, this.updatedAt}): _busy = busy,_snapshotOps = snapshotOps,_deleting = deleting,_editing = editing,_samples = samples,super._();
  

@override final  String serverId;
/// Null only for a server that no longer exists.
@override final  VirtHostKind? kind;
/// The last successful load. Kept while [error] is set, so the list does
/// not blank on one failed refresh.
@override final  VirtSnapshot? data;
/// Why the last refresh failed; null after a success.
@override final  VirtErr? error;
/// A refresh someone asked for is running (an automatic one is not
/// announced).
@override@JsonKey() final  bool loading;
/// Guests with a power action in flight, and which.
 final  Map<String, VirtPowerAction> _busy;
/// Guests with a power action in flight, and which.
@override@JsonKey() Map<String, VirtPowerAction> get busy {
  if (_busy is EqualUnmodifiableMapView) return _busy;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_busy);
}

/// Guests with a snapshot operation in flight, and which. A guest in
/// either map takes no other action until it is out.
 final  Map<String, VirtSnapshotOp> _snapshotOps;
/// Guests with a snapshot operation in flight, and which. A guest in
/// either map takes no other action until it is out.
@override@JsonKey() Map<String, VirtSnapshotOp> get snapshotOps {
  if (_snapshotOps is EqualUnmodifiableMapView) return _snapshotOps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_snapshotOps);
}

/// Guests being deleted.
 final  Set<String> _deleting;
/// Guests being deleted.
@override@JsonKey() Set<String> get deleting {
  if (_deleting is EqualUnmodifiableSetView) return _deleting;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_deleting);
}

/// Guests with a hardware change in flight.
 final  Set<String> _editing;
/// Guests with a hardware change in flight.
@override@JsonKey() Set<String> get editing {
  if (_editing is EqualUnmodifiableSetView) return _editing;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_editing);
}

/// This session's readings per guest, oldest first, capped at
/// [VirtHostNotifier.sampleLimit] — the chart for a host without
/// `storedHistory`, and the live tail for one with it.
 final  Map<String, List<VirtStats>> _samples;
/// This session's readings per guest, oldest first, capped at
/// [VirtHostNotifier.sampleLimit] — the chart for a host without
/// `storedHistory`, and the live tail for one with it.
@override@JsonKey() Map<String, List<VirtStats>> get samples {
  if (_samples is EqualUnmodifiableMapView) return _samples;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_samples);
}

@override final  DateTime? updatedAt;

/// Create a copy of VirtHostState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHostStateCopyWith<_VirtHostState> get copyWith => __$VirtHostStateCopyWithImpl<_VirtHostState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHostState&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.data, data) || other.data == data)&&(identical(other.error, error) || other.error == error)&&(identical(other.loading, loading) || other.loading == loading)&&const DeepCollectionEquality().equals(other._busy, _busy)&&const DeepCollectionEquality().equals(other._snapshotOps, _snapshotOps)&&const DeepCollectionEquality().equals(other._deleting, _deleting)&&const DeepCollectionEquality().equals(other._editing, _editing)&&const DeepCollectionEquality().equals(other._samples, _samples)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,serverId,kind,data,error,loading,const DeepCollectionEquality().hash(_busy),const DeepCollectionEquality().hash(_snapshotOps),const DeepCollectionEquality().hash(_deleting),const DeepCollectionEquality().hash(_editing),const DeepCollectionEquality().hash(_samples),updatedAt);

@override
String toString() {
  return 'VirtHostState(serverId: $serverId, kind: $kind, data: $data, error: $error, loading: $loading, busy: $busy, snapshotOps: $snapshotOps, deleting: $deleting, editing: $editing, samples: $samples, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$VirtHostStateCopyWith<$Res> implements $VirtHostStateCopyWith<$Res> {
  factory _$VirtHostStateCopyWith(_VirtHostState value, $Res Function(_VirtHostState) _then) = __$VirtHostStateCopyWithImpl;
@override @useResult
$Res call({
 String serverId, VirtHostKind? kind, VirtSnapshot? data, VirtErr? error, bool loading, Map<String, VirtPowerAction> busy, Map<String, VirtSnapshotOp> snapshotOps, Set<String> deleting, Set<String> editing, Map<String, List<VirtStats>> samples, DateTime? updatedAt
});


@override $VirtSnapshotCopyWith<$Res>? get data;

}
/// @nodoc
class __$VirtHostStateCopyWithImpl<$Res>
    implements _$VirtHostStateCopyWith<$Res> {
  __$VirtHostStateCopyWithImpl(this._self, this._then);

  final _VirtHostState _self;
  final $Res Function(_VirtHostState) _then;

/// Create a copy of VirtHostState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serverId = null,Object? kind = freezed,Object? data = freezed,Object? error = freezed,Object? loading = null,Object? busy = null,Object? snapshotOps = null,Object? deleting = null,Object? editing = null,Object? samples = null,Object? updatedAt = freezed,}) {
  return _then(_VirtHostState(
serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtHostKind?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as VirtSnapshot?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as VirtErr?,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,busy: null == busy ? _self._busy : busy // ignore: cast_nullable_to_non_nullable
as Map<String, VirtPowerAction>,snapshotOps: null == snapshotOps ? _self._snapshotOps : snapshotOps // ignore: cast_nullable_to_non_nullable
as Map<String, VirtSnapshotOp>,deleting: null == deleting ? _self._deleting : deleting // ignore: cast_nullable_to_non_nullable
as Set<String>,editing: null == editing ? _self._editing : editing // ignore: cast_nullable_to_non_nullable
as Set<String>,samples: null == samples ? _self._samples : samples // ignore: cast_nullable_to_non_nullable
as Map<String, List<VirtStats>>,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of VirtHostState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtSnapshotCopyWith<$Res>? get data {
    if (_self.data == null) {
    return null;
  }

  return $VirtSnapshotCopyWith<$Res>(_self.data!, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
