// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'discovery_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SshDiscoveryResult {

 String get ip; int get port; String? get banner; bool get isSelected;
/// Create a copy of SshDiscoveryResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SshDiscoveryResultCopyWith<SshDiscoveryResult> get copyWith => _$SshDiscoveryResultCopyWithImpl<SshDiscoveryResult>(this as SshDiscoveryResult, _$identity);

  /// Serializes this SshDiscoveryResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SshDiscoveryResult&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.port, port) || other.port == port)&&(identical(other.banner, banner) || other.banner == banner)&&(identical(other.isSelected, isSelected) || other.isSelected == isSelected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ip,port,banner,isSelected);

@override
String toString() {
  return 'SshDiscoveryResult(ip: $ip, port: $port, banner: $banner, isSelected: $isSelected)';
}


}

/// @nodoc
abstract mixin class $SshDiscoveryResultCopyWith<$Res>  {
  factory $SshDiscoveryResultCopyWith(SshDiscoveryResult value, $Res Function(SshDiscoveryResult) _then) = _$SshDiscoveryResultCopyWithImpl;
@useResult
$Res call({
 String ip, int port, String? banner, bool isSelected
});




}
/// @nodoc
class _$SshDiscoveryResultCopyWithImpl<$Res>
    implements $SshDiscoveryResultCopyWith<$Res> {
  _$SshDiscoveryResultCopyWithImpl(this._self, this._then);

  final SshDiscoveryResult _self;
  final $Res Function(SshDiscoveryResult) _then;

/// Create a copy of SshDiscoveryResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ip = null,Object? port = null,Object? banner = freezed,Object? isSelected = null,}) {
  return _then(_self.copyWith(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,banner: freezed == banner ? _self.banner : banner // ignore: cast_nullable_to_non_nullable
as String?,isSelected: null == isSelected ? _self.isSelected : isSelected // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SshDiscoveryResult].
extension SshDiscoveryResultPatterns on SshDiscoveryResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SshDiscoveryResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SshDiscoveryResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SshDiscoveryResult value)  $default,){
final _that = this;
switch (_that) {
case _SshDiscoveryResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SshDiscoveryResult value)?  $default,){
final _that = this;
switch (_that) {
case _SshDiscoveryResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ip,  int port,  String? banner,  bool isSelected)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SshDiscoveryResult() when $default != null:
return $default(_that.ip,_that.port,_that.banner,_that.isSelected);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ip,  int port,  String? banner,  bool isSelected)  $default,) {final _that = this;
switch (_that) {
case _SshDiscoveryResult():
return $default(_that.ip,_that.port,_that.banner,_that.isSelected);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ip,  int port,  String? banner,  bool isSelected)?  $default,) {final _that = this;
switch (_that) {
case _SshDiscoveryResult() when $default != null:
return $default(_that.ip,_that.port,_that.banner,_that.isSelected);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SshDiscoveryResult implements SshDiscoveryResult {
  const _SshDiscoveryResult({required this.ip, required this.port, this.banner, this.isSelected = false});
  factory _SshDiscoveryResult.fromJson(Map<String, dynamic> json) => _$SshDiscoveryResultFromJson(json);

@override final  String ip;
@override final  int port;
@override final  String? banner;
@override@JsonKey() final  bool isSelected;

/// Create a copy of SshDiscoveryResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SshDiscoveryResultCopyWith<_SshDiscoveryResult> get copyWith => __$SshDiscoveryResultCopyWithImpl<_SshDiscoveryResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SshDiscoveryResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SshDiscoveryResult&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.port, port) || other.port == port)&&(identical(other.banner, banner) || other.banner == banner)&&(identical(other.isSelected, isSelected) || other.isSelected == isSelected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ip,port,banner,isSelected);

@override
String toString() {
  return 'SshDiscoveryResult(ip: $ip, port: $port, banner: $banner, isSelected: $isSelected)';
}


}

/// @nodoc
abstract mixin class _$SshDiscoveryResultCopyWith<$Res> implements $SshDiscoveryResultCopyWith<$Res> {
  factory _$SshDiscoveryResultCopyWith(_SshDiscoveryResult value, $Res Function(_SshDiscoveryResult) _then) = __$SshDiscoveryResultCopyWithImpl;
@override @useResult
$Res call({
 String ip, int port, String? banner, bool isSelected
});




}
/// @nodoc
class __$SshDiscoveryResultCopyWithImpl<$Res>
    implements _$SshDiscoveryResultCopyWith<$Res> {
  __$SshDiscoveryResultCopyWithImpl(this._self, this._then);

  final _SshDiscoveryResult _self;
  final $Res Function(_SshDiscoveryResult) _then;

/// Create a copy of SshDiscoveryResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ip = null,Object? port = null,Object? banner = freezed,Object? isSelected = null,}) {
  return _then(_SshDiscoveryResult(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,banner: freezed == banner ? _self.banner : banner // ignore: cast_nullable_to_non_nullable
as String?,isSelected: null == isSelected ? _self.isSelected : isSelected // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SshDiscoveryReport {

 String get generatedAt; int get durationMs; int get count; List<SshDiscoveryResult> get items;
/// Create a copy of SshDiscoveryReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SshDiscoveryReportCopyWith<SshDiscoveryReport> get copyWith => _$SshDiscoveryReportCopyWithImpl<SshDiscoveryReport>(this as SshDiscoveryReport, _$identity);

  /// Serializes this SshDiscoveryReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SshDiscoveryReport&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.count, count) || other.count == count)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,generatedAt,durationMs,count,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'SshDiscoveryReport(generatedAt: $generatedAt, durationMs: $durationMs, count: $count, items: $items)';
}


}

/// @nodoc
abstract mixin class $SshDiscoveryReportCopyWith<$Res>  {
  factory $SshDiscoveryReportCopyWith(SshDiscoveryReport value, $Res Function(SshDiscoveryReport) _then) = _$SshDiscoveryReportCopyWithImpl;
@useResult
$Res call({
 String generatedAt, int durationMs, int count, List<SshDiscoveryResult> items
});




}
/// @nodoc
class _$SshDiscoveryReportCopyWithImpl<$Res>
    implements $SshDiscoveryReportCopyWith<$Res> {
  _$SshDiscoveryReportCopyWithImpl(this._self, this._then);

  final SshDiscoveryReport _self;
  final $Res Function(SshDiscoveryReport) _then;

/// Create a copy of SshDiscoveryReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? generatedAt = null,Object? durationMs = null,Object? count = null,Object? items = null,}) {
  return _then(_self.copyWith(
generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<SshDiscoveryResult>,
  ));
}

}


/// Adds pattern-matching-related methods to [SshDiscoveryReport].
extension SshDiscoveryReportPatterns on SshDiscoveryReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SshDiscoveryReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SshDiscoveryReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SshDiscoveryReport value)  $default,){
final _that = this;
switch (_that) {
case _SshDiscoveryReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SshDiscoveryReport value)?  $default,){
final _that = this;
switch (_that) {
case _SshDiscoveryReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String generatedAt,  int durationMs,  int count,  List<SshDiscoveryResult> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SshDiscoveryReport() when $default != null:
return $default(_that.generatedAt,_that.durationMs,_that.count,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String generatedAt,  int durationMs,  int count,  List<SshDiscoveryResult> items)  $default,) {final _that = this;
switch (_that) {
case _SshDiscoveryReport():
return $default(_that.generatedAt,_that.durationMs,_that.count,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String generatedAt,  int durationMs,  int count,  List<SshDiscoveryResult> items)?  $default,) {final _that = this;
switch (_that) {
case _SshDiscoveryReport() when $default != null:
return $default(_that.generatedAt,_that.durationMs,_that.count,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SshDiscoveryReport implements SshDiscoveryReport {
  const _SshDiscoveryReport({required this.generatedAt, required this.durationMs, required this.count, required final  List<SshDiscoveryResult> items}): _items = items;
  factory _SshDiscoveryReport.fromJson(Map<String, dynamic> json) => _$SshDiscoveryReportFromJson(json);

@override final  String generatedAt;
@override final  int durationMs;
@override final  int count;
 final  List<SshDiscoveryResult> _items;
@override List<SshDiscoveryResult> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of SshDiscoveryReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SshDiscoveryReportCopyWith<_SshDiscoveryReport> get copyWith => __$SshDiscoveryReportCopyWithImpl<_SshDiscoveryReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SshDiscoveryReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SshDiscoveryReport&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.count, count) || other.count == count)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,generatedAt,durationMs,count,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'SshDiscoveryReport(generatedAt: $generatedAt, durationMs: $durationMs, count: $count, items: $items)';
}


}

/// @nodoc
abstract mixin class _$SshDiscoveryReportCopyWith<$Res> implements $SshDiscoveryReportCopyWith<$Res> {
  factory _$SshDiscoveryReportCopyWith(_SshDiscoveryReport value, $Res Function(_SshDiscoveryReport) _then) = __$SshDiscoveryReportCopyWithImpl;
@override @useResult
$Res call({
 String generatedAt, int durationMs, int count, List<SshDiscoveryResult> items
});




}
/// @nodoc
class __$SshDiscoveryReportCopyWithImpl<$Res>
    implements _$SshDiscoveryReportCopyWith<$Res> {
  __$SshDiscoveryReportCopyWithImpl(this._self, this._then);

  final _SshDiscoveryReport _self;
  final $Res Function(_SshDiscoveryReport) _then;

/// Create a copy of SshDiscoveryReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? generatedAt = null,Object? durationMs = null,Object? count = null,Object? items = null,}) {
  return _then(_SshDiscoveryReport(
generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<SshDiscoveryResult>,
  ));
}


}

/// @nodoc
mixin _$SshDiscoveryConfig {

 int get timeoutMs; int get maxConcurrency; bool get enableMdns; int get hostEnumerationLimit;
/// Create a copy of SshDiscoveryConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SshDiscoveryConfigCopyWith<SshDiscoveryConfig> get copyWith => _$SshDiscoveryConfigCopyWithImpl<SshDiscoveryConfig>(this as SshDiscoveryConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SshDiscoveryConfig&&(identical(other.timeoutMs, timeoutMs) || other.timeoutMs == timeoutMs)&&(identical(other.maxConcurrency, maxConcurrency) || other.maxConcurrency == maxConcurrency)&&(identical(other.enableMdns, enableMdns) || other.enableMdns == enableMdns)&&(identical(other.hostEnumerationLimit, hostEnumerationLimit) || other.hostEnumerationLimit == hostEnumerationLimit));
}


@override
int get hashCode => Object.hash(runtimeType,timeoutMs,maxConcurrency,enableMdns,hostEnumerationLimit);

@override
String toString() {
  return 'SshDiscoveryConfig(timeoutMs: $timeoutMs, maxConcurrency: $maxConcurrency, enableMdns: $enableMdns, hostEnumerationLimit: $hostEnumerationLimit)';
}


}

/// @nodoc
abstract mixin class $SshDiscoveryConfigCopyWith<$Res>  {
  factory $SshDiscoveryConfigCopyWith(SshDiscoveryConfig value, $Res Function(SshDiscoveryConfig) _then) = _$SshDiscoveryConfigCopyWithImpl;
@useResult
$Res call({
 int timeoutMs, int maxConcurrency, bool enableMdns, int hostEnumerationLimit
});




}
/// @nodoc
class _$SshDiscoveryConfigCopyWithImpl<$Res>
    implements $SshDiscoveryConfigCopyWith<$Res> {
  _$SshDiscoveryConfigCopyWithImpl(this._self, this._then);

  final SshDiscoveryConfig _self;
  final $Res Function(SshDiscoveryConfig) _then;

/// Create a copy of SshDiscoveryConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timeoutMs = null,Object? maxConcurrency = null,Object? enableMdns = null,Object? hostEnumerationLimit = null,}) {
  return _then(_self.copyWith(
timeoutMs: null == timeoutMs ? _self.timeoutMs : timeoutMs // ignore: cast_nullable_to_non_nullable
as int,maxConcurrency: null == maxConcurrency ? _self.maxConcurrency : maxConcurrency // ignore: cast_nullable_to_non_nullable
as int,enableMdns: null == enableMdns ? _self.enableMdns : enableMdns // ignore: cast_nullable_to_non_nullable
as bool,hostEnumerationLimit: null == hostEnumerationLimit ? _self.hostEnumerationLimit : hostEnumerationLimit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SshDiscoveryConfig].
extension SshDiscoveryConfigPatterns on SshDiscoveryConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SshDiscoveryConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SshDiscoveryConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SshDiscoveryConfig value)  $default,){
final _that = this;
switch (_that) {
case _SshDiscoveryConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SshDiscoveryConfig value)?  $default,){
final _that = this;
switch (_that) {
case _SshDiscoveryConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int timeoutMs,  int maxConcurrency,  bool enableMdns,  int hostEnumerationLimit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SshDiscoveryConfig() when $default != null:
return $default(_that.timeoutMs,_that.maxConcurrency,_that.enableMdns,_that.hostEnumerationLimit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int timeoutMs,  int maxConcurrency,  bool enableMdns,  int hostEnumerationLimit)  $default,) {final _that = this;
switch (_that) {
case _SshDiscoveryConfig():
return $default(_that.timeoutMs,_that.maxConcurrency,_that.enableMdns,_that.hostEnumerationLimit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int timeoutMs,  int maxConcurrency,  bool enableMdns,  int hostEnumerationLimit)?  $default,) {final _that = this;
switch (_that) {
case _SshDiscoveryConfig() when $default != null:
return $default(_that.timeoutMs,_that.maxConcurrency,_that.enableMdns,_that.hostEnumerationLimit);case _:
  return null;

}
}

}

/// @nodoc


class _SshDiscoveryConfig implements SshDiscoveryConfig {
  const _SshDiscoveryConfig({this.timeoutMs = 700, this.maxConcurrency = 128, this.enableMdns = false, this.hostEnumerationLimit = 4096});
  

@override@JsonKey() final  int timeoutMs;
@override@JsonKey() final  int maxConcurrency;
@override@JsonKey() final  bool enableMdns;
@override@JsonKey() final  int hostEnumerationLimit;

/// Create a copy of SshDiscoveryConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SshDiscoveryConfigCopyWith<_SshDiscoveryConfig> get copyWith => __$SshDiscoveryConfigCopyWithImpl<_SshDiscoveryConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SshDiscoveryConfig&&(identical(other.timeoutMs, timeoutMs) || other.timeoutMs == timeoutMs)&&(identical(other.maxConcurrency, maxConcurrency) || other.maxConcurrency == maxConcurrency)&&(identical(other.enableMdns, enableMdns) || other.enableMdns == enableMdns)&&(identical(other.hostEnumerationLimit, hostEnumerationLimit) || other.hostEnumerationLimit == hostEnumerationLimit));
}


@override
int get hashCode => Object.hash(runtimeType,timeoutMs,maxConcurrency,enableMdns,hostEnumerationLimit);

@override
String toString() {
  return 'SshDiscoveryConfig(timeoutMs: $timeoutMs, maxConcurrency: $maxConcurrency, enableMdns: $enableMdns, hostEnumerationLimit: $hostEnumerationLimit)';
}


}

/// @nodoc
abstract mixin class _$SshDiscoveryConfigCopyWith<$Res> implements $SshDiscoveryConfigCopyWith<$Res> {
  factory _$SshDiscoveryConfigCopyWith(_SshDiscoveryConfig value, $Res Function(_SshDiscoveryConfig) _then) = __$SshDiscoveryConfigCopyWithImpl;
@override @useResult
$Res call({
 int timeoutMs, int maxConcurrency, bool enableMdns, int hostEnumerationLimit
});




}
/// @nodoc
class __$SshDiscoveryConfigCopyWithImpl<$Res>
    implements _$SshDiscoveryConfigCopyWith<$Res> {
  __$SshDiscoveryConfigCopyWithImpl(this._self, this._then);

  final _SshDiscoveryConfig _self;
  final $Res Function(_SshDiscoveryConfig) _then;

/// Create a copy of SshDiscoveryConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timeoutMs = null,Object? maxConcurrency = null,Object? enableMdns = null,Object? hostEnumerationLimit = null,}) {
  return _then(_SshDiscoveryConfig(
timeoutMs: null == timeoutMs ? _self.timeoutMs : timeoutMs // ignore: cast_nullable_to_non_nullable
as int,maxConcurrency: null == maxConcurrency ? _self.maxConcurrency : maxConcurrency // ignore: cast_nullable_to_non_nullable
as int,enableMdns: null == enableMdns ? _self.enableMdns : enableMdns // ignore: cast_nullable_to_non_nullable
as bool,hostEnumerationLimit: null == hostEnumerationLimit ? _self.hostEnumerationLimit : hostEnumerationLimit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
