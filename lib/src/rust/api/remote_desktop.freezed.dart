// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'remote_desktop.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RemoteDesktopEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDesktopEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RemoteDesktopEvent()';
}


}

/// @nodoc
class $RemoteDesktopEventCopyWith<$Res>  {
$RemoteDesktopEventCopyWith(RemoteDesktopEvent _, $Res Function(RemoteDesktopEvent) __);
}


/// Adds pattern-matching-related methods to [RemoteDesktopEvent].
extension RemoteDesktopEventPatterns on RemoteDesktopEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RemoteDesktopEvent_ConnectionState value)?  connectionState,TResult Function( RemoteDesktopEvent_Frame value)?  frame,TResult Function( RemoteDesktopEvent_Resolution value)?  resolution,TResult Function( RemoteDesktopEvent_CursorDefault value)?  cursorDefault,TResult Function( RemoteDesktopEvent_CursorHidden value)?  cursorHidden,TResult Function( RemoteDesktopEvent_CursorPosition value)?  cursorPosition,TResult Function( RemoteDesktopEvent_CursorBitmap value)?  cursorBitmap,TResult Function( RemoteDesktopEvent_ClipboardText value)?  clipboardText,TResult Function( RemoteDesktopEvent_CertificateRequest value)?  certificateRequest,TResult Function( RemoteDesktopEvent_Error value)?  error,TResult Function( RemoteDesktopEvent_Ended value)?  ended,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RemoteDesktopEvent_ConnectionState() when connectionState != null:
return connectionState(_that);case RemoteDesktopEvent_Frame() when frame != null:
return frame(_that);case RemoteDesktopEvent_Resolution() when resolution != null:
return resolution(_that);case RemoteDesktopEvent_CursorDefault() when cursorDefault != null:
return cursorDefault(_that);case RemoteDesktopEvent_CursorHidden() when cursorHidden != null:
return cursorHidden(_that);case RemoteDesktopEvent_CursorPosition() when cursorPosition != null:
return cursorPosition(_that);case RemoteDesktopEvent_CursorBitmap() when cursorBitmap != null:
return cursorBitmap(_that);case RemoteDesktopEvent_ClipboardText() when clipboardText != null:
return clipboardText(_that);case RemoteDesktopEvent_CertificateRequest() when certificateRequest != null:
return certificateRequest(_that);case RemoteDesktopEvent_Error() when error != null:
return error(_that);case RemoteDesktopEvent_Ended() when ended != null:
return ended(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RemoteDesktopEvent_ConnectionState value)  connectionState,required TResult Function( RemoteDesktopEvent_Frame value)  frame,required TResult Function( RemoteDesktopEvent_Resolution value)  resolution,required TResult Function( RemoteDesktopEvent_CursorDefault value)  cursorDefault,required TResult Function( RemoteDesktopEvent_CursorHidden value)  cursorHidden,required TResult Function( RemoteDesktopEvent_CursorPosition value)  cursorPosition,required TResult Function( RemoteDesktopEvent_CursorBitmap value)  cursorBitmap,required TResult Function( RemoteDesktopEvent_ClipboardText value)  clipboardText,required TResult Function( RemoteDesktopEvent_CertificateRequest value)  certificateRequest,required TResult Function( RemoteDesktopEvent_Error value)  error,required TResult Function( RemoteDesktopEvent_Ended value)  ended,}){
final _that = this;
switch (_that) {
case RemoteDesktopEvent_ConnectionState():
return connectionState(_that);case RemoteDesktopEvent_Frame():
return frame(_that);case RemoteDesktopEvent_Resolution():
return resolution(_that);case RemoteDesktopEvent_CursorDefault():
return cursorDefault(_that);case RemoteDesktopEvent_CursorHidden():
return cursorHidden(_that);case RemoteDesktopEvent_CursorPosition():
return cursorPosition(_that);case RemoteDesktopEvent_CursorBitmap():
return cursorBitmap(_that);case RemoteDesktopEvent_ClipboardText():
return clipboardText(_that);case RemoteDesktopEvent_CertificateRequest():
return certificateRequest(_that);case RemoteDesktopEvent_Error():
return error(_that);case RemoteDesktopEvent_Ended():
return ended(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RemoteDesktopEvent_ConnectionState value)?  connectionState,TResult? Function( RemoteDesktopEvent_Frame value)?  frame,TResult? Function( RemoteDesktopEvent_Resolution value)?  resolution,TResult? Function( RemoteDesktopEvent_CursorDefault value)?  cursorDefault,TResult? Function( RemoteDesktopEvent_CursorHidden value)?  cursorHidden,TResult? Function( RemoteDesktopEvent_CursorPosition value)?  cursorPosition,TResult? Function( RemoteDesktopEvent_CursorBitmap value)?  cursorBitmap,TResult? Function( RemoteDesktopEvent_ClipboardText value)?  clipboardText,TResult? Function( RemoteDesktopEvent_CertificateRequest value)?  certificateRequest,TResult? Function( RemoteDesktopEvent_Error value)?  error,TResult? Function( RemoteDesktopEvent_Ended value)?  ended,}){
final _that = this;
switch (_that) {
case RemoteDesktopEvent_ConnectionState() when connectionState != null:
return connectionState(_that);case RemoteDesktopEvent_Frame() when frame != null:
return frame(_that);case RemoteDesktopEvent_Resolution() when resolution != null:
return resolution(_that);case RemoteDesktopEvent_CursorDefault() when cursorDefault != null:
return cursorDefault(_that);case RemoteDesktopEvent_CursorHidden() when cursorHidden != null:
return cursorHidden(_that);case RemoteDesktopEvent_CursorPosition() when cursorPosition != null:
return cursorPosition(_that);case RemoteDesktopEvent_CursorBitmap() when cursorBitmap != null:
return cursorBitmap(_that);case RemoteDesktopEvent_ClipboardText() when clipboardText != null:
return clipboardText(_that);case RemoteDesktopEvent_CertificateRequest() when certificateRequest != null:
return certificateRequest(_that);case RemoteDesktopEvent_Error() when error != null:
return error(_that);case RemoteDesktopEvent_Ended() when ended != null:
return ended(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( RemoteDesktopConnectionState state,  int attempt)?  connectionState,TResult Function( Uint8List bgra,  int width,  int height,  BigInt sequence)?  frame,TResult Function( int width,  int height)?  resolution,TResult Function()?  cursorDefault,TResult Function()?  cursorHidden,TResult Function( int x,  int y)?  cursorPosition,TResult Function( Uint8List rgba,  int width,  int height,  int hotspotX,  int hotspotY)?  cursorBitmap,TResult Function( String text)?  clipboardText,TResult Function( String sha256,  String subject,  String issuer,  String validFrom,  String validTo,  String? previousSha256)?  certificateRequest,TResult Function( String message,  bool retryable)?  error,TResult Function( RemoteDesktopEndReason reason,  String? message)?  ended,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RemoteDesktopEvent_ConnectionState() when connectionState != null:
return connectionState(_that.state,_that.attempt);case RemoteDesktopEvent_Frame() when frame != null:
return frame(_that.bgra,_that.width,_that.height,_that.sequence);case RemoteDesktopEvent_Resolution() when resolution != null:
return resolution(_that.width,_that.height);case RemoteDesktopEvent_CursorDefault() when cursorDefault != null:
return cursorDefault();case RemoteDesktopEvent_CursorHidden() when cursorHidden != null:
return cursorHidden();case RemoteDesktopEvent_CursorPosition() when cursorPosition != null:
return cursorPosition(_that.x,_that.y);case RemoteDesktopEvent_CursorBitmap() when cursorBitmap != null:
return cursorBitmap(_that.rgba,_that.width,_that.height,_that.hotspotX,_that.hotspotY);case RemoteDesktopEvent_ClipboardText() when clipboardText != null:
return clipboardText(_that.text);case RemoteDesktopEvent_CertificateRequest() when certificateRequest != null:
return certificateRequest(_that.sha256,_that.subject,_that.issuer,_that.validFrom,_that.validTo,_that.previousSha256);case RemoteDesktopEvent_Error() when error != null:
return error(_that.message,_that.retryable);case RemoteDesktopEvent_Ended() when ended != null:
return ended(_that.reason,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( RemoteDesktopConnectionState state,  int attempt)  connectionState,required TResult Function( Uint8List bgra,  int width,  int height,  BigInt sequence)  frame,required TResult Function( int width,  int height)  resolution,required TResult Function()  cursorDefault,required TResult Function()  cursorHidden,required TResult Function( int x,  int y)  cursorPosition,required TResult Function( Uint8List rgba,  int width,  int height,  int hotspotX,  int hotspotY)  cursorBitmap,required TResult Function( String text)  clipboardText,required TResult Function( String sha256,  String subject,  String issuer,  String validFrom,  String validTo,  String? previousSha256)  certificateRequest,required TResult Function( String message,  bool retryable)  error,required TResult Function( RemoteDesktopEndReason reason,  String? message)  ended,}) {final _that = this;
switch (_that) {
case RemoteDesktopEvent_ConnectionState():
return connectionState(_that.state,_that.attempt);case RemoteDesktopEvent_Frame():
return frame(_that.bgra,_that.width,_that.height,_that.sequence);case RemoteDesktopEvent_Resolution():
return resolution(_that.width,_that.height);case RemoteDesktopEvent_CursorDefault():
return cursorDefault();case RemoteDesktopEvent_CursorHidden():
return cursorHidden();case RemoteDesktopEvent_CursorPosition():
return cursorPosition(_that.x,_that.y);case RemoteDesktopEvent_CursorBitmap():
return cursorBitmap(_that.rgba,_that.width,_that.height,_that.hotspotX,_that.hotspotY);case RemoteDesktopEvent_ClipboardText():
return clipboardText(_that.text);case RemoteDesktopEvent_CertificateRequest():
return certificateRequest(_that.sha256,_that.subject,_that.issuer,_that.validFrom,_that.validTo,_that.previousSha256);case RemoteDesktopEvent_Error():
return error(_that.message,_that.retryable);case RemoteDesktopEvent_Ended():
return ended(_that.reason,_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( RemoteDesktopConnectionState state,  int attempt)?  connectionState,TResult? Function( Uint8List bgra,  int width,  int height,  BigInt sequence)?  frame,TResult? Function( int width,  int height)?  resolution,TResult? Function()?  cursorDefault,TResult? Function()?  cursorHidden,TResult? Function( int x,  int y)?  cursorPosition,TResult? Function( Uint8List rgba,  int width,  int height,  int hotspotX,  int hotspotY)?  cursorBitmap,TResult? Function( String text)?  clipboardText,TResult? Function( String sha256,  String subject,  String issuer,  String validFrom,  String validTo,  String? previousSha256)?  certificateRequest,TResult? Function( String message,  bool retryable)?  error,TResult? Function( RemoteDesktopEndReason reason,  String? message)?  ended,}) {final _that = this;
switch (_that) {
case RemoteDesktopEvent_ConnectionState() when connectionState != null:
return connectionState(_that.state,_that.attempt);case RemoteDesktopEvent_Frame() when frame != null:
return frame(_that.bgra,_that.width,_that.height,_that.sequence);case RemoteDesktopEvent_Resolution() when resolution != null:
return resolution(_that.width,_that.height);case RemoteDesktopEvent_CursorDefault() when cursorDefault != null:
return cursorDefault();case RemoteDesktopEvent_CursorHidden() when cursorHidden != null:
return cursorHidden();case RemoteDesktopEvent_CursorPosition() when cursorPosition != null:
return cursorPosition(_that.x,_that.y);case RemoteDesktopEvent_CursorBitmap() when cursorBitmap != null:
return cursorBitmap(_that.rgba,_that.width,_that.height,_that.hotspotX,_that.hotspotY);case RemoteDesktopEvent_ClipboardText() when clipboardText != null:
return clipboardText(_that.text);case RemoteDesktopEvent_CertificateRequest() when certificateRequest != null:
return certificateRequest(_that.sha256,_that.subject,_that.issuer,_that.validFrom,_that.validTo,_that.previousSha256);case RemoteDesktopEvent_Error() when error != null:
return error(_that.message,_that.retryable);case RemoteDesktopEvent_Ended() when ended != null:
return ended(_that.reason,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class RemoteDesktopEvent_ConnectionState extends RemoteDesktopEvent {
  const RemoteDesktopEvent_ConnectionState({required this.state, required this.attempt}): super._();


 final  RemoteDesktopConnectionState state;
 final  int attempt;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteDesktopEvent_ConnectionStateCopyWith<RemoteDesktopEvent_ConnectionState> get copyWith => _$RemoteDesktopEvent_ConnectionStateCopyWithImpl<RemoteDesktopEvent_ConnectionState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDesktopEvent_ConnectionState&&(identical(other.state, state) || other.state == state)&&(identical(other.attempt, attempt) || other.attempt == attempt));
}


@override
int get hashCode => Object.hash(runtimeType,state,attempt);

@override
String toString() {
  return 'RemoteDesktopEvent.connectionState(state: $state, attempt: $attempt)';
}


}

/// @nodoc
abstract mixin class $RemoteDesktopEvent_ConnectionStateCopyWith<$Res> implements $RemoteDesktopEventCopyWith<$Res> {
  factory $RemoteDesktopEvent_ConnectionStateCopyWith(RemoteDesktopEvent_ConnectionState value, $Res Function(RemoteDesktopEvent_ConnectionState) _then) = _$RemoteDesktopEvent_ConnectionStateCopyWithImpl;
@useResult
$Res call({
 RemoteDesktopConnectionState state, int attempt
});




}
/// @nodoc
class _$RemoteDesktopEvent_ConnectionStateCopyWithImpl<$Res>
    implements $RemoteDesktopEvent_ConnectionStateCopyWith<$Res> {
  _$RemoteDesktopEvent_ConnectionStateCopyWithImpl(this._self, this._then);

  final RemoteDesktopEvent_ConnectionState _self;
  final $Res Function(RemoteDesktopEvent_ConnectionState) _then;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? state = null,Object? attempt = null,}) {
  return _then(RemoteDesktopEvent_ConnectionState(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as RemoteDesktopConnectionState,attempt: null == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class RemoteDesktopEvent_Frame extends RemoteDesktopEvent {
  const RemoteDesktopEvent_Frame({required this.bgra, required this.width, required this.height, required this.sequence}): super._();


 final  Uint8List bgra;
 final  int width;
 final  int height;
 final  BigInt sequence;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteDesktopEvent_FrameCopyWith<RemoteDesktopEvent_Frame> get copyWith => _$RemoteDesktopEvent_FrameCopyWithImpl<RemoteDesktopEvent_Frame>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDesktopEvent_Frame&&const DeepCollectionEquality().equals(other.bgra, bgra)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.sequence, sequence) || other.sequence == sequence));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(bgra),width,height,sequence);

@override
String toString() {
  return 'RemoteDesktopEvent.frame(bgra: $bgra, width: $width, height: $height, sequence: $sequence)';
}


}

/// @nodoc
abstract mixin class $RemoteDesktopEvent_FrameCopyWith<$Res> implements $RemoteDesktopEventCopyWith<$Res> {
  factory $RemoteDesktopEvent_FrameCopyWith(RemoteDesktopEvent_Frame value, $Res Function(RemoteDesktopEvent_Frame) _then) = _$RemoteDesktopEvent_FrameCopyWithImpl;
@useResult
$Res call({
 Uint8List bgra, int width, int height, BigInt sequence
});




}
/// @nodoc
class _$RemoteDesktopEvent_FrameCopyWithImpl<$Res>
    implements $RemoteDesktopEvent_FrameCopyWith<$Res> {
  _$RemoteDesktopEvent_FrameCopyWithImpl(this._self, this._then);

  final RemoteDesktopEvent_Frame _self;
  final $Res Function(RemoteDesktopEvent_Frame) _then;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bgra = null,Object? width = null,Object? height = null,Object? sequence = null,}) {
  return _then(RemoteDesktopEvent_Frame(
bgra: null == bgra ? _self.bgra : bgra // ignore: cast_nullable_to_non_nullable
as Uint8List,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class RemoteDesktopEvent_Resolution extends RemoteDesktopEvent {
  const RemoteDesktopEvent_Resolution({required this.width, required this.height}): super._();


 final  int width;
 final  int height;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteDesktopEvent_ResolutionCopyWith<RemoteDesktopEvent_Resolution> get copyWith => _$RemoteDesktopEvent_ResolutionCopyWithImpl<RemoteDesktopEvent_Resolution>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDesktopEvent_Resolution&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,width,height);

@override
String toString() {
  return 'RemoteDesktopEvent.resolution(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $RemoteDesktopEvent_ResolutionCopyWith<$Res> implements $RemoteDesktopEventCopyWith<$Res> {
  factory $RemoteDesktopEvent_ResolutionCopyWith(RemoteDesktopEvent_Resolution value, $Res Function(RemoteDesktopEvent_Resolution) _then) = _$RemoteDesktopEvent_ResolutionCopyWithImpl;
@useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class _$RemoteDesktopEvent_ResolutionCopyWithImpl<$Res>
    implements $RemoteDesktopEvent_ResolutionCopyWith<$Res> {
  _$RemoteDesktopEvent_ResolutionCopyWithImpl(this._self, this._then);

  final RemoteDesktopEvent_Resolution _self;
  final $Res Function(RemoteDesktopEvent_Resolution) _then;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? width = null,Object? height = null,}) {
  return _then(RemoteDesktopEvent_Resolution(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class RemoteDesktopEvent_CursorDefault extends RemoteDesktopEvent {
  const RemoteDesktopEvent_CursorDefault(): super._();







@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDesktopEvent_CursorDefault);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RemoteDesktopEvent.cursorDefault()';
}


}




/// @nodoc


class RemoteDesktopEvent_CursorHidden extends RemoteDesktopEvent {
  const RemoteDesktopEvent_CursorHidden(): super._();







@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDesktopEvent_CursorHidden);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RemoteDesktopEvent.cursorHidden()';
}


}




/// @nodoc


class RemoteDesktopEvent_CursorPosition extends RemoteDesktopEvent {
  const RemoteDesktopEvent_CursorPosition({required this.x, required this.y}): super._();


 final  int x;
 final  int y;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteDesktopEvent_CursorPositionCopyWith<RemoteDesktopEvent_CursorPosition> get copyWith => _$RemoteDesktopEvent_CursorPositionCopyWithImpl<RemoteDesktopEvent_CursorPosition>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDesktopEvent_CursorPosition&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y));
}


@override
int get hashCode => Object.hash(runtimeType,x,y);

@override
String toString() {
  return 'RemoteDesktopEvent.cursorPosition(x: $x, y: $y)';
}


}

/// @nodoc
abstract mixin class $RemoteDesktopEvent_CursorPositionCopyWith<$Res> implements $RemoteDesktopEventCopyWith<$Res> {
  factory $RemoteDesktopEvent_CursorPositionCopyWith(RemoteDesktopEvent_CursorPosition value, $Res Function(RemoteDesktopEvent_CursorPosition) _then) = _$RemoteDesktopEvent_CursorPositionCopyWithImpl;
@useResult
$Res call({
 int x, int y
});




}
/// @nodoc
class _$RemoteDesktopEvent_CursorPositionCopyWithImpl<$Res>
    implements $RemoteDesktopEvent_CursorPositionCopyWith<$Res> {
  _$RemoteDesktopEvent_CursorPositionCopyWithImpl(this._self, this._then);

  final RemoteDesktopEvent_CursorPosition _self;
  final $Res Function(RemoteDesktopEvent_CursorPosition) _then;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? x = null,Object? y = null,}) {
  return _then(RemoteDesktopEvent_CursorPosition(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class RemoteDesktopEvent_CursorBitmap extends RemoteDesktopEvent {
  const RemoteDesktopEvent_CursorBitmap({required this.rgba, required this.width, required this.height, required this.hotspotX, required this.hotspotY}): super._();


 final  Uint8List rgba;
 final  int width;
 final  int height;
 final  int hotspotX;
 final  int hotspotY;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteDesktopEvent_CursorBitmapCopyWith<RemoteDesktopEvent_CursorBitmap> get copyWith => _$RemoteDesktopEvent_CursorBitmapCopyWithImpl<RemoteDesktopEvent_CursorBitmap>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDesktopEvent_CursorBitmap&&const DeepCollectionEquality().equals(other.rgba, rgba)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.hotspotX, hotspotX) || other.hotspotX == hotspotX)&&(identical(other.hotspotY, hotspotY) || other.hotspotY == hotspotY));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(rgba),width,height,hotspotX,hotspotY);

@override
String toString() {
  return 'RemoteDesktopEvent.cursorBitmap(rgba: $rgba, width: $width, height: $height, hotspotX: $hotspotX, hotspotY: $hotspotY)';
}


}

/// @nodoc
abstract mixin class $RemoteDesktopEvent_CursorBitmapCopyWith<$Res> implements $RemoteDesktopEventCopyWith<$Res> {
  factory $RemoteDesktopEvent_CursorBitmapCopyWith(RemoteDesktopEvent_CursorBitmap value, $Res Function(RemoteDesktopEvent_CursorBitmap) _then) = _$RemoteDesktopEvent_CursorBitmapCopyWithImpl;
@useResult
$Res call({
 Uint8List rgba, int width, int height, int hotspotX, int hotspotY
});




}
/// @nodoc
class _$RemoteDesktopEvent_CursorBitmapCopyWithImpl<$Res>
    implements $RemoteDesktopEvent_CursorBitmapCopyWith<$Res> {
  _$RemoteDesktopEvent_CursorBitmapCopyWithImpl(this._self, this._then);

  final RemoteDesktopEvent_CursorBitmap _self;
  final $Res Function(RemoteDesktopEvent_CursorBitmap) _then;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? rgba = null,Object? width = null,Object? height = null,Object? hotspotX = null,Object? hotspotY = null,}) {
  return _then(RemoteDesktopEvent_CursorBitmap(
rgba: null == rgba ? _self.rgba : rgba // ignore: cast_nullable_to_non_nullable
as Uint8List,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,hotspotX: null == hotspotX ? _self.hotspotX : hotspotX // ignore: cast_nullable_to_non_nullable
as int,hotspotY: null == hotspotY ? _self.hotspotY : hotspotY // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class RemoteDesktopEvent_ClipboardText extends RemoteDesktopEvent {
  const RemoteDesktopEvent_ClipboardText({required this.text}): super._();


 final  String text;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteDesktopEvent_ClipboardTextCopyWith<RemoteDesktopEvent_ClipboardText> get copyWith => _$RemoteDesktopEvent_ClipboardTextCopyWithImpl<RemoteDesktopEvent_ClipboardText>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDesktopEvent_ClipboardText&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'RemoteDesktopEvent.clipboardText(text: $text)';
}


}

/// @nodoc
abstract mixin class $RemoteDesktopEvent_ClipboardTextCopyWith<$Res> implements $RemoteDesktopEventCopyWith<$Res> {
  factory $RemoteDesktopEvent_ClipboardTextCopyWith(RemoteDesktopEvent_ClipboardText value, $Res Function(RemoteDesktopEvent_ClipboardText) _then) = _$RemoteDesktopEvent_ClipboardTextCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$RemoteDesktopEvent_ClipboardTextCopyWithImpl<$Res>
    implements $RemoteDesktopEvent_ClipboardTextCopyWith<$Res> {
  _$RemoteDesktopEvent_ClipboardTextCopyWithImpl(this._self, this._then);

  final RemoteDesktopEvent_ClipboardText _self;
  final $Res Function(RemoteDesktopEvent_ClipboardText) _then;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(RemoteDesktopEvent_ClipboardText(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RemoteDesktopEvent_CertificateRequest extends RemoteDesktopEvent {
  const RemoteDesktopEvent_CertificateRequest({required this.sha256, required this.subject, required this.issuer, required this.validFrom, required this.validTo, this.previousSha256}): super._();


 final  String sha256;
 final  String subject;
 final  String issuer;
 final  String validFrom;
 final  String validTo;
 final  String? previousSha256;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteDesktopEvent_CertificateRequestCopyWith<RemoteDesktopEvent_CertificateRequest> get copyWith => _$RemoteDesktopEvent_CertificateRequestCopyWithImpl<RemoteDesktopEvent_CertificateRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDesktopEvent_CertificateRequest&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.subject, subject) || other.subject == subject)&&(identical(other.issuer, issuer) || other.issuer == issuer)&&(identical(other.validFrom, validFrom) || other.validFrom == validFrom)&&(identical(other.validTo, validTo) || other.validTo == validTo)&&(identical(other.previousSha256, previousSha256) || other.previousSha256 == previousSha256));
}


@override
int get hashCode => Object.hash(runtimeType,sha256,subject,issuer,validFrom,validTo,previousSha256);

@override
String toString() {
  return 'RemoteDesktopEvent.certificateRequest(sha256: $sha256, subject: $subject, issuer: $issuer, validFrom: $validFrom, validTo: $validTo, previousSha256: $previousSha256)';
}


}

/// @nodoc
abstract mixin class $RemoteDesktopEvent_CertificateRequestCopyWith<$Res> implements $RemoteDesktopEventCopyWith<$Res> {
  factory $RemoteDesktopEvent_CertificateRequestCopyWith(RemoteDesktopEvent_CertificateRequest value, $Res Function(RemoteDesktopEvent_CertificateRequest) _then) = _$RemoteDesktopEvent_CertificateRequestCopyWithImpl;
@useResult
$Res call({
 String sha256, String subject, String issuer, String validFrom, String validTo, String? previousSha256
});




}
/// @nodoc
class _$RemoteDesktopEvent_CertificateRequestCopyWithImpl<$Res>
    implements $RemoteDesktopEvent_CertificateRequestCopyWith<$Res> {
  _$RemoteDesktopEvent_CertificateRequestCopyWithImpl(this._self, this._then);

  final RemoteDesktopEvent_CertificateRequest _self;
  final $Res Function(RemoteDesktopEvent_CertificateRequest) _then;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sha256 = null,Object? subject = null,Object? issuer = null,Object? validFrom = null,Object? validTo = null,Object? previousSha256 = freezed,}) {
  return _then(RemoteDesktopEvent_CertificateRequest(
sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,subject: null == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String,issuer: null == issuer ? _self.issuer : issuer // ignore: cast_nullable_to_non_nullable
as String,validFrom: null == validFrom ? _self.validFrom : validFrom // ignore: cast_nullable_to_non_nullable
as String,validTo: null == validTo ? _self.validTo : validTo // ignore: cast_nullable_to_non_nullable
as String,previousSha256: freezed == previousSha256 ? _self.previousSha256 : previousSha256 // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class RemoteDesktopEvent_Error extends RemoteDesktopEvent {
  const RemoteDesktopEvent_Error({required this.message, required this.retryable}): super._();


 final  String message;
 final  bool retryable;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteDesktopEvent_ErrorCopyWith<RemoteDesktopEvent_Error> get copyWith => _$RemoteDesktopEvent_ErrorCopyWithImpl<RemoteDesktopEvent_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDesktopEvent_Error&&(identical(other.message, message) || other.message == message)&&(identical(other.retryable, retryable) || other.retryable == retryable));
}


@override
int get hashCode => Object.hash(runtimeType,message,retryable);

@override
String toString() {
  return 'RemoteDesktopEvent.error(message: $message, retryable: $retryable)';
}


}

/// @nodoc
abstract mixin class $RemoteDesktopEvent_ErrorCopyWith<$Res> implements $RemoteDesktopEventCopyWith<$Res> {
  factory $RemoteDesktopEvent_ErrorCopyWith(RemoteDesktopEvent_Error value, $Res Function(RemoteDesktopEvent_Error) _then) = _$RemoteDesktopEvent_ErrorCopyWithImpl;
@useResult
$Res call({
 String message, bool retryable
});




}
/// @nodoc
class _$RemoteDesktopEvent_ErrorCopyWithImpl<$Res>
    implements $RemoteDesktopEvent_ErrorCopyWith<$Res> {
  _$RemoteDesktopEvent_ErrorCopyWithImpl(this._self, this._then);

  final RemoteDesktopEvent_Error _self;
  final $Res Function(RemoteDesktopEvent_Error) _then;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,Object? retryable = null,}) {
  return _then(RemoteDesktopEvent_Error(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,retryable: null == retryable ? _self.retryable : retryable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class RemoteDesktopEvent_Ended extends RemoteDesktopEvent {
  const RemoteDesktopEvent_Ended({required this.reason, this.message}): super._();


 final  RemoteDesktopEndReason reason;
 final  String? message;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteDesktopEvent_EndedCopyWith<RemoteDesktopEvent_Ended> get copyWith => _$RemoteDesktopEvent_EndedCopyWithImpl<RemoteDesktopEvent_Ended>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDesktopEvent_Ended&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,reason,message);

@override
String toString() {
  return 'RemoteDesktopEvent.ended(reason: $reason, message: $message)';
}


}

/// @nodoc
abstract mixin class $RemoteDesktopEvent_EndedCopyWith<$Res> implements $RemoteDesktopEventCopyWith<$Res> {
  factory $RemoteDesktopEvent_EndedCopyWith(RemoteDesktopEvent_Ended value, $Res Function(RemoteDesktopEvent_Ended) _then) = _$RemoteDesktopEvent_EndedCopyWithImpl;
@useResult
$Res call({
 RemoteDesktopEndReason reason, String? message
});




}
/// @nodoc
class _$RemoteDesktopEvent_EndedCopyWithImpl<$Res>
    implements $RemoteDesktopEvent_EndedCopyWith<$Res> {
  _$RemoteDesktopEvent_EndedCopyWithImpl(this._self, this._then);

  final RemoteDesktopEvent_Ended _self;
  final $Res Function(RemoteDesktopEvent_Ended) _then;

/// Create a copy of RemoteDesktopEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,Object? message = freezed,}) {
  return _then(RemoteDesktopEvent_Ended(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as RemoteDesktopEndReason,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
