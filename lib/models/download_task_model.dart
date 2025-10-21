import 'package:hive/hive.dart';

part 'download_task_model.g.dart';

/// 下载任务模型（用于持久化）
@HiveType(typeId: 6)
class DownloadTaskModel extends HiveObject {
  /// 任务 ID
  @HiveField(0)
  final String id;
  
  /// 歌曲 ID
  @HiveField(1)
  final String songId;
  
  /// 歌曲标题
  @HiveField(2)
  final String songTitle;
  
  /// 歌曲艺人
  @HiveField(3)
  final String songArtist;
  
  /// 歌曲来源
  @HiveField(4)
  final String songSource;
  
  /// 任务状态 (pending, running, completed, failed, cancelled)
  @HiveField(5)
  String status;
  
  /// 创建时间
  @HiveField(6)
  final DateTime createdAt;
  
  /// 开始时间
  @HiveField(7)
  DateTime? startedAt;
  
  /// 完成时间
  @HiveField(8)
  DateTime? completedAt;
  
  /// 错误信息（如果失败）
  @HiveField(9)
  String? errorMessage;
  
  DownloadTaskModel({
    required this.id,
    required this.songId,
    required this.songTitle,
    required this.songArtist,
    required this.songSource,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
  });
  
  /// 从 JSON 创建
  factory DownloadTaskModel.fromJson(Map<String, dynamic> json) {
    return DownloadTaskModel(
      id: json['id'] as String,
      songId: json['songId'] as String,
      songTitle: json['songTitle'] as String,
      songArtist: json['songArtist'] as String,
      songSource: json['songSource'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] != null 
          ? DateTime.parse(json['startedAt'] as String) 
          : null,
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt'] as String) 
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }
  
  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'songId': songId,
      'songTitle': songTitle,
      'songArtist': songArtist,
      'songSource': songSource,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }
  
  /// 复制并更新
  DownloadTaskModel copyWith({
    String? status,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return DownloadTaskModel(
      id: id,
      songId: songId,
      songTitle: songTitle,
      songArtist: songArtist,
      songSource: songSource,
      status: status ?? this.status,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
  
  @override
  String toString() {
    return 'DownloadTaskModel(id: $id, songTitle: $songTitle, status: $status)';
  }
}

