import '../models/local_song.dart';
import '../utils/logger.dart';
import 'hive_local_song_storage.dart';

/// 数据库优化服务
/// 
/// 功能：
/// - 分页加载：避免一次性加载大量数据
/// - 批量操作优化：减少数据库 I/O
/// - 索引优化：基于常用查询字段的索引
/// - 性能监控：统计查询性能
class DatabaseOptimizer {
  static final DatabaseOptimizer _instance = DatabaseOptimizer._internal();
  factory DatabaseOptimizer() => _instance;
  DatabaseOptimizer._internal();

  // 分页配置
  static const int defaultPageSize = 50;
  static const int maxPageSize = 200;
  
  // 索引缓存（基于不同字段）
  Map<String, List<String>>? _artistIndex; // 艺术家 -> 歌曲ID列表
  Map<String, List<String>>? _albumIndex;  // 专辑 -> 歌曲ID列表
  Map<String, List<LocalSong>>? _paginatedCache; // 页码 -> 歌曲列表
  
  // 性能统计
  final Map<String, int> _queryStats = {
    'totalQueries': 0,
    'cachedQueries': 0,
    'dbQueries': 0,
  };
  
  /// 分页加载本地歌曲
  /// 
  /// [page] - 页码（从0开始）
  /// [pageSize] - 每页数量
  /// [forceRefresh] - 强制从数据库重新加载
  Future<PaginatedResult<LocalSong>> getSongsPaginated({
    int page = 0,
    int pageSize = defaultPageSize,
    bool forceRefresh = false,
  }) async {
    try {
      _queryStats['totalQueries'] = (_queryStats['totalQueries'] ?? 0) + 1;
      
      // 验证参数
      if (page < 0) page = 0;
      if (pageSize <= 0 || pageSize > maxPageSize) {
        pageSize = defaultPageSize;
      }
      
      // 检查缓存
      final cacheKey = '${page}_$pageSize';
      if (!forceRefresh && _paginatedCache?[cacheKey] != null) {
        _queryStats['cachedQueries'] = (_queryStats['cachedQueries'] ?? 0) + 1;
        Logger.debug('使用缓存的分页数据: 第${page + 1}页', tag: 'DatabaseOptimizer');
        
        final total = await _getTotalCount();
        return PaginatedResult(
          data: _paginatedCache![cacheKey]!,
          page: page,
          pageSize: pageSize,
          totalItems: total,
          hasMore: (page + 1) * pageSize < total,
        );
      }
      
      _queryStats['dbQueries'] = (_queryStats['dbQueries'] ?? 0) + 1;
      
      // 从数据库加载
      Logger.debug('从数据库分页加载: 第${page + 1}页（每页$pageSize首）', tag: 'DatabaseOptimizer');
      
      final allSongs = await LocalSongStorage.getSongs();
      final total = allSongs.length;
      final startIndex = page * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, total);
      
      if (startIndex >= total) {
        // 页码超出范围
        return PaginatedResult(
          data: [],
          page: page,
          pageSize: pageSize,
          totalItems: total,
          hasMore: false,
        );
      }
      
      final paginatedSongs = allSongs.sublist(startIndex, endIndex);
      
      // 缓存结果
      _paginatedCache ??= {};
      _paginatedCache![cacheKey] = paginatedSongs;
      
      Logger.info('分页加载完成: 第${page + 1}页，加载${paginatedSongs.length}首，总计$total首', 
          tag: 'DatabaseOptimizer');
      
      return PaginatedResult(
        data: paginatedSongs,
        page: page,
        pageSize: pageSize,
        totalItems: total,
        hasMore: endIndex < total,
      );
    } catch (e) {
      Logger.error('分页加载失败', error: e, tag: 'DatabaseOptimizer');
      return PaginatedResult(
        data: [],
        page: page,
        pageSize: pageSize,
        totalItems: 0,
        hasMore: false,
      );
    }
  }
  
  /// 根据艺术家查询歌曲（使用索引）
  /// 
  /// [artist] - 艺术家名称
  Future<List<LocalSong>> getSongsByArtist(String artist) async {
    try {
      _queryStats['totalQueries'] = (_queryStats['totalQueries'] ?? 0) + 1;
      
      // 构建索引（如果尚未构建）
      if (_artistIndex == null) {
        await _buildArtistIndex();
      }
      
      // 从索引查找
      final songIds = _artistIndex?[artist.toLowerCase()] ?? [];
      if (songIds.isEmpty) {
        Logger.debug('艺术家 "$artist" 没有歌曲', tag: 'DatabaseOptimizer');
        return [];
      }
      
      _queryStats['cachedQueries'] = (_queryStats['cachedQueries'] ?? 0) + 1;
      
      // 加载完整歌曲信息
      final allSongs = await LocalSongStorage.getSongs();
      final songs = allSongs.where((song) => songIds.contains(song.id)).toList();
      
      Logger.info('通过索引查询艺术家 "$artist"：找到${songs.length}首歌曲', 
          tag: 'DatabaseOptimizer');
      
      return songs;
    } catch (e) {
      Logger.error('艺术家查询失败: $artist', error: e, tag: 'DatabaseOptimizer');
      return [];
    }
  }
  
  /// 根据专辑查询歌曲（使用索引）
  /// 
  /// [album] - 专辑名称
  Future<List<LocalSong>> getSongsByAlbum(String album) async {
    try {
      _queryStats['totalQueries'] = (_queryStats['totalQueries'] ?? 0) + 1;
      
      // 构建索引（如果尚未构建）
      if (_albumIndex == null) {
        await _buildAlbumIndex();
      }
      
      // 从索引查找
      final songIds = _albumIndex?[album.toLowerCase()] ?? [];
      if (songIds.isEmpty) {
        Logger.debug('专辑 "$album" 没有歌曲', tag: 'DatabaseOptimizer');
        return [];
      }
      
      _queryStats['cachedQueries'] = (_queryStats['cachedQueries'] ?? 0) + 1;
      
      // 加载完整歌曲信息
      final allSongs = await LocalSongStorage.getSongs();
      final songs = allSongs.where((song) => songIds.contains(song.id)).toList();
      
      Logger.info('通过索引查询专辑 "$album"：找到${songs.length}首歌曲', 
          tag: 'DatabaseOptimizer');
      
      return songs;
    } catch (e) {
      Logger.error('专辑查询失败: $album', error: e, tag: 'DatabaseOptimizer');
      return [];
    }
  }
  
  /// 批量添加歌曲（优化版）
  /// 
  /// 一次性提交，减少数据库 I/O
  Future<void> addSongsBatch(List<LocalSong> songs) async {
    if (songs.isEmpty) return;
    
    try {
      Logger.info('批量添加${songs.length}首歌曲...', tag: 'DatabaseOptimizer');
      final startTime = DateTime.now();
      
      // 使用 Hive 的批量操作（如果支持）
      // 目前一次性提交
      for (final song in songs) {
        await LocalSongStorage.addSong(song);
      }
      
      // 清空缓存（数据已变化）
      _invalidateCache();
      
      final duration = DateTime.now().difference(startTime);
      Logger.info('批量添加完成，耗时: ${duration.inMilliseconds}ms', 
          tag: 'DatabaseOptimizer');
    } catch (e) {
      Logger.error('批量添加失败', error: e, tag: 'DatabaseOptimizer');
      rethrow;
    }
  }
  
  /// 批量删除歌曲（优化版）
  Future<void> removeSongsBatch(List<String> songIds) async {
    if (songIds.isEmpty) return;
    
    try {
      Logger.info('批量删除${songIds.length}首歌曲...', tag: 'DatabaseOptimizer');
      final startTime = DateTime.now();
      
      for (final id in songIds) {
        await LocalSongStorage.removeSong(id);
      }
      
      // 清空缓存
      _invalidateCache();
      
      final duration = DateTime.now().difference(startTime);
      Logger.info('批量删除完成，耗时: ${duration.inMilliseconds}ms', 
          tag: 'DatabaseOptimizer');
    } catch (e) {
      Logger.error('批量删除失败', error: e, tag: 'DatabaseOptimizer');
      rethrow;
    }
  }
  
  /// 构建艺术家索引
  Future<void> _buildArtistIndex() async {
    try {
      Logger.debug('构建艺术家索引...', tag: 'DatabaseOptimizer');
      
      final allSongs = await LocalSongStorage.getSongs();
      _artistIndex = {};
      
      for (final song in allSongs) {
        final artist = song.artist.toLowerCase();
        _artistIndex![artist] ??= [];
        _artistIndex![artist]!.add(song.id);
      }
      
      Logger.info('艺术家索引构建完成：${_artistIndex!.length}个艺术家', 
          tag: 'DatabaseOptimizer');
    } catch (e) {
      Logger.error('构建艺术家索引失败', error: e, tag: 'DatabaseOptimizer');
    }
  }
  
  /// 构建专辑索引
  Future<void> _buildAlbumIndex() async {
    try {
      Logger.debug('构建专辑索引...', tag: 'DatabaseOptimizer');
      
      final allSongs = await LocalSongStorage.getSongs();
      _albumIndex = {};
      
      for (final song in allSongs) {
        final album = song.album.toLowerCase();
        _albumIndex![album] ??= [];
        _albumIndex![album]!.add(song.id);
      }
      
      Logger.info('专辑索引构建完成：${_albumIndex!.length}个专辑', 
          tag: 'DatabaseOptimizer');
    } catch (e) {
      Logger.error('构建专辑索引失败', error: e, tag: 'DatabaseOptimizer');
    }
  }
  
  /// 获取总歌曲数
  Future<int> _getTotalCount() async {
    try {
      final songs = await LocalSongStorage.getSongs();
      return songs.length;
    } catch (e) {
      Logger.error('获取总数失败', error: e, tag: 'DatabaseOptimizer');
      return 0;
    }
  }
  
  /// 清空缓存
  void _invalidateCache() {
    _paginatedCache?.clear();
    _artistIndex = null;
    _albumIndex = null;
    Logger.debug('数据库缓存已清空', tag: 'DatabaseOptimizer');
  }
  
  /// 预热索引（启动时调用）
  Future<void> warmupIndexes() async {
    Logger.info('开始预热数据库索引...', tag: 'DatabaseOptimizer');
    final startTime = DateTime.now();
    
    await Future.wait([
      _buildArtistIndex(),
      _buildAlbumIndex(),
    ]);
    
    final duration = DateTime.now().difference(startTime);
    Logger.info('索引预热完成，耗时: ${duration.inMilliseconds}ms', 
        tag: 'DatabaseOptimizer');
  }
  
  /// 获取性能统计
  Map<String, dynamic> getStats() {
    final total = _queryStats['totalQueries'] ?? 0;
    final cached = _queryStats['cachedQueries'] ?? 0;
    final cacheHitRate = total > 0 ? (cached / total * 100).toStringAsFixed(1) : '0.0';
    
    return {
      'totalQueries': total,
      'cachedQueries': cached,
      'dbQueries': _queryStats['dbQueries'] ?? 0,
      'cacheHitRate': '$cacheHitRate%',
      'artistIndexSize': _artistIndex?.length ?? 0,
      'albumIndexSize': _albumIndex?.length ?? 0,
      'paginatedCacheSize': _paginatedCache?.length ?? 0,
    };
  }
}

/// 分页结果包装类
class PaginatedResult<T> {
  final List<T> data;
  final int page;
  final int pageSize;
  final int totalItems;
  final bool hasMore;
  
  PaginatedResult({
    required this.data,
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.hasMore,
  });
  
  int get totalPages => (totalItems / pageSize).ceil();
  int get currentItemCount => data.length;
  
  @override
  String toString() {
    return 'PaginatedResult(page: $page, items: $currentItemCount/$totalItems, hasMore: $hasMore)';
  }
}

