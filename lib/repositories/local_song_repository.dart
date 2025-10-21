import 'package:flutter/foundation.dart';
import '../models/local_song.dart';
import '../services/hive_local_song_storage.dart';
import '../services/database_optimizer.dart';
import '../utils/logger.dart';

/// 本地歌曲仓库
/// 
/// 提供统一的本地歌曲数据访问接口，包括：
/// - 内存缓存，减少数据库查询
/// - 数据一致性管理
/// - 统一的错误处理
class LocalSongRepository extends ChangeNotifier {
  // 单例模式
  static final LocalSongRepository _instance = LocalSongRepository._internal();
  factory LocalSongRepository() => _instance;
  LocalSongRepository._internal();

  // 🎯 优化：使用数据库优化器
  final DatabaseOptimizer _dbOptimizer = DatabaseOptimizer();
  
  // 缓存
  List<LocalSong>? _cachedSongs;
  DateTime? _lastUpdate;
  static const _cacheValidDuration = Duration(minutes: 5);
  
  // 索引（用于快速查找）
  Map<String, LocalSong>? _songMap;
  
  /// 获取本地歌曲（带缓存）
  /// 
  /// [forceRefresh] - 是否强制刷新缓存
  Future<List<LocalSong>> getSongs({bool forceRefresh = false}) async {
    try {
      // 检查缓存有效性
      if (!forceRefresh && _cachedSongs != null && _lastUpdate != null) {
        final cacheAge = DateTime.now().difference(_lastUpdate!);
        if (cacheAge < _cacheValidDuration) {
          Logger.debug('使用缓存的本地歌曲数据 (${_cachedSongs!.length} 首)', tag: 'Repository');
          return _cachedSongs!;
        }
      }
      
      // 从数据库加载
      Logger.debug('从数据库加载本地歌曲...', tag: 'Repository');
      _cachedSongs = await LocalSongStorage.getSongs();
      _lastUpdate = DateTime.now();
      
      // 构建索引
      _buildIndex();
      
      Logger.info('加载了 ${_cachedSongs!.length} 首本地歌曲', tag: 'Repository');
      notifyListeners();
      
      return _cachedSongs!;
    } catch (e) {
      Logger.error('加载本地歌曲失败', error: e, tag: 'Repository');
      return _cachedSongs ?? [];
    }
  }
  
  /// 🎯 优化：分页获取歌曲
  /// 
  /// [page] - 页码（从0开始）
  /// [pageSize] - 每页数量
  Future<PaginatedResult<LocalSong>> getSongsPaginated({
    int page = 0,
    int pageSize = 50,
    bool forceRefresh = false,
  }) async {
    return await _dbOptimizer.getSongsPaginated(
      page: page,
      pageSize: pageSize,
      forceRefresh: forceRefresh,
    );
  }
  
  /// 根据 ID 获取歌曲（使用索引，O(1) 查找）
  /// 
  /// 返回 null 表示未找到
  LocalSong? getSongById(String id) {
    if (_songMap == null || _cachedSongs == null) {
      Logger.warn('尚未加载歌曲数据，请先调用 getSongs()', tag: 'Repository');
      return null;
    }
    
    return _songMap![id];
  }
  
  /// 根据多个 ID 批量获取歌曲
  /// 
  /// 返回找到的歌曲列表（忽略未找到的 ID）
  List<LocalSong> getSongsByIds(List<String> ids) {
    if (_songMap == null || _cachedSongs == null) {
      Logger.warn('尚未加载歌曲数据，请先调用 getSongs()', tag: 'Repository');
      return [];
    }
    
    final songs = <LocalSong>[];
    for (final id in ids) {
      final song = _songMap![id];
      if (song != null) {
        songs.add(song);
      }
    }
    
    return songs;
  }
  
  /// 🎯 优化：根据艺术家查询（使用索引）
  Future<List<LocalSong>> getSongsByArtist(String artist) async {
    return await _dbOptimizer.getSongsByArtist(artist);
  }
  
  /// 🎯 优化：根据专辑查询（使用索引）
  Future<List<LocalSong>> getSongsByAlbum(String album) async {
    return await _dbOptimizer.getSongsByAlbum(album);
  }
  
  /// 搜索本地歌曲
  /// 
  /// 在标题、艺术家、专辑中搜索关键字
  List<LocalSong> searchSongs(String keyword) {
    if (_cachedSongs == null) {
      Logger.warn('尚未加载歌曲数据，请先调用 getSongs()', tag: 'Repository');
      return [];
    }
    
    if (keyword.isEmpty) {
      return [];
    }
    
    final lowerKeyword = keyword.toLowerCase();
    return _cachedSongs!.where((song) {
      return song.title.toLowerCase().contains(lowerKeyword) ||
             song.artist.toLowerCase().contains(lowerKeyword) ||
             song.album.toLowerCase().contains(lowerKeyword);
    }).toList();
  }
  
  /// 添加歌曲
  Future<void> addSong(LocalSong song) async {
    try {
      await LocalSongStorage.addSong(song);
      
      // 更新缓存
      if (_cachedSongs != null) {
        _cachedSongs!.add(song);
        _songMap?[song.id] = song;
        _lastUpdate = DateTime.now();
      }
      
      Logger.info('添加歌曲: ${song.title}', tag: 'Repository');
      notifyListeners();
    } catch (e) {
      Logger.error('添加歌曲失败: ${song.title}', error: e, tag: 'Repository');
      rethrow;
    }
  }
  
  /// 🎯 优化：批量添加歌曲（使用优化器）
  Future<void> addSongs(List<LocalSong> songs) async {
    try {
      await _dbOptimizer.addSongsBatch(songs);
      
      // 更新缓存
      if (_cachedSongs != null) {
        _cachedSongs!.addAll(songs);
        for (final song in songs) {
          _songMap?[song.id] = song;
        }
        _lastUpdate = DateTime.now();
      }
      
      Logger.info('批量添加了 ${songs.length} 首歌曲', tag: 'Repository');
      notifyListeners();
    } catch (e) {
      Logger.error('批量添加歌曲失败', error: e, tag: 'Repository');
      rethrow;
    }
  }
  
  /// 删除歌曲
  Future<void> removeSong(String songId) async {
    try {
      await LocalSongStorage.removeSong(songId);
      
      // 更新缓存
      if (_cachedSongs != null) {
        _cachedSongs!.removeWhere((s) => s.id == songId);
        _songMap?.remove(songId);
        _lastUpdate = DateTime.now();
      }
      
      Logger.info('删除歌曲: $songId', tag: 'Repository');
      notifyListeners();
    } catch (e) {
      Logger.error('删除歌曲失败: $songId', error: e, tag: 'Repository');
      rethrow;
    }
  }
  
  /// 🎯 优化：批量删除歌曲（使用优化器）
  Future<void> removeSongs(List<String> songIds) async {
    try {
      await _dbOptimizer.removeSongsBatch(songIds);
      
      // 更新缓存
      if (_cachedSongs != null) {
        _cachedSongs!.removeWhere((s) => songIds.contains(s.id));
        for (final id in songIds) {
          _songMap?.remove(id);
        }
        _lastUpdate = DateTime.now();
      }
      
      Logger.info('批量删除了 ${songIds.length} 首歌曲', tag: 'Repository');
      notifyListeners();
    } catch (e) {
      Logger.error('批量删除歌曲失败', error: e, tag: 'Repository');
      rethrow;
    }
  }
  
  /// 更新歌曲
  Future<void> updateSong(LocalSong song) async {
    try {
      // Hive 中更新（先删除再添加）
      await LocalSongStorage.removeSong(song.id);
      await LocalSongStorage.addSong(song);
      
      // 更新缓存
      if (_cachedSongs != null) {
        final index = _cachedSongs!.indexWhere((s) => s.id == song.id);
        if (index != -1) {
          _cachedSongs![index] = song;
        }
        _songMap?[song.id] = song;
        _lastUpdate = DateTime.now();
      }
      
      Logger.info('更新歌曲: ${song.title}', tag: 'Repository');
      notifyListeners();
    } catch (e) {
      Logger.error('更新歌曲失败: ${song.title}', error: e, tag: 'Repository');
      rethrow;
    }
  }
  
  /// 清空所有歌曲
  Future<void> clearAll() async {
    try {
      final songs = await LocalSongStorage.getSongs();
      for (final song in songs) {
        await LocalSongStorage.removeSong(song.id);
      }
      
      // 清空缓存
      _cachedSongs?.clear();
      _songMap?.clear();
      _lastUpdate = DateTime.now();
      
      Logger.info('清空了所有本地歌曲', tag: 'Repository');
      notifyListeners();
    } catch (e) {
      Logger.error('清空歌曲失败', error: e, tag: 'Repository');
      rethrow;
    }
  }
  
  /// 清空缓存（强制下次重新加载）
  void invalidateCache() {
    _cachedSongs = null;
    _songMap = null;
    _lastUpdate = null;
    Logger.debug('缓存已清空', tag: 'Repository');
  }
  
  /// 构建索引以加速查找
  void _buildIndex() {
    if (_cachedSongs == null) return;
    
    _songMap = {
      for (final song in _cachedSongs!) song.id: song
    };
    
    Logger.debug('构建了 ${_songMap!.length} 个歌曲索引', tag: 'Repository');
  }
  
  /// 🎯 优化：预热数据库索引
  Future<void> warmupIndexes() async {
    await _dbOptimizer.warmupIndexes();
  }
  
  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return {
      'isCached': _cachedSongs != null,
      'songCount': _cachedSongs?.length ?? 0,
      'lastUpdate': _lastUpdate?.toIso8601String(),
      'cacheAge': _lastUpdate != null 
          ? DateTime.now().difference(_lastUpdate!).inSeconds 
          : null,
      'hasIndex': _songMap != null,
      'indexSize': _songMap?.length ?? 0,
      'dbOptimizerStats': _dbOptimizer.getStats(),
    };
  }
}

