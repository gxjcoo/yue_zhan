import 'dart:async';
import 'package:dio/dio.dart';
import 'logger.dart';

/// 网络请求优化工具
/// 
/// 功能：
/// - 请求去重：防止同一时间重复请求
/// - 智能重试：失败后自动重试（指数退避）
/// - 请求队列：控制并发数量
/// - 超时控制：避免长时间等待
/// - 性能监控：统计网络请求性能
class NetworkOptimizer {
  static final NetworkOptimizer _instance = NetworkOptimizer._internal();
  factory NetworkOptimizer() => _instance;
  NetworkOptimizer._internal();

  // 请求去重 - 存储正在进行的请求
  final Map<String, Completer<dynamic>> _pendingRequests = {};
  
  // 请求缓存 - 存储最近的成功响应
  final Map<String, _CachedResponse> _responseCache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  // 重试配置
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(milliseconds: 500);
  static const double retryDelayMultiplier = 2.0;
  
  // 性能统计
  final Map<String, int> _stats = {
    'totalRequests': 0,
    'deduplicatedRequests': 0,
    'cachedResponses': 0,
    'retriedRequests': 0,
    'failedRequests': 0,
    'successfulRequests': 0,
  };
  
  /// 执行HTTP请求（带去重、缓存、重试）
  /// 
  /// [dio] - Dio 实例
  /// [requestKey] - 请求唯一标识（用于去重和缓存）
  /// [requestBuilder] - 请求构建函数
  /// [useCache] - 是否使用缓存
  /// [enableRetry] - 是否启用重试
  Future<T> execute<T>({
    required Dio dio,
    required String requestKey,
    required Future<T> Function() requestBuilder,
    bool useCache = true,
    bool enableRetry = true,
  }) async {
    _stats['totalRequests'] = (_stats['totalRequests'] ?? 0) + 1;
    
    // 1. 检查缓存
    if (useCache && _isCached(requestKey)) {
      _stats['cachedResponses'] = (_stats['cachedResponses'] ?? 0) + 1;
      Logger.debug('使用缓存响应: $requestKey', tag: 'NetworkOptimizer');
      return _responseCache[requestKey]!.data as T;
    }
    
    // 2. 请求去重
    if (_pendingRequests.containsKey(requestKey)) {
      _stats['deduplicatedRequests'] = (_stats['deduplicatedRequests'] ?? 0) + 1;
      Logger.debug('请求去重，等待现有请求: $requestKey', tag: 'NetworkOptimizer');
      return await _pendingRequests[requestKey]!.future as T;
    }
    
    // 3. 创建新的请求
    final completer = Completer<T>();
    _pendingRequests[requestKey] = completer as Completer;
    
    try {
      T result;
      
      if (enableRetry) {
        // 使用重试机制
        result = await _executeWithRetry(requestBuilder, requestKey);
      } else {
        // 直接执行
        result = await requestBuilder();
      }
      
      // 缓存成功响应
      if (useCache) {
        _cacheResponse(requestKey, result);
      }
      
      _stats['successfulRequests'] = (_stats['successfulRequests'] ?? 0) + 1;
      completer.complete(result);
      return result;
    } catch (e) {
      _stats['failedRequests'] = (_stats['failedRequests'] ?? 0) + 1;
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      rethrow;
    } finally {
      _pendingRequests.remove(requestKey);
    }
  }
  
  /// 执行请求（带重试）
  Future<T> _executeWithRetry<T>(
    Future<T> Function() requestBuilder,
    String requestKey,
  ) async {
    int attempt = 0;
    Duration delay = initialRetryDelay;
    
    while (true) {
      try {
        attempt++;
        Logger.debug('执行请求: $requestKey (尝试 $attempt/$maxRetries)', 
            tag: 'NetworkOptimizer');
        
        return await requestBuilder();
      } catch (e) {
        // 判断是否应该重试
        if (attempt >= maxRetries || !_shouldRetry(e)) {
          Logger.error('请求失败，不再重试: $requestKey', 
              error: e, tag: 'NetworkOptimizer');
          rethrow;
        }
        
        // 记录重试
        _stats['retriedRequests'] = (_stats['retriedRequests'] ?? 0) + 1;
        
        Logger.warn('请求失败，将在${delay.inMilliseconds}ms后重试 (${attempt + 1}/$maxRetries): $requestKey', 
            tag: 'NetworkOptimizer');
        
        // 等待后重试
        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * retryDelayMultiplier).toInt(),
        );
      }
    }
  }
  
  /// 判断错误是否应该重试
  bool _shouldRetry(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true; // 网络超时或连接错误可以重试
        
        case DioExceptionType.badResponse:
          // 5xx 错误可以重试，4xx 错误不重试
          final statusCode = error.response?.statusCode ?? 0;
          return statusCode >= 500 && statusCode < 600;
        
        default:
          return false;
      }
    }
    
    // 其他错误默认不重试
    return false;
  }
  
  /// 检查是否有缓存
  bool _isCached(String key) {
    final cached = _responseCache[key];
    if (cached == null) return false;
    
    final age = DateTime.now().difference(cached.timestamp);
    if (age > _cacheDuration) {
      _responseCache.remove(key);
      return false;
    }
    
    return true;
  }
  
  /// 缓存响应
  void _cacheResponse(String key, dynamic data) {
    _responseCache[key] = _CachedResponse(
      data: data,
      timestamp: DateTime.now(),
    );
    
    // 限制缓存大小
    if (_responseCache.length > 100) {
      _cleanupCache();
    }
  }
  
  /// 清理过期缓存
  void _cleanupCache() {
    final now = DateTime.now();
    _responseCache.removeWhere((key, cached) {
      return now.difference(cached.timestamp) > _cacheDuration;
    });
    
    Logger.debug('缓存清理完成，当前缓存数: ${_responseCache.length}', 
        tag: 'NetworkOptimizer');
  }
  
  /// 取消所有待处理的请求
  void cancelAllRequests() {
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('请求已取消');
      }
    }
    _pendingRequests.clear();
    Logger.info('所有待处理的请求已取消', tag: 'NetworkOptimizer');
  }
  
  /// 清空所有缓存
  void clearCache() {
    _responseCache.clear();
    Logger.info('网络缓存已清空', tag: 'NetworkOptimizer');
  }
  
  /// 获取性能统计
  Map<String, dynamic> getStats() {
    final total = _stats['totalRequests'] ?? 0;
    final deduplicated = _stats['deduplicatedRequests'] ?? 0;
    final cached = _stats['cachedResponses'] ?? 0;
    final successful = _stats['successfulRequests'] ?? 0;
    final failed = _stats['failedRequests'] ?? 0;
    
    final deduplicationRate = total > 0 
        ? (deduplicated / total * 100).toStringAsFixed(1) 
        : '0.0';
    final cacheHitRate = total > 0 
        ? (cached / total * 100).toStringAsFixed(1) 
        : '0.0';
    final successRate = total > 0 
        ? (successful / total * 100).toStringAsFixed(1) 
        : '0.0';
    
    return {
      'totalRequests': total,
      'deduplicatedRequests': deduplicated,
      'cachedResponses': cached,
      'retriedRequests': _stats['retriedRequests'] ?? 0,
      'successfulRequests': successful,
      'failedRequests': failed,
      'pendingRequests': _pendingRequests.length,
      'cacheSize': _responseCache.length,
      'deduplicationRate': '$deduplicationRate%',
      'cacheHitRate': '$cacheHitRate%',
      'successRate': '$successRate%',
    };
  }
  
  /// 重置统计
  void resetStats() {
    _stats.clear();
    _stats['totalRequests'] = 0;
    _stats['deduplicatedRequests'] = 0;
    _stats['cachedResponses'] = 0;
    _stats['retriedRequests'] = 0;
    _stats['failedRequests'] = 0;
    _stats['successfulRequests'] = 0;
    Logger.info('网络统计已重置', tag: 'NetworkOptimizer');
  }
}

/// 缓存响应数据
class _CachedResponse {
  final dynamic data;
  final DateTime timestamp;
  
  _CachedResponse({
    required this.data,
    required this.timestamp,
  });
}

/// 网络请求队列管理器（控制并发数）
class NetworkQueue {
  static final NetworkQueue _instance = NetworkQueue._internal();
  factory NetworkQueue() => _instance;
  NetworkQueue._internal();
  
  int _maxConcurrency = 5; // 最大并发数
  int _currentConcurrency = 0;
  final List<_QueuedRequest<dynamic>> _queue = [];
  
  /// 设置最大并发数
  void setMaxConcurrency(int max) {
    _maxConcurrency = max.clamp(1, 20);
    Logger.info('网络并发数已设置为: $_maxConcurrency', tag: 'NetworkQueue');
    _processQueue();
  }
  
  /// 添加请求到队列
  Future<T> enqueue<T>(Future<T> Function() request) async {
    final completer = Completer<T>();
    final queuedRequest = _QueuedRequest<T>(
      request: request,
      completer: completer,
    );
    
    _queue.add(queuedRequest);
    _processQueue();
    
    return completer.future;
  }
  
  /// 处理队列
  void _processQueue() {
    while (_currentConcurrency < _maxConcurrency && _queue.isNotEmpty) {
      final queuedRequest = _queue.removeAt(0);
      _currentConcurrency++;
      
      _executeRequest(queuedRequest).whenComplete(() {
        _currentConcurrency--;
        _processQueue(); // 继续处理队列
      });
    }
  }
  
  /// 执行单个请求
  Future<void> _executeRequest(_QueuedRequest queuedRequest) async {
    try {
      final result = await queuedRequest.request();
      queuedRequest.completer.complete(result);
    } catch (e) {
      queuedRequest.completer.completeError(e);
    }
  }
  
  /// 获取队列状态
  Map<String, int> getStatus() {
    return {
      'queueLength': _queue.length,
      'currentConcurrency': _currentConcurrency,
      'maxConcurrency': _maxConcurrency,
    };
  }
}

/// 队列中的请求
class _QueuedRequest<T> {
  final Future<T> Function() request;
  final Completer<T> completer;
  
  _QueuedRequest({
    required this.request,
    required this.completer,
  });
}

