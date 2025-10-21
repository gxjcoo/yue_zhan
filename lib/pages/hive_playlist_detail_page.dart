import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import '../models/hive_playlist.dart';
import '../models/local_song.dart';
import '../models/online_song.dart';
import '../services/playlist_storage.dart';
import '../services/hive_local_song_storage.dart';
import '../services/global_audio_service.dart';
import '../widgets/song_tile.dart';
import '../widgets/song_selector_dialog.dart';
import '../routes/app_routes.dart' show AppRoutes, rootNavigatorKey;
import '../pages/playlist_editor_page.dart';
import '../pages/player_page.dart';
import '../utils/logger.dart';
import '../utils/format_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

class HivePlaylistDetailPage extends StatefulWidget {
  final String playlistId;

  const HivePlaylistDetailPage({
    super.key,
    required this.playlistId,
  });

  @override
  State<HivePlaylistDetailPage> createState() => _HivePlaylistDetailPageState();
}

class _HivePlaylistDetailPageState extends State<HivePlaylistDetailPage> {
  HivePlaylist? _playlist;
  List<Object> _songs = []; // 可以是 Song 或 LocalSong
  bool _isLoading = true;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadPlaylistData();
  }

  Future<void> _loadPlaylistData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取歌单信息
      final playlist = await PlaylistStorage.getPlaylist(widget.playlistId);
      
      if (playlist == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('歌单不存在')),
          );
          context.pop();
        }
        return;
      }

      // 获取本地歌曲
      final localSongs = await LocalSongStorage.getSongs();
      
      // 构建索引以提升查找性能 O(n) -> O(1)
      final songMap = <String, LocalSong>{
        for (var song in localSongs) song.id: song
      };
      
      // 根据 songIds 快速获取本地歌曲
      final songs = <Object>[];
      for (final songId in playlist.songIds) {
        final localSong = songMap[songId];
        if (localSong != null) {
          songs.add(localSong);
        }
      }

      // 解析在线歌曲
      for (final songJson in playlist.onlineSongJsons) {
        try {
          final onlineSong = OnlineSong.fromJson(jsonDecode(songJson));
          songs.add(onlineSong);
        } catch (e) {
          Logger.error('解析在线歌曲失败', error: e, tag: 'HivePlaylistDetail');
        }
      }

      // 计算总时长（只统计本地歌曲和有时长信息的在线歌曲）
      Duration totalDuration = Duration.zero;
      for (final song in songs) {
        if (song is LocalSong) {
          totalDuration += song.duration;
        } else if (song is OnlineSong && song.duration != null) {
          totalDuration += song.duration!;
        }
      }

      if (mounted) {
        setState(() {
          _playlist = playlist;
          _songs = songs;
          _totalDuration = totalDuration;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('加载歌单数据失败', error: e, tag: 'HivePlaylistDetail');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          foregroundColor: AppColors.getTextPrimary(context),
          iconTheme: IconThemeData(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.getPrimary(context),
          ),
        ),
      );
    }

    if (_playlist == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          foregroundColor: AppColors.getTextPrimary(context),
          iconTheme: IconThemeData(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        body: Center(
          child: Text(
            '歌单不存在',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 模糊背景
          _buildBlurredBackground(),
          
          // 主要内容
          RefreshIndicator(
            onRefresh: _loadPlaylistData,
            child: CustomScrollView(
              slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.getTextPrimary(context),
                iconTheme: IconThemeData(
                  color: AppColors.getTextPrimary(context),
                ),
                elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: _showMoreOptions,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 歌单封面
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildPlaylistCover(),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '歌单',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                                const SizedBox(height: AppDimensions.spacingS),
                                Text(
                                  _playlist!.name,
                                  style: AppTextStyles.displayMedium.copyWith(
                                    color: AppColors.getTextPrimary(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_playlist!.description != null && _playlist!.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text(
                                      _playlist!.description!,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.getTextSecondary(context),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.music_note,
                                      size: 14,
                                      color: AppColors.getTextSecondary(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_songs.length} 首',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.getTextSecondary(context),
                                      ),
                                    ),
                                    if (_totalDuration.inSeconds > 0) ...[
                                      Text(
                                        ' · ',
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.getTextSecondary(context),
                                        ),
                                      ),
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: AppColors.getTextSecondary(context),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        FormatUtils.formatDuration(_totalDuration),
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.getTextSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // 播放全部按钮
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _songs.isEmpty ? null : _playAll,
                      icon: const Icon(Icons.play_arrow, size: 22),
                      label: const Text(
                        '播放全部',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.getPrimary(context),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.getSurface(context),
                        disabledForegroundColor: AppColors.getTextSecondary(context),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 随机播放按钮
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _songs.isEmpty ? null : _shufflePlay,
                      icon: const Icon(Icons.shuffle, size: 20),
                      label: const Text(
                        '随机播放',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.getTextPrimary(context),
                        disabledForegroundColor: AppColors.getTextSecondary(context),
                        side: BorderSide(
                          color: _songs.isEmpty ? AppColors.getSurface(context) : AppColors.getTextPrimary(context),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _songs.isEmpty
              ? SliverFillRemaining(
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.music_note_outlined,
                            size: 80,
                            color: AppColors.getTextSecondary(context),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '歌单是空的',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '添加一些歌曲来开始吧',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _addSongsToPlaylist,
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text(
                              '添加歌曲',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.getPrimary(context),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = _songs[index];
                      return Container(
                        color: Colors.transparent,
                        child: SongTile(
                          song: song,
                          onTap: () => _playSong(song, index),
                          showIndex: true,
                          index: index + 1,
                          showAlbumArt: true,
                          backgroundColor: Colors.transparent,
                          textColor: AppColors.getTextPrimary(context),
                          showDuration: false, // 隐藏时长
                          onMorePressed: () => _showSongOptions(song),
                        ),
                      );
                    },
                    childCount: _songs.length,
                  ),
                ),
        ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建模糊背景
  Widget _buildBlurredBackground() {
    final coverImage = _playlist?.coverImage;
    final isDark = AppColors.isDark(context);
    
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景图片或默认背景
          if (coverImage != null && coverImage.isNotEmpty)
            _buildBackgroundImage(coverImage)
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          AppColors.getPrimary(context).withOpacity(0.3),
                          AppColors.getBackground(context),
                        ]
                      : [
                          AppColors.getPrimary(context).withOpacity(0.1),
                          AppColors.getBackground(context),
                        ],
                ),
              ),
            ),
          
          // 模糊效果（只在有封面图片时应用）
          if (coverImage != null && coverImage.isNotEmpty)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: isDark 
                    ? Colors.black.withOpacity(0.3)
                    : Colors.white.withOpacity(0.2),
              ),
            ),
          
          // 渐变遮罩（根据主题调整）
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.4),
                        AppColors.getBackground(context).withOpacity(0.8),
                      ]
                    : [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.3),
                        AppColors.getBackground(context).withOpacity(0.8),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建背景图片
  Widget _buildBackgroundImage(String coverImage) {
    // 使用主题色作为默认颜色
    final defaultColor = AppColors.getPrimary(context);
    
    if (coverImage.startsWith('color:')) {
      // 颜色封面
      final colorStr = coverImage.substring(6);
      final color = Color(int.parse('FF$colorStr', radix: 16));
      return Container(color: color);
    }
    
    if (coverImage.startsWith('http')) {
      // 网络图片
      return Image.network(
        coverImage,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  defaultColor,
                  defaultColor.withOpacity(0.7),
                ],
              ),
            ),
          );
        },
      );
    }
    
    // 本地图片
    return Image.file(
      File(coverImage),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                defaultColor,
                defaultColor.withOpacity(0.7),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistCover() {
    final coverImage = _playlist?.coverImage;
    
    // 使用主题色作为默认背景色
    final defaultColor = AppColors.getPrimary(context);

    if (coverImage == null) {
      // 没有封面，使用默认颜色
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: defaultColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.library_music,
          size: 60,
          color: Colors.white,
        ),
      );
    }
    
    if (coverImage.startsWith('color:')) {
      // 颜色封面
      final colorStr = coverImage.substring(6);
      final color = Color(int.parse('FF$colorStr', radix: 16));
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.library_music,
          size: 60,
          color: Colors.white,
        ),
      );
    }
    
    if (coverImage.startsWith('http')) {
      // 网络图片
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: defaultColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            coverImage,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.library_music,
                size: 60,
                color: Colors.white,
              );
            },
          ),
        ),
      );
    }
    
    // 本地图片
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: defaultColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(coverImage),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.library_music,
              size: 60,
              color: Colors.white,
            );
          },
        ),
      ),
    );
  }

  // 🎯 优化：使用 FormatUtils 统一格式化（带缓存）
  // String _formatDuration(Duration duration) { ... } 已移除

  void _playAll() {
    if (_songs.isNotEmpty) {
      _playSong(_songs.first, 0);
    }
  }

  void _shufflePlay() {
    if (_songs.isNotEmpty) {
      final shuffledSongs = List<Object>.from(_songs)..shuffle();
      _playSong(shuffledSongs.first, 0, playlist: shuffledSongs);
    }
  }

  void _playSong(dynamic song, int index, {List<Object>? playlist}) {
    // 使用全局播放服务 - 播放整个歌单（重置队列）
    final audioService = GlobalAudioService();
    audioService.playPlaylist(
      playlist: playlist ?? _songs,
      initialIndex: index,
    );
    
    // 打开播放器页面
    context.push(
      AppRoutes.player, 
      extra: PlayerArguments(
        song: song,
        playlist: playlist ?? _songs,
        initialIndex: index,
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽指示器
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getTextSecondary(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.library_add, color: AppColors.getTextPrimary(context)),
                title: Text(
                  '添加歌曲', 
                  style: TextStyle(color: AppColors.getTextPrimary(context)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addSongsToPlaylist();
                },
              ),
              ListTile(
                leading: Icon(Icons.edit, color: AppColors.getTextPrimary(context)),
                title: Text(
                  '编辑歌单', 
                  style: TextStyle(color: AppColors.getTextPrimary(context)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _editPlaylist();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除歌单', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deletePlaylist();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showSongOptions(dynamic song) {
    String songTitle = '未知歌曲';
    String songArtist = '未知艺人';
    
    if (song is LocalSong) {
      songTitle = song.title;
      songArtist = song.artist;
    } else if (song is OnlineSong) {
      songTitle = song.title;
      songArtist = song.artist;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽指示器
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getTextSecondary(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _buildSongCover(song),
                ),
                title: Text(
                  songTitle,
                  style: TextStyle(color: AppColors.getTextPrimary(context)),
                ),
                subtitle: Text(
                  songArtist,
                  style: TextStyle(color: AppColors.getTextSecondary(context)),
                ),
              ),
              Divider(color: AppColors.getDivider(context)),
              ListTile(
                leading: Icon(
                  Icons.remove_circle_outline, 
                  color: AppColors.getTextPrimary(context),
                ),
                title: Text(
                  '从歌单中移除', 
                  style: TextStyle(color: AppColors.getTextPrimary(context)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeSongFromPlaylist(song);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSongCover(dynamic song) {
    if (song is LocalSong && song.albumArt != null) {
      return Image.file(
        File(song.albumArt!),
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            color: AppColors.getSurface(context),
            child: Icon(
              Icons.music_note, 
              color: AppColors.getTextSecondary(context),
            ),
          );
        },
      );
    }
    
    return Container(
      width: 50,
      height: 50,
      color: AppColors.getSurface(context),
      child: Icon(
        Icons.music_note, 
        color: AppColors.getTextSecondary(context),
      ),
    );
  }

  /// 添加歌曲到歌单（直接弹出歌曲选择对话框）
  Future<void> _addSongsToPlaylist() async {
    if (_playlist == null) return;
    
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (context) => SongSelectorDialog(
          initialSelectedSongIds: _playlist!.songIds,
        ),
        fullscreenDialog: true,
      ),
    );
    
    if (result != null) {
      try {
        // 更新歌单的歌曲列表
        final updatedPlaylist = _playlist!.copyWith(
          songIds: result,
        );
        
        await PlaylistStorage.updatePlaylist(updatedPlaylist);
        
        // 重新加载数据
        await _loadPlaylistData();
        
        if (mounted) {
          final addedCount = result.length - _playlist!.songIds.length;
          final removedCount = _playlist!.songIds.length - result.length;
          
          String message;
          if (addedCount > 0 && removedCount > 0) {
            message = '歌单已更新：添加了 $addedCount 首，移除了 $removedCount 首歌曲';
          } else if (addedCount > 0) {
            message = '成功添加了 $addedCount 首歌曲';
          } else if (removedCount > 0) {
            message = '成功移除了 $removedCount 首歌曲';
          } else {
            message = '歌单未发生变化';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新失败: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _editPlaylist() async {
    if (_playlist == null) return;
    
    final result = await Navigator.of(rootNavigatorKey.currentContext!, rootNavigator: true).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => PlaylistEditorPage(
          title: '编辑歌单',
          confirmText: '保存',
          initialName: _playlist!.name,
          initialDescription: _playlist!.description,
          initialCoverImage: _playlist!.coverImage,
          initialSongIds: _playlist!.songIds,
        ),
      ),
    );
    
    if (result != null) {
      final name = result['name'] as String;
      final description = result['description'] as String?;
      final coverImage = result['coverImage'] as String?;
      final songIds = result['songIds'] as List<String>;
      
      try {
        final updatedPlaylist = _playlist!.copyWith(
          name: name,
          description: description,
          coverImage: coverImage,
          songIds: songIds,
        );
        
        await PlaylistStorage.updatePlaylist(updatedPlaylist);
        
        // 重新加载数据
        await _loadPlaylistData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('歌单更新成功'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新失败: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _deletePlaylist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.getSurface(context),
          title: Text(
            '确认删除',
            style: TextStyle(color: AppColors.getTextPrimary(context)),
          ),
          content: Text(
            '确定要删除歌单 "${_playlist!.name}" 吗？\n\n这不会删除歌单中的歌曲文件。',
            style: TextStyle(color: AppColors.getTextSecondary(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                '取消',
                style: TextStyle(color: AppColors.getTextPrimary(context)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await PlaylistStorage.deletePlaylist(_playlist!.id);
        
        if (mounted) {
          context.pop(true); // 传递 true 表示需要刷新
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('歌单 "${_playlist!.name}" 已删除'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeSongFromPlaylist(dynamic song) async {
    String songTitle = '未知歌曲';
    String? localSongId;
    String? onlineSongId;
    
    if (song is LocalSong) {
      songTitle = song.title;
      localSongId = song.id;
    } else if (song is OnlineSong) {
      songTitle = song.title;
      onlineSongId = song.id;
    } else {
      return; // 不支持的歌曲类型
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.getSurface(context),
          title: Text(
            '移除歌曲',
            style: TextStyle(color: AppColors.getTextPrimary(context)),
          ),
          content: Text(
            '确定要从歌单中移除 "$songTitle" 吗？',
            style: TextStyle(color: AppColors.getTextSecondary(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                '取消',
                style: TextStyle(color: AppColors.getTextPrimary(context)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('移除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        if (localSongId != null) {
          // 移除本地歌曲
          await PlaylistStorage.removeSongFromPlaylist(_playlist!.id, localSongId);
        } else if (onlineSongId != null) {
          // 移除在线歌曲
          await PlaylistStorage.removeOnlineSongFromPlaylist(_playlist!.id, onlineSongId);
        }
        
        // 重新加载数据
        await _loadPlaylistData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已从歌单中移除 "$songTitle"'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('移除失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

