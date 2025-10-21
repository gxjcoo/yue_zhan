import 'package:hive_flutter/hive_flutter.dart';
import '../models/local_song.dart';
import '../models/duration_adapter.dart';
import '../models/hive_playlist.dart';
import '../models/download_task_model.dart';
import '../utils/logger.dart';

class HiveInitialization {
  /// 🎯 优化：快速初始化 - 只初始化必要的Box
  /// 
  /// 启动时只打开首屏需要的Box，其他延迟到首次使用时打开
  /// 预估节省：~100ms
  static Future<void> init() async {
    try {
      // 初始化Hive
      await Hive.initFlutter();
      
      // 检查适配器是否已注册，避免重复注册
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(LocalSongAdapter());
      }
      
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(DurationAdapter());
      }
      
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(HivePlaylistAdapter());
      }
      
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(DownloadTaskModelAdapter());
      }
      
      // 🎯 优化：只打开首屏必要的Box（音乐库需要）
      if (!Hive.isBoxOpen('local_songs')) {
        await Hive.openBox<LocalSong>('local_songs');
      }
      
      if (!Hive.isBoxOpen('playlists')) {
        await Hive.openBox<HivePlaylist>('playlists');
      }
      
      // 🎯 延迟加载：search_history 和 download_queue 延迟到首次使用时打开
      // 这些Box在首屏不需要，可以节省启动时间
      
      Logger.info('Hive快速初始化完成（延迟加载模式）', tag: 'Hive');
    } catch (e) {
      Logger.error('Hive初始化失败', error: e, tag: 'Hive');
      rethrow;
    }
  }
  
  /// 🎯 延迟打开搜索历史Box
  static Future<Box<String>> openSearchHistoryBox() async {
    if (!Hive.isBoxOpen('search_history')) {
      Logger.info('延迟打开搜索历史Box', tag: 'Hive');
      return await Hive.openBox<String>('search_history');
    }
    return Hive.box<String>('search_history');
  }
  
  /// 🎯 延迟打开下载队列Box
  static Future<Box<DownloadTaskModel>> openDownloadQueueBox() async {
    if (!Hive.isBoxOpen('download_queue')) {
      Logger.info('延迟打开下载队列Box', tag: 'Hive');
      return await Hive.openBox<DownloadTaskModel>('download_queue');
    }
    return Hive.box<DownloadTaskModel>('download_queue');
  }
  
  static Box<LocalSong> getLocalSongsBox() {
    try {
      return Hive.box<LocalSong>('local_songs');
    } catch (e) {
      Logger.error('获取Hive盒子失败', error: e, tag: 'Hive');
      rethrow;
    }
  }
  
  static Box<HivePlaylist> getPlaylistsBox() {
    try {
      return Hive.box<HivePlaylist>('playlists');
    } catch (e) {
      Logger.error('获取歌单盒子失败', error: e, tag: 'Hive');
      rethrow;
    }
  }
}