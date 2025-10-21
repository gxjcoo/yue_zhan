import 'package:flutter/material.dart';
import 'dart:io';
import '../models/local_song.dart';
import '../models/online_song.dart';
import '../services/global_audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../utils/image_loader.dart';
import '../utils/format_utils.dart';

/// 播放列表对话框
/// 显示当前播放队列，支持切换歌曲和查看列表
class PlaylistDialog extends StatefulWidget {
  const PlaylistDialog({super.key});

  @override
  State<PlaylistDialog> createState() => _PlaylistDialogState();
}

class _PlaylistDialogState extends State<PlaylistDialog> {
  final GlobalAudioService _audioService = GlobalAudioService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 延迟滚动到当前歌曲
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentSong();
    });
    
    // 监听音频服务变化
    _audioService.addListener(_onAudioServiceChanged);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioServiceChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onAudioServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 滚动到当前播放的歌曲
  void _scrollToCurrentSong() {
    if (!_scrollController.hasClients) return;
    
    final currentIndex = _audioService.currentIndex;
    if (currentIndex >= 0) {
      final position = currentIndex * 72.0; // 每个列表项的高度
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 获取歌曲标题
  String _getSongTitle(dynamic song) {
    if (song is OnlineSong) return song.title;
    if (song is LocalSong) return song.title;
    return '未知歌曲';
  }

  /// 获取歌曲艺术家
  String _getSongArtist(dynamic song) {
    if (song is OnlineSong) return song.artist;
    if (song is LocalSong) return song.artist;
    return '未知艺术家';
  }

  /// 获取专辑封面
  String? _getAlbumArt(dynamic song) {
    if (song is OnlineSong) return song.albumArt;
    if (song is LocalSong) return song.albumArt;
    return null;
  }

  /// 获取歌曲时长（带缓存优化）
  String _formatDuration(dynamic song) {
    Duration? duration;
    if (song is OnlineSong) {
      duration = song.duration;
    } else if (song is LocalSong) {
      duration = song.duration;
    }
    
    if (duration == null) return '--:--';
    
    // 🎯 优化：使用 FormatUtils 统一格式化（带缓存）
    return FormatUtils.formatDuration(duration);
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _audioService.playlist ?? [];
    final currentIndex = _audioService.currentIndex;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖动条
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.getTextSecondary(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.queue_music,
                      color: AppColors.getPrimary(context),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '播放列表',
                          style: AppTextStyles.headlineLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        Text(
                          '共 ${playlist.length} 首',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    // 清空列表按钮
                    if (playlist.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep),
                        tooltip: '清空列表',
                        onPressed: _showClearPlaylistConfirmation,
                      ),
                    // 关闭按钮
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // 歌曲列表
          Flexible(
            child: playlist.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: playlist.length,
                    // 🎯 性能优化参数
                    cacheExtent: 200,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    itemBuilder: (context, index) {
                      final song = playlist[index];
                      final isCurrentSong = index == currentIndex;
                      
                      return _buildSongTile(
                        song: song,
                        index: index,
                        isCurrentSong: isCurrentSong,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 构建歌曲列表项
  Widget _buildSongTile({
    required dynamic song,
    required int index,
    required bool isCurrentSong,
  }) {
    return InkWell(
      onTap: () async {
        // 切换到选中的歌曲
        await _audioService.playSong(
          song: song,
          playlist: _audioService.playlist,
          index: index,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrentSong 
              ? AppColors.getPrimary(context).withOpacity(0.1)
              : null,
          border: Border(
            left: BorderSide(
              color: isCurrentSong 
                  ? AppColors.getPrimary(context)
                  : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            // 索引或播放图标
            SizedBox(
              width: 40,
              child: Center(
                child: isCurrentSong
                    ? Icon(
                        _audioService.isPlaying 
                            ? Icons.equalizer 
                            : Icons.pause_circle_outline,
                        color: AppColors.getPrimary(context),
                        size: 24,
                      )
                    : Text(
                        '${index + 1}',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // 专辑封面
            _buildAlbumArtWidget(song),
            
            const SizedBox(width: 12),
            
            // 歌曲信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getSongTitle(song),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentSong 
                          ? AppColors.getPrimary(context)
                          : AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getSongArtist(song),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // 时长
            Text(
              _formatDuration(song),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // 更多选项
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: AppColors.getTextSecondary(context),
                size: 20,
              ),
              onPressed: () => _showSongOptions(song, index),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建专辑封面
  Widget _buildAlbumArtWidget(dynamic song) {
    final albumArt = _getAlbumArt(song);
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.getCard(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: albumArt == null || albumArt.isEmpty
            ? Icon(Icons.music_note, color: AppColors.getTextSecondary(context), size: 24)
            : song is LocalSong
                ? _buildLocalAlbumArt(albumArt)
                : _buildNetworkAlbumArt(albumArt),
      ),
    );
  }

  /// 构建本地专辑封面
  Widget _buildLocalAlbumArt(String albumArt) {
    if (albumArt.endsWith('#metadata')) {
      return Icon(Icons.album, color: AppColors.getTextSecondary(context), size: 24);
    }
    
    return Image.file(
      File(albumArt),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.music_note, color: AppColors.getTextSecondary(context), size: 24);
      },
    );
  }

  /// 构建网络专辑封面
  Widget _buildNetworkAlbumArt(String albumArt) {
    return ImageLoader.loadAlbumArt(
      albumArt: albumArt,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      errorWidget: Icon(Icons.music_note, color: AppColors.getTextSecondary(context), size: 24),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music,
              size: 80,
              color: AppColors.getTextSecondary(context),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              '播放列表为空',
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              '还没有添加任何歌曲',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示歌曲选项菜单
  void _showSongOptions(dynamic song, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('歌曲信息'),
              onTap: () {
                Navigator.pop(context);
                _showSongInfo(song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('播放'),
              onTap: () async {
                Navigator.pop(context);
                await _audioService.playSong(
                  song: song,
                  playlist: _audioService.playlist,
                  index: index,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.skip_next),
              title: const Text('下一首播放'),
              onTap: () {
                Navigator.pop(context);
                _playNext(song, index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('收藏'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现收藏功能
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('功能开发中...')),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
              title: const Text('从列表中移除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _removeFromPlaylist(index);
              },
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  /// 显示歌曲详细信息
  void _showSongInfo(dynamic song) {
    showDialog(
      context: context,
      builder: (context) {
        String title = _getSongTitle(song);
        String artist = _getSongArtist(song);
        String duration = _formatDuration(song);
        String album = '未知专辑';
        String source = '未知';
        
        if (song is OnlineSong) {
          album = song.album;
          source = song.source;
        } else if (song is LocalSong) {
          album = song.album;
          source = '本地音乐';
        }

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 8),
              Text('歌曲信息'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('标题', title),
                const Divider(),
                _buildInfoRow('艺术家', artist),
                const Divider(),
                _buildInfoRow('专辑', album),
                const Divider(),
                _buildInfoRow('时长', duration),
                const Divider(),
                _buildInfoRow('来源', source),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 从播放列表中移除歌曲
  void _removeFromPlaylist(int index) {
    final song = _audioService.playlist![index];
    final songTitle = _getSongTitle(song);
    
    // 显示确认对话框
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认移除'),
          content: Text('确定要从播放列表中移除 "$songTitle" 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _audioService.removeFromPlaylist(index);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已从列表中移除 "$songTitle"'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('移除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// 下一首播放
  void _playNext(dynamic song, int currentIndex) {
    // 如果歌曲已经是下一首，不需要操作
    if (currentIndex == _audioService.currentIndex + 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('该歌曲已经是下一首'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // 从原位置移除，然后插入到下一首位置
    _audioService.removeFromPlaylist(currentIndex);
    _audioService.insertNextToPlay(song);
    
    final songTitle = _getSongTitle(song);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$songTitle" 将在下一首播放'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 显示清空播放列表确认对话框
  void _showClearPlaylistConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('确认清空'),
            ],
          ),
          content: const Text('确定要清空整个播放列表吗？此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _audioService.clearPlaylist();
                Navigator.of(context).pop(); // 关闭播放列表对话框
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('播放列表已清空'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('清空', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

