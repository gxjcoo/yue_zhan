import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/online_song.dart';
import '../models/local_song.dart';
import '../models/hive_playlist.dart';
import '../providers/online_music_provider.dart';
import '../providers/download_provider.dart';
import '../services/playlist_storage.dart'; 
import '../utils/logger.dart';

/// 歌曲操作辅助类
/// 提供收藏、下载等通用功能，供播放页和搜索页复用
class SongActionHelper {
  /// 显示歌单选择对话框（在线歌曲 - 只收藏不下载）
  static Future<void> showFavoriteDialog(
    BuildContext context,
    OnlineSong song,
  ) async {
    final playlists = await PlaylistStorage.getPlaylists();
    
    if (!context.mounted) return;
    
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('还没有歌单，请先创建歌单'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.favorite, color: Colors.red),
              SizedBox(width: 8),
              Text('收藏到歌单'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.primaries[playlist.name.hashCode % Colors.primaries.length],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.library_music,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.songCount} 首歌曲'),
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    await favoriteOnlineSongToPlaylist(context, song, playlist);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// 显示歌单选择对话框（本地歌曲）
  static Future<void> showFavoriteDialogForLocal(
    BuildContext context,
    LocalSong song,
  ) async {
    final playlists = await PlaylistStorage.getPlaylists();
    
    if (!context.mounted) return;
    
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('还没有歌单，请先创建歌单'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.favorite, color: Colors.red),
              SizedBox(width: 8),
              Text('添加到歌单'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.primaries[playlist.name.hashCode % Colors.primaries.length],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.library_music,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.songIds.length} 首歌曲'),
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    await addLocalSongToPlaylist(context, song, playlist);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// 收藏在线歌曲到歌单（不下载，只保存歌曲信息）
  static Future<void> favoriteOnlineSongToPlaylist(
    BuildContext context,
    OnlineSong song,
    HivePlaylist playlist,
  ) async {
    if (!context.mounted) return;
    
    // 保存 ScaffoldMessenger 引用
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // 直接添加在线歌曲到歌单（不下载）
      await PlaylistStorage.addOnlineSongToPlaylist(playlist.id, song);
      
      // 收藏成功
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('✅ 已收藏到 "${playlist.name}"'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      Logger.info('收藏成功: ${song.title} -> ${playlist.name}', tag: 'SongAction');
    } catch (e, stackTrace) {
      Logger.error('收藏失败', error: e, stackTrace: stackTrace, tag: 'SongAction');
      
      // 显示错误信息
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('收藏失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 收藏在线歌曲到歌单（旧方法 - 自动下载，保留兼容性）
  @Deprecated('使用 favoriteOnlineSongToPlaylist 代替')
  static Future<void> favoriteToPlaylist(
    BuildContext context,
    OnlineSong song,
    HivePlaylist playlist,
  ) async {
    // 现在直接调用新方法（不下载）
    await favoriteOnlineSongToPlaylist(context, song, playlist);
  }

  /// 添加本地歌曲到歌单
  static Future<void> addLocalSongToPlaylist(
    BuildContext context,
    LocalSong song,
    HivePlaylist playlist,
  ) async {
    try {
      await PlaylistStorage.addSongToPlaylist(playlist.id, song.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 已添加到 "${playlist.name}"'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 下载在线歌曲（使用队列）
  static Future<void> downloadSong(
    BuildContext context,
    OnlineSong song,
  ) async {
    final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
    
    // 使用队列下载（限制并发）
    final result = await downloadProvider.downloadSongQueued(song);
    
    if (context.mounted) {
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.download, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('开始下载: ${song.title}'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? '下载失败'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 删除已下载的歌曲
  static Future<void> deleteDownloadedSong(
    BuildContext context,
    OnlineSong song,
  ) async {
    final provider = Provider.of<OnlineMusicProvider>(context, listen: false);
    
    final success = await provider.deleteDownloadedSong(song.id);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '删除成功' : '删除失败'),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 构建下载按钮组件
  /// 
  /// [iconColor] 图标颜色，默认为黑色（适合浅色背景）
  /// 对于深色背景，传入 Colors.white70
  static Widget buildDownloadButton(
    BuildContext context,
    OnlineSong song, {
    Color? iconColor,
  }) {
    final defaultIconColor = iconColor ?? Colors.black87;
    
    return Consumer2<OnlineMusicProvider, DownloadProvider>(
      builder: (context, onlineProvider, downloadProvider, child) {
        // 优先使用 DownloadProvider 的状态
        final isDownloaded = downloadProvider.isDownloaded(song.id) || 
                            onlineProvider.isDownloaded(song.id);
        final isDownloading = downloadProvider.isDownloading(song.id) || 
                             onlineProvider.isDownloading(song.id);
        final downloadProgress = downloadProvider.getDownloadProgress(song.id) != 0 
            ? downloadProvider.getDownloadProgress(song.id)
            : onlineProvider.getDownloadProgress(song.id);

        if (isDownloading) {
          // 正在下载
          return SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: downloadProgress,
                  strokeWidth: 2,
                  color: defaultIconColor,
                ),
                Text(
                  '${(downloadProgress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 8,
                    color: defaultIconColor,
                  ),
                ),
              ],
            ),
          );
        }

        if (isDownloaded) {
          // 已下载
          return PopupMenuButton(
            icon: const Icon(Icons.download_done, color: Colors.green),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('删除下载'),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'delete') {
                await deleteDownloadedSong(context, song);
              }
            },
          );
        }

        // 未下载
        return IconButton(
          icon: Icon(Icons.download, color: defaultIconColor),
          onPressed: () => downloadSong(context, song),
        );
      },
    );
  }
}

