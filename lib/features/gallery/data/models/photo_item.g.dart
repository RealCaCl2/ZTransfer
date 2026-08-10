// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PhotoItemImpl _$$PhotoItemImplFromJson(Map<String, dynamic> json) =>
    _$PhotoItemImpl(
      objectHandle: (json['objectHandle'] as num).toInt(),
      fileName: json['fileName'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      captureDate: DateTime.parse(json['captureDate'] as String),
      localPath: json['localPath'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      formatCode: (json['formatCode'] as num?)?.toInt() ?? 0x3801,
      isSynced: json['isSynced'] as bool? ?? false,
    );

Map<String, dynamic> _$$PhotoItemImplToJson(_$PhotoItemImpl instance) =>
    <String, dynamic>{
      'objectHandle': instance.objectHandle,
      'fileName': instance.fileName,
      'sizeBytes': instance.sizeBytes,
      'captureDate': instance.captureDate.toIso8601String(),
      'localPath': instance.localPath,
      'thumbnailPath': instance.thumbnailPath,
      'formatCode': instance.formatCode,
      'isSynced': instance.isSynced,
    };
