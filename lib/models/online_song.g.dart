// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'online_song.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnlineSong _$OnlineSongFromJson(Map<String, dynamic> json) => OnlineSong(
      id: json['id'] as String,
      apiId: json['apiId'] as String?,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String? ?? '未知专辑',
      albumArt: json['albumArt'] as String?,
      audioUrl: json['audioUrl'] as String?,
      duration: json['duration'] == null
          ? null
          : Duration(microseconds: (json['duration'] as num).toInt()),
      lyric: json['lyric'] as String?,
      source: json['source'] as String? ?? '龙珠音乐',
    );

Map<String, dynamic> _$OnlineSongToJson(OnlineSong instance) =>
    <String, dynamic>{
      'id': instance.id,
      'apiId': instance.apiId,
      'title': instance.title,
      'artist': instance.artist,
      'album': instance.album,
      'albumArt': instance.albumArt,
      'audioUrl': instance.audioUrl,
      'duration': instance.duration?.inMicroseconds,
      'lyric': instance.lyric,
      'source': instance.source,
    };
