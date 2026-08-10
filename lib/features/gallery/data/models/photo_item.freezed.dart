// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'photo_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PhotoItem _$PhotoItemFromJson(Map<String, dynamic> json) {
  return _PhotoItem.fromJson(json);
}

/// @nodoc
mixin _$PhotoItem {
  /// Camera object handle (PTP).
  int get objectHandle => throw _privateConstructorUsedError;

  /// Original file name on the camera.
  String get fileName => throw _privateConstructorUsedError;

  /// Compressed file size in bytes.
  int get sizeBytes => throw _privateConstructorUsedError;

  /// Capture timestamp from EXIF (or file modification time).
  DateTime get captureDate => throw _privateConstructorUsedError;

  /// Local file path after sync (null if not yet downloaded).
  String? get localPath => throw _privateConstructorUsedError;

  /// Path to a local thumbnail (null if not yet generated).
  String? get thumbnailPath => throw _privateConstructorUsedError;

  /// Format code (0x3801 = EXIF JPEG).
  int get formatCode => throw _privateConstructorUsedError;

  /// Whether this photo has been synced to the phone.
  bool get isSynced => throw _privateConstructorUsedError;

  /// Serializes this PhotoItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PhotoItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PhotoItemCopyWith<PhotoItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PhotoItemCopyWith<$Res> {
  factory $PhotoItemCopyWith(PhotoItem value, $Res Function(PhotoItem) then) =
      _$PhotoItemCopyWithImpl<$Res, PhotoItem>;
  @useResult
  $Res call(
      {int objectHandle,
      String fileName,
      int sizeBytes,
      DateTime captureDate,
      String? localPath,
      String? thumbnailPath,
      int formatCode,
      bool isSynced});
}

/// @nodoc
class _$PhotoItemCopyWithImpl<$Res, $Val extends PhotoItem>
    implements $PhotoItemCopyWith<$Res> {
  _$PhotoItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PhotoItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? objectHandle = null,
    Object? fileName = null,
    Object? sizeBytes = null,
    Object? captureDate = null,
    Object? localPath = freezed,
    Object? thumbnailPath = freezed,
    Object? formatCode = null,
    Object? isSynced = null,
  }) {
    return _then(_value.copyWith(
      objectHandle: null == objectHandle
          ? _value.objectHandle
          : objectHandle // ignore: cast_nullable_to_non_nullable
              as int,
      fileName: null == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      sizeBytes: null == sizeBytes
          ? _value.sizeBytes
          : sizeBytes // ignore: cast_nullable_to_non_nullable
              as int,
      captureDate: null == captureDate
          ? _value.captureDate
          : captureDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      localPath: freezed == localPath
          ? _value.localPath
          : localPath // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailPath: freezed == thumbnailPath
          ? _value.thumbnailPath
          : thumbnailPath // ignore: cast_nullable_to_non_nullable
              as String?,
      formatCode: null == formatCode
          ? _value.formatCode
          : formatCode // ignore: cast_nullable_to_non_nullable
              as int,
      isSynced: null == isSynced
          ? _value.isSynced
          : isSynced // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PhotoItemImplCopyWith<$Res>
    implements $PhotoItemCopyWith<$Res> {
  factory _$$PhotoItemImplCopyWith(
          _$PhotoItemImpl value, $Res Function(_$PhotoItemImpl) then) =
      __$$PhotoItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int objectHandle,
      String fileName,
      int sizeBytes,
      DateTime captureDate,
      String? localPath,
      String? thumbnailPath,
      int formatCode,
      bool isSynced});
}

/// @nodoc
class __$$PhotoItemImplCopyWithImpl<$Res>
    extends _$PhotoItemCopyWithImpl<$Res, _$PhotoItemImpl>
    implements _$$PhotoItemImplCopyWith<$Res> {
  __$$PhotoItemImplCopyWithImpl(
      _$PhotoItemImpl _value, $Res Function(_$PhotoItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of PhotoItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? objectHandle = null,
    Object? fileName = null,
    Object? sizeBytes = null,
    Object? captureDate = null,
    Object? localPath = freezed,
    Object? thumbnailPath = freezed,
    Object? formatCode = null,
    Object? isSynced = null,
  }) {
    return _then(_$PhotoItemImpl(
      objectHandle: null == objectHandle
          ? _value.objectHandle
          : objectHandle // ignore: cast_nullable_to_non_nullable
              as int,
      fileName: null == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      sizeBytes: null == sizeBytes
          ? _value.sizeBytes
          : sizeBytes // ignore: cast_nullable_to_non_nullable
              as int,
      captureDate: null == captureDate
          ? _value.captureDate
          : captureDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      localPath: freezed == localPath
          ? _value.localPath
          : localPath // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailPath: freezed == thumbnailPath
          ? _value.thumbnailPath
          : thumbnailPath // ignore: cast_nullable_to_non_nullable
              as String?,
      formatCode: null == formatCode
          ? _value.formatCode
          : formatCode // ignore: cast_nullable_to_non_nullable
              as int,
      isSynced: null == isSynced
          ? _value.isSynced
          : isSynced // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PhotoItemImpl implements _PhotoItem {
  const _$PhotoItemImpl(
      {required this.objectHandle,
      required this.fileName,
      required this.sizeBytes,
      required this.captureDate,
      this.localPath,
      this.thumbnailPath,
      this.formatCode = 0x3801,
      this.isSynced = false});

  factory _$PhotoItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$PhotoItemImplFromJson(json);

  /// Camera object handle (PTP).
  @override
  final int objectHandle;

  /// Original file name on the camera.
  @override
  final String fileName;

  /// Compressed file size in bytes.
  @override
  final int sizeBytes;

  /// Capture timestamp from EXIF (or file modification time).
  @override
  final DateTime captureDate;

  /// Local file path after sync (null if not yet downloaded).
  @override
  final String? localPath;

  /// Path to a local thumbnail (null if not yet generated).
  @override
  final String? thumbnailPath;

  /// Format code (0x3801 = EXIF JPEG).
  @override
  @JsonKey()
  final int formatCode;

  /// Whether this photo has been synced to the phone.
  @override
  @JsonKey()
  final bool isSynced;

  @override
  String toString() {
    return 'PhotoItem(objectHandle: $objectHandle, fileName: $fileName, sizeBytes: $sizeBytes, captureDate: $captureDate, localPath: $localPath, thumbnailPath: $thumbnailPath, formatCode: $formatCode, isSynced: $isSynced)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PhotoItemImpl &&
            (identical(other.objectHandle, objectHandle) ||
                other.objectHandle == objectHandle) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.sizeBytes, sizeBytes) ||
                other.sizeBytes == sizeBytes) &&
            (identical(other.captureDate, captureDate) ||
                other.captureDate == captureDate) &&
            (identical(other.localPath, localPath) ||
                other.localPath == localPath) &&
            (identical(other.thumbnailPath, thumbnailPath) ||
                other.thumbnailPath == thumbnailPath) &&
            (identical(other.formatCode, formatCode) ||
                other.formatCode == formatCode) &&
            (identical(other.isSynced, isSynced) ||
                other.isSynced == isSynced));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, objectHandle, fileName,
      sizeBytes, captureDate, localPath, thumbnailPath, formatCode, isSynced);

  /// Create a copy of PhotoItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PhotoItemImplCopyWith<_$PhotoItemImpl> get copyWith =>
      __$$PhotoItemImplCopyWithImpl<_$PhotoItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PhotoItemImplToJson(
      this,
    );
  }
}

abstract class _PhotoItem implements PhotoItem {
  const factory _PhotoItem(
      {required final int objectHandle,
      required final String fileName,
      required final int sizeBytes,
      required final DateTime captureDate,
      final String? localPath,
      final String? thumbnailPath,
      final int formatCode,
      final bool isSynced}) = _$PhotoItemImpl;

  factory _PhotoItem.fromJson(Map<String, dynamic> json) =
      _$PhotoItemImpl.fromJson;

  /// Camera object handle (PTP).
  @override
  int get objectHandle;

  /// Original file name on the camera.
  @override
  String get fileName;

  /// Compressed file size in bytes.
  @override
  int get sizeBytes;

  /// Capture timestamp from EXIF (or file modification time).
  @override
  DateTime get captureDate;

  /// Local file path after sync (null if not yet downloaded).
  @override
  String? get localPath;

  /// Path to a local thumbnail (null if not yet generated).
  @override
  String? get thumbnailPath;

  /// Format code (0x3801 = EXIF JPEG).
  @override
  int get formatCode;

  /// Whether this photo has been synced to the phone.
  @override
  bool get isSynced;

  /// Create a copy of PhotoItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PhotoItemImplCopyWith<_$PhotoItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
