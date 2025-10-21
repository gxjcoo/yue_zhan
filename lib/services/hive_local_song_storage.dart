import '../models/local_song.dart';
import 'hive_initialization.dart';
import '../utils/logger.dart';

class LocalSongStorage {
  
  /// 保存本地歌曲列表（增量更新：相同歌曲覆盖，新歌曲添加）
  static Future<void> saveSongs(List<LocalSong> songs) async {
    try {
      final box = HiveInitialization.getLocalSongsBox();
      
      // 获取现有歌曲，建立ID到索引的映射
      final existingSongs = box.values.toList();
      final Map<String, int> existingIndexMap = {};
      
      for (int i = 0; i < existingSongs.length; i++) {
        existingIndexMap[existingSongs[i].id] = i;
      }
      
      // 统计信息
      int updatedCount = 0;
      int addedCount = 0;
      
      // 处理每首新歌曲
      for (final song in songs) {
        final existingIndex = existingIndexMap[song.id];
        
        if (existingIndex != null) {
          // 歌曲已存在，更新（覆盖）
          await box.putAt(existingIndex, song);
          updatedCount++;
          Logger.debug('更新歌曲: ${song.title}', tag: 'Storage');
        } else {
          // 新歌曲，添加
          await box.add(song);
          addedCount++;
          Logger.debug('添加新歌曲: ${song.title}', tag: 'Storage');
        }
      }
      
      Logger.info('歌曲保存完成 - 总计: ${songs.length} 首，新增: $addedCount 首，更新: $updatedCount 首', tag: 'Storage');
    } catch (e) {
      Logger.error('保存本地歌曲失败', error: e, tag: 'Storage');
      rethrow;
    }
  }
  
  /// 获取本地歌曲列表
  static Future<List<LocalSong>> getSongs() async {
    try {
      final box = HiveInitialization.getLocalSongsBox();
      return box.values.toList();
    } catch (e) {
      print('获取本地歌曲失败: $e');
      return [];
    }
  }
  
  /// 添加或更新单个歌曲（upsert操作）
  static Future<void> addSong(LocalSong song) async {
    try {
      final box = HiveInitialization.getLocalSongsBox();
      
      // 查找是否已存在
      final existingSongs = box.values.toList();
      int? existingIndex;
      
      for (int i = 0; i < existingSongs.length; i++) {
        if (existingSongs[i].id == song.id) {
          existingIndex = i;
          break;
        }
      }
      
      if (existingIndex != null) {
        // 歌曲已存在，更新
        await box.putAt(existingIndex, song);
        Logger.debug('更新歌曲: ${song.title}', tag: 'Storage');
      } else {
        // 新歌曲，添加
        await box.add(song);
        Logger.debug('添加新歌曲: ${song.title}', tag: 'Storage');
      }
    } catch (e) {
      Logger.error('添加/更新本地歌曲失败', error: e, tag: 'Storage');
      rethrow;
    }
  }
  
  /// 删除歌曲
  static Future<void> removeSong(String songId) async {
    try {
      final box = HiveInitialization.getLocalSongsBox();
      
      // 查找并删除歌曲
      final songs = box.values.toList();
      for (int i = 0; i < songs.length; i++) {
        if (songs[i].id == songId) {
          await box.deleteAt(i);
          break;
        }
      }
    } catch (e) {
      Logger.error('删除本地歌曲失败', error: e, tag: 'Storage');
      rethrow;
    }
  }
  
  /// 清空所有本地歌曲
  static Future<void> clearSongs() async {
    try {
      final box = HiveInitialization.getLocalSongsBox();
      await box.clear();
    } catch (e) {
      Logger.error('清空本地歌曲失败', error: e, tag: 'Storage');
      rethrow;
    }
  }
  
  /// 获取歌曲数量统计
  static Future<int> getSongCount() async {
    try {
      final box = HiveInitialization.getLocalSongsBox();
      return box.length;
    } catch (e) {
      Logger.error('获取歌曲数量失败', error: e, tag: 'Storage');
      return 0;
    }
  }
  
  /// 检查歌曲是否存在
  static Future<bool> songExists(String songId) async {
    try {
      final box = HiveInitialization.getLocalSongsBox();
      return box.values.any((song) => song.id == songId);
    } catch (e) {
      print('检查歌曲存在性失败: $e');
      return false;
    }
  }
  
  /// 批量删除歌曲
  static Future<void> removeSongs(List<String> songIds) async {
    try {
      final box = HiveInitialization.getLocalSongsBox();
      final songs = box.values.toList();
      
      // 从后往前删除，避免索引变化问题
      for (int i = songs.length - 1; i >= 0; i--) {
        if (songIds.contains(songs[i].id)) {
          await box.deleteAt(i);
        }
      }
      
      Logger.info('批量删除完成，删除了 ${songIds.length} 首歌曲', tag: 'Storage');
    } catch (e) {
      Logger.error('批量删除歌曲失败', error: e, tag: 'Storage');
      rethrow;
    }
  }
}