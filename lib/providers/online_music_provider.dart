import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../models/online_song.dart';
import '../models/local_song.dart';
import '../services/music_api_manager.dart';
import '../services/hive_local_song_storage.dart';
import '../services/playlist_storage.dart';
import '../services/library_refresh_notifier.dart';
import '../services/connectivity_service.dart';
import '../utils/logger.dart';
import '../config/constants.dart';

/// 下载的歌曲信息
class DownloadedSongInfo {
  /// 音频文件路径
  final String audioPath;
  
  /// 封面图片路径（可选）
  final String? coverPath;
  
  /// 歌词文件路径（可选）
  final String? lyricPath;
  
  /// 下载时间
  final DateTime downloadTime;

  DownloadedSongInfo({
    required this.audioPath,
    this.coverPath,
    this.lyricPath,
    DateTime? downloadTime,
  }) : downloadTime = downloadTime ?? DateTime.now();
}

/// 在线音乐状态管理 Provider
class OnlineMusicProvider with ChangeNotifier {
  final MusicApiManager _apiManager = MusicApiManager();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  // 构造函数中自动初始化网络监听
  OnlineMusicProvider() {
    _initializeConnectivity();
  }
  
  // 搜索结果
  List<OnlineSong> _searchResults = [];
  List<OnlineSong> get searchResults => _searchResults;
  
  // 搜索状态
  bool _isSearching = false;
  bool get isSearching => _isSearching;
  
  // 错误信息
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  // 下载任务管理
  final Map<String, double> _downloadProgress = {}; // songId -> progress (0.0 - 1.0)
  final Map<String, DownloadedSongInfo> _downloadedSongs = {}; // songId -> 下载信息
  
  // 节流相关
  final Map<String, DateTime> _lastNotifyTime = {}; // songId -> 最后通知时间
  static const _notifyInterval = Duration(milliseconds: 100); // 通知间隔
  
  // 文件存在性缓存
  final Map<String, bool> _fileExistenceCache = {}; // songId -> 文件是否存在
  DateTime? _lastCacheValidation; // 最后一次缓存验证时间
  static const _cacheValidDuration = Duration(seconds: 30); // 缓存有效期
  
  Map<String, double> get downloadProgress => _downloadProgress;
  Map<String, DownloadedSongInfo> get downloadedSongs => _downloadedSongs;

  /// 初始化网络连接监听
  Future<void> _initializeConnectivity() async {
    try {
      await _connectivityService.initialize();
      Logger.info('网络连接监听已初始化', tag: 'OnlineMusic');
    } catch (e) {
      Logger.error('网络连接监听初始化失败', error: e, tag: 'OnlineMusic');
      // 不抛出异常，继续运行（使用默认的"有网络"假设）
    }
  }

  /// 初始化：从 Hive 加载已下载的歌曲记录
  Future<void> loadDownloadedSongs() async {
    try {
      Logger.info('开始加载已下载的歌曲记录...', tag: 'OnlineMusic');
      final localSongs = await LocalSongStorage.getSongs();
      
      int loadedCount = 0;
      for (final localSong in localSongs) {
        // 只处理从在线下载的歌曲（有 onlineId）
        if (localSong.onlineId != null && localSong.onlineId!.isNotEmpty) {
          // 验证文件是否真实存在
          final audioFile = File(localSong.filePath);
          if (await audioFile.exists()) {
            _downloadedSongs[localSong.onlineId!] = DownloadedSongInfo(
              audioPath: localSong.filePath,
              coverPath: localSong.albumArt,
              lyricPath: null, // 歌词已经存储在 LocalSong.lyric 中
            );
            loadedCount++;
          } else {
            Logger.warn('文件不存在，跳过: ${localSong.filePath}', tag: 'OnlineMusic');
          }
        }
      }
      
      Logger.info('已加载 $loadedCount 条下载记录', tag: 'OnlineMusic');
      notifyListeners();
    } catch (e) {
      Logger.error('加载下载记录失败', error: e, tag: 'OnlineMusic');
    }
  }

  /// 搜索歌曲
  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) {
      _searchResults = [];
      _errorMessage = null;
      notifyListeners();
      return;
    }

    // 检查网络连接
    if (!_connectivityService.isOnline) {
      _errorMessage = '无网络连接，请检查网络设置';
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      Logger.warn('无网络连接，无法搜索', tag: 'OnlineMusic');
      return;
    }

    _isSearching = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _apiManager.search(keyword, limit: 50);
      _searchResults = results;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = '搜索失败: ${e.toString()}';
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// 清空搜索结果
  void clearSearch() {
    _searchResults = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// 节流更新下载进度（避免频繁触发 UI 重建）
  void _updateDownloadProgress(String songId, double progress) {
    _downloadProgress[songId] = progress;
    
    // 检查是否需要通知
    final lastTime = _lastNotifyTime[songId];
    final now = DateTime.now();
    
    if (lastTime == null || now.difference(lastTime) >= _notifyInterval) {
      _lastNotifyTime[songId] = now;
      notifyListeners();
    }
  }
  
  /// 强制更新下载进度（用于下载开始和完成时）
  void _forceUpdateProgress(String songId, double progress) {
    _downloadProgress[songId] = progress;
    _lastNotifyTime[songId] = DateTime.now();
    notifyListeners();
  }

  /// 获取歌曲详细信息（包括播放链接）
  Future<OnlineSong?> getMusicInfo(OnlineSong song) async {
    try {
      final detailedSong = await _apiManager.getMusicInfo(song);
      return detailedSong;
    } catch (e) {
      _errorMessage = '获取歌曲信息失败: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  /// 获取播放链接
  Future<String?> getSongUrl(OnlineSong song) async {
    try {
      final url = await _apiManager.getSongUrl(song);
      return url;
    } catch (e) {
      _errorMessage = '获取播放链接失败: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  /// 下载歌曲（包含音频、封面和歌词）
  Future<bool> downloadSong(OnlineSong song) async {
    try {
      Logger.info('========== 开始下载歌曲 ==========', tag: 'Download');
      Logger.info('歌曲: ${song.title} - ${song.artist}', tag: 'Download');
      
      // 获取下载目录
      final directory = await getApplicationDocumentsDirectory();
      final downloadBaseDir = Directory('${directory.path}/Music');
      
      if (!await downloadBaseDir.exists()) {
        await downloadBaseDir.create(recursive: true);
      }

      // 为每首歌创建独立的文件夹（使用预编译的正则表达式）
      final safeTitle = song.title.replaceAll(Constants.illegalFileNameChars, '_');
      final safeArtist = song.artist.replaceAll(Constants.illegalFileNameChars, '_');
      final songFolderName = '${safeTitle}_$safeArtist';
      final songDir = Directory('${downloadBaseDir.path}/$songFolderName');
      
      if (!await songDir.exists()) {
        await songDir.create(recursive: true);
      }
      
      Logger.debug('下载目录: ${songDir.path}', tag: 'Download');

      // 检查是否已下载
      if (_downloadedSongs.containsKey(song.id)) {
        final existingInfo = _downloadedSongs[song.id];
        if (existingInfo != null && await File(existingInfo.audioPath).exists()) {
          Logger.info('歌曲已下载，跳过', tag: 'Download');
          return true; // 已下载
        }
      }

      // 初始化下载进度
      _forceUpdateProgress(song.id, 0.0);

      // 获取歌曲完整信息（包含封面和歌词）
      Logger.info('步骤1: 获取歌曲详细信息...', tag: 'Download');
      final detailedSong = await _apiManager.getMusicInfo(song);
      
      // 定义文件路径
      final audioPath = '${songDir.path}/$safeTitle.mp3';
      String? coverPath;
      String? lyricPath;

      // 下载音频文件（主要进度）
      Logger.info('步骤2: 开始下载音频文件...', tag: 'Download');
      await _apiManager.downloadSong(
        detailedSong,
        audioPath,
        onProgress: (received, total) {
          if (total > 0) {
            // 音频下载占总进度的 80%，使用节流更新避免频繁触发 UI 重建
            _updateDownloadProgress(song.id, (received / total) * 0.8);
          }
        },
      );
      Logger.info('音频下载完成: $audioPath', tag: 'Download');

      // 下载封面图片（如果有）
      if (detailedSong.albumArt != null && detailedSong.albumArt!.isNotEmpty) {
        Logger.info('步骤3: 开始下载封面图片...', tag: 'Download');
        _forceUpdateProgress(song.id, 0.85);
        
        final coverExtension = _getImageExtension(detailedSong.albumArt!);
        coverPath = '${songDir.path}/cover$coverExtension';
        
        final downloadedCover = await _apiManager.downloadCover(
          detailedSong.albumArt!,
          coverPath,
          detailedSong.source, // 传入来源平台
        );
        
        if (downloadedCover != null) {
          Logger.info('封面下载完成: $coverPath', tag: 'Download');
        } else {
          Logger.warn('封面下载失败', tag: 'Download');
          coverPath = null;
        }
      } else {
        Logger.debug('没有封面信息', tag: 'Download');
      }

      // 保存歌词文件（如果有）
      if (detailedSong.lyric != null && detailedSong.lyric!.isNotEmpty) {
        Logger.info('步骤4: 开始保存歌词文件...', tag: 'Download');
        _forceUpdateProgress(song.id, 0.95);
        
        lyricPath = '${songDir.path}/$safeTitle.lrc';
        
        final savedLyric = await _apiManager.saveLyric(
          detailedSong.lyric!,
          lyricPath,
          detailedSong.source, // 传入来源平台
        );
        
        if (savedLyric != null) {
          Logger.info('歌词保存完成: $lyricPath', tag: 'Download');
        } else {
          Logger.warn('歌词保存失败', tag: 'Download');
          lyricPath = null;
        }
      } else {
        Logger.debug('没有歌词信息', tag: 'Download');
      }

      // 保存下载信息
      _downloadedSongs[song.id] = DownloadedSongInfo(
        audioPath: audioPath,
        coverPath: coverPath,
        lyricPath: lyricPath,
      );
      
      // 使缓存失效，确保下次检查时重新验证
      _invalidateCache(song.id);
      
      // 下载完成
      _downloadProgress.remove(song.id);
      _lastNotifyTime.remove(song.id);  // 清理节流记录
      notifyListeners();

      Logger.info('========== 下载完成 ==========', tag: 'Download');
      Logger.info('音频: $audioPath', tag: 'Download');
      Logger.info('封面: ${coverPath ?? "无"}', tag: 'Download');
      Logger.info('歌词: ${lyricPath ?? "无"}', tag: 'Download');
      
      // 5️⃣ 保存到本地歌曲数据库（Hive）
      Logger.info('步骤5: 保存到本地歌曲数据库...', tag: 'Download');
      await _saveToLocalDatabase(
        song: detailedSong,
        audioPath: audioPath,
        coverPath: coverPath,
        lyricPath: lyricPath,
      );
      
      return true;
    } catch (e) {
      _errorMessage = '下载失败: ${e.toString()}';
      _downloadProgress.remove(song.id);
      notifyListeners();
      Logger.error('下载失败', error: e, tag: 'Download');
      return false;
    }
  }

  /// 根据 URL 获取图片扩展名
  String _getImageExtension(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('.png')) return '.png';
    if (lowerUrl.contains('.jpg') || lowerUrl.contains('.jpeg')) return '.jpg';
    if (lowerUrl.contains('.webp')) return '.webp';
    if (lowerUrl.contains('.gif')) return '.gif';
    return '.jpg'; // 默认使用 jpg
  }

  /// 保存到本地歌曲数据库（Hive）
  Future<void> _saveToLocalDatabase({
    required OnlineSong song,
    required String audioPath,
    String? coverPath,
    String? lyricPath,
  }) async {
    try {
      // 读取音频文件的元数据
      final audioFile = File(audioPath);
      final stat = await audioFile.stat();
      
      // 读取歌词内容（如果有）
      String? lyricContent;
      if (lyricPath != null) {
        try {
          final lyricFile = File(lyricPath);
          if (await lyricFile.exists()) {
            lyricContent = await lyricFile.readAsString();
            Logger.debug('读取歌词文件成功: ${lyricContent.length} 字符', tag: 'Download');
          }
        } catch (e) {
          Logger.warn('读取歌词文件失败', error: e, tag: 'Download');
        }
      }
      
      // 读取音频文件的实际时长
      Duration actualDuration = song.duration ?? Duration.zero;
      try {
        Logger.debug('正在读取音频文件时长...', tag: 'Download');
        final metadata = readMetadata(audioFile, getImage: false);
        if (metadata.duration != null) {
          actualDuration = metadata.duration!;
          Logger.info('成功读取音频时长: ${actualDuration.inSeconds} 秒', tag: 'Download');
        } else {
          Logger.warn('未能从元数据读取时长，使用默认值', tag: 'Download');
        }
      } catch (e) {
        Logger.warn('读取音频时长失败，使用默认值', error: e, tag: 'Download');
      }
      
      // 创建 LocalSong 对象
      final localSong = LocalSong(
        id: audioPath, // 使用文件路径作为唯一ID
        title: song.title,
        artist: song.artist,
        album: song.album,
        albumArt: coverPath, // 封面图片路径
        filePath: audioPath,
        duration: actualDuration, // 使用从文件读取的实际时长
        lastModified: stat.modified,
        fileSize: stat.size,
        lyric: lyricContent, // 歌词内容
        onlineId: song.id, // 记录在线歌曲ID
        source: song.source, // 记录来源平台
      );
      
      // 保存到 Hive
      await LocalSongStorage.addSong(localSong);
      
      Logger.info('已保存到本地歌曲数据库', tag: 'Download');
      Logger.info('  - 标题: ${localSong.title}', tag: 'Download');
      Logger.info('  - 艺术家: ${localSong.artist}', tag: 'Download');
      Logger.info('  - 时长: ${localSong.duration.inMinutes}:${(localSong.duration.inSeconds % 60).toString().padLeft(2, '0')}', tag: 'Download');
      Logger.info('  - 文件大小: ${(localSong.fileSize / 1024 / 1024).toStringAsFixed(2)} MB', tag: 'Download');
      Logger.info('  - 封面: ${coverPath != null ? "有" : "无"}', tag: 'Download');
      Logger.info('  - 歌词: ${lyricContent != null ? "有" : "无"}', tag: 'Download');
      
      // 通知音乐库页面刷新
      LibraryRefreshNotifier().notifyLibraryChanged();
    } catch (e) {
      Logger.error('保存到本地数据库失败', error: e, tag: 'Download');
      // 不抛出异常，避免影响下载流程
    }
  }

  /// 检查歌曲是否已下载（完全避免同步 I/O）
  /// 
  /// 🎯 优化策略：
  /// 1. 优先从缓存读取（最快，<0.1ms）
  /// 2. 缓存失效时，触发后台异步验证（不阻塞UI）
  /// 3. 返回上次缓存的值（乐观假设）
  bool isDownloaded(String songId) {
    if (!_downloadedSongs.containsKey(songId)) {
      return false;
    }
    
    // ✅ 优先从缓存读取
    if (_fileExistenceCache.containsKey(songId)) {
      final now = DateTime.now();
      if (_lastCacheValidation != null && 
          now.difference(_lastCacheValidation!) < _cacheValidDuration) {
        // 缓存有效，直接返回
        return _fileExistenceCache[songId]!;
      }
    }
    
    // ✅ 缓存失效，触发后台异步验证（不阻塞UI）
    _validateSingleDownloadAsync(songId);
    
    // ✅ 返回上次缓存的值（乐观假设文件仍存在）
    // 如果文件被删除，后台验证会更新缓存，下次调用就会返回false
    return _fileExistenceCache[songId] ?? true;
  }
  
  /// 后台异步验证单个下载文件（不阻塞主线程）
  void _validateSingleDownloadAsync(String songId) {
    final info = _downloadedSongs[songId];
    if (info == null) return;
    
    // 🎯 异步检查文件存在性（不阻塞主线程）
    File(info.audioPath).exists().then((exists) {
      // 更新缓存
      _fileExistenceCache[songId] = exists;
      _lastCacheValidation = DateTime.now();
      
      // 如果文件不存在，清理记录
      if (!exists) {
        _downloadedSongs.remove(songId);
        _fileExistenceCache.remove(songId);
        notifyListeners();
        Logger.warn('检测到下载文件已被删除，清理记录: $songId', tag: 'OnlineMusic');
      }
    }).catchError((e) {
      Logger.error('验证下载文件失败: $songId', error: e, tag: 'OnlineMusic');
    });
  }
  
  /// 主动使缓存失效（在下载或删除后调用）
  void _invalidateCache([String? songId]) {
    if (songId != null) {
      _fileExistenceCache.remove(songId);
    } else {
      _fileExistenceCache.clear();
      _lastCacheValidation = null;
    }
  }
  
  /// 后台验证所有下载文件（异步并发，不阻塞 UI）
  Future<void> validateAllDownloads() async {
    try {
      if (_downloadedSongs.isEmpty) {
        Logger.info('没有需要验证的下载文件', tag: 'OnlineMusic');
        return;
      }
      
      Logger.info('开始验证 ${_downloadedSongs.length} 个下载文件...', tag: 'OnlineMusic');
      
      // 并发检查所有文件存在性
      final checkFutures = _downloadedSongs.entries.map((entry) async {
        final exists = await File(entry.value.audioPath).exists();
        return MapEntry(entry.key, exists);
      });
      
      final results = await Future.wait(checkFutures);
      
      // 更新缓存并收集无效 ID
      final invalidIds = <String>[];
      for (final result in results) {
        _fileExistenceCache[result.key] = result.value;
        if (!result.value) {
          invalidIds.add(result.key);
        }
      }
      
      // 清理无效记录
      if (invalidIds.isNotEmpty) {
        for (final id in invalidIds) {
          _downloadedSongs.remove(id);
          _fileExistenceCache.remove(id);
        }
        _lastCacheValidation = DateTime.now();
        notifyListeners();
        Logger.warn('清理了 ${invalidIds.length} 个无效下载记录', tag: 'OnlineMusic');
      } else {
        _lastCacheValidation = DateTime.now();
        Logger.info('所有 ${_downloadedSongs.length} 个下载文件验证通过', tag: 'OnlineMusic');
      }
    } catch (e) {
      Logger.error('验证下载文件失败', error: e, tag: 'OnlineMusic');
    }
  }

  /// 检查歌曲是否正在下载
  bool isDownloading(String songId) {
    return _downloadProgress.containsKey(songId);
  }

  /// 获取下载进度
  double getDownloadProgress(String songId) {
    return _downloadProgress[songId] ?? 0.0;
  }

  /// 删除已下载的歌曲（包括音频、封面、歌词和数据库记录）
  Future<bool> deleteDownloadedSong(String songId) async {
    try {
      final info = _downloadedSongs[songId];
      if (info != null) {
        Logger.info('========== 开始删除下载的歌曲 ==========', tag: 'Delete');
        
        // 删除音频文件
        final audioFile = File(info.audioPath);
        if (await audioFile.exists()) {
          await audioFile.delete();
          Logger.info('已删除音频: ${info.audioPath}', tag: 'Delete');
        }
        
        // 删除封面文件
        if (info.coverPath != null) {
          final coverFile = File(info.coverPath!);
          if (await coverFile.exists()) {
            await coverFile.delete();
            Logger.info('已删除封面: ${info.coverPath}', tag: 'Delete');
          }
        }
        
        // 删除歌词文件
        if (info.lyricPath != null) {
          final lyricFile = File(info.lyricPath!);
          if (await lyricFile.exists()) {
            await lyricFile.delete();
            Logger.info('已删除歌词: ${info.lyricPath}', tag: 'Delete');
          }
        }
        
        // 从 Hive 本地数据库删除
        try {
          // 使用音频文件路径作为 ID（与保存时一致）
          await LocalSongStorage.removeSong(info.audioPath);
          Logger.info('已从本地数据库删除', tag: 'Delete');
        } catch (e) {
          Logger.warn('从数据库删除失败', error: e, tag: 'Delete');
        }
        
        // 从所有歌单中移除此歌曲
        try {
          final removedCount = await PlaylistStorage.removeSongFromAllPlaylists(info.audioPath);
          if (removedCount > 0) {
            Logger.info('已从 $removedCount 个歌单中移除', tag: 'Delete');
          }
        } catch (e) {
          Logger.warn('从歌单移除失败', error: e, tag: 'Delete');
        }
        
        // 删除歌曲文件夹（如果为空）
        final audioDir = audioFile.parent;
        if (await audioDir.exists()) {
          final files = await audioDir.list().toList();
          if (files.isEmpty) {
            await audioDir.delete();
            Logger.info('已删除空文件夹: ${audioDir.path}', tag: 'Delete');
          }
        }
        
        _downloadedSongs.remove(songId);
        _invalidateCache(songId);  // 使缓存失效
        notifyListeners();
        
        // 通知音乐库刷新
        LibraryRefreshNotifier().notifyLibraryChanged();
        Logger.info('已通知音乐库刷新', tag: 'Delete');

        Logger.info('========== 删除完成 ==========', tag: 'Delete');
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = '删除失败: ${e.toString()}';
      notifyListeners();
      Logger.error('删除失败', error: e, tag: 'Delete');
      return false;
    }
  }

  /// 获取已下载歌曲的音频路径
  String? getDownloadedPath(String songId) {
    return _downloadedSongs[songId]?.audioPath;
  }

  /// 获取已下载歌曲的完整信息
  DownloadedSongInfo? getDownloadedInfo(String songId) {
    return _downloadedSongs[songId];
  }

  /// 根据文件路径清理下载记录（用于外部删除文件时同步状态）
  void cleanupDownloadRecordByPath(String audioPath) {
    // 查找对应的 songId
    String? targetSongId;
    for (final entry in _downloadedSongs.entries) {
      if (entry.value.audioPath == audioPath) {
        targetSongId = entry.key;
        break;
      }
    }
    
    if (targetSongId != null) {
      _downloadedSongs.remove(targetSongId);
      notifyListeners();
      Logger.info('已清理下载记录: $targetSongId (文件: $audioPath)', tag: 'OnlineMusic');
    }
  }

  /// 清理所有无效的下载记录（文件已不存在）
  Future<void> cleanupInvalidRecords() async {
    final invalidSongIds = <String>[];
    
    for (final entry in _downloadedSongs.entries) {
      final audioFile = File(entry.value.audioPath);
      if (!await audioFile.exists()) {
        invalidSongIds.add(entry.key);
      }
    }
    
    if (invalidSongIds.isNotEmpty) {
      for (final songId in invalidSongIds) {
        _downloadedSongs.remove(songId);
      }
      notifyListeners();
      Logger.info('已清理 ${invalidSongIds.length} 条无效下载记录', tag: 'OnlineMusic');
    }
  }
}

