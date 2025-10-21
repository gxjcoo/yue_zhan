import 'package:hive/hive.dart';

part 'hive_playlist.g.dart';

@HiveType(typeId: 2)
class HivePlaylist extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String? coverImage;

  @HiveField(4)
  List<String> songIds; // 存储本地歌曲ID列表（文件路径）

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  List<String> onlineSongJsons; // 存储在线歌曲的JSON字符串列表

  HivePlaylist({
    required this.id,
    required this.name,
    this.description,
    this.coverImage,
    required this.songIds,
    required this.createdAt,
    required this.updatedAt,
    List<String>? onlineSongJsons,
  }) : onlineSongJsons = onlineSongJsons ?? [];

  HivePlaylist copyWith({
    String? id,
    String? name,
    String? description,
    String? coverImage,
    List<String>? songIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? onlineSongJsons,
  }) {
    return HivePlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      onlineSongJsons: onlineSongJsons ?? this.onlineSongJsons,
    );
  }

  int get songCount => songIds.length + onlineSongJsons.length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HivePlaylist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

