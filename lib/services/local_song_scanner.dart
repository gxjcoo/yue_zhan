import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/local_song.dart';
import '../utils/isolate_helper.dart';
import '../utils/logger.dart';
import 'permission_exception.dart';
import 'album_art_service.dart';
import 'audio_metadata_processor.dart';
import 'web_file_picker_service.dart' if (dart.library.io) 'web_file_picker_service_stub.dart';

class LocalSongScanner {
  static const List<String> _supportedExtensions = [
    '.mp3',
    '.wav',
    '.flac',
    '.m4a',
    '.aac',
    '.ogg',
  ];
  
  static const List<String> _lyricsExtensions = [
    '.lrc',
    '.txt',
    '.srt',
  ];

  /// 检查并请求存储权限
  static Future<bool> requestPermissions() async {
    try {
      // Web环境不需要权限检查
      if (kIsWeb) {
        print('Web环境：跳过权限检查');
        return true;
      }
      
      if (Platform.isAndroid) {
        // 尝试多种权限策略以适应不同Android版本
        
        // 首先尝试新的媒体权限 (Android 13+)
        try {
          final audioGranted = await Permission.audio.request().isGranted;
          final imagesGranted = await Permission.photos.request().isGranted;
          if (audioGranted && imagesGranted) {
            return true;
          }
        } catch (e) {
          print('媒体权限请求失败: $e');
        }
        
        // 尝试管理外部存储权限 (Android 11+)
        try {
          if (await Permission.manageExternalStorage.request().isGranted) {
            return true;
          }
        } catch (e) {
          print('管理外部存储权限请求失败: $e');
        }
        
        // 尝试传统存储权限
        try {
          if (await Permission.storage.request().isGranted) {
            return true;
          }
        } catch (e) {
          print('存储权限请求失败: $e');
        }
      } else if (Platform.isIOS) {
        if (await Permission.mediaLibrary.request().isGranted) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('请求权限时出错: $e');
      // 如果权限请求失败，尝试检查是否已经授予权限
      return await _checkPermissions();
    }
  }

  /// 检查权限状态
  static Future<bool> _checkPermissions() async {
    try {
      // Web环境总是返回true
      if (kIsWeb) {
        return true;
      }
      
      if (Platform.isAndroid) {
        return await Permission.storage.isGranted || 
               await Permission.manageExternalStorage.isGranted ||
               (await Permission.audio.isGranted && await Permission.photos.isGranted);
      } else if (Platform.isIOS) {
        return await Permission.mediaLibrary.isGranted;
      }
      return false;
    } catch (e) {
      print('检查权限时出错: $e');
      return false;
    }
  }

  /// 扫描本地歌曲（Isolate 优化版）
  /// 
  /// 使用 Isolate 在后台处理元数据读取，避免阻塞主线程
  /// 
  /// [onProgress] - 进度回调，参数为 (当前数量, 总数量)
  /// [onStatusUpdate] - 状态更新回调，用于显示当前处理的文件
  static Future<List<LocalSong>> scanSongsWithIsolate({
    Function(int current, int total)? onProgress,
    Function(String status)? onStatusUpdate,
  }) async {
    // Web环境使用文件选择器（不使用 Isolate）
    if (kIsWeb) {
      return await _scanSongsWeb();
    }
    
    // 检查权限
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      await openAppSettings();
      throw PermissionDeniedException('没有获得访问存储的权限，请在设置中授予权限');
    }
    
    onStatusUpdate?.call('正在扫描目录...');
    Logger.info('开始扫描本地歌曲（Isolate 模式）', tag: 'Scanner');
    
    // 🎯 第一阶段：收集所有音频文件路径（快速，主线程）
    List<String> audioFilePaths = [];
    
    // 获取音乐目录
    List<Directory> musicDirs = [];
    
    if (Platform.isAndroid) {
      // 应用私有目录
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final appMusicDir = Directory('${appDocDir.path}/Music');
        if (await appMusicDir.exists()) {
          musicDirs.add(appMusicDir);
          Logger.info('添加应用私有音乐目录', tag: 'Scanner');
        }
      } catch (e) {
        Logger.warn('获取应用目录失败', error: e, tag: 'Scanner');
      }
      
      // 外部存储目录
      final storageDir = Directory('/storage/emulated/0');
      if (await storageDir.exists()) {
        musicDirs.addAll([
          Directory('${storageDir.path}/Music'),
          Directory('${storageDir.path}/音乐'),
          Directory('${storageDir.path}/Download'),
          Directory('${storageDir.path}/下载'),
          Directory('${storageDir.path}/netease'),
          Directory('${storageDir.path}/QQMusic'),
          Directory('${storageDir.path}/kugou'),
        ]);
      }
    } else if (Platform.isIOS) {
      final documentDir = await getApplicationDocumentsDirectory();
      musicDirs.add(documentDir);
    } else {
      final homeDir = Directory(Platform.environment['HOME'] ?? '');
      if (await homeDir.exists()) {
        musicDirs.add(Directory('${homeDir.path}/Music'));
      }
    }
    
    // 快速扫描文件路径（不读取元数据）
    for (var dir in musicDirs) {
      if (await dir.exists()) {
        final dirFiles = await _collectAudioFiles(dir);
        audioFilePaths.addAll(dirFiles);
      }
    }
    
    Logger.info('找到 ${audioFilePaths.length} 个音频文件', tag: 'Scanner');
    
    if (audioFilePaths.isEmpty) {
      return [];
    }
    
    onStatusUpdate?.call('找到 ${audioFilePaths.length} 个音频文件，开始读取元数据...');
    
    // 🎯 第二阶段：在 Isolate 中批量处理元数据（不阻塞主线程）
    final songs = await IsolateHelper.runBatch<String, LocalSong?>(
      items: audioFilePaths,
      processor: (filePath) async {
        // 每个文件在 Isolate 中处理
        return await compute(
          AudioMetadataProcessor.processAudioFileSync,
          AudioFileTask(filePath, 0),
        );
      },
      onProgress: (current, total) {
        onProgress?.call(current, total);
        
        if (current % 10 == 0 || current == total) {
          Logger.info('元数据处理进度: $current/$total', tag: 'Scanner');
        }
      },
      batchSize: 5, // 每批5个文件，平衡速度和内存
      debugLabel: '音频元数据读取',
    );
    
    // 过滤掉处理失败的文件
    final validSongs = songs.whereType<LocalSong>().toList();
    
    // 🎯 第三阶段：在主线程中补充封面信息（Isolate中无法访问文件系统）
    onStatusUpdate?.call('正在查找专辑封面...');
    for (int i = 0; i < validSongs.length; i++) {
      final song = validSongs[i];
      try {
        final file = File(song.filePath);
        final hasMetadataImage = song.albumArt?.endsWith('#metadata') ?? false;
        
        // 调用 AlbumArtService 获取真实的封面路径
        final albumArtPath = await AlbumArtService.getAlbumArt(
          file,
          hasMetadataImage: hasMetadataImage,
          artist: song.artist,
          album: song.album,
        );
        
        // 更新封面路径
        if (albumArtPath != null) {
          validSongs[i] = song.copyWith(albumArt: albumArtPath);
        }
      } catch (e) {
        Logger.debug('获取封面失败: ${song.filePath}', tag: 'Scanner');
      }
      
      // 每处理10个更新一次进度
      if ((i + 1) % 10 == 0 || (i + 1) == validSongs.length) {
        onProgress?.call(i + 1, validSongs.length);
      }
    }
    
    Logger.info(
      '元数据读取完成: ${validSongs.length}/${audioFilePaths.length}',
      tag: 'Scanner',
    );
    
    onStatusUpdate?.call('正在合并重复歌曲...');
    
    // 智能合并重复歌曲
    final mergeResult = await _mergeDuplicateSongs(validSongs);
    final finalSongs = mergeResult.songs;
    
    if (mergeResult.duplicatesRemoved > 0) {
      Logger.info(
        '去除 ${mergeResult.duplicatesRemoved} 首重复歌曲',
        tag: 'Scanner',
      );
    }
    
    onStatusUpdate?.call('扫描完成！');
    Logger.info('扫描完成，共 ${finalSongs.length} 首歌曲', tag: 'Scanner');
    
    return finalSongs;
  }
  
  /// 收集目录中的音频文件路径（不读取元数据）
  static Future<List<String>> _collectAudioFiles(Directory directory) async {
    final List<String> filePaths = [];
    
    try {
      await for (FileSystemEntity entity in directory.list(recursive: false, followLinks: false)) {
        // 跳过受限制的目录
        if (entity is Directory && _isRestrictedDirectory(entity.path)) {
          continue;
        }
        
        if (entity is File) {
          final fileExtension = path.extension(entity.path).toLowerCase();
          
          // 检查是否为支持的音频文件
          if (_supportedExtensions.contains(fileExtension)) {
            filePaths.add(entity.path);
          }
        } else if (entity is Directory) {
          // 递归收集子目录
          try {
            final subFiles = await _collectAudioFiles(entity);
            filePaths.addAll(subFiles);
          } catch (e) {
            Logger.debug('扫描子目录失败: ${entity.path}', tag: 'Scanner');
          }
        }
      }
    } catch (e) {
      Logger.warn('收集音频文件失败: ${directory.path}', error: e, tag: 'Scanner');
    }
    
    return filePaths;
  }
  
  /// 扫描本地歌曲（旧版，保持向后兼容）
  static Future<List<LocalSong>> scanSongs() async {
    // Web环境使用文件选择器
    if (kIsWeb) {
      return await _scanSongsWeb();
    }
    
    // 检查权限
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      // 尝试打开应用设置页面
      await openAppSettings();
      throw PermissionDeniedException('没有获得访问存储的权限，请在设置中授予权限');
    }

    List<LocalSong> songs = [];
    
    // 获取音乐目录
    List<Directory> musicDirs = [];
    
    if (Platform.isAndroid) {
      // 🔥 优先扫描应用私有目录（下载的歌曲保存在这里）
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final appMusicDir = Directory('${appDocDir.path}/Music');
        if (await appMusicDir.exists()) {
          musicDirs.add(appMusicDir);
          print('✅ 添加应用私有音乐目录: ${appMusicDir.path}');
        }
      } catch (e) {
        print('获取应用目录失败: $e');
      }
      
      // Android外部存储音乐目录 - 避免访问受限制的目录
      final storageDir = Directory('/storage/emulated/0');
      if (await storageDir.exists()) {
        // 扫描外部存储的音乐目录
        musicDirs.add(Directory('${storageDir.path}/Music'));
        musicDirs.add(Directory('${storageDir.path}/音乐'));
        musicDirs.add(Directory('${storageDir.path}/Download'));
        musicDirs.add(Directory('${storageDir.path}/下载'));
        // 添加常见的音乐应用目录
        musicDirs.add(Directory('${storageDir.path}/netease'));
        musicDirs.add(Directory('${storageDir.path}/QQMusic'));
        musicDirs.add(Directory('${storageDir.path}/kugou'));
      }
    } else if (Platform.isIOS) {
      // iOS文档目录
      final documentDir = await getApplicationDocumentsDirectory();
      musicDirs.add(documentDir);
    } else {
      // 其他平台
      final homeDir = Directory(Platform.environment['HOME'] ?? '');
      if (await homeDir.exists()) {
        musicDirs.add(Directory('${homeDir.path}/Music'));
      }
    }
    
    // 扫描所有音乐目录
    for (var dir in musicDirs) {
      if (await dir.exists()) {
        final dirSongs = await _scanDirectory(dir);
        songs.addAll(dirSongs);
      }
    }
    
    // 智能合并重复歌曲
    final mergeResult = await _mergeDuplicateSongs(songs);
    songs = mergeResult.songs;
    
    // 打印合并统计信息
    if (mergeResult.duplicatesRemoved > 0) {
      print('智能合并统计: 原始${mergeResult.originalCount}首 → 合并后${songs.length}首，去除${mergeResult.duplicatesRemoved}首重复');
    }
    
    return songs;
  }
  
  /// Web环境下的歌曲扫描
  static Future<List<LocalSong>> _scanSongsWeb() async {
    try {
      print('Web环境：开始文件选择');
      
      List<LocalSong> songs = [];
      
      // 策略1: 尝试使用原生HTML文件选择器
      try {
        if (kIsWeb) {
          print('尝试使用原生HTML文件选择器');
          final htmlFiles = await WebFilePickerService.pickAudioFiles();
          
          if (htmlFiles.isNotEmpty) {
            for (final htmlFile in htmlFiles) {
              try {
                final platformFile = WebFilePickerService.htmlFileToPlatformFile(htmlFile);
                final song = await _createSongFromWebFile(platformFile);
                songs.add(song);
              } catch (e) {
                print('处理HTML文件失败: ${htmlFile.name}, 错误: $e');
              }
            }
            
            if (songs.isNotEmpty) {
              print('Web环境：HTML文件选择器成功，选择了 ${songs.length} 个文件');
              return songs;
            }
          }
        }
      } catch (e) {
        print('HTML文件选择器失败: $e');
      }
      
      // 策略2: 尝试使用FilePicker
      try {
        print('尝试使用FilePicker备用方案');
        final result = await WebFilePickerService.pickFilesWithFilePicker();
        
        if (result != null && result.files.isNotEmpty) {
          for (PlatformFile file in result.files) {
            try {
              final song = await _createSongFromWebFile(file);
              songs.add(song);
            } catch (e) {
              print('处理FilePicker文件失败: ${file.name}, 错误: $e');
            }
          }
          
          if (songs.isNotEmpty) {
            print('Web环境：FilePicker成功，选择了 ${songs.length} 个文件');
            return songs;
          }
        }
      } catch (e) {
        print('FilePicker备用方案也失败: $e');
      }
      
      // 策略3: 最后的备用方案
      try {
        print('使用最后的备用文件选择方案');
        final result = await _lastResortWebFilePicker();
        
        if (result != null && result.files.isNotEmpty) {
          for (PlatformFile file in result.files) {
            try {
              final song = await _createSongFromWebFile(file);
              songs.add(song);
            } catch (e) {
              print('处理备用文件失败: ${file.name}, 错误: $e');
            }
          }
        }
      } catch (e) {
        print('所有文件选择方案都失败: $e');
      }
      
      if (songs.isEmpty) {
        print('Web环境：未能选择任何文件');
        return [];
      }
      
      print('Web环境：最终成功选择 ${songs.length} 个音频文件');
      return songs;
      
    } catch (e) {
      print('Web环境文件选择完全失败: $e');
      // 不抛出异常，返回空列表
      return [];
    }
  }
  
  /// 最后的备用文件选择器
  static Future<FilePickerResult?> _lastResortWebFilePicker() async {
    try {
      print('使用最后的备用文件选择方案');
      
      // 等待更长时间确保完全初始化
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 使用最基础的文件选择方式
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: false,
        withReadStream: false,
      );
      
      if (result != null) {
        // 过滤出音频文件
        final audioFiles = result.files.where((file) {
          final extension = file.extension?.toLowerCase();
          return extension != null && _supportedExtensions.contains('.$extension');
        }).toList();
        
        if (audioFiles.isNotEmpty) {
          return FilePickerResult(audioFiles);
        }
      }
      
      return null;
    } catch (e) {
      print('最后的备用文件选择器也失败: $e');
      return null;
    }
  }

  /// 递归扫描目录
  static Future<List<LocalSong>> _scanDirectory(Directory directory) async {
    List<LocalSong> songs = [];
    
    try {
      await for (FileSystemEntity entity in directory.list(recursive: false, followLinks: false)) {
        // 跳过受限制的目录
        if (entity is Directory && _isRestrictedDirectory(entity.path)) {
          continue;
        }
        
        if (entity is File) {
          final fileExtension = path.extension(entity.path).toLowerCase();
          
          // 检查是否为支持的音频文件
          if (_supportedExtensions.contains(fileExtension)) {
            try {
              final song = await _createSongFromFile(entity);
              songs.add(song);
            } catch (e) {
              // 忽略无法处理的文件
              print('无法处理文件: ${entity.path}, 错误: $e');
            }
          }
        } else if (entity is Directory) {
          // 递归扫描子目录
          try {
            final subSongs = await _scanDirectory(entity);
            songs.addAll(subSongs);
          } catch (e) {
            print('扫描子目录失败: ${entity.path}, 错误: $e');
          }
        }
      }
    } catch (e) {
      print('扫描目录时出错: ${directory.path}, 错误: $e');
    }
    
    return songs;
  }
  
  /// 检查是否为受限制的目录
  static bool _isRestrictedDirectory(String path) {
    final restrictedPaths = [
      '/storage/emulated/0/Android',
      '/storage/emulated/0/android',
      '/storage/emulated/0/.android_secure',
      // 添加其他可能受限的系统目录
    ];
    
    for (final restrictedPath in restrictedPaths) {
      if (path.startsWith(restrictedPath)) {
        return true;
      }
    }
    
    return false;
  }

  /// 从文件创建LocalSong对象
  static Future<LocalSong> _createSongFromFile(File file) async {
    late final FileStat stat;
    
    try {
      stat = await file.stat();
    } catch (e) {
      print('获取文件状态失败: ${file.path}, 错误: $e');
      // 如果无法获取文件状态，抛出异常让上层处理
      rethrow;
    }
    
    final fileName = file.uri.pathSegments.last;
    
    // 提取文件名作为默认标题（去掉扩展名）
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
    String? lyric;
    
    // 尝试读取音频元数据
    try {
      // 检查文件是否可读
      if (!await file.exists()) {
        throw Exception('文件不存在: ${file.path}');
      }
      
      print('开始读取元数据: ${file.path}');
      
      // 使用 audio_metadata_reader 读取元数据，添加超时保护
      AudioMetadata? metadata;
      await Future.microtask(() {
        metadata = readMetadata(file, getImage: true);
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('读取音频元数据超时: ${file.path}');
        },
      );
      
      if (metadata != null) {
        // 提取基本信息
        if (metadata!.title?.isNotEmpty == true) {
          songTitle = metadata!.title!;
        }
        if (metadata!.artist?.isNotEmpty == true) {
          songArtist = metadata!.artist!;
        }
        if (metadata!.album?.isNotEmpty == true) {
          songAlbum = metadata!.album!;
        }
        
        // 获取时长
        if (metadata!.duration != null) {
          duration = metadata!.duration!;
        }
        
        // 使用专辑封面服务获取封面
        if (!kIsWeb) {
          albumArt = await AlbumArtService.getAlbumArt(
            file,
            hasMetadataImage: metadata!.pictures.isNotEmpty,
            artist: songArtist,
            album: songAlbum,
          );
        } else if (metadata!.pictures.isNotEmpty) {
          albumArt = '${file.path}#metadata';
        }
        
        print('成功读取元数据: ${file.path} - $songTitle by $songArtist (${duration.inSeconds}秒)');
      } else {
        print('元数据为空: ${file.path}');
        // 即使元数据为空，也尝试查找本地封面图片
        if (!kIsWeb) {
          albumArt = await AlbumArtService.getAlbumArt(
            file,
            hasMetadataImage: false,
            artist: songArtist,
            album: songAlbum,
          );
        }
      }
      
    } catch (e) {
      print('audio_metadata_reader读取失败: ${file.path}, 错误: $e');
      
      // 如果元数据读取失败，尝试用AudioPlayer获取时长
      try {
        print('尝试用AudioPlayer获取时长: ${file.path}');
        final player = AudioPlayer();
        await player.setSource(DeviceFileSource(file.path));
        duration = await player.getDuration() ?? Duration.zero;
        await player.dispose();
        print('AudioPlayer获取时长成功: ${file.path} - ${duration.inSeconds}秒');
      } catch (playerError) {
        print('AudioPlayer获取时长也失败: ${file.path}, 错误: $playerError');
      }
      
      // 即使元数据读取完全失败，也尝试查找本地封面图片
      if (!kIsWeb) {
        albumArt = await AlbumArtService.getAlbumArt(
          file,
          hasMetadataImage: false,
          artist: songArtist,
          album: songAlbum,
        );
      }
    }
    
    // 尝试读取歌词文件
    try {
      lyric = await _readLyricsFile(file.path);
      if (lyric != null && lyric.isNotEmpty) {
        print('成功读取歌词: ${file.path}');
      }
    } catch (e) {
      print('读取歌词文件失败: ${file.path}, 错误: $e');
    }
    
    return LocalSong(
      id: file.path,
      title: songTitle,
      artist: songArtist,
      album: songAlbum,
      albumArt: albumArt,
      filePath: file.path,
      duration: duration,
      lastModified: stat.modified,
      fileSize: stat.size,
      lyric: lyric,
    );
  }
  
  /// 从Web文件创建LocalSong对象
  static Future<LocalSong> _createSongFromWebFile(PlatformFile file) async {
    final fileName = file.name;
    
    // 提取文件名作为默认标题（去掉扩展名）
    String title = fileName;
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex > 0) {
      title = fileName.substring(0, lastDotIndex);
    }
    
    // Web环境下的基本信息
    String songTitle = title;
    String songArtist = '未知艺人';
    String songAlbum = '未知专辑';
    Duration duration = Duration.zero;
    String? albumArt;
    
    // 尝试从文件名解析艺人和歌曲信息
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      if (parts.length >= 2) {
        songArtist = parts[0].trim();
        songTitle = parts.sublist(1).join(' - ').trim();
      }
    }
    
    print('Web文件处理: $fileName -> $songTitle by $songArtist');
    
    // 在Web环境中，我们使用文件名作为唯一ID
    final fileSize = file.size;
    final fileId = 'web_${fileName}_$fileSize';
    
    return LocalSong(
      id: fileId,
      title: songTitle,
      artist: songArtist,
      album: songAlbum,
      albumArt: albumArt,
      filePath: fileName, // Web环境下使用文件名作为路径
      duration: duration,
      lastModified: DateTime.now(), // Web环境下使用当前时间
      fileSize: fileSize,
    );
  }
  
  /// 智能合并重复歌曲
  /// 合并策略：同名且时长相同的歌曲进行合并
  /// 优先保留有封面和歌词的版本
  static Future<MergeResult> _mergeDuplicateSongs(List<LocalSong> songs) async {
    if (songs.isEmpty) {
      return MergeResult(songs, songs.length, 0);
    }
    
    final originalCount = songs.length;
    print('开始智能合并重复歌曲，原始数量: $originalCount');
    
    // 按标题和时长分组
    Map<String, List<LocalSong>> groups = {};
    
    for (final song in songs) {
      // 创建合并键：标题 + 时长（秒）+ 艺术家（可选）
      final normalizedTitle = song.title.toLowerCase().trim();
      final normalizedArtist = song.artist.toLowerCase().trim();
      
      // 如果艺术家不是"未知艺人"，则包含在合并键中以提高准确性
      String mergeKey;
      if (normalizedArtist != '未知艺人' && normalizedArtist.isNotEmpty) {
        mergeKey = '${normalizedTitle}_${normalizedArtist}_${song.duration.inSeconds}';
      } else {
        mergeKey = '${normalizedTitle}_${song.duration.inSeconds}';
      }
      
      if (!groups.containsKey(mergeKey)) {
        groups[mergeKey] = [];
      }
      groups[mergeKey]!.add(song);
    }
    
    List<LocalSong> mergedSongs = [];
    int duplicatesRemoved = 0;
    
    for (final entry in groups.entries) {
      final group = entry.value;
      
      if (group.length == 1) {
        // 没有重复，直接添加
        mergedSongs.add(group.first);
      } else {
        // 有重复，需要合并
        duplicatesRemoved += group.length - 1;
        print('发现重复歌曲组: ${group.first.title} (${group.length} 个版本)');
        
        final bestSong = await _selectBestSong(group);
        mergedSongs.add(bestSong);
        
        print('选择最佳版本: ${bestSong.filePath}');
      }
    }
    
    print('合并完成，最终数量: ${mergedSongs.length}，合并了 $duplicatesRemoved 首重复歌曲');
    return MergeResult(mergedSongs, originalCount, duplicatesRemoved);
  }
  
  /// 从重复歌曲组中选择最佳版本
  /// 优先级：有封面和歌词 > 有封面 > 有歌词 > 文件质量最高
  static Future<LocalSong> _selectBestSong(List<LocalSong> duplicates) async {
    if (duplicates.length == 1) return duplicates.first;
    
    // 为每首歌曲计算评分
    List<SongScore> scores = [];
    
    for (final song in duplicates) {
      final score = await _calculateSongScore(song);
      scores.add(SongScore(song, score));
    }
    
    // 按评分排序，选择最高分的
    scores.sort((a, b) => b.score.compareTo(a.score));
    
    final bestSong = scores.first.song;
    print('  最佳版本评分: ${scores.first.score} - ${bestSong.filePath}');
    
    return bestSong;
  }
  
  /// 计算歌曲评分
  /// 评分标准：
  /// - 有专辑封面: +100分
  /// - 有歌词文件: +80分
  /// - 文件大小: 每MB +1分
  /// - 音频格式质量: FLAC(+50) > WAV(+40) > M4A(+30) > MP3(+20) > AAC(+15) > OGG(+10)
  static Future<int> _calculateSongScore(LocalSong song) async {
    int score = 0;
    
    try {
      // 1. 专辑封面评分
      if (song.albumArt != null && song.albumArt!.isNotEmpty) {
        if (song.albumArt!.endsWith('#metadata')) {
          score += 100; // 内嵌封面
        } else {
          // 检查外部封面文件是否存在
          final coverFile = File(song.albumArt!);
          if (await coverFile.exists()) {
            score += 100;
          }
        }
      }
      
      // 2. 歌词文件评分
      final hasLyrics = await _hasLyricsFile(song.filePath);
      if (hasLyrics) {
        score += 80;
      }
      
      // 3. 文件大小评分（每MB +1分，最多50分）
      final fileSizeMB = song.fileSize / (1024 * 1024);
      score += (fileSizeMB.round()).clamp(0, 50);
      
      // 4. 音频格式质量评分
      final extension = path.extension(song.filePath).toLowerCase();
      switch (extension) {
        case '.flac':
          score += 50;
          break;
        case '.wav':
          score += 40;
          break;
        case '.m4a':
          score += 30;
          break;
        case '.mp3':
          score += 20;
          break;
        case '.aac':
          score += 15;
          break;
        case '.ogg':
          score += 10;
          break;
      }
      
      // 5. 元数据完整性评分
      if (song.artist != '未知艺人') score += 10;
      if (song.album != '未知专辑') score += 10;
      if (song.duration.inSeconds > 0) score += 5;
      
    } catch (e) {
      print('计算歌曲评分失败: ${song.filePath}, 错误: $e');
    }
    
    return score;
  }
  
  /// 检查是否有对应的歌词文件
  static Future<bool> _hasLyricsFile(String audioFilePath) async {
    try {
      final audioFile = File(audioFilePath);
      final audioDir = audioFile.parent;
      final audioBaseName = path.basenameWithoutExtension(audioFilePath);
      
      // 检查同名歌词文件
      for (final ext in _lyricsExtensions) {
        final lyricsFile = File(path.join(audioDir.path, '$audioBaseName$ext'));
        if (await lyricsFile.exists()) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('检查歌词文件失败: $audioFilePath, 错误: $e');
      return false;
    }
  }
  
  /// 读取歌词文件内容
  static Future<String?> _readLyricsFile(String audioFilePath) async {
    try {
      final audioFile = File(audioFilePath);
      final audioDir = audioFile.parent;
      final audioBaseName = path.basenameWithoutExtension(audioFilePath);
      
      // 按优先级查找歌词文件：.lrc > .txt > .srt
      for (final ext in _lyricsExtensions) {
        final lyricsFile = File(path.join(audioDir.path, '$audioBaseName$ext'));
        if (await lyricsFile.exists()) {
          try {
            // 读取文件内容
            final content = await lyricsFile.readAsString();
            
            if (content.trim().isNotEmpty) {
              print('读取歌词文件成功: ${lyricsFile.path} (${content.length} 字符)');
              return content;
            }
          } catch (e) {
            print('读取歌词文件内容失败: ${lyricsFile.path}, 错误: $e');
            // 继续尝试下一个扩展名
            continue;
          }
        }
      }
      
      return null;
    } catch (e) {
      print('读取歌词文件失败: $audioFilePath, 错误: $e');
      return null;
    }
  }
}

/// 歌曲评分辅助类
class SongScore {
  final LocalSong song;
  final int score;
  
  SongScore(this.song, this.score);
}

/// 合并结果类
class MergeResult {
  final List<LocalSong> songs;
  final int originalCount;
  final int duplicatesRemoved;
  
  MergeResult(this.songs, this.originalCount, this.duplicatesRemoved);
}