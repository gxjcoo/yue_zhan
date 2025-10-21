import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../models/online_song.dart';
import '../models/local_song.dart';
import '../services/music_api_manager.dart';
import '../services/hive_local_song_storage.dart';
import '../services/library_refresh_notifier.dart';
import '../services/download_queue_manager.dart';
import '../core/result.dart';
import '../config/constants.dart';
import '../utils/logger.dart';

/// 下载的歌曲信息
class DownloadedSongInfo {
  final String audioPath;
  final String? coverPath;
  final String? lyricPath;
  final DateTime downloadTime;

  DownloadedSongInfo({
    required this.audioPath,
    this.coverPath,
    this.lyricPath,
    DateTime? downloadTime,
  }) : downloadTime = downloadTime ?? DateTime.now();
}

/// 在线音乐下载 Provider
/// 
/// 职责：
/// - 管理下载任务
/// - 追踪下载进度
/// - 管理已下载歌曲
/// - 文件存在性验证
class DownloadProvider with ChangeNotifier {
  final MusicApiManager _apiManager = MusicApiManager();
  final DownloadQueueManager _queueManager = DownloadQueueManager();
  
  // 下载任务管理
  final Map<String, double> _downloadProgress = {};
  final Map<String, DownloadedSongInfo> _downloadedSongs = {};
  
  // 节流相关
  final Map<String, DateTime> _lastNotifyTime = {};
  static const _notifyInterval = Duration(milliseconds: 100);
  
  // 文件存在性缓存
  final Map<String, bool> _fileExistenceCache = {};
  DateTime? _lastCacheValidation;
  static const _cacheValidDuration = Duration(seconds: 30);
  
  Map<String, double> get downloadProgress => _downloadProgress;
  Map<String, DownloadedSongInfo> get downloadedSongs => _downloadedSongs;
  
  // 队列管理器访问
  DownloadQueueManager get queueManager => _queueManager;
  
  /// 初始化：从 Hive 加载已下载的歌曲记录
  Future<Result<int>> loadDownloadedSongs() async {
    try {
      // 确保下载队列管理器已初始化
      await _queueManager.ensureInitialized();
      
      Logger.info('开始加载已下载的歌曲记录...', tag: 'DownloadProvider');
      final localSongs = await LocalSongStorage.getSongs();
      
      int loadedCount = 0;
      for (final localSong in localSongs) {
        if (localSong.onlineId != null && localSong.onlineId!.isNotEmpty) {
          final audioFile = File(localSong.filePath);
          if (await audioFile.exists()) {
            _downloadedSongs[localSong.onlineId!] = DownloadedSongInfo(
              audioPath: localSong.filePath,
              coverPath: localSong.albumArt,
              lyricPath: null,
            );
            loadedCount++;
          }
        }
      }
      
      Logger.info('成功加载 $loadedCount 个已下载歌曲记录', tag: 'DownloadProvider');
      notifyListeners();
      return Result.success(loadedCount);
    } catch (e, stackTrace) {
      Logger.error('加载已下载歌曲失败', error: e, stackTrace: stackTrace, tag: 'DownloadProvider');
      return Result.failure('加载已下载歌曲失败: $e', error: e, stackTrace: stackTrace);
    }
  }
  
  /// 获取歌曲详细信息
  Future<Result<OnlineSong>> getMusicInfo(OnlineSong song) async {
    try {
      final detailedSong = await _apiManager.getMusicInfo(song);
      return Result.success(detailedSong);
    } catch (e, stackTrace) {
      final message = '获取歌曲信息失败: ${e.toString()}';
      Logger.error(message, error: e, stackTrace: stackTrace, tag: 'DownloadProvider');
      return Result.failure(message, error: e, stackTrace: stackTrace);
    }
  }
  
  /// 获取播放链接
  Future<Result<String>> getSongUrl(OnlineSong song) async {
    try {
      final url = await _apiManager.getSongUrl(song);
      if (url == null || url.isEmpty) {
        return Result.failure('播放链接为空');
      }
      return Result.success(url);
    } catch (e, stackTrace) {
      final message = '获取播放链接失败: ${e.toString()}';
      Logger.error(message, error: e, stackTrace: stackTrace, tag: 'DownloadProvider');
      return Result.failure(message, error: e, stackTrace: stackTrace);
    }
  }
  
  /// 下载歌曲（使用队列管理）
  /// 
  /// 将下载任务添加到队列，由队列管理器调度执行
  Future<Result<bool>> downloadSongQueued(OnlineSong song) async {
    try {
      // 检查是否已下载
      if (_downloadedSongs.containsKey(song.id)) {
        final existingInfo = _downloadedSongs[song.id];
        if (existingInfo != null && await File(existingInfo.audioPath).exists()) {
          Logger.info('歌曲已下载，跳过: ${song.title}', tag: 'DownloadProvider');
          return Result.success(true);
        }
      }
      
      // 检查是否已在队列中
      if (_downloadProgress.containsKey(song.id)) {
        Logger.warn('歌曲正在下载中: ${song.title}', tag: 'DownloadProvider');
        return Result.failure('歌曲正在下载中', errorCode: ErrorCodes.duplicateOperation);
      }
      
      // 添加到队列
      final taskId = _queueManager.addTask(
        song: song,
        onStart: (task) async {
          Logger.info('队列开始下载: ${task.song.title}', tag: 'DownloadProvider');
          _forceUpdateProgress(task.song.id, 0.0);
          
          // 执行实际下载
          final result = await downloadSong(task.song);
          
          // 通知队列管理器任务完成
          _queueManager.onTaskCompleted(task.id, result.isSuccess);
        },
        onComplete: (task, success) {
          if (success) {
            Logger.info('队列下载完成: ${task.song.title}', tag: 'DownloadProvider');
          } else {
            Logger.warn('队列下载失败: ${task.song.title}', tag: 'DownloadProvider');
          }
        },
        onError: (task, error) {
          Logger.error('队列下载错误: ${task.song.title}', error: error, tag: 'DownloadProvider');
          _downloadProgress.remove(task.song.id);
          _lastNotifyTime.remove(task.song.id);
          notifyListeners();
        },
      );
      
      Logger.info('下载任务已加入队列: ${song.title} (任务ID: $taskId)', tag: 'DownloadProvider');
      return Result.success(true);
    } catch (e, stackTrace) {
      final message = '添加下载任务失败: ${e.toString()}';
      Logger.error(message, error: e, stackTrace: stackTrace, tag: 'DownloadProvider');
      return Result.failure(message, error: e, stackTrace: stackTrace);
    }
  }
  
  /// 直接下载歌曲（不使用队列）
  /// 
  /// 用于兼容性或特殊场景
  Future<Result<bool>> downloadSong(OnlineSong song) async {
    try {
      // 检查是否已下载
      if (_downloadedSongs.containsKey(song.id)) {
        final existingInfo = _downloadedSongs[song.id];
        if (existingInfo != null && await File(existingInfo.audioPath).exists()) {
          Logger.info('歌曲已下载，跳过: ${song.title}', tag: 'DownloadProvider');
          return Result.success(true);
        }
      }
      
      // 获取下载目录
      final directory = await getApplicationDocumentsDirectory();
      final downloadBaseDir = Directory('${directory.path}/Music');
      if (!await downloadBaseDir.exists()) {
        await downloadBaseDir.create(recursive: true);
      }
      
      // 创建歌曲文件夹
      final safeTitle = song.title.replaceAll(Constants.illegalFileNameChars, '_');
      final safeArtist = song.artist.replaceAll(Constants.illegalFileNameChars, '_');
      final songFolderName = '${safeTitle}_$safeArtist';
      final songDir = Directory('${downloadBaseDir.path}/$songFolderName');
      if (!await songDir.exists()) {
        await songDir.create(recursive: true);
      }
      
      // 初始化进度
      _forceUpdateProgress(song.id, 0.0);
      
      // 获取歌曲详细信息
      Logger.info('获取歌曲详细信息: ${song.title}', tag: 'DownloadProvider');
      final detailedSong = await _apiManager.getMusicInfo(song);
      
      // 下载音频
      final audioPath = '${songDir.path}/$safeTitle.mp3';
      Logger.info('开始下载音频: ${song.title}', tag: 'DownloadProvider');
      await _apiManager.downloadSong(
        detailedSong,
        audioPath,
        onProgress: (received, total) {
          if (total > 0) {
            _updateDownloadProgress(song.id, (received / total) * 0.8);
          }
        },
      );
      
      String? coverPath;
      String? lyricPath;
      
      // 下载封面
      if (detailedSong.albumArt != null && detailedSong.albumArt!.isNotEmpty) {
        _forceUpdateProgress(song.id, 0.85);
        final coverExtension = _getImageExtension(detailedSong.albumArt!);
        coverPath = '${songDir.path}/cover$coverExtension';
        await _apiManager.downloadCover(detailedSong.albumArt!, coverPath, detailedSong.source);
      }
      
      // 保存歌词
      if (detailedSong.lyric != null && detailedSong.lyric!.isNotEmpty) {
        _forceUpdateProgress(song.id, 0.95);
        lyricPath = '${songDir.path}/$safeTitle.lrc';
        await _apiManager.saveLyric(detailedSong.lyric!, lyricPath, detailedSong.source);
      }
      
      // 保存下载信息
      _downloadedSongs[song.id] = DownloadedSongInfo(
        audioPath: audioPath,
        coverPath: coverPath,
        lyricPath: lyricPath,
      );
      _invalidateCache(song.id);
      
      // 完成
      _downloadProgress.remove(song.id);
      _lastNotifyTime.remove(song.id);
      notifyListeners();
      
      // 保存到数据库
      await _saveToDatabase(detailedSong, audioPath, coverPath, lyricPath);
      
      Logger.info('下载完成: ${song.title}', tag: 'DownloadProvider');
      return Result.success(true);
    } catch (e, stackTrace) {
      _downloadProgress.remove(song.id);
      notifyListeners();
      Logger.error('下载失败: ${song.title}', error: e, stackTrace: stackTrace, tag: 'DownloadProvider');
      return Result.failure('下载失败: $e', error: e, stackTrace: stackTrace);
    }
  }
  
  /// 检查歌曲是否已下载
  bool isDownloaded(String songId) {
    if (!_downloadedSongs.containsKey(songId)) {
      return false;
    }
    
    // 检查缓存
    if (_fileExistenceCache.containsKey(songId)) {
      final now = DateTime.now();
      if (_lastCacheValidation != null && 
          now.difference(_lastCacheValidation!) < _cacheValidDuration) {
        return _fileExistenceCache[songId]!;
      }
    }
    
    // 验证文件
    final info = _downloadedSongs[songId];
    if (info != null) {
      final exists = File(info.audioPath).existsSync();
      _fileExistenceCache[songId] = exists;
      _lastCacheValidation = DateTime.now();
      
      if (!exists) {
        _downloadedSongs.remove(songId);
        _fileExistenceCache.remove(songId);
        notifyListeners();
      }
      
      return exists;
    }
    
    return false;
  }
  
  /// 检查是否正在下载
  bool isDownloading(String songId) {
    return _downloadProgress.containsKey(songId);
  }
  
  /// 获取下载进度
  double getDownloadProgress(String songId) {
    return _downloadProgress[songId] ?? 0.0;
  }
  
  /// 检查歌曲是否下载失败
  bool hasDownloadFailed(String songId) {
    return _queueManager.hasFailed(songId);
  }
  
  /// 后台验证所有下载文件
  Future<Result<int>> validateAllDownloads() async {
    try {
      if (_downloadedSongs.isEmpty) {
        return Result.success(0);
      }
      
      Logger.info('开始验证 ${_downloadedSongs.length} 个下载文件...', tag: 'DownloadProvider');
      
      final checkFutures = _downloadedSongs.entries.map((entry) async {
        final exists = await File(entry.value.audioPath).exists();
        return MapEntry(entry.key, exists);
      });
      
      final results = await Future.wait(checkFutures);
      
      final invalidIds = <String>[];
      for (final result in results) {
        _fileExistenceCache[result.key] = result.value;
        if (!result.value) {
          invalidIds.add(result.key);
        }
      }
      
      if (invalidIds.isNotEmpty) {
        for (final id in invalidIds) {
          _downloadedSongs.remove(id);
          _fileExistenceCache.remove(id);
        }
        _lastCacheValidation = DateTime.now();
        notifyListeners();
        Logger.warn('清理了 ${invalidIds.length} 个无效下载记录', tag: 'DownloadProvider');
      } else {
        _lastCacheValidation = DateTime.now();
        Logger.info('所有 ${_downloadedSongs.length} 个下载文件验证通过', tag: 'DownloadProvider');
      }
      
      return Result.success(invalidIds.length);
    } catch (e, stackTrace) {
      Logger.error('验证下载文件失败', error: e, stackTrace: stackTrace, tag: 'DownloadProvider');
      return Result.failure('验证失败: $e', error: e, stackTrace: stackTrace);
    }
  }
  
  /// 节流更新进度
  void _updateDownloadProgress(String songId, double progress) {
    _downloadProgress[songId] = progress;
    
    final lastTime = _lastNotifyTime[songId];
    final now = DateTime.now();
    
    if (lastTime == null || now.difference(lastTime) >= _notifyInterval) {
      _lastNotifyTime[songId] = now;
      notifyListeners();
    }
  }
  
  /// 强制更新进度
  void _forceUpdateProgress(String songId, double progress) {
    _downloadProgress[songId] = progress;
    _lastNotifyTime[songId] = DateTime.now();
    notifyListeners();
  }
  
  /// 使缓存失效
  void _invalidateCache([String? songId]) {
    if (songId != null) {
      _fileExistenceCache.remove(songId);
    } else {
      _fileExistenceCache.clear();
      _lastCacheValidation = null;
    }
  }
  
  /// 获取图片扩展名
  String _getImageExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path.toLowerCase();
      if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return '.jpg';
      if (path.endsWith('.png')) return '.png';
      if (path.endsWith('.webp')) return '.webp';
      if (path.endsWith('.gif')) return '.gif';
    }
    return '.jpg';
  }
  
  /// 保存到数据库
  Future<void> _saveToDatabase(
    OnlineSong song,
    String audioPath,
    String? coverPath,
    String? lyricPath,
  ) async {
    try {
      final audioFile = File(audioPath);
      final metadata = readMetadata(audioFile, getImage: false);
      
      String? lyricContent;
      if (lyricPath != null && lyricPath.isNotEmpty) {
        final lyricFile = File(lyricPath);
        if (await lyricFile.exists()) {
          lyricContent = await lyricFile.readAsString();
        }
      }
      
      final localSong = LocalSong(
        id: audioPath,
        title: metadata.title ?? song.title,
        artist: metadata.artist ?? song.artist,
        album: metadata.album ?? song.album,
        filePath: audioPath,
        duration: metadata.duration ?? Duration.zero,
        fileSize: await audioFile.length(),
        albumArt: coverPath,
        lyric: lyricContent,
        onlineId: song.id,
        lastModified: DateTime.now(),
      );
      
      await LocalSongStorage.addSong(localSong);
      LibraryRefreshNotifier().notifyLibraryChanged();
      
      Logger.info('已保存到本地数据库: ${song.title}', tag: 'DownloadProvider');
    } catch (e, stackTrace) {
      Logger.error('保存到数据库失败', error: e, stackTrace: stackTrace, tag: 'DownloadProvider');
    }
  }
}

