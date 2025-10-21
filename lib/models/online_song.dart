import 'package:json_annotation/json_annotation.dart';

part 'online_song.g.dart';

@JsonSerializable()
class OnlineSong {
  /// 歌曲唯一标识（用于下载状态记录）
  final String id;
  
  /// API 原始 ID（用于获取歌曲详情）
  final String? apiId;
  
  /// 歌曲标题
  final String title;
  
  /// 艺术家
  final String artist;
  
  /// 专辑名称
  final String album;
  
  /// 专辑封面图片 URL
  final String? albumArt;
  
  /// 音频播放 URL（可能需要二次请求获取）
  final String? audioUrl;
  
  /// 歌曲时长
  final Duration? duration;
  
  /// 歌词（LRC 格式）
  final String? lyric;
  
  /// 音乐来源平台
  final String source;

  OnlineSong({
    required this.id,
    this.apiId,
    required this.title,
    required this.artist,
    this.album = '未知专辑',
    this.albumArt,
    this.audioUrl,
    this.duration,
    this.lyric,
    this.source = '龙珠音乐',
  });

  OnlineSong copyWith({
    String? id,
    String? apiId,
    String? title,
    String? artist,
    String? album,
    String? albumArt,
    String? audioUrl,
    Duration? duration,
    String? lyric,
    String? source,
  }) {
    return OnlineSong(
      id: id ?? this.id,
      apiId: apiId ?? this.apiId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArt: albumArt ?? this.albumArt,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      lyric: lyric ?? this.lyric,
      source: source ?? this.source,
    );
  }

  factory OnlineSong.fromJson(Map<String, dynamic> json) =>
      _$OnlineSongFromJson(json);

  Map<String, dynamic> toJson() => _$OnlineSongToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OnlineSong && other.id == id && other.source == source;
  }

  @override
  int get hashCode => Object.hash(id, source);
}

