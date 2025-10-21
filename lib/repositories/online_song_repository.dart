import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/online_song.dart';
import '../services/music_api_manager.dart';
import '../utils/network_optimizer.dart';
import '../core/result.dart';
import '../utils/logger.dart';

/// 在线歌曲仓库
/// 
/// 提供统一的在线歌曲数据访问接口，包括：
/// - 搜索歌曲
/// - 获取歌曲详情
/// - 获取播放链接
/// - 获取歌词
/// - 缓存管理
class OnlineSongRepository extends ChangeNotifier {
  // 单例模式
  static final OnlineSongRepository _instance = OnlineSongRepository._internal();
  factory OnlineSongRepository() => _instance;
  OnlineSongRepository._internal();

  final MusicApiManager _apiManager = MusicApiManager();
  
  // 🎯 优化：使用网络优化器
  final NetworkOptimizer _networkOptimizer = NetworkOptimizer();
  final Dio _dio = Dio();
  
  // 搜索结果缓存
  final Map<String, List<OnlineSong>> _searchCache = {};
  final Map<String, DateTime> _searchCacheTimestamps = {};
  static const _searchCacheValidDuration = Duration(minutes: 5);
  
  // 歌曲详情缓存
  final Map<String, OnlineSong> _songDetailsCache = {};
  final Map<String, DateTime> _songDetailsCacheTimestamps = {};
  static const _songDetailsCacheValidDuration = Duration(minutes: 10);
  
  // 播放链接缓存
  final Map<String, String> _playUrlCache = {};
  final Map<String, DateTime> _playUrlCacheTimestamps = {};
  static const _playUrlCacheValidDuration = Duration(minutes: 30);
  
  /// 🎯 优化：搜索歌曲（带请求去重和缓存）
  /// 
  /// [keyword] - 搜索关键字
  /// [limit] - 结果数量限制
  /// [useCache] - 是否使用缓存
  Future<Result<List<OnlineSong>>> searchSongs(
    String keyword, {
    int limit = 30,
    bool useCache = true,
  }) async {
    try {
      // 验证输入
      if (keyword.trim().isEmpty) {
        return Result.failure(
          '搜索关键字不能为空',
          errorCode: ErrorCodes.validationError,
        );
      }
      
      // 检查缓存
      if (useCache && _isSearchCached(keyword)) {
        Logger.debug('使用缓存的搜索结果: $keyword', tag: 'OnlineSongRepository');
        return Result.success(_searchCache[keyword]!);
      }
      
      // 🎯 使用网络优化器执行搜索（自动去重）
      final requestKey = 'search_$keyword\_$limit';
      final results = await _networkOptimizer.execute<List<OnlineSong>>(
        dio: _dio,
        requestKey: requestKey,
        useCache: useCache,
        enableRetry: true,
        requestBuilder: () async {
          Logger.info('搜索歌曲: $keyword', tag: 'OnlineSongRepository');
          return await _apiManager.search(keyword, limit: limit);
        },
      );
      
      // 更新缓存
      _searchCache[keyword] = results;
      _searchCacheTimestamps[keyword] = DateTime.now();
      
      Logger.info('搜索完成: 找到 ${results.length} 首歌曲', tag: 'OnlineSongRepository');
      return Result.success(results);
    } catch (e, stackTrace) {
      final message = '搜索失败: ${e.toString()}';
      Logger.error(message, error: e, stackTrace: stackTrace, tag: 'OnlineSongRepository');
      return Result.failure(message, error: e, stackTrace: stackTrace);
    }
  }
  
  /// 🎯 优化：获取歌曲详细信息（带请求去重和重试）
  /// 
  /// [song] - 歌曲对象
  /// [useCache] - 是否使用缓存
  Future<Result<OnlineSong>> getSongDetails(
    OnlineSong song, {
    bool useCache = true,
  }) async {
    try {
      // 检查缓存
      if (useCache && _isSongDetailsCached(song.id)) {
        Logger.debug('使用缓存的歌曲详情: ${song.title}', tag: 'OnlineSongRepository');
        return Result.success(_songDetailsCache[song.id]!);
      }
      
      // 🎯 使用网络优化器执行请求（自动去重和重试）
      final requestKey = 'song_details_${song.id}';
      final detailedSong = await _networkOptimizer.execute<OnlineSong>(
        dio: _dio,
        requestKey: requestKey,
        useCache: useCache,
        enableRetry: true,
        requestBuilder: () async {
          Logger.info('获取歌曲详情: ${song.title}', tag: 'OnlineSongRepository');
          return await _apiManager.getMusicInfo(song);
        },
      );
      
      // 更新缓存
      _songDetailsCache[song.id] = detailedSong;
      _songDetailsCacheTimestamps[song.id] = DateTime.now();
      
      Logger.info('获取歌曲详情成功: ${song.title}', tag: 'OnlineSongRepository');
      return Result.success(detailedSong);
    } catch (e, stackTrace) {
      final message = '获取歌曲详情失败: ${e.toString()}';
      Logger.error(message, error: e, stackTrace: stackTrace, tag: 'OnlineSongRepository');
      return Result.failure(message, error: e, stackTrace: stackTrace);
    }
  }
  
  /// 🎯 优化：获取播放链接（带请求去重和重试）
  /// 
  /// [song] - 歌曲对象
  /// [useCache] - 是否使用缓存
  Future<Result<String>> getPlayUrl(
    OnlineSong song, {
    bool useCache = true,
  }) async {
    try {
      // 检查缓存
      if (useCache && _isPlayUrlCached(song.id)) {
        Logger.debug('使用缓存的播放链接: ${song.title}', tag: 'OnlineSongRepository');
        return Result.success(_playUrlCache[song.id]!);
      }
      
      // 🎯 使用网络优化器执行请求（自动去重和重试）
      final requestKey = 'play_url_${song.id}';
      final url = await _networkOptimizer.execute<String?>(
        dio: _dio,
        requestKey: requestKey,
        useCache: useCache,
        enableRetry: true,
        requestBuilder: () async {
          Logger.info('获取播放链接: ${song.title}', tag: 'OnlineSongRepository');
          return await _apiManager.getSongUrl(song);
        },
      );
      
      // 验证 URL
      if (url == null || url.isEmpty) {
        return Result.failure('播放链接为空', errorCode: ErrorCodes.notFound);
      }
      
      // 更新缓存
      _playUrlCache[song.id] = url;
      _playUrlCacheTimestamps[song.id] = DateTime.now();
      
      Logger.info('获取播放链接成功: ${song.title}', tag: 'OnlineSongRepository');
      return Result.success(url);
    } catch (e, stackTrace) {
      final message = '获取播放链接失败: ${e.toString()}';
      Logger.error(message, error: e, stackTrace: stackTrace, tag: 'OnlineSongRepository');
      return Result.failure(message, error: e, stackTrace: stackTrace);
    }
  }
  
  /// 获取歌词
  /// 
  /// [song] - 歌曲对象
  Future<Result<String>> getLyric(OnlineSong song) async {
    try {
      // 如果歌曲已有歌词，直接返回
      if (song.lyric != null && song.lyric!.isNotEmpty) {
        return Result.success(song.lyric!);
      }
      
      // 否则获取详细信息（包含歌词）
      final detailsResult = await getSongDetails(song, useCache: false);
      if (detailsResult.isSuccess) {
        final detailedSong = detailsResult.data!;
        if (detailedSong.lyric != null && detailedSong.lyric!.isNotEmpty) {
          return Result.success(detailedSong.lyric!);
        }
      }
      
      return Result.failure('该歌曲暂无歌词', errorCode: ErrorCodes.notFound);
    } catch (e, stackTrace) {
      final message = '获取歌词失败: ${e.toString()}';
      Logger.error(message, error: e, stackTrace: stackTrace, tag: 'OnlineSongRepository');
      return Result.failure(message, error: e, stackTrace: stackTrace);
    }
  }
  
  /// 批量获取歌曲详情
  Future<Result<List<OnlineSong>>> getBatchSongDetails(
    List<OnlineSong> songs, {
    bool useCache = true,
  }) async {
    try {
      final futures = songs.map((song) => getSongDetails(song, useCache: useCache));
      final results = await Future.wait(futures);
      
      final detailedSongs = <OnlineSong>[];
      final failures = <String>[];
      
      for (var i = 0; i < results.length; i++) {
        final result = results[i];
        if (result.isSuccess) {
          detailedSongs.add(result.data!);
        } else {
          failures.add('${songs[i].title}: ${result.message}');
        }
      }
      
      if (failures.isNotEmpty) {
        Logger.warn('部分歌曲详情获取失败: ${failures.join(", ")}', tag: 'OnlineSongRepository');
      }
      
      return Result.success(detailedSongs);
    } catch (e, stackTrace) {
      final message = '批量获取歌曲详情失败: ${e.toString()}';
      Logger.error(message, error: e, stackTrace: stackTrace, tag: 'OnlineSongRepository');
      return Result.failure(message, error: e, stackTrace: stackTrace);
    }
  }
  
  /// 检查搜索结果是否已缓存且有效
  bool _isSearchCached(String keyword) {
    if (!_searchCache.containsKey(keyword)) return false;
    
    final timestamp = _searchCacheTimestamps[keyword];
    if (timestamp == null) return false;
    
    final age = DateTime.now().difference(timestamp);
    return age < _searchCacheValidDuration;
  }
  
  /// 检查歌曲详情是否已缓存且有效
  bool _isSongDetailsCached(String songId) {
    if (!_songDetailsCache.containsKey(songId)) return false;
    
    final timestamp = _songDetailsCacheTimestamps[songId];
    if (timestamp == null) return false;
    
    final age = DateTime.now().difference(timestamp);
    return age < _songDetailsCacheValidDuration;
  }
  
  /// 检查播放链接是否已缓存且有效
  bool _isPlayUrlCached(String songId) {
    if (!_playUrlCache.containsKey(songId)) return false;
    
    final timestamp = _playUrlCacheTimestamps[songId];
    if (timestamp == null) return false;
    
    final age = DateTime.now().difference(timestamp);
    return age < _playUrlCacheValidDuration;
  }
  
  /// 清空所有缓存
  void clearAllCache() {
    _searchCache.clear();
    _searchCacheTimestamps.clear();
    _songDetailsCache.clear();
    _songDetailsCacheTimestamps.clear();
    _playUrlCache.clear();
    _playUrlCacheTimestamps.clear();
    
    // 🎯 清空网络优化器缓存
    _networkOptimizer.clearCache();
    
    Logger.debug('所有缓存已清空', tag: 'OnlineSongRepository');
  }
  
  /// 🎯 获取网络统计
  Map<String, dynamic> getNetworkStats() {
    return _networkOptimizer.getStats();
  }
  
  /// 清空搜索缓存
  void clearSearchCache() {
    _searchCache.clear();
    _searchCacheTimestamps.clear();
    Logger.debug('搜索缓存已清空', tag: 'OnlineSongRepository');
  }
  
  /// 清空歌曲详情缓存
  void clearDetailsCache() {
    _songDetailsCache.clear();
    _songDetailsCacheTimestamps.clear();
    Logger.debug('歌曲详情缓存已清空', tag: 'OnlineSongRepository');
  }
  
  /// 清空播放链接缓存
  void clearPlayUrlCache() {
    _playUrlCache.clear();
    _playUrlCacheTimestamps.clear();
    Logger.debug('播放链接缓存已清空', tag: 'OnlineSongRepository');
  }
  
  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return {
      'searchCache': {
        'size': _searchCache.length,
        'keys': _searchCache.keys.toList(),
      },
      'detailsCache': {
        'size': _songDetailsCache.length,
      },
      'playUrlCache': {
        'size': _playUrlCache.length,
      },
      'totalCacheSize': _searchCache.length + 
                       _songDetailsCache.length + 
                       _playUrlCache.length,
    };
  }
}

