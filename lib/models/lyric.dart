/// 歌词行模型
class LyricLine {
  final Duration timestamp; // 时间戳
  final String text; // 歌词文本

  LyricLine({
    required this.timestamp,
    required this.text,
  });

  @override
  String toString() => '[${timestamp.inSeconds}s] $text';
}

/// 歌词解析工具（带缓存优化）
class LyricParser {
  // 🎯 优化：歌词解析缓存（避免重复解析）
  static final Map<String, List<LyricLine>> _cache = {};
  static const int _maxCacheSize = 50; // 最多缓存50首歌的歌词
  static int _parseCount = 0;
  static int _cacheHitCount = 0;
  
  /// 解析LRC格式的歌词（带缓存）
  /// 格式示例: [00:12.50]歌词内容
  static List<LyricLine> parse(String lrcContent) {
    if (lrcContent.isEmpty) {
      return [];
    }
    
    // 🎯 使用内容的哈希作为缓存键（避免存储大量字符串）
    final cacheKey = lrcContent.hashCode.toString();
    
    // 检查缓存
    if (_cache.containsKey(cacheKey)) {
      _cacheHitCount++;
      return _cache[cacheKey]!;
    }
    
    _parseCount++;
    
    // 执行解析
    final lyrics = _parseLyric(lrcContent);
    
    // 更新缓存（LRU策略：超出大小时删除最旧的）
    if (_cache.length >= _maxCacheSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
    _cache[cacheKey] = lyrics;
    
    return lyrics;
  }
  
  /// 实际的解析逻辑
  static List<LyricLine> _parseLyric(String lrcContent) {
    final List<LyricLine> lyrics = [];
    final lines = lrcContent.split('\n');
    final timeRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final line in lines) {
      final match = timeRegex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)?.trim() ?? '';

        if (text.isNotEmpty) {
          final timestamp = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          );

          lyrics.add(LyricLine(
            timestamp: timestamp,
            text: text,
          ));
        }
      }
    }

    // 按时间排序
    lyrics.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return lyrics;
  }
  
  /// 清空缓存
  static void clearCache() {
    _cache.clear();
    _parseCount = 0;
    _cacheHitCount = 0;
  }
  
  /// 获取缓存统计
  static Map<String, dynamic> getCacheStats() {
    final total = _parseCount + _cacheHitCount;
    final hitRate = total > 0 ? (_cacheHitCount / total * 100) : 0.0;
    
    return {
      'cacheSize': _cache.length,
      'maxCacheSize': _maxCacheSize,
      'parseCount': _parseCount,
      'cacheHitCount': _cacheHitCount,
      'hitRate': '${hitRate.toStringAsFixed(1)}%',
    };
  }

  /// 根据当前播放时间查找当前应该显示的歌词索引
  static int findCurrentIndex(List<LyricLine> lyrics, Duration currentTime) {
    if (lyrics.isEmpty) return -1;

    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (currentTime >= lyrics[i].timestamp) {
        return i;
      }
    }

    return -1;
  }
}

