import 'dart:io';
import 'package:hive/hive.dart';

part 'local_song.g.dart';

@HiveType(typeId: 0)
class LocalSong extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String artist;
  
  @HiveField(3)
  final String album;
  
  @HiveField(4)
  final String? albumArt;
  
  @HiveField(5)
  final String filePath;
  
  @HiveField(6)
  final Duration duration;
  
  @HiveField(7)
  final DateTime lastModified;
  
  @HiveField(8)
  final int fileSize;
  
  @HiveField(9)
  final String? lyric; // LRC格式歌词
  
  @HiveField(10)
  final String? onlineId; // 在线歌曲ID（如果是从在线下载的）
  
  @HiveField(11)
  final String? source; // 来源平台（如 "龙珠音乐"）

  LocalSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArt,
    required this.filePath,
    required this.duration,
    required this.lastModified,
    required this.fileSize,
    this.lyric,
    this.onlineId,
    this.source,
  });

  LocalSong copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumArt,
    String? filePath,
    Duration? duration,
    DateTime? lastModified,
    int? fileSize,
    String? lyric,
    String? onlineId,
    String? source,
  }) {
    return LocalSong(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArt: albumArt ?? this.albumArt,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      lastModified: lastModified ?? this.lastModified,
      fileSize: fileSize ?? this.fileSize,
      lyric: lyric ?? this.lyric,
      onlineId: onlineId ?? this.onlineId,
      source: source ?? this.source,
    );
  }

  /// 从文件路径创建LocalSong实例
  static Future<LocalSong> fromFile(File file) async {
    final stat = await file.stat();
    final fileName = file.uri.pathSegments.last;
    
    // 提取文件名作为默认标题（去掉扩展名）
    String title = fileName;
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex > 0) {
      title = fileName.substring(0, lastDotIndex);
    }
    
    return LocalSong(
      id: file.path,
      title: title,
      artist: '未知艺人',
      album: '未知专辑',
      filePath: file.path,
      duration: Duration.zero, // 需要在扫描时获取实际时长
      lastModified: stat.modified,
      fileSize: stat.size,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalSong && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}