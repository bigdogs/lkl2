// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'file.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FileStatus {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FileStatus()';
}


}

/// @nodoc
class $FileStatusCopyWith<$Res>  {
$FileStatusCopyWith(FileStatus _, $Res Function(FileStatus) __);
}


/// Adds pattern-matching-related methods to [FileStatus].
extension FileStatusPatterns on FileStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( FileStatus_Uninit value)?  uninit,TResult Function( FileStatus_Pending value)?  pending,TResult Function( FileStatus_Complete value)?  complete,TResult Function( FileStatus_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case FileStatus_Uninit() when uninit != null:
return uninit(_that);case FileStatus_Pending() when pending != null:
return pending(_that);case FileStatus_Complete() when complete != null:
return complete(_that);case FileStatus_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( FileStatus_Uninit value)  uninit,required TResult Function( FileStatus_Pending value)  pending,required TResult Function( FileStatus_Complete value)  complete,required TResult Function( FileStatus_Error value)  error,}){
final _that = this;
switch (_that) {
case FileStatus_Uninit():
return uninit(_that);case FileStatus_Pending():
return pending(_that);case FileStatus_Complete():
return complete(_that);case FileStatus_Error():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( FileStatus_Uninit value)?  uninit,TResult? Function( FileStatus_Pending value)?  pending,TResult? Function( FileStatus_Complete value)?  complete,TResult? Function( FileStatus_Error value)?  error,}){
final _that = this;
switch (_that) {
case FileStatus_Uninit() when uninit != null:
return uninit(_that);case FileStatus_Pending() when pending != null:
return pending(_that);case FileStatus_Complete() when complete != null:
return complete(_that);case FileStatus_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  uninit,TResult Function()?  pending,TResult Function()?  complete,TResult Function( String field0)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case FileStatus_Uninit() when uninit != null:
return uninit();case FileStatus_Pending() when pending != null:
return pending();case FileStatus_Complete() when complete != null:
return complete();case FileStatus_Error() when error != null:
return error(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  uninit,required TResult Function()  pending,required TResult Function()  complete,required TResult Function( String field0)  error,}) {final _that = this;
switch (_that) {
case FileStatus_Uninit():
return uninit();case FileStatus_Pending():
return pending();case FileStatus_Complete():
return complete();case FileStatus_Error():
return error(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  uninit,TResult? Function()?  pending,TResult? Function()?  complete,TResult? Function( String field0)?  error,}) {final _that = this;
switch (_that) {
case FileStatus_Uninit() when uninit != null:
return uninit();case FileStatus_Pending() when pending != null:
return pending();case FileStatus_Complete() when complete != null:
return complete();case FileStatus_Error() when error != null:
return error(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class FileStatus_Uninit extends FileStatus {
  const FileStatus_Uninit(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileStatus_Uninit);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FileStatus.uninit()';
}


}




/// @nodoc


class FileStatus_Pending extends FileStatus {
  const FileStatus_Pending(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileStatus_Pending);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FileStatus.pending()';
}


}




/// @nodoc


class FileStatus_Complete extends FileStatus {
  const FileStatus_Complete(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileStatus_Complete);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FileStatus.complete()';
}


}




/// @nodoc


class FileStatus_Error extends FileStatus {
  const FileStatus_Error(this.field0): super._();
  

 final  String field0;

/// Create a copy of FileStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileStatus_ErrorCopyWith<FileStatus_Error> get copyWith => _$FileStatus_ErrorCopyWithImpl<FileStatus_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileStatus_Error&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'FileStatus.error(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FileStatus_ErrorCopyWith<$Res> implements $FileStatusCopyWith<$Res> {
  factory $FileStatus_ErrorCopyWith(FileStatus_Error value, $Res Function(FileStatus_Error) _then) = _$FileStatus_ErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FileStatus_ErrorCopyWithImpl<$Res>
    implements $FileStatus_ErrorCopyWith<$Res> {
  _$FileStatus_ErrorCopyWithImpl(this._self, this._then);

  final FileStatus_Error _self;
  final $Res Function(FileStatus_Error) _then;

/// Create a copy of FileStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FileStatus_Error(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
