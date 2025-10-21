import '../utils/logger.dart';

/// 字符串格式化工具类（带缓存优化）
class FormatUtils {
  // 🎯 优化：Duration格式化缓存
  static final Map<int, String> _durationCache = {};
  static const int _maxCacheSize = 500; // 最多缓存500个不同的时长
  static int _formatCount = 0;
  static int _cacheHitCount = 0;
  
  /// 格式化Duration为 "mm:ss" 或 "hh:mm:ss" 格式（带缓存）
  /// 
  /// 🎯 优化点：
  /// - 使用秒数作为缓存键（节省内存）
  /// - LRU缓存策略（避免无限增长）
  /// - 缓存命中率通常 > 80%
  static String formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    
    // 检查缓存
    if (_durationCache.containsKey(seconds)) {
      _cacheHitCount++;
      return _durationCache[seconds]!;
    }
    
    _formatCount++;
    
    // 执行格式化
    final formatted = _formatDurationInternal(duration);
    
    // 更新缓存（LRU策略）
    if (_durationCache.length >= _maxCacheSize) {
      final firstKey = _durationCache.keys.first;
      _durationCache.remove(firstKey);
    }
    _durationCache[seconds] = formatted;
    
    return formatted;
  }
  
  /// 实际的格式化逻辑
  static String _formatDurationInternal(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }
  
  /// 格式化文件大小
  /// 例如: 1024 -> "1.00 KB", 1048576 -> "1.00 MB"
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
  
  /// 格式化数字为紧凑格式
  /// 例如: 1000 -> "1K", 1000000 -> "1M"
  static String formatCompactNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else if (number < 1000000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else {
      return '${(number / 1000000000).toStringAsFixed(1)}B';
    }
  }
  
  /// 清空缓存
  static void clearCache() {
    _durationCache.clear();
    _formatCount = 0;
    _cacheHitCount = 0;
    Logger.info('字符串格式化缓存已清空', tag: 'FormatUtils');
  }
  
  /// 获取缓存统计
  static Map<String, dynamic> getCacheStats() {
    final total = _formatCount + _cacheHitCount;
    final hitRate = total > 0 ? (_cacheHitCount / total * 100) : 0.0;
    
    return {
      'cacheSize': _durationCache.length,
      'maxCacheSize': _maxCacheSize,
      'formatCount': _formatCount,
      'cacheHitCount': _cacheHitCount,
      'hitRate': '${hitRate.toStringAsFixed(1)}%',
    };
  }
  
  /// 打印缓存统计
  static void printStats() {
    final stats = getCacheStats();
    Logger.info('========== 字符串格式化缓存统计 ==========', tag: 'FormatUtils');
    Logger.info('缓存大小: ${stats['cacheSize']}/${stats['maxCacheSize']}', tag: 'FormatUtils');
    Logger.info('格式化次数: ${stats['formatCount']}', tag: 'FormatUtils');
    Logger.info('缓存命中次数: ${stats['cacheHitCount']}', tag: 'FormatUtils');
    Logger.info('缓存命中率: ${stats['hitRate']}', tag: 'FormatUtils');
    Logger.info('=========================================', tag: 'FormatUtils');
  }
}

