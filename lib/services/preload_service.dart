import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/online_song.dart';
import '../services/global_audio_service.dart';
import '../utils/logger.dart';

/// 智能预加载服务
/// 在播放到70%时自动预加载下一首歌曲，实现无缝切歌
class PreloadService {
  static final PreloadService _instance = PreloadService._internal();
  factory PreloadService() => _instance;
  PreloadService._internal();
  
  final GlobalAudioService _audioService = GlobalAudioService();
  final Dio _dio = Dio();
  final Map<String, File> _cache = {};
  
  bool _isPreloading = false;
  bool _isEnabled = true;
  double _lastProgress = 0.0;
  
  /// 开始智能预加载
  void startSmartPreload() {
    if (!_isEnabled) return;
    
    _audioService.positionNotifier.addListener(_onPositionChanged);
    Logger.info('智能预加载服务已启动', tag: 'Preload');
  }
  
  /// 停止智能预加载
  void stopSmartPreload() {
    _audioService.positionNotifier.removeListener(_onPositionChanged);
    Logger.info('智能预加载服务已停止', tag: 'Preload');
  }
  
  /// 监听播放进度
  void _onPositionChanged() {
    if (!_isEnabled || _isPreloading) return;
    
    final currentPosition = _audioService.currentPosition.inSeconds;
    final totalDuration = _audioService.totalDuration.inSeconds;
    
    if (totalDuration <= 0) return;
    
    final progress = currentPosition / totalDuration;
    
    // 播放到70%时预加载下一首
    if (progress >= 0.7 && _lastProgress < 0.7) {
      preloadNext();
    }
    
    _lastProgress = progress;
  }
  
  /// 预加载下一首歌曲
  Future<void> preloadNext() async {
    if (_isPreloading) return;
    
    final playlist = _audioService.playlist;
    final currentIndex = _audioService.currentIndex;
    
    if (playlist == null || currentIndex >= playlist.length - 1) {
      return;
    }
    
    final nextSong = playlist[currentIndex + 1];
    
    // 只预加载在线歌曲
    if (nextSong is OnlineSong && nextSong.audioUrl != null) {
      _isPreloading = true;
      await _preloadAudio(nextSong.audioUrl!, nextSong.title);
      _isPreloading = false;
    }
  }
  
  /// 预加载音频文件
  Future<void> _preloadAudio(String url, String songTitle) async {
    if (_cache.containsKey(url)) {
      Logger.debug('歌曲已缓存: $songTitle', tag: 'Preload');
      return;
    }
    
    try {
      Logger.info('开始预加载: $songTitle', tag: 'Preload');
      
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      
      final tempDir = await getTemporaryDirectory();
      final fileName = '${url.hashCode}.mp3';
      final file = File('${tempDir.path}/preload_$fileName');
      
      await file.writeAsBytes(response.data);
      _cache[url] = file;
      
      Logger.info('预加载完成: $songTitle (${(response.data.length / 1024 / 1024).toStringAsFixed(2)}MB)', tag: 'Preload');
      
      // 限制缓存大小（保留最近3首）
      _maintainCacheSize();
    } catch (e) {
      Logger.error('预加载失败: $songTitle', error: e, tag: 'Preload');
    }
  }
  
  /// 维护缓存大小
  void _maintainCacheSize() {
    const maxCacheSize = 3;
    
    if (_cache.length > maxCacheSize) {
      final firstKey = _cache.keys.first;
      final file = _cache[firstKey];
      
      file?.delete().catchError((e) {
        Logger.error('删除缓存文件失败', error: e, tag: 'Preload');
        return file;
      });
      
      _cache.remove(firstKey);
      Logger.debug('清理旧缓存，当前缓存数: ${_cache.length}', tag: 'Preload');
    }
  }
  
  /// 获取缓存的文件
  File? getCached(String url) => _cache[url];
  
  /// 检查是否已缓存
  bool isCached(String url) => _cache.containsKey(url);
  
  /// 清理所有缓存
  Future<void> clearCache() async {
    Logger.info('清理所有预加载缓存', tag: 'Preload');
    
    for (final file in _cache.values) {
      try {
        await file.delete();
      } catch (e) {
        Logger.error('删除缓存文件失败', error: e, tag: 'Preload');
      }
    }
    
    _cache.clear();
  }
  
  /// 启用/禁用预加载
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    Logger.info('预加载服务${enabled ? "已启用" : "已禁用"}', tag: 'Preload');
    
    if (enabled) {
      startSmartPreload();
    } else {
      stopSmartPreload();
    }
  }
  
  /// 获取缓存统计
  Map<String, dynamic> getCacheStats() {
    int totalSize = 0;
    
    for (final file in _cache.values) {
      if (file.existsSync()) {
        totalSize += file.lengthSync();
      }
    }
    
    return {
      'count': _cache.length,
      'totalSizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
      'isPreloading': _isPreloading,
      'isEnabled': _isEnabled,
    };
  }
}

