import 'dart:convert';
import '../models/hive_playlist.dart';
import '../models/online_song.dart';
import 'hive_initialization.dart';
import '../utils/logger.dart';

class PlaylistStorage {
  
  /// 创建新歌单
  static Future<HivePlaylist> createPlaylist({
    required String name,
    String? description,
    String? coverImage,
  }) async {
    try {
      final box = HiveInitialization.getPlaylistsBox();
      
      // 生成唯一ID
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      
      final playlist = HivePlaylist(
        id: id,
        name: name,
        description: description,
        coverImage: coverImage,
        songIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await box.add(playlist);
      Logger.info('创建歌单成功: $name', tag: 'Playlist');
      
      return playlist;
    } catch (e) {
      Logger.error('创建歌单失败', error: e, tag: 'Playlist');
      rethrow;
    }
  }
  
  /// 获取所有歌单
  static Future<List<HivePlaylist>> getPlaylists() async {
    try {
      final box = HiveInitialization.getPlaylistsBox();
      return box.values.toList();
    } catch (e) {
      print('获取歌单列表失败: $e');
      return [];
    }
  }
  
  /// 获取指定歌单
  static Future<HivePlaylist?> getPlaylist(String id) async {
    try {
      final box = HiveInitialization.getPlaylistsBox();
      return box.values.firstWhere(
        (playlist) => playlist.id == id,
        orElse: () => throw Exception('歌单不存在'),
      );
    } catch (e) {
      print('获取歌单失败: $e');
      return null;
    }
  }
  
  /// 更新歌单信息
  static Future<void> updatePlaylist(HivePlaylist playlist) async {
    try {
      final box = HiveInitialization.getPlaylistsBox();
      
      // 查找歌单索引
      final playlists = box.values.toList();
      int? index;
      
      for (int i = 0; i < playlists.length; i++) {
        if (playlists[i].id == playlist.id) {
          index = i;
          break;
        }
      }
      
      if (index != null) {
        playlist.updatedAt = DateTime.now();
        await box.putAt(index, playlist);
        Logger.info('更新歌单成功: ${playlist.name}', tag: 'Playlist');
      } else {
        throw Exception('歌单不存在');
      }
    } catch (e) {
      Logger.error('更新歌单失败', error: e, tag: 'Playlist');
      rethrow;
    }
  }
  
  /// 删除歌单
  static Future<void> deletePlaylist(String id) async {
    try {
      final box = HiveInitialization.getPlaylistsBox();
      
      // 查找并删除歌单
      final playlists = box.values.toList();
      for (int i = 0; i < playlists.length; i++) {
        if (playlists[i].id == id) {
          await box.deleteAt(i);
          Logger.info('删除歌单成功', tag: 'Playlist');
          break;
        }
      }
    } catch (e) {
      Logger.error('删除歌单失败', error: e, tag: 'Playlist');
      rethrow;
    }
  }
  
  /// 添加本地歌曲到歌单
  static Future<void> addSongToPlaylist(String playlistId, String songId) async {
    try {
      final playlist = await getPlaylist(playlistId);
      if (playlist == null) {
        throw Exception('歌单不存在');
      }
      
      if (!playlist.songIds.contains(songId)) {
        playlist.songIds.add(songId);
        await updatePlaylist(playlist);
        Logger.info('添加本地歌曲到歌单成功', tag: 'Playlist');
      }
    } catch (e) {
      Logger.error('添加本地歌曲到歌单失败', error: e, tag: 'Playlist');
      rethrow;
    }
  }

  /// 添加在线歌曲到歌单
  static Future<void> addOnlineSongToPlaylist(String playlistId, OnlineSong song) async {
    try {
      final playlist = await getPlaylist(playlistId);
      if (playlist == null) {
        throw Exception('歌单不存在');
      }
      
      // 将OnlineSong转换为JSON字符串
      final songJson = jsonEncode(song.toJson());
      
      // 检查是否已存在（通过song.id）
      final existingSongs = playlist.onlineSongJsons
          .map((json) => OnlineSong.fromJson(jsonDecode(json)))
          .toList();
      
      if (!existingSongs.any((s) => s.id == song.id)) {
        playlist.onlineSongJsons.add(songJson);
        await updatePlaylist(playlist);
        Logger.info('添加在线歌曲到歌单成功: ${song.title}', tag: 'Playlist');
      } else {
        Logger.info('歌曲已存在于歌单中', tag: 'Playlist');
      }
    } catch (e) {
      Logger.error('添加在线歌曲到歌单失败', error: e, tag: 'Playlist');
      rethrow;
    }
  }
  
  /// 从歌单移除本地歌曲
  static Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    try {
      final playlist = await getPlaylist(playlistId);
      if (playlist == null) {
        throw Exception('歌单不存在');
      }
      
      playlist.songIds.remove(songId);
      await updatePlaylist(playlist);
      Logger.info('从歌单移除本地歌曲成功', tag: 'Playlist');
    } catch (e) {
      Logger.error('从歌单移除本地歌曲失败', error: e, tag: 'Playlist');
      rethrow;
    }
  }

  /// 从歌单移除在线歌曲
  static Future<void> removeOnlineSongFromPlaylist(String playlistId, String onlineSongId) async {
    try {
      final playlist = await getPlaylist(playlistId);
      if (playlist == null) {
        throw Exception('歌单不存在');
      }
      
      // 找到并移除匹配的在线歌曲
      playlist.onlineSongJsons.removeWhere((json) {
        final song = OnlineSong.fromJson(jsonDecode(json));
        return song.id == onlineSongId;
      });
      
      await updatePlaylist(playlist);
      Logger.info('从歌单移除在线歌曲成功', tag: 'Playlist');
    } catch (e) {
      Logger.error('从歌单移除在线歌曲失败', error: e, tag: 'Playlist');
      rethrow;
    }
  }
  
  /// 批量添加歌曲到歌单
  static Future<void> addSongsToPlaylist(String playlistId, List<String> songIds) async {
    try {
      final playlist = await getPlaylist(playlistId);
      if (playlist == null) {
        throw Exception('歌单不存在');
      }
      
      for (final songId in songIds) {
        if (!playlist.songIds.contains(songId)) {
          playlist.songIds.add(songId);
        }
      }
      
      await updatePlaylist(playlist);
      Logger.info('批量添加歌曲到歌单成功: ${songIds.length} 首', tag: 'Playlist');
    } catch (e) {
      Logger.error('批量添加歌曲到歌单失败', error: e, tag: 'Playlist');
      rethrow;
    }
  }
  
  /// 清空所有歌单
  static Future<void> clearPlaylists() async {
    try {
      final box = HiveInitialization.getPlaylistsBox();
      await box.clear();
      Logger.info('清空所有歌单成功', tag: 'Playlist');
    } catch (e) {
      Logger.error('清空歌单失败', error: e, tag: 'Playlist');
      rethrow;
    }
  }
  
  /// 获取歌单数量
  static Future<int> getPlaylistCount() async {
    try {
      final box = HiveInitialization.getPlaylistsBox();
      return box.length;
    } catch (e) {
      Logger.error('获取歌单数量失败', error: e, tag: 'Playlist');
      return 0;
    }
  }

  /// 从所有歌单中移除指定歌曲（用于删除歌曲时清理歌单引用）
  static Future<int> removeSongFromAllPlaylists(String songId) async {
    try {
      final playlists = await getPlaylists();
      int removedCount = 0;
      
      for (final playlist in playlists) {
        if (playlist.songIds.contains(songId)) {
          playlist.songIds.remove(songId);
          await updatePlaylist(playlist);
          removedCount++;
          print('从歌单 "${playlist.name}" 中移除歌曲');
        }
      }
      
      if (removedCount > 0) {
        print('✅ 从 $removedCount 个歌单中移除了歌曲');
      }
      
      return removedCount;
    } catch (e) {
      print('从歌单移除歌曲失败: $e');
      return 0;
    }
  }
}

