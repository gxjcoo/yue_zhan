import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../models/local_song.dart';

/// 音频元数据处理器（Isolate 友好）
/// 
/// 此类设计为可以在 Isolate 中运行，所有方法都是静态的，
/// 不依赖任何 Flutter UI 相关的类
class AudioMetadataProcessor {
  /// 处理单个音频文件（Isolate 入口点）
  /// 
  /// 这个方法会在独立的 Isolate 中运行，不会阻塞主线程
  static Future<LocalSong?> processAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      
      // 检查文件是否存在
      if (!await file.exists()) {
        print('[Isolate] 文件不存在: $filePath');
        return null;
      }
      
      // 获取文件信息
      final stat = await file.stat();
      final fileName = file.uri.pathSegments.last;
      
      // 提取文件名作为默认标题
      String title = fileName;
      final lastDotIndex = fileName.lastIndexOf('.');
      if (lastDotIndex > 0) {
        title = fileName.substring(0, lastDotIndex);
      }
      
      // 初始化默认值
      String songTitle = title;
      String songArtist = '未知艺人';
      String songAlbum = '未知专辑';
      Duration duration = Duration.zero;
      String? albumArt;
      
      // 🎯 关键：在 Isolate 中读取元数据（不阻塞主线程）
      try {
        print('[Isolate] 开始读取元数据: $filePath');
        
        final metadata = readMetadata(file, getImage: true);
        
        if (metadata != null) {
          // 提取基本信息
          if (metadata.title != null && metadata.title!.isNotEmpty) {
            songTitle = metadata.title!;
          }
          if (metadata.artist != null && metadata.artist!.isNotEmpty) {
            songArtist = metadata.artist!;
          }
          if (metadata.album != null && metadata.album!.isNotEmpty) {
            songAlbum = metadata.album!;
          }
          if (metadata.duration != null) {
            duration = metadata.duration!;
          }
          
          // 如果有内嵌封面，标记为元数据封面
          if (metadata.pictures.isNotEmpty) {
            albumArt = '$filePath#metadata';
          }
          
          print('[Isolate] 元数据读取成功: $songTitle by $songArtist (${duration.inSeconds}秒)');
        } else {
          print('[Isolate] 元数据为空: $filePath');
        }
      } catch (e) {
        print('[Isolate] 元数据读取失败: $filePath, 错误: $e');
        // 继续处理，使用默认值
      }
      
      // 创建 LocalSong 对象
      final song = LocalSong(
        id: filePath,
        title: songTitle,
        artist: songArtist,
        album: songAlbum,
        albumArt: albumArt,
        filePath: filePath,
        duration: duration,
        lastModified: stat.modified,
        fileSize: stat.size,
      );
      
      print('[Isolate] 歌曲处理完成: $songTitle');
      return song;
      
    } catch (e, stackTrace) {
      print('[Isolate] 处理音频文件失败: $filePath');
      print('[Isolate] 错误: $e');
      print('[Isolate] 堆栈: $stackTrace');
      return null;
    }
  }
  
  /// 批量处理音频文件列表
  /// 
  /// 此方法设计为在主线程调用，但会为每个文件创建独立的 Isolate
  static Future<List<LocalSong>> processBatch(List<String> filePaths) async {
    final results = <LocalSong>[];
    
    for (final filePath in filePaths) {
      try {
        final song = await processAudioFile(filePath);
        if (song != null) {
          results.add(song);
        }
      } catch (e) {
        print('[Batch] 处理文件失败: $filePath, 错误: $e');
        // 继续处理下一个文件
      }
    }
    
    return results;
  }
  
  /// 处理文件包装器（用于传递给 compute）
  static LocalSong? processAudioFileSync(AudioFileTask task) {
    try {
      final file = File(task.filePath);
      
      // 检查文件是否存在（同步）
      if (!file.existsSync()) {
        print('[Isolate] 文件不存在: ${task.filePath}');
        return null;
      }
      
      // 获取文件信息
      final stat = file.statSync();
      final fileName = file.uri.pathSegments.last;
      
      // 提取文件名作为默认标题
      String title = fileName;
      final lastDotIndex = fileName.lastIndexOf('.');
      if (lastDotIndex > 0) {
        title = fileName.substring(0, lastDotIndex);
      }
      
      // 初始化默认值
      String songTitle = title;
      String songArtist = '未知艺人';
      String songAlbum = '未知专辑';
      Duration duration = Duration.zero;
      String? albumArt;
      
      // 🎯 在 Isolate 中同步读取元数据
      try {
        print('[Isolate] 读取元数据: ${task.filePath}');
        
        final metadata = readMetadata(file, getImage: true);
        
        if (metadata != null) {
          if (metadata.title != null && metadata.title!.isNotEmpty) {
            songTitle = metadata.title!;
          }
          if (metadata.artist != null && metadata.artist!.isNotEmpty) {
            songArtist = metadata.artist!;
          }
          if (metadata.album != null && metadata.album!.isNotEmpty) {
            songAlbum = metadata.album!;
          }
          if (metadata.duration != null) {
            duration = metadata.duration!;
          }
          
          if (metadata.pictures.isNotEmpty) {
            albumArt = '${task.filePath}#metadata';
          }
          
          print('[Isolate] ✅ $songTitle - $songArtist (${duration.inSeconds}s)');
        }
      } catch (e) {
        print('[Isolate] ❌ 元数据读取失败: $e');
      }
      
      // 🎯 读取歌词文件（在 Isolate 中同步处理）
      String? lyric;
      try {
        lyric = _readLyricsFileSync(task.filePath);
        if (lyric != null && lyric.isNotEmpty) {
          print('[Isolate] ✅ 读取歌词成功: ${lyric.length} 字符');
        }
      } catch (e) {
        print('[Isolate] ❌ 读取歌词失败: $e');
      }
      
      // 创建并返回 LocalSong
      return LocalSong(
        id: task.filePath,
        title: songTitle,
        artist: songArtist,
        album: songAlbum,
        albumArt: albumArt,
        filePath: task.filePath,
        duration: duration,
        lastModified: stat.modified,
        fileSize: stat.size,
        lyric: lyric, // 包含歌词
      );
      
    } catch (e) {
      print('[Isolate] 处理失败: ${task.filePath}');
      print('[Isolate] 错误: $e');
      return null;
    }
  }

  /// 同步读取歌词文件（用于 Isolate）
  static String? _readLyricsFileSync(String audioFilePath) {
    try {
      final audioFile = File(audioFilePath);
      final audioDir = audioFile.parent;
      final audioBaseName = audioFilePath.split('/').last.split('.').first;
      
      // 支持的歌词文件扩展名
      const lyricsExtensions = ['.lrc', '.txt', '.srt'];
      
      // 按优先级查找歌词文件：.lrc > .txt > .srt
      for (final ext in lyricsExtensions) {
        final lyricsPath = '${audioDir.path}/$audioBaseName$ext';
        final lyricsFile = File(lyricsPath);
        
        if (lyricsFile.existsSync()) {
          try {
            final content = lyricsFile.readAsStringSync();
            if (content.trim().isNotEmpty) {
              print('[Isolate] 读取歌词文件成功: $lyricsPath (${content.length} 字符)');
              return content;
            }
          } catch (e) {
            print('[Isolate] 读取歌词文件内容失败: $lyricsPath, 错误: $e');
            continue; // 尝试下一个扩展名
          }
        }
      }
      
      return null;
    } catch (e) {
      print('[Isolate] 读取歌词文件失败: $audioFilePath, 错误: $e');
      return null;
    }
  }
}

/// 音频文件任务（用于 Isolate 通信）
class AudioFileTask {
  final String filePath;
  final int index; // 任务索引（用于排序）
  
  const AudioFileTask(this.filePath, this.index);
}

/// 音频处理结果
class AudioProcessResult {
  final LocalSong? song;
  final String filePath;
  final int index;
  final bool success;
  final String? error;
  
  AudioProcessResult({
    required this.song,
    required this.filePath,
    required this.index,
    required this.success,
    this.error,
  });
  
  factory AudioProcessResult.success(LocalSong song, int index) {
    return AudioProcessResult(
      song: song,
      filePath: song.filePath,
      index: index,
      success: true,
    );
  }
  
  factory AudioProcessResult.failure(String filePath, int index, String error) {
    return AudioProcessResult(
      song: null,
      filePath: filePath,
      index: index,
      success: false,
      error: error,
    );
  }
}

