import 'dart:io';
import 'package:flutter/material.dart';
import '../models/local_song.dart';
import '../utils/logger.dart';
import '../utils/image_loader.dart';
import '../utils/permission_cache.dart';
import '../utils/format_utils.dart';

class SongTile extends StatelessWidget {
  final dynamic song; // LocalSong类型
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showAlbumArt;
  final bool showIndex;
  final int? index;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onMorePressed;
  final bool showDuration; // 是否显示时长
  
  // 选择功能相关参数
  final bool isSelectable;
  final bool isSelected;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
    this.showAlbumArt = false,
    this.showIndex = false,
    this.index,
    this.backgroundColor,
    this.textColor,
    this.onMorePressed,
    this.showDuration = true, // 默认显示时长
    this.isSelectable = false,
    this.isSelected = false,
  });

  // 获取歌曲标题
  String get _title {
    if (song is LocalSong) {
      return song.title;
    }
    return '未知歌曲';
  }

  // 获取艺人
  String get _artist {
    if (song is LocalSong) {
      return song.artist;
    }
    return '未知艺人';
  }

  // 获取专辑
  String get _album {
    if (song is LocalSong) {
      return song.album;
    }
    return '未知专辑';
  }

  // 获取时长
  Duration get _duration {
    if (song is LocalSong) {
      return song.duration;
    }
    return Duration.zero;
  }

  // 获取专辑封面
  String? get _albumArt {
    if (song is LocalSong) {
      return song.albumArt;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final defaultTextColor = textColor ?? Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleColor = textColor?.withOpacity(0.7) ?? 
        Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? (isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null),
        border: isSelected ? Border.all(
          color: Theme.of(context).primaryColor,
          width: 2,
        ) : null,
        borderRadius: isSelected ? BorderRadius.circular(8) : null,
      ),
      margin: isSelected ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2) : null,
      child: ListTile(
        leading: _buildLeading(),
        title: Text(
          _title,
          style: TextStyle(
            color: defaultTextColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$_artist • $_album',
          style: TextStyle(
            color: subtitleColor,
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _buildTrailing(context, subtitleColor),
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, Color? subtitleColor) {
    if (isSelectable) {
      // 选择模式：显示复选框
      return Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).primaryColor : subtitleColor,
        size: 24,
      );
    }

    // 普通模式：显示时长和更多按钮
    if (!showDuration && onMorePressed != null) {
      // 只显示更多按钮
      return IconButton(
        icon: Icon(
          Icons.more_vert,
          color: subtitleColor,
          size: 20,
        ),
        onPressed: onMorePressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 24,
          minHeight: 24,
          maxWidth: 24,
          maxHeight: 24,
        ),
      );
    }

    if (!showDuration) {
      // 不显示时长也不显示更多按钮
      return const SizedBox.shrink();
    }

    // 显示时长和更多按钮
    return SizedBox(
      width: 80,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              FormatUtils.formatDuration(_duration),
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
          if (onMorePressed != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: subtitleColor,
                size: 20,
              ),
              onPressed: onMorePressed,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
                maxWidth: 24,
                maxHeight: 24,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeading() {
    // 选择模式下的leading处理
    if (isSelectable) {
      if (showAlbumArt) {
        return _buildAlbumArt(size: 50);
      }
      return const Icon(Icons.music_note);
    }

    // 普通模式
    if (showIndex && index != null) {
      return SizedBox(
        width: showAlbumArt ? 72 : 40,
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '$index',
                style: TextStyle(
                  color: textColor?.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            if (showAlbumArt)
              _buildAlbumArt(size: 40)
            else
              const Icon(Icons.music_note, size: 20),
          ],
        ),
      );
    }

    if (showAlbumArt) {
      return _buildAlbumArt(size: 50);
    }

    return const Icon(Icons.music_note);
  }

  Widget _buildAlbumArt({required double size}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: _buildAlbumArtImage(size),
    );
  }

  Widget _buildAlbumArtImage(double size) {
    if (_albumArt != null && _albumArt!.isNotEmpty) {
      // 对于本地歌曲，处理本地专辑封面
      if (song is LocalSong) {
        return _buildLocalAlbumArt(size);
      } else {
        // 网络图片 - 使用增强的 ImageLoader
        return ImageLoader.loadAlbumArt(
          albumArt: _albumArt,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: _buildDefaultAlbumArt(size),
        );
      }
    }
    return _buildDefaultAlbumArt(size);
  }
  
  Widget _buildLocalAlbumArt(double size) {
    final albumArtPath = _albumArt!;
    
    // 检查是否为元数据标识
    if (albumArtPath.endsWith('#metadata')) {
      Logger.debug('显示元数据封面图标', tag: 'SongTile');
      return _buildDefaultAlbumArt(size, icon: Icons.album);
    }
    
    // 🎯 优化：使用缓存同步检查，避免 FutureBuilder 带来的性能开销
    final permissionCache = PermissionCache();
    
    // 异步检查权限（首次），但不阻塞UI
    _checkPermissionInBackground(permissionCache);
    
    // 同步检查文件存在性（使用缓存）
    final fileExists = permissionCache.fileExistsSync(albumArtPath);
    
    if (!fileExists) {
      Logger.debug('文件不存在（缓存）: $albumArtPath', tag: 'SongTile');
      return _buildDefaultAlbumArt(size);
    }
    
    // 文件存在，尝试显示图片
    Logger.debug('显示本地封面: $albumArtPath', tag: 'SongTile');
    final imageFile = File(albumArtPath);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.file(
        imageFile,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          Logger.warn('图片加载失败: $albumArtPath', error: error, tag: 'SongTile');
          // 如果是权限问题，显示特殊图标
          if (error.toString().contains('Permission denied')) {
            return _buildDefaultAlbumArt(size, icon: Icons.no_photography);
          }
          return _buildDefaultAlbumArt(size);
        },
      ),
    );
  }
  
  /// 后台检查权限（不阻塞UI）
  void _checkPermissionInBackground(PermissionCache cache) {
    // 异步检查权限，但不等待结果
    cache.hasPhotoPermission().then((hasPermission) {
      if (!hasPermission) {
        Logger.warn('没有图片读取权限', tag: 'SongTile');
      }
    }).catchError((e) {
      Logger.error('权限检查失败', error: e, tag: 'SongTile');
    });
  }
  
  Widget _buildDefaultAlbumArt(double size, {IconData icon = Icons.music_note}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: Colors.grey[600],
      ),
    );
  }

  // 🎯 优化：使用 FormatUtils 统一格式化（带缓存）
  // String _formatDuration(Duration duration) { ... } 已移除
}