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
mixin _$VirtNode {

 String get name; bool get online;/// Fraction of [maxCpu] in use, 0..1.
 double? get cpu; int? get maxCpu; int? get memUsed; int? get memTotal; Duration? get uptime;
/// Create a copy of VirtNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtNodeCopyWith<VirtNode> get copyWith => _$VirtNodeCopyWithImpl<VirtNode>(this as VirtNode, _$identity);

  /// Serializes this VirtNode to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtNode&&(identical(other.name, name) || other.name == name)&&(identical(other.online, online) || other.online == online)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.maxCpu, maxCpu) || other.maxCpu == maxCpu)&&(identical(other.memUsed, memUsed) || other.memUsed == memUsed)&&(identical(other.memTotal, memTotal) || other.memTotal == memTotal)&&(identical(other.uptime, uptime) || other.uptime == uptime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,online,cpu,maxCpu,memUsed,memTotal,uptime);

@override
String toString() {
  return 'VirtNode(name: $name, online: $online, cpu: $cpu, maxCpu: $maxCpu, memUsed: $memUsed, memTotal: $memTotal, uptime: $uptime)';
}


}

/// @nodoc
abstract mixin class $VirtNodeCopyWith<$Res>  {
  factory $VirtNodeCopyWith(VirtNode value, $Res Function(VirtNode) _then) = _$VirtNodeCopyWithImpl;
@useResult
$Res call({
 String name, bool online, double? cpu, int? maxCpu, int? memUsed, int? memTotal, Duration? uptime
});




}
/// @nodoc
class _$VirtNodeCopyWithImpl<$Res>
    implements $VirtNodeCopyWith<$Res> {
  _$VirtNodeCopyWithImpl(this._self, this._then);

  final VirtNode _self;
  final $Res Function(VirtNode) _then;

/// Create a copy of VirtNode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? online = null,Object? cpu = freezed,Object? maxCpu = freezed,Object? memUsed = freezed,Object? memTotal = freezed,Object? uptime = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,cpu: freezed == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as double?,maxCpu: freezed == maxCpu ? _self.maxCpu : maxCpu // ignore: cast_nullable_to_non_nullable
as int?,memUsed: freezed == memUsed ? _self.memUsed : memUsed // ignore: cast_nullable_to_non_nullable
as int?,memTotal: freezed == memTotal ? _self.memTotal : memTotal // ignore: cast_nullable_to_non_nullable
as int?,uptime: freezed == uptime ? _self.uptime : uptime // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtNode].
extension VirtNodePatterns on VirtNode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtNode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtNode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtNode value)  $default,){
final _that = this;
switch (_that) {
case _VirtNode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtNode value)?  $default,){
final _that = this;
switch (_that) {
case _VirtNode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  bool online,  double? cpu,  int? maxCpu,  int? memUsed,  int? memTotal,  Duration? uptime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtNode() when $default != null:
return $default(_that.name,_that.online,_that.cpu,_that.maxCpu,_that.memUsed,_that.memTotal,_that.uptime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  bool online,  double? cpu,  int? maxCpu,  int? memUsed,  int? memTotal,  Duration? uptime)  $default,) {final _that = this;
switch (_that) {
case _VirtNode():
return $default(_that.name,_that.online,_that.cpu,_that.maxCpu,_that.memUsed,_that.memTotal,_that.uptime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  bool online,  double? cpu,  int? maxCpu,  int? memUsed,  int? memTotal,  Duration? uptime)?  $default,) {final _that = this;
switch (_that) {
case _VirtNode() when $default != null:
return $default(_that.name,_that.online,_that.cpu,_that.maxCpu,_that.memUsed,_that.memTotal,_that.uptime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VirtNode implements VirtNode {
  const _VirtNode({required this.name, this.online = true, this.cpu, this.maxCpu, this.memUsed, this.memTotal, this.uptime});
  factory _VirtNode.fromJson(Map<String, dynamic> json) => _$VirtNodeFromJson(json);

@override final  String name;
@override@JsonKey() final  bool online;
/// Fraction of [maxCpu] in use, 0..1.
@override final  double? cpu;
@override final  int? maxCpu;
@override final  int? memUsed;
@override final  int? memTotal;
@override final  Duration? uptime;

/// Create a copy of VirtNode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtNodeCopyWith<_VirtNode> get copyWith => __$VirtNodeCopyWithImpl<_VirtNode>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VirtNodeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtNode&&(identical(other.name, name) || other.name == name)&&(identical(other.online, online) || other.online == online)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.maxCpu, maxCpu) || other.maxCpu == maxCpu)&&(identical(other.memUsed, memUsed) || other.memUsed == memUsed)&&(identical(other.memTotal, memTotal) || other.memTotal == memTotal)&&(identical(other.uptime, uptime) || other.uptime == uptime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,online,cpu,maxCpu,memUsed,memTotal,uptime);

@override
String toString() {
  return 'VirtNode(name: $name, online: $online, cpu: $cpu, maxCpu: $maxCpu, memUsed: $memUsed, memTotal: $memTotal, uptime: $uptime)';
}


}

/// @nodoc
abstract mixin class _$VirtNodeCopyWith<$Res> implements $VirtNodeCopyWith<$Res> {
  factory _$VirtNodeCopyWith(_VirtNode value, $Res Function(_VirtNode) _then) = __$VirtNodeCopyWithImpl;
@override @useResult
$Res call({
 String name, bool online, double? cpu, int? maxCpu, int? memUsed, int? memTotal, Duration? uptime
});




}
/// @nodoc
class __$VirtNodeCopyWithImpl<$Res>
    implements _$VirtNodeCopyWith<$Res> {
  __$VirtNodeCopyWithImpl(this._self, this._then);

  final _VirtNode _self;
  final $Res Function(_VirtNode) _then;

/// Create a copy of VirtNode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? online = null,Object? cpu = freezed,Object? maxCpu = freezed,Object? memUsed = freezed,Object? memTotal = freezed,Object? uptime = freezed,}) {
  return _then(_VirtNode(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,cpu: freezed == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as double?,maxCpu: freezed == maxCpu ? _self.maxCpu : maxCpu // ignore: cast_nullable_to_non_nullable
as int?,memUsed: freezed == memUsed ? _self.memUsed : memUsed // ignore: cast_nullable_to_non_nullable
as int?,memTotal: freezed == memTotal ? _self.memTotal : memTotal // ignore: cast_nullable_to_non_nullable
as int?,uptime: freezed == uptime ? _self.uptime : uptime // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}


}


/// @nodoc
mixin _$VirtHost {

 String get serverId; VirtHostKind get kind;/// PVE's release (`8.2`), or libvirt's library version (`10.0.0`).
 String? get version;/// The hypervisor as the host names it, e.g. `QEMU 8.2.2`. libvirt only.
 String? get hypervisor; List<VirtNode> get nodes;
/// Create a copy of VirtHost
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtHostCopyWith<VirtHost> get copyWith => _$VirtHostCopyWithImpl<VirtHost>(this as VirtHost, _$identity);

  /// Serializes this VirtHost to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtHost&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.version, version) || other.version == version)&&(identical(other.hypervisor, hypervisor) || other.hypervisor == hypervisor)&&const DeepCollectionEquality().equals(other.nodes, nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serverId,kind,version,hypervisor,const DeepCollectionEquality().hash(nodes));

@override
String toString() {
  return 'VirtHost(serverId: $serverId, kind: $kind, version: $version, hypervisor: $hypervisor, nodes: $nodes)';
}


}

/// @nodoc
abstract mixin class $VirtHostCopyWith<$Res>  {
  factory $VirtHostCopyWith(VirtHost value, $Res Function(VirtHost) _then) = _$VirtHostCopyWithImpl;
@useResult
$Res call({
 String serverId, VirtHostKind kind, String? version, String? hypervisor, List<VirtNode> nodes
});




}
/// @nodoc
class _$VirtHostCopyWithImpl<$Res>
    implements $VirtHostCopyWith<$Res> {
  _$VirtHostCopyWithImpl(this._self, this._then);

  final VirtHost _self;
  final $Res Function(VirtHost) _then;

/// Create a copy of VirtHost
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serverId = null,Object? kind = null,Object? version = freezed,Object? hypervisor = freezed,Object? nodes = null,}) {
  return _then(_self.copyWith(
serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtHostKind,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,hypervisor: freezed == hypervisor ? _self.hypervisor : hypervisor // ignore: cast_nullable_to_non_nullable
as String?,nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<VirtNode>,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtHost].
extension VirtHostPatterns on VirtHost {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtHost value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtHost() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtHost value)  $default,){
final _that = this;
switch (_that) {
case _VirtHost():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtHost value)?  $default,){
final _that = this;
switch (_that) {
case _VirtHost() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serverId,  VirtHostKind kind,  String? version,  String? hypervisor,  List<VirtNode> nodes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtHost() when $default != null:
return $default(_that.serverId,_that.kind,_that.version,_that.hypervisor,_that.nodes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serverId,  VirtHostKind kind,  String? version,  String? hypervisor,  List<VirtNode> nodes)  $default,) {final _that = this;
switch (_that) {
case _VirtHost():
return $default(_that.serverId,_that.kind,_that.version,_that.hypervisor,_that.nodes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serverId,  VirtHostKind kind,  String? version,  String? hypervisor,  List<VirtNode> nodes)?  $default,) {final _that = this;
switch (_that) {
case _VirtHost() when $default != null:
return $default(_that.serverId,_that.kind,_that.version,_that.hypervisor,_that.nodes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VirtHost extends VirtHost {
  const _VirtHost({required this.serverId, required this.kind, this.version, this.hypervisor, final  List<VirtNode> nodes = const <VirtNode>[]}): _nodes = nodes,super._();
  factory _VirtHost.fromJson(Map<String, dynamic> json) => _$VirtHostFromJson(json);

@override final  String serverId;
@override final  VirtHostKind kind;
/// PVE's release (`8.2`), or libvirt's library version (`10.0.0`).
@override final  String? version;
/// The hypervisor as the host names it, e.g. `QEMU 8.2.2`. libvirt only.
@override final  String? hypervisor;
 final  List<VirtNode> _nodes;
@override@JsonKey() List<VirtNode> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}


/// Create a copy of VirtHost
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtHostCopyWith<_VirtHost> get copyWith => __$VirtHostCopyWithImpl<_VirtHost>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VirtHostToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtHost&&(identical(other.serverId, serverId) || other.serverId == serverId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.version, version) || other.version == version)&&(identical(other.hypervisor, hypervisor) || other.hypervisor == hypervisor)&&const DeepCollectionEquality().equals(other._nodes, _nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serverId,kind,version,hypervisor,const DeepCollectionEquality().hash(_nodes));

@override
String toString() {
  return 'VirtHost(serverId: $serverId, kind: $kind, version: $version, hypervisor: $hypervisor, nodes: $nodes)';
}


}

/// @nodoc
abstract mixin class _$VirtHostCopyWith<$Res> implements $VirtHostCopyWith<$Res> {
  factory _$VirtHostCopyWith(_VirtHost value, $Res Function(_VirtHost) _then) = __$VirtHostCopyWithImpl;
@override @useResult
$Res call({
 String serverId, VirtHostKind kind, String? version, String? hypervisor, List<VirtNode> nodes
});




}
/// @nodoc
class __$VirtHostCopyWithImpl<$Res>
    implements _$VirtHostCopyWith<$Res> {
  __$VirtHostCopyWithImpl(this._self, this._then);

  final _VirtHost _self;
  final $Res Function(_VirtHost) _then;

/// Create a copy of VirtHost
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serverId = null,Object? kind = null,Object? version = freezed,Object? hypervisor = freezed,Object? nodes = null,}) {
  return _then(_VirtHost(
serverId: null == serverId ? _self.serverId : serverId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtHostKind,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,hypervisor: freezed == hypervisor ? _self.hypervisor : hypervisor // ignore: cast_nullable_to_non_nullable
as String?,nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<VirtNode>,
  ));
}


}


/// @nodoc
mixin _$VirtGuest {

/// Stable within the host: PVE `qemu/100`, libvirt the domain's UUID.
 String get id; String get name; VirtGuestKind get kind; VirtGuestState get state;/// The raw detail behind [state], for display and for decisions the
/// state alone cannot make: PVE's `lock` (`backup`, `snapshot`, ...) or
/// QEMU status (`prelaunch`, `io-error`), libvirt's reason (`crashed`,
/// `pmsuspended`, `user`, ...). Null when there is nothing to add.
 String? get stateReason;/// PVE's numeric id.
 int? get vmid;/// The PVE node the guest is on.
 String? get node; int? get vcpu;/// Memory assigned to the guest, bytes.
 int? get memBytes; Duration? get uptime; List<String> get tags;/// A PVE template: not a guest that runs, and offers no actions.
 bool get template;/// Starts with the host (libvirt autostart, PVE `onboot` is not in the
/// resource list and is left null).
 bool? get autostart;/// The power actions this guest offers now.
 Set<VirtPowerAction> get actions;
/// Create a copy of VirtGuest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtGuestCopyWith<VirtGuest> get copyWith => _$VirtGuestCopyWithImpl<VirtGuest>(this as VirtGuest, _$identity);

  /// Serializes this VirtGuest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtGuest&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.state, state) || other.state == state)&&(identical(other.stateReason, stateReason) || other.stateReason == stateReason)&&(identical(other.vmid, vmid) || other.vmid == vmid)&&(identical(other.node, node) || other.node == node)&&(identical(other.vcpu, vcpu) || other.vcpu == vcpu)&&(identical(other.memBytes, memBytes) || other.memBytes == memBytes)&&(identical(other.uptime, uptime) || other.uptime == uptime)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.template, template) || other.template == template)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&const DeepCollectionEquality().equals(other.actions, actions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,kind,state,stateReason,vmid,node,vcpu,memBytes,uptime,const DeepCollectionEquality().hash(tags),template,autostart,const DeepCollectionEquality().hash(actions));

@override
String toString() {
  return 'VirtGuest(id: $id, name: $name, kind: $kind, state: $state, stateReason: $stateReason, vmid: $vmid, node: $node, vcpu: $vcpu, memBytes: $memBytes, uptime: $uptime, tags: $tags, template: $template, autostart: $autostart, actions: $actions)';
}


}

/// @nodoc
abstract mixin class $VirtGuestCopyWith<$Res>  {
  factory $VirtGuestCopyWith(VirtGuest value, $Res Function(VirtGuest) _then) = _$VirtGuestCopyWithImpl;
@useResult
$Res call({
 String id, String name, VirtGuestKind kind, VirtGuestState state, String? stateReason, int? vmid, String? node, int? vcpu, int? memBytes, Duration? uptime, List<String> tags, bool template, bool? autostart, Set<VirtPowerAction> actions
});




}
/// @nodoc
class _$VirtGuestCopyWithImpl<$Res>
    implements $VirtGuestCopyWith<$Res> {
  _$VirtGuestCopyWithImpl(this._self, this._then);

  final VirtGuest _self;
  final $Res Function(VirtGuest) _then;

/// Create a copy of VirtGuest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? kind = null,Object? state = null,Object? stateReason = freezed,Object? vmid = freezed,Object? node = freezed,Object? vcpu = freezed,Object? memBytes = freezed,Object? uptime = freezed,Object? tags = null,Object? template = null,Object? autostart = freezed,Object? actions = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtGuestKind,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as VirtGuestState,stateReason: freezed == stateReason ? _self.stateReason : stateReason // ignore: cast_nullable_to_non_nullable
as String?,vmid: freezed == vmid ? _self.vmid : vmid // ignore: cast_nullable_to_non_nullable
as int?,node: freezed == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String?,vcpu: freezed == vcpu ? _self.vcpu : vcpu // ignore: cast_nullable_to_non_nullable
as int?,memBytes: freezed == memBytes ? _self.memBytes : memBytes // ignore: cast_nullable_to_non_nullable
as int?,uptime: freezed == uptime ? _self.uptime : uptime // ignore: cast_nullable_to_non_nullable
as Duration?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as bool,autostart: freezed == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool?,actions: null == actions ? _self.actions : actions // ignore: cast_nullable_to_non_nullable
as Set<VirtPowerAction>,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtGuest].
extension VirtGuestPatterns on VirtGuest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtGuest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtGuest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtGuest value)  $default,){
final _that = this;
switch (_that) {
case _VirtGuest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtGuest value)?  $default,){
final _that = this;
switch (_that) {
case _VirtGuest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  VirtGuestKind kind,  VirtGuestState state,  String? stateReason,  int? vmid,  String? node,  int? vcpu,  int? memBytes,  Duration? uptime,  List<String> tags,  bool template,  bool? autostart,  Set<VirtPowerAction> actions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtGuest() when $default != null:
return $default(_that.id,_that.name,_that.kind,_that.state,_that.stateReason,_that.vmid,_that.node,_that.vcpu,_that.memBytes,_that.uptime,_that.tags,_that.template,_that.autostart,_that.actions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  VirtGuestKind kind,  VirtGuestState state,  String? stateReason,  int? vmid,  String? node,  int? vcpu,  int? memBytes,  Duration? uptime,  List<String> tags,  bool template,  bool? autostart,  Set<VirtPowerAction> actions)  $default,) {final _that = this;
switch (_that) {
case _VirtGuest():
return $default(_that.id,_that.name,_that.kind,_that.state,_that.stateReason,_that.vmid,_that.node,_that.vcpu,_that.memBytes,_that.uptime,_that.tags,_that.template,_that.autostart,_that.actions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  VirtGuestKind kind,  VirtGuestState state,  String? stateReason,  int? vmid,  String? node,  int? vcpu,  int? memBytes,  Duration? uptime,  List<String> tags,  bool template,  bool? autostart,  Set<VirtPowerAction> actions)?  $default,) {final _that = this;
switch (_that) {
case _VirtGuest() when $default != null:
return $default(_that.id,_that.name,_that.kind,_that.state,_that.stateReason,_that.vmid,_that.node,_that.vcpu,_that.memBytes,_that.uptime,_that.tags,_that.template,_that.autostart,_that.actions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VirtGuest extends VirtGuest {
  const _VirtGuest({required this.id, required this.name, required this.kind, required this.state, this.stateReason, this.vmid, this.node, this.vcpu, this.memBytes, this.uptime, final  List<String> tags = const <String>[], this.template = false, this.autostart, final  Set<VirtPowerAction> actions = const <VirtPowerAction>{}}): _tags = tags,_actions = actions,super._();
  factory _VirtGuest.fromJson(Map<String, dynamic> json) => _$VirtGuestFromJson(json);

/// Stable within the host: PVE `qemu/100`, libvirt the domain's UUID.
@override final  String id;
@override final  String name;
@override final  VirtGuestKind kind;
@override final  VirtGuestState state;
/// The raw detail behind [state], for display and for decisions the
/// state alone cannot make: PVE's `lock` (`backup`, `snapshot`, ...) or
/// QEMU status (`prelaunch`, `io-error`), libvirt's reason (`crashed`,
/// `pmsuspended`, `user`, ...). Null when there is nothing to add.
@override final  String? stateReason;
/// PVE's numeric id.
@override final  int? vmid;
/// The PVE node the guest is on.
@override final  String? node;
@override final  int? vcpu;
/// Memory assigned to the guest, bytes.
@override final  int? memBytes;
@override final  Duration? uptime;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// A PVE template: not a guest that runs, and offers no actions.
@override@JsonKey() final  bool template;
/// Starts with the host (libvirt autostart, PVE `onboot` is not in the
/// resource list and is left null).
@override final  bool? autostart;
/// The power actions this guest offers now.
 final  Set<VirtPowerAction> _actions;
/// The power actions this guest offers now.
@override@JsonKey() Set<VirtPowerAction> get actions {
  if (_actions is EqualUnmodifiableSetView) return _actions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_actions);
}


/// Create a copy of VirtGuest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtGuestCopyWith<_VirtGuest> get copyWith => __$VirtGuestCopyWithImpl<_VirtGuest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VirtGuestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtGuest&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.state, state) || other.state == state)&&(identical(other.stateReason, stateReason) || other.stateReason == stateReason)&&(identical(other.vmid, vmid) || other.vmid == vmid)&&(identical(other.node, node) || other.node == node)&&(identical(other.vcpu, vcpu) || other.vcpu == vcpu)&&(identical(other.memBytes, memBytes) || other.memBytes == memBytes)&&(identical(other.uptime, uptime) || other.uptime == uptime)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.template, template) || other.template == template)&&(identical(other.autostart, autostart) || other.autostart == autostart)&&const DeepCollectionEquality().equals(other._actions, _actions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,kind,state,stateReason,vmid,node,vcpu,memBytes,uptime,const DeepCollectionEquality().hash(_tags),template,autostart,const DeepCollectionEquality().hash(_actions));

@override
String toString() {
  return 'VirtGuest(id: $id, name: $name, kind: $kind, state: $state, stateReason: $stateReason, vmid: $vmid, node: $node, vcpu: $vcpu, memBytes: $memBytes, uptime: $uptime, tags: $tags, template: $template, autostart: $autostart, actions: $actions)';
}


}

/// @nodoc
abstract mixin class _$VirtGuestCopyWith<$Res> implements $VirtGuestCopyWith<$Res> {
  factory _$VirtGuestCopyWith(_VirtGuest value, $Res Function(_VirtGuest) _then) = __$VirtGuestCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, VirtGuestKind kind, VirtGuestState state, String? stateReason, int? vmid, String? node, int? vcpu, int? memBytes, Duration? uptime, List<String> tags, bool template, bool? autostart, Set<VirtPowerAction> actions
});




}
/// @nodoc
class __$VirtGuestCopyWithImpl<$Res>
    implements _$VirtGuestCopyWith<$Res> {
  __$VirtGuestCopyWithImpl(this._self, this._then);

  final _VirtGuest _self;
  final $Res Function(_VirtGuest) _then;

/// Create a copy of VirtGuest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? kind = null,Object? state = null,Object? stateReason = freezed,Object? vmid = freezed,Object? node = freezed,Object? vcpu = freezed,Object? memBytes = freezed,Object? uptime = freezed,Object? tags = null,Object? template = null,Object? autostart = freezed,Object? actions = null,}) {
  return _then(_VirtGuest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as VirtGuestKind,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as VirtGuestState,stateReason: freezed == stateReason ? _self.stateReason : stateReason // ignore: cast_nullable_to_non_nullable
as String?,vmid: freezed == vmid ? _self.vmid : vmid // ignore: cast_nullable_to_non_nullable
as int?,node: freezed == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String?,vcpu: freezed == vcpu ? _self.vcpu : vcpu // ignore: cast_nullable_to_non_nullable
as int?,memBytes: freezed == memBytes ? _self.memBytes : memBytes // ignore: cast_nullable_to_non_nullable
as int?,uptime: freezed == uptime ? _self.uptime : uptime // ignore: cast_nullable_to_non_nullable
as Duration?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as bool,autostart: freezed == autostart ? _self.autostart : autostart // ignore: cast_nullable_to_non_nullable
as bool?,actions: null == actions ? _self._actions : actions // ignore: cast_nullable_to_non_nullable
as Set<VirtPowerAction>,
  ));
}


}


/// @nodoc
mixin _$VirtStats {

 DateTime get at;/// Percent of the guest's own vCPUs, 0..100.
 double? get cpu; int? get memUsed; int? get memTotal; int? get diskUsed; int? get diskTotal; double? get diskRead; double? get diskWrite; double? get netIn; double? get netOut;
/// Create a copy of VirtStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtStatsCopyWith<VirtStats> get copyWith => _$VirtStatsCopyWithImpl<VirtStats>(this as VirtStats, _$identity);

  /// Serializes this VirtStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtStats&&(identical(other.at, at) || other.at == at)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.memUsed, memUsed) || other.memUsed == memUsed)&&(identical(other.memTotal, memTotal) || other.memTotal == memTotal)&&(identical(other.diskUsed, diskUsed) || other.diskUsed == diskUsed)&&(identical(other.diskTotal, diskTotal) || other.diskTotal == diskTotal)&&(identical(other.diskRead, diskRead) || other.diskRead == diskRead)&&(identical(other.diskWrite, diskWrite) || other.diskWrite == diskWrite)&&(identical(other.netIn, netIn) || other.netIn == netIn)&&(identical(other.netOut, netOut) || other.netOut == netOut));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,at,cpu,memUsed,memTotal,diskUsed,diskTotal,diskRead,diskWrite,netIn,netOut);

@override
String toString() {
  return 'VirtStats(at: $at, cpu: $cpu, memUsed: $memUsed, memTotal: $memTotal, diskUsed: $diskUsed, diskTotal: $diskTotal, diskRead: $diskRead, diskWrite: $diskWrite, netIn: $netIn, netOut: $netOut)';
}


}

/// @nodoc
abstract mixin class $VirtStatsCopyWith<$Res>  {
  factory $VirtStatsCopyWith(VirtStats value, $Res Function(VirtStats) _then) = _$VirtStatsCopyWithImpl;
@useResult
$Res call({
 DateTime at, double? cpu, int? memUsed, int? memTotal, int? diskUsed, int? diskTotal, double? diskRead, double? diskWrite, double? netIn, double? netOut
});




}
/// @nodoc
class _$VirtStatsCopyWithImpl<$Res>
    implements $VirtStatsCopyWith<$Res> {
  _$VirtStatsCopyWithImpl(this._self, this._then);

  final VirtStats _self;
  final $Res Function(VirtStats) _then;

/// Create a copy of VirtStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? at = null,Object? cpu = freezed,Object? memUsed = freezed,Object? memTotal = freezed,Object? diskUsed = freezed,Object? diskTotal = freezed,Object? diskRead = freezed,Object? diskWrite = freezed,Object? netIn = freezed,Object? netOut = freezed,}) {
  return _then(_self.copyWith(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,cpu: freezed == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as double?,memUsed: freezed == memUsed ? _self.memUsed : memUsed // ignore: cast_nullable_to_non_nullable
as int?,memTotal: freezed == memTotal ? _self.memTotal : memTotal // ignore: cast_nullable_to_non_nullable
as int?,diskUsed: freezed == diskUsed ? _self.diskUsed : diskUsed // ignore: cast_nullable_to_non_nullable
as int?,diskTotal: freezed == diskTotal ? _self.diskTotal : diskTotal // ignore: cast_nullable_to_non_nullable
as int?,diskRead: freezed == diskRead ? _self.diskRead : diskRead // ignore: cast_nullable_to_non_nullable
as double?,diskWrite: freezed == diskWrite ? _self.diskWrite : diskWrite // ignore: cast_nullable_to_non_nullable
as double?,netIn: freezed == netIn ? _self.netIn : netIn // ignore: cast_nullable_to_non_nullable
as double?,netOut: freezed == netOut ? _self.netOut : netOut // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtStats].
extension VirtStatsPatterns on VirtStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtStats value)  $default,){
final _that = this;
switch (_that) {
case _VirtStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtStats value)?  $default,){
final _that = this;
switch (_that) {
case _VirtStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime at,  double? cpu,  int? memUsed,  int? memTotal,  int? diskUsed,  int? diskTotal,  double? diskRead,  double? diskWrite,  double? netIn,  double? netOut)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtStats() when $default != null:
return $default(_that.at,_that.cpu,_that.memUsed,_that.memTotal,_that.diskUsed,_that.diskTotal,_that.diskRead,_that.diskWrite,_that.netIn,_that.netOut);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime at,  double? cpu,  int? memUsed,  int? memTotal,  int? diskUsed,  int? diskTotal,  double? diskRead,  double? diskWrite,  double? netIn,  double? netOut)  $default,) {final _that = this;
switch (_that) {
case _VirtStats():
return $default(_that.at,_that.cpu,_that.memUsed,_that.memTotal,_that.diskUsed,_that.diskTotal,_that.diskRead,_that.diskWrite,_that.netIn,_that.netOut);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime at,  double? cpu,  int? memUsed,  int? memTotal,  int? diskUsed,  int? diskTotal,  double? diskRead,  double? diskWrite,  double? netIn,  double? netOut)?  $default,) {final _that = this;
switch (_that) {
case _VirtStats() when $default != null:
return $default(_that.at,_that.cpu,_that.memUsed,_that.memTotal,_that.diskUsed,_that.diskTotal,_that.diskRead,_that.diskWrite,_that.netIn,_that.netOut);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VirtStats implements VirtStats {
  const _VirtStats({required this.at, this.cpu, this.memUsed, this.memTotal, this.diskUsed, this.diskTotal, this.diskRead, this.diskWrite, this.netIn, this.netOut});
  factory _VirtStats.fromJson(Map<String, dynamic> json) => _$VirtStatsFromJson(json);

@override final  DateTime at;
/// Percent of the guest's own vCPUs, 0..100.
@override final  double? cpu;
@override final  int? memUsed;
@override final  int? memTotal;
@override final  int? diskUsed;
@override final  int? diskTotal;
@override final  double? diskRead;
@override final  double? diskWrite;
@override final  double? netIn;
@override final  double? netOut;

/// Create a copy of VirtStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtStatsCopyWith<_VirtStats> get copyWith => __$VirtStatsCopyWithImpl<_VirtStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VirtStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtStats&&(identical(other.at, at) || other.at == at)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.memUsed, memUsed) || other.memUsed == memUsed)&&(identical(other.memTotal, memTotal) || other.memTotal == memTotal)&&(identical(other.diskUsed, diskUsed) || other.diskUsed == diskUsed)&&(identical(other.diskTotal, diskTotal) || other.diskTotal == diskTotal)&&(identical(other.diskRead, diskRead) || other.diskRead == diskRead)&&(identical(other.diskWrite, diskWrite) || other.diskWrite == diskWrite)&&(identical(other.netIn, netIn) || other.netIn == netIn)&&(identical(other.netOut, netOut) || other.netOut == netOut));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,at,cpu,memUsed,memTotal,diskUsed,diskTotal,diskRead,diskWrite,netIn,netOut);

@override
String toString() {
  return 'VirtStats(at: $at, cpu: $cpu, memUsed: $memUsed, memTotal: $memTotal, diskUsed: $diskUsed, diskTotal: $diskTotal, diskRead: $diskRead, diskWrite: $diskWrite, netIn: $netIn, netOut: $netOut)';
}


}

/// @nodoc
abstract mixin class _$VirtStatsCopyWith<$Res> implements $VirtStatsCopyWith<$Res> {
  factory _$VirtStatsCopyWith(_VirtStats value, $Res Function(_VirtStats) _then) = __$VirtStatsCopyWithImpl;
@override @useResult
$Res call({
 DateTime at, double? cpu, int? memUsed, int? memTotal, int? diskUsed, int? diskTotal, double? diskRead, double? diskWrite, double? netIn, double? netOut
});




}
/// @nodoc
class __$VirtStatsCopyWithImpl<$Res>
    implements _$VirtStatsCopyWith<$Res> {
  __$VirtStatsCopyWithImpl(this._self, this._then);

  final _VirtStats _self;
  final $Res Function(_VirtStats) _then;

/// Create a copy of VirtStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? at = null,Object? cpu = freezed,Object? memUsed = freezed,Object? memTotal = freezed,Object? diskUsed = freezed,Object? diskTotal = freezed,Object? diskRead = freezed,Object? diskWrite = freezed,Object? netIn = freezed,Object? netOut = freezed,}) {
  return _then(_VirtStats(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,cpu: freezed == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as double?,memUsed: freezed == memUsed ? _self.memUsed : memUsed // ignore: cast_nullable_to_non_nullable
as int?,memTotal: freezed == memTotal ? _self.memTotal : memTotal // ignore: cast_nullable_to_non_nullable
as int?,diskUsed: freezed == diskUsed ? _self.diskUsed : diskUsed // ignore: cast_nullable_to_non_nullable
as int?,diskTotal: freezed == diskTotal ? _self.diskTotal : diskTotal // ignore: cast_nullable_to_non_nullable
as int?,diskRead: freezed == diskRead ? _self.diskRead : diskRead // ignore: cast_nullable_to_non_nullable
as double?,diskWrite: freezed == diskWrite ? _self.diskWrite : diskWrite // ignore: cast_nullable_to_non_nullable
as double?,netIn: freezed == netIn ? _self.netIn : netIn // ignore: cast_nullable_to_non_nullable
as double?,netOut: freezed == netOut ? _self.netOut : netOut // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$VirtCapabilities {

 bool get lxc; bool get pause;/// Snapshots can be listed, taken, reverted to and deleted.
 bool get snapshots;/// A snapshot of an active guest always holds its memory, with no way to
/// leave it out (libvirt's internal snapshots: QEMU refuses one without).
/// Otherwise it is the user's choice, where the guest is not a container.
 bool get snapshotMemoryRequired;/// Storage pools and their volumes can be listed.
 bool get storage;/// Networks and the guests on them can be listed.
 bool get network;/// Guests can be backed up now, their backups listed, restored and
/// deleted, and the backup jobs that take them read (PVE `vzdump`).
 bool get backup;/// Guests can be cloned: libvirt copying each disk or making it empty,
/// PVE a full clone.
 bool get clone;/// A template can be cloned as a linked clone, sharing its disks (PVE).
 bool get linkedClone;/// More than one node: guests are grouped by node.
 bool get cluster;/// A serial console in a terminal session (`virsh console`).
 bool get serialConsole;/// A graphical (VNC) console.
 bool get vncConsole;/// A text console through PVE's `termproxy`.
 bool get termConsole;/// The host keeps a usage history, so a chart can show the last hour at
/// once (PVE `rrddata`). Without it the chart fills from this session's
/// samples.
 bool get storedHistory;/// Guests can be created (VMs; containers too where [lxc]) and deleted.
 bool get create;/// Deleting a guest can keep its disks. PVE's cannot: a guest's own
/// volumes go with it.
 bool get deleteKeepsDisks;/// A guest's hardware can be read and changed (the Hardware view).
 bool get hardware;/// Pending changes can be dropped before they apply (PVE `revert`).
/// libvirt keeps no such list: what is pending is the difference between
/// two definitions.
 bool get hardwareRevert;
/// Create a copy of VirtCapabilities
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtCapabilitiesCopyWith<VirtCapabilities> get copyWith => _$VirtCapabilitiesCopyWithImpl<VirtCapabilities>(this as VirtCapabilities, _$identity);

  /// Serializes this VirtCapabilities to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtCapabilities&&(identical(other.lxc, lxc) || other.lxc == lxc)&&(identical(other.pause, pause) || other.pause == pause)&&(identical(other.snapshots, snapshots) || other.snapshots == snapshots)&&(identical(other.snapshotMemoryRequired, snapshotMemoryRequired) || other.snapshotMemoryRequired == snapshotMemoryRequired)&&(identical(other.storage, storage) || other.storage == storage)&&(identical(other.network, network) || other.network == network)&&(identical(other.backup, backup) || other.backup == backup)&&(identical(other.clone, clone) || other.clone == clone)&&(identical(other.linkedClone, linkedClone) || other.linkedClone == linkedClone)&&(identical(other.cluster, cluster) || other.cluster == cluster)&&(identical(other.serialConsole, serialConsole) || other.serialConsole == serialConsole)&&(identical(other.vncConsole, vncConsole) || other.vncConsole == vncConsole)&&(identical(other.termConsole, termConsole) || other.termConsole == termConsole)&&(identical(other.storedHistory, storedHistory) || other.storedHistory == storedHistory)&&(identical(other.create, create) || other.create == create)&&(identical(other.deleteKeepsDisks, deleteKeepsDisks) || other.deleteKeepsDisks == deleteKeepsDisks)&&(identical(other.hardware, hardware) || other.hardware == hardware)&&(identical(other.hardwareRevert, hardwareRevert) || other.hardwareRevert == hardwareRevert));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lxc,pause,snapshots,snapshotMemoryRequired,storage,network,backup,clone,linkedClone,cluster,serialConsole,vncConsole,termConsole,storedHistory,create,deleteKeepsDisks,hardware,hardwareRevert);

@override
String toString() {
  return 'VirtCapabilities(lxc: $lxc, pause: $pause, snapshots: $snapshots, snapshotMemoryRequired: $snapshotMemoryRequired, storage: $storage, network: $network, backup: $backup, clone: $clone, linkedClone: $linkedClone, cluster: $cluster, serialConsole: $serialConsole, vncConsole: $vncConsole, termConsole: $termConsole, storedHistory: $storedHistory, create: $create, deleteKeepsDisks: $deleteKeepsDisks, hardware: $hardware, hardwareRevert: $hardwareRevert)';
}


}

/// @nodoc
abstract mixin class $VirtCapabilitiesCopyWith<$Res>  {
  factory $VirtCapabilitiesCopyWith(VirtCapabilities value, $Res Function(VirtCapabilities) _then) = _$VirtCapabilitiesCopyWithImpl;
@useResult
$Res call({
 bool lxc, bool pause, bool snapshots, bool snapshotMemoryRequired, bool storage, bool network, bool backup, bool clone, bool linkedClone, bool cluster, bool serialConsole, bool vncConsole, bool termConsole, bool storedHistory, bool create, bool deleteKeepsDisks, bool hardware, bool hardwareRevert
});




}
/// @nodoc
class _$VirtCapabilitiesCopyWithImpl<$Res>
    implements $VirtCapabilitiesCopyWith<$Res> {
  _$VirtCapabilitiesCopyWithImpl(this._self, this._then);

  final VirtCapabilities _self;
  final $Res Function(VirtCapabilities) _then;

/// Create a copy of VirtCapabilities
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lxc = null,Object? pause = null,Object? snapshots = null,Object? snapshotMemoryRequired = null,Object? storage = null,Object? network = null,Object? backup = null,Object? clone = null,Object? linkedClone = null,Object? cluster = null,Object? serialConsole = null,Object? vncConsole = null,Object? termConsole = null,Object? storedHistory = null,Object? create = null,Object? deleteKeepsDisks = null,Object? hardware = null,Object? hardwareRevert = null,}) {
  return _then(_self.copyWith(
lxc: null == lxc ? _self.lxc : lxc // ignore: cast_nullable_to_non_nullable
as bool,pause: null == pause ? _self.pause : pause // ignore: cast_nullable_to_non_nullable
as bool,snapshots: null == snapshots ? _self.snapshots : snapshots // ignore: cast_nullable_to_non_nullable
as bool,snapshotMemoryRequired: null == snapshotMemoryRequired ? _self.snapshotMemoryRequired : snapshotMemoryRequired // ignore: cast_nullable_to_non_nullable
as bool,storage: null == storage ? _self.storage : storage // ignore: cast_nullable_to_non_nullable
as bool,network: null == network ? _self.network : network // ignore: cast_nullable_to_non_nullable
as bool,backup: null == backup ? _self.backup : backup // ignore: cast_nullable_to_non_nullable
as bool,clone: null == clone ? _self.clone : clone // ignore: cast_nullable_to_non_nullable
as bool,linkedClone: null == linkedClone ? _self.linkedClone : linkedClone // ignore: cast_nullable_to_non_nullable
as bool,cluster: null == cluster ? _self.cluster : cluster // ignore: cast_nullable_to_non_nullable
as bool,serialConsole: null == serialConsole ? _self.serialConsole : serialConsole // ignore: cast_nullable_to_non_nullable
as bool,vncConsole: null == vncConsole ? _self.vncConsole : vncConsole // ignore: cast_nullable_to_non_nullable
as bool,termConsole: null == termConsole ? _self.termConsole : termConsole // ignore: cast_nullable_to_non_nullable
as bool,storedHistory: null == storedHistory ? _self.storedHistory : storedHistory // ignore: cast_nullable_to_non_nullable
as bool,create: null == create ? _self.create : create // ignore: cast_nullable_to_non_nullable
as bool,deleteKeepsDisks: null == deleteKeepsDisks ? _self.deleteKeepsDisks : deleteKeepsDisks // ignore: cast_nullable_to_non_nullable
as bool,hardware: null == hardware ? _self.hardware : hardware // ignore: cast_nullable_to_non_nullable
as bool,hardwareRevert: null == hardwareRevert ? _self.hardwareRevert : hardwareRevert // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtCapabilities].
extension VirtCapabilitiesPatterns on VirtCapabilities {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtCapabilities value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtCapabilities() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtCapabilities value)  $default,){
final _that = this;
switch (_that) {
case _VirtCapabilities():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtCapabilities value)?  $default,){
final _that = this;
switch (_that) {
case _VirtCapabilities() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool lxc,  bool pause,  bool snapshots,  bool snapshotMemoryRequired,  bool storage,  bool network,  bool backup,  bool clone,  bool linkedClone,  bool cluster,  bool serialConsole,  bool vncConsole,  bool termConsole,  bool storedHistory,  bool create,  bool deleteKeepsDisks,  bool hardware,  bool hardwareRevert)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtCapabilities() when $default != null:
return $default(_that.lxc,_that.pause,_that.snapshots,_that.snapshotMemoryRequired,_that.storage,_that.network,_that.backup,_that.clone,_that.linkedClone,_that.cluster,_that.serialConsole,_that.vncConsole,_that.termConsole,_that.storedHistory,_that.create,_that.deleteKeepsDisks,_that.hardware,_that.hardwareRevert);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool lxc,  bool pause,  bool snapshots,  bool snapshotMemoryRequired,  bool storage,  bool network,  bool backup,  bool clone,  bool linkedClone,  bool cluster,  bool serialConsole,  bool vncConsole,  bool termConsole,  bool storedHistory,  bool create,  bool deleteKeepsDisks,  bool hardware,  bool hardwareRevert)  $default,) {final _that = this;
switch (_that) {
case _VirtCapabilities():
return $default(_that.lxc,_that.pause,_that.snapshots,_that.snapshotMemoryRequired,_that.storage,_that.network,_that.backup,_that.clone,_that.linkedClone,_that.cluster,_that.serialConsole,_that.vncConsole,_that.termConsole,_that.storedHistory,_that.create,_that.deleteKeepsDisks,_that.hardware,_that.hardwareRevert);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool lxc,  bool pause,  bool snapshots,  bool snapshotMemoryRequired,  bool storage,  bool network,  bool backup,  bool clone,  bool linkedClone,  bool cluster,  bool serialConsole,  bool vncConsole,  bool termConsole,  bool storedHistory,  bool create,  bool deleteKeepsDisks,  bool hardware,  bool hardwareRevert)?  $default,) {final _that = this;
switch (_that) {
case _VirtCapabilities() when $default != null:
return $default(_that.lxc,_that.pause,_that.snapshots,_that.snapshotMemoryRequired,_that.storage,_that.network,_that.backup,_that.clone,_that.linkedClone,_that.cluster,_that.serialConsole,_that.vncConsole,_that.termConsole,_that.storedHistory,_that.create,_that.deleteKeepsDisks,_that.hardware,_that.hardwareRevert);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VirtCapabilities implements VirtCapabilities {
  const _VirtCapabilities({this.lxc = false, this.pause = false, this.snapshots = false, this.snapshotMemoryRequired = false, this.storage = false, this.network = false, this.backup = false, this.clone = false, this.linkedClone = false, this.cluster = false, this.serialConsole = false, this.vncConsole = false, this.termConsole = false, this.storedHistory = false, this.create = false, this.deleteKeepsDisks = false, this.hardware = false, this.hardwareRevert = false});
  factory _VirtCapabilities.fromJson(Map<String, dynamic> json) => _$VirtCapabilitiesFromJson(json);

@override@JsonKey() final  bool lxc;
@override@JsonKey() final  bool pause;
/// Snapshots can be listed, taken, reverted to and deleted.
@override@JsonKey() final  bool snapshots;
/// A snapshot of an active guest always holds its memory, with no way to
/// leave it out (libvirt's internal snapshots: QEMU refuses one without).
/// Otherwise it is the user's choice, where the guest is not a container.
@override@JsonKey() final  bool snapshotMemoryRequired;
/// Storage pools and their volumes can be listed.
@override@JsonKey() final  bool storage;
/// Networks and the guests on them can be listed.
@override@JsonKey() final  bool network;
/// Guests can be backed up now, their backups listed, restored and
/// deleted, and the backup jobs that take them read (PVE `vzdump`).
@override@JsonKey() final  bool backup;
/// Guests can be cloned: libvirt copying each disk or making it empty,
/// PVE a full clone.
@override@JsonKey() final  bool clone;
/// A template can be cloned as a linked clone, sharing its disks (PVE).
@override@JsonKey() final  bool linkedClone;
/// More than one node: guests are grouped by node.
@override@JsonKey() final  bool cluster;
/// A serial console in a terminal session (`virsh console`).
@override@JsonKey() final  bool serialConsole;
/// A graphical (VNC) console.
@override@JsonKey() final  bool vncConsole;
/// A text console through PVE's `termproxy`.
@override@JsonKey() final  bool termConsole;
/// The host keeps a usage history, so a chart can show the last hour at
/// once (PVE `rrddata`). Without it the chart fills from this session's
/// samples.
@override@JsonKey() final  bool storedHistory;
/// Guests can be created (VMs; containers too where [lxc]) and deleted.
@override@JsonKey() final  bool create;
/// Deleting a guest can keep its disks. PVE's cannot: a guest's own
/// volumes go with it.
@override@JsonKey() final  bool deleteKeepsDisks;
/// A guest's hardware can be read and changed (the Hardware view).
@override@JsonKey() final  bool hardware;
/// Pending changes can be dropped before they apply (PVE `revert`).
/// libvirt keeps no such list: what is pending is the difference between
/// two definitions.
@override@JsonKey() final  bool hardwareRevert;

/// Create a copy of VirtCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtCapabilitiesCopyWith<_VirtCapabilities> get copyWith => __$VirtCapabilitiesCopyWithImpl<_VirtCapabilities>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VirtCapabilitiesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtCapabilities&&(identical(other.lxc, lxc) || other.lxc == lxc)&&(identical(other.pause, pause) || other.pause == pause)&&(identical(other.snapshots, snapshots) || other.snapshots == snapshots)&&(identical(other.snapshotMemoryRequired, snapshotMemoryRequired) || other.snapshotMemoryRequired == snapshotMemoryRequired)&&(identical(other.storage, storage) || other.storage == storage)&&(identical(other.network, network) || other.network == network)&&(identical(other.backup, backup) || other.backup == backup)&&(identical(other.clone, clone) || other.clone == clone)&&(identical(other.linkedClone, linkedClone) || other.linkedClone == linkedClone)&&(identical(other.cluster, cluster) || other.cluster == cluster)&&(identical(other.serialConsole, serialConsole) || other.serialConsole == serialConsole)&&(identical(other.vncConsole, vncConsole) || other.vncConsole == vncConsole)&&(identical(other.termConsole, termConsole) || other.termConsole == termConsole)&&(identical(other.storedHistory, storedHistory) || other.storedHistory == storedHistory)&&(identical(other.create, create) || other.create == create)&&(identical(other.deleteKeepsDisks, deleteKeepsDisks) || other.deleteKeepsDisks == deleteKeepsDisks)&&(identical(other.hardware, hardware) || other.hardware == hardware)&&(identical(other.hardwareRevert, hardwareRevert) || other.hardwareRevert == hardwareRevert));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lxc,pause,snapshots,snapshotMemoryRequired,storage,network,backup,clone,linkedClone,cluster,serialConsole,vncConsole,termConsole,storedHistory,create,deleteKeepsDisks,hardware,hardwareRevert);

@override
String toString() {
  return 'VirtCapabilities(lxc: $lxc, pause: $pause, snapshots: $snapshots, snapshotMemoryRequired: $snapshotMemoryRequired, storage: $storage, network: $network, backup: $backup, clone: $clone, linkedClone: $linkedClone, cluster: $cluster, serialConsole: $serialConsole, vncConsole: $vncConsole, termConsole: $termConsole, storedHistory: $storedHistory, create: $create, deleteKeepsDisks: $deleteKeepsDisks, hardware: $hardware, hardwareRevert: $hardwareRevert)';
}


}

/// @nodoc
abstract mixin class _$VirtCapabilitiesCopyWith<$Res> implements $VirtCapabilitiesCopyWith<$Res> {
  factory _$VirtCapabilitiesCopyWith(_VirtCapabilities value, $Res Function(_VirtCapabilities) _then) = __$VirtCapabilitiesCopyWithImpl;
@override @useResult
$Res call({
 bool lxc, bool pause, bool snapshots, bool snapshotMemoryRequired, bool storage, bool network, bool backup, bool clone, bool linkedClone, bool cluster, bool serialConsole, bool vncConsole, bool termConsole, bool storedHistory, bool create, bool deleteKeepsDisks, bool hardware, bool hardwareRevert
});




}
/// @nodoc
class __$VirtCapabilitiesCopyWithImpl<$Res>
    implements _$VirtCapabilitiesCopyWith<$Res> {
  __$VirtCapabilitiesCopyWithImpl(this._self, this._then);

  final _VirtCapabilities _self;
  final $Res Function(_VirtCapabilities) _then;

/// Create a copy of VirtCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lxc = null,Object? pause = null,Object? snapshots = null,Object? snapshotMemoryRequired = null,Object? storage = null,Object? network = null,Object? backup = null,Object? clone = null,Object? linkedClone = null,Object? cluster = null,Object? serialConsole = null,Object? vncConsole = null,Object? termConsole = null,Object? storedHistory = null,Object? create = null,Object? deleteKeepsDisks = null,Object? hardware = null,Object? hardwareRevert = null,}) {
  return _then(_VirtCapabilities(
lxc: null == lxc ? _self.lxc : lxc // ignore: cast_nullable_to_non_nullable
as bool,pause: null == pause ? _self.pause : pause // ignore: cast_nullable_to_non_nullable
as bool,snapshots: null == snapshots ? _self.snapshots : snapshots // ignore: cast_nullable_to_non_nullable
as bool,snapshotMemoryRequired: null == snapshotMemoryRequired ? _self.snapshotMemoryRequired : snapshotMemoryRequired // ignore: cast_nullable_to_non_nullable
as bool,storage: null == storage ? _self.storage : storage // ignore: cast_nullable_to_non_nullable
as bool,network: null == network ? _self.network : network // ignore: cast_nullable_to_non_nullable
as bool,backup: null == backup ? _self.backup : backup // ignore: cast_nullable_to_non_nullable
as bool,clone: null == clone ? _self.clone : clone // ignore: cast_nullable_to_non_nullable
as bool,linkedClone: null == linkedClone ? _self.linkedClone : linkedClone // ignore: cast_nullable_to_non_nullable
as bool,cluster: null == cluster ? _self.cluster : cluster // ignore: cast_nullable_to_non_nullable
as bool,serialConsole: null == serialConsole ? _self.serialConsole : serialConsole // ignore: cast_nullable_to_non_nullable
as bool,vncConsole: null == vncConsole ? _self.vncConsole : vncConsole // ignore: cast_nullable_to_non_nullable
as bool,termConsole: null == termConsole ? _self.termConsole : termConsole // ignore: cast_nullable_to_non_nullable
as bool,storedHistory: null == storedHistory ? _self.storedHistory : storedHistory // ignore: cast_nullable_to_non_nullable
as bool,create: null == create ? _self.create : create // ignore: cast_nullable_to_non_nullable
as bool,deleteKeepsDisks: null == deleteKeepsDisks ? _self.deleteKeepsDisks : deleteKeepsDisks // ignore: cast_nullable_to_non_nullable
as bool,hardware: null == hardware ? _self.hardware : hardware // ignore: cast_nullable_to_non_nullable
as bool,hardwareRevert: null == hardwareRevert ? _self.hardwareRevert : hardwareRevert // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$VirtSnapshot {

 VirtHost get host; List<VirtGuest> get guests;/// By [VirtGuest.id]. A guest missing here has nothing measured yet.
 Map<String, VirtStats> get stats; VirtCapabilities get capabilities;
/// Create a copy of VirtSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtSnapshotCopyWith<VirtSnapshot> get copyWith => _$VirtSnapshotCopyWithImpl<VirtSnapshot>(this as VirtSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtSnapshot&&(identical(other.host, host) || other.host == host)&&const DeepCollectionEquality().equals(other.guests, guests)&&const DeepCollectionEquality().equals(other.stats, stats)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities));
}


@override
int get hashCode => Object.hash(runtimeType,host,const DeepCollectionEquality().hash(guests),const DeepCollectionEquality().hash(stats),capabilities);

@override
String toString() {
  return 'VirtSnapshot(host: $host, guests: $guests, stats: $stats, capabilities: $capabilities)';
}


}

/// @nodoc
abstract mixin class $VirtSnapshotCopyWith<$Res>  {
  factory $VirtSnapshotCopyWith(VirtSnapshot value, $Res Function(VirtSnapshot) _then) = _$VirtSnapshotCopyWithImpl;
@useResult
$Res call({
 VirtHost host, List<VirtGuest> guests, Map<String, VirtStats> stats, VirtCapabilities capabilities
});


$VirtHostCopyWith<$Res> get host;$VirtCapabilitiesCopyWith<$Res> get capabilities;

}
/// @nodoc
class _$VirtSnapshotCopyWithImpl<$Res>
    implements $VirtSnapshotCopyWith<$Res> {
  _$VirtSnapshotCopyWithImpl(this._self, this._then);

  final VirtSnapshot _self;
  final $Res Function(VirtSnapshot) _then;

/// Create a copy of VirtSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? host = null,Object? guests = null,Object? stats = null,Object? capabilities = null,}) {
  return _then(_self.copyWith(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as VirtHost,guests: null == guests ? _self.guests : guests // ignore: cast_nullable_to_non_nullable
as List<VirtGuest>,stats: null == stats ? _self.stats : stats // ignore: cast_nullable_to_non_nullable
as Map<String, VirtStats>,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as VirtCapabilities,
  ));
}
/// Create a copy of VirtSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHostCopyWith<$Res> get host {
  
  return $VirtHostCopyWith<$Res>(_self.host, (value) {
    return _then(_self.copyWith(host: value));
  });
}/// Create a copy of VirtSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtCapabilitiesCopyWith<$Res> get capabilities {
  
  return $VirtCapabilitiesCopyWith<$Res>(_self.capabilities, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}
}


/// Adds pattern-matching-related methods to [VirtSnapshot].
extension VirtSnapshotPatterns on VirtSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _VirtSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _VirtSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VirtHost host,  List<VirtGuest> guests,  Map<String, VirtStats> stats,  VirtCapabilities capabilities)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtSnapshot() when $default != null:
return $default(_that.host,_that.guests,_that.stats,_that.capabilities);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VirtHost host,  List<VirtGuest> guests,  Map<String, VirtStats> stats,  VirtCapabilities capabilities)  $default,) {final _that = this;
switch (_that) {
case _VirtSnapshot():
return $default(_that.host,_that.guests,_that.stats,_that.capabilities);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VirtHost host,  List<VirtGuest> guests,  Map<String, VirtStats> stats,  VirtCapabilities capabilities)?  $default,) {final _that = this;
switch (_that) {
case _VirtSnapshot() when $default != null:
return $default(_that.host,_that.guests,_that.stats,_that.capabilities);case _:
  return null;

}
}

}

/// @nodoc


class _VirtSnapshot implements VirtSnapshot {
  const _VirtSnapshot({required this.host, required final  List<VirtGuest> guests, final  Map<String, VirtStats> stats = const <String, VirtStats>{}, required this.capabilities}): _guests = guests,_stats = stats;
  

@override final  VirtHost host;
 final  List<VirtGuest> _guests;
@override List<VirtGuest> get guests {
  if (_guests is EqualUnmodifiableListView) return _guests;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_guests);
}

/// By [VirtGuest.id]. A guest missing here has nothing measured yet.
 final  Map<String, VirtStats> _stats;
/// By [VirtGuest.id]. A guest missing here has nothing measured yet.
@override@JsonKey() Map<String, VirtStats> get stats {
  if (_stats is EqualUnmodifiableMapView) return _stats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_stats);
}

@override final  VirtCapabilities capabilities;

/// Create a copy of VirtSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtSnapshotCopyWith<_VirtSnapshot> get copyWith => __$VirtSnapshotCopyWithImpl<_VirtSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtSnapshot&&(identical(other.host, host) || other.host == host)&&const DeepCollectionEquality().equals(other._guests, _guests)&&const DeepCollectionEquality().equals(other._stats, _stats)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities));
}


@override
int get hashCode => Object.hash(runtimeType,host,const DeepCollectionEquality().hash(_guests),const DeepCollectionEquality().hash(_stats),capabilities);

@override
String toString() {
  return 'VirtSnapshot(host: $host, guests: $guests, stats: $stats, capabilities: $capabilities)';
}


}

/// @nodoc
abstract mixin class _$VirtSnapshotCopyWith<$Res> implements $VirtSnapshotCopyWith<$Res> {
  factory _$VirtSnapshotCopyWith(_VirtSnapshot value, $Res Function(_VirtSnapshot) _then) = __$VirtSnapshotCopyWithImpl;
@override @useResult
$Res call({
 VirtHost host, List<VirtGuest> guests, Map<String, VirtStats> stats, VirtCapabilities capabilities
});


@override $VirtHostCopyWith<$Res> get host;@override $VirtCapabilitiesCopyWith<$Res> get capabilities;

}
/// @nodoc
class __$VirtSnapshotCopyWithImpl<$Res>
    implements _$VirtSnapshotCopyWith<$Res> {
  __$VirtSnapshotCopyWithImpl(this._self, this._then);

  final _VirtSnapshot _self;
  final $Res Function(_VirtSnapshot) _then;

/// Create a copy of VirtSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? host = null,Object? guests = null,Object? stats = null,Object? capabilities = null,}) {
  return _then(_VirtSnapshot(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as VirtHost,guests: null == guests ? _self._guests : guests // ignore: cast_nullable_to_non_nullable
as List<VirtGuest>,stats: null == stats ? _self._stats : stats // ignore: cast_nullable_to_non_nullable
as Map<String, VirtStats>,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as VirtCapabilities,
  ));
}

/// Create a copy of VirtSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtHostCopyWith<$Res> get host {
  
  return $VirtHostCopyWith<$Res>(_self.host, (value) {
    return _then(_self.copyWith(host: value));
  });
}/// Create a copy of VirtSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VirtCapabilitiesCopyWith<$Res> get capabilities {
  
  return $VirtCapabilitiesCopyWith<$Res>(_self.capabilities, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}
}

// dart format on
