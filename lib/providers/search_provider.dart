import 'package:flutter/foundation.dart';
import '../models/online_song.dart';
import '../services/music_api_manager.dart';
import '../services/connectivity_service.dart';
import '../core/result.dart';
import '../utils/logger.dart';

/// 在线音乐搜索 Provider
/// 
/// 职责：
/// - 管理搜索状态
/// - 执行在线搜索
/// - 缓存搜索结果
/// - 处理搜索错误
class SearchProvider with ChangeNotifier {
  final MusicApiManager _apiManager = MusicApiManager();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  // 搜索状态
  List<OnlineSong> _searchResults = [];
  List<OnlineSong> get searchResults => _searchResults;
  
  // 分源搜索结果 Map<平台名称, 歌曲列表>
  Map<String, List<OnlineSong>> _searchResultsBySource = {};
  Map<String, List<OnlineSong>> get searchResultsBySource => _searchResultsBySource;
  
  // 可用的音乐源列表
  List<String> _availableSources = [];
  List<String> get availableSources => _availableSources;
  
  bool _isSearching = false;
  bool get isSearching => _isSearching;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  String? _lastSearchKeyword;
  String? get lastSearchKeyword => _lastSearchKeyword;
  
  DateTime? _lastSearchTime;
  DateTime? get lastSearchTime => _lastSearchTime;
  
  // 搜索缓存（避免重复搜索）
  final Map<String, List<OnlineSong>> _searchCache = {};
  final Map<String, Map<String, List<OnlineSong>>> _searchCacheBySource = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const _cacheValidDuration = Duration(minutes: 5);
  
  /// 构造函数 - 初始化网络监听
  SearchProvider() {
    _initializeConnectivity();
    _initializeAvailableSources();
  }
  
  /// 初始化网络连接监听
  Future<void> _initializeConnectivity() async {
    try {
      await _connectivityService.initialize();
      Logger.info('搜索服务网络监听已初始化', tag: 'SearchProvider');
    } catch (e) {
      Logger.error('网络监听初始化失败', error: e, tag: 'SearchProvider');
    }
  }
  
  /// 初始化可用的音乐源列表
  void _initializeAvailableSources() {
    _availableSources = _apiManager.platformNames;
    Logger.info('可用音乐源: $_availableSources', tag: 'SearchProvider');
  }
  
  /// 搜索在线歌曲
  /// 
  /// [keyword] - 搜索关键字
  /// [limit] - 每个 API 返回的结果数量限制
  /// [useCache] - 是否使用缓存
  Future<Result<List<OnlineSong>>> search(
    String keyword, {
    int limit = 50,
    bool useCache = true,
  }) async {
    final trimmedKeyword = keyword.trim();
    
    // 验证输入
    if (trimmedKeyword.isEmpty) {
      return Result.failure('搜索关键字不能为空', errorCode: ErrorCodes.validationError);
    }
    
    // 检查缓存
    if (useCache && _isSearchCached(trimmedKeyword)) {
      Logger.debug('使用缓存的搜索结果: $trimmedKeyword', tag: 'SearchProvider');
      final cachedResults = _searchCache[trimmedKeyword]!;
      final cachedResultsBySource = _searchCacheBySource[trimmedKeyword] ?? {};
      _searchResults = cachedResults;
      _searchResultsBySource = cachedResultsBySource;
      _lastSearchKeyword = trimmedKeyword;
      _lastSearchTime = DateTime.now();
      notifyListeners();
      return Result.success(cachedResults);
    }
    
    // 检查网络连接
    if (!_connectivityService.isOnline) {
      const message = '无网络连接，请检查网络设置';
      _errorMessage = message;
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      Logger.warn(message, tag: 'SearchProvider');
      return Result.failure(message, errorCode: ErrorCodes.networkError);
    }
    
    // 开始搜索
    _isSearching = true;
    _errorMessage = null;
    _lastSearchKeyword = trimmedKeyword;
    notifyListeners();
    
    try {
      Logger.info('开始分源搜索: $trimmedKeyword', tag: 'SearchProvider');
      
      // 按源搜索
      final resultsBySource = await _apiManager.searchBySource(trimmedKeyword, limit: limit);
      
      // 合并所有源的结果（用于兼容旧代码）
      final allResults = <OnlineSong>[];
      for (final songs in resultsBySource.values) {
        allResults.addAll(songs);
      }
      
      // 去重
      final uniqueSongs = <String, OnlineSong>{};
      for (final song in allResults) {
        uniqueSongs[song.id] ??= song;
      }
      final mergedResults = uniqueSongs.values.toList();
      
      // 更新状态
      _searchResults = mergedResults;
      _searchResultsBySource = resultsBySource;
      _errorMessage = null;
      _lastSearchTime = DateTime.now();
      
      // 更新缓存
      _searchCache[trimmedKeyword] = mergedResults;
      _searchCacheBySource[trimmedKeyword] = resultsBySource;
      _cacheTimestamps[trimmedKeyword] = DateTime.now();
      
      Logger.info('搜索完成: 找到 ${mergedResults.length} 首歌曲 (${resultsBySource.length} 个源)', tag: 'SearchProvider');
      
      return Result.success(mergedResults);
    } catch (e, stackTrace) {
      final message = '搜索失败: ${e.toString()}';
      _errorMessage = message;
      _searchResults = [];
      _searchResultsBySource = {};
      Logger.error(message, error: e, stackTrace: stackTrace, tag: 'SearchProvider');
      return Result.failure(message, error: e, stackTrace: stackTrace);
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }
  
  /// 检查搜索结果是否已缓存且有效
  bool _isSearchCached(String keyword) {
    if (!_searchCache.containsKey(keyword)) {
      return false;
    }
    
    final timestamp = _cacheTimestamps[keyword];
    if (timestamp == null) {
      return false;
    }
    
    final age = DateTime.now().difference(timestamp);
    return age < _cacheValidDuration;
  }
  
  /// 清空搜索结果
  void clearSearch() {
    _searchResults = [];
    _searchResultsBySource = {};
    _errorMessage = null;
    _lastSearchKeyword = null;
    notifyListeners();
    Logger.debug('搜索结果已清空', tag: 'SearchProvider');
  }
  
  /// 清空缓存
  void clearCache() {
    _searchCache.clear();
    _searchCacheBySource.clear();
    _cacheTimestamps.clear();
    Logger.debug('搜索缓存已清空', tag: 'SearchProvider');
  }
  
  /// 获取缓存统计
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _searchCache.length,
      'cacheKeys': _searchCache.keys.toList(),
      'lastSearch': _lastSearchKeyword,
      'lastSearchTime': _lastSearchTime?.toIso8601String(),
    };
  }
  
  /// 重试上次搜索
  Future<Result<List<OnlineSong>>> retryLastSearch() async {
    if (_lastSearchKeyword == null || _lastSearchKeyword!.isEmpty) {
      return Result.failure('没有可重试的搜索', errorCode: ErrorCodes.validationError);
    }
    
    Logger.info('重试搜索: $_lastSearchKeyword', tag: 'SearchProvider');
    return search(_lastSearchKeyword!, useCache: false);
  }
}

