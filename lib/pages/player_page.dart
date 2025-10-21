import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../models/local_song.dart';
import '../models/online_song.dart';
import '../models/lyric.dart';
import '../utils/song_action_helper.dart';
import '../utils/image_loader.dart';
import '../utils/format_utils.dart';
import '../services/global_audio_service.dart';
import '../widgets/lyric_view.dart';
import '../widgets/playlist_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// 播放器参数
class PlayerArguments {
  final dynamic song;
  final List<dynamic>? playlist;
  final int? initialIndex;

  PlayerArguments({
    required this.song,
    this.playlist,
    this.initialIndex,
  });
}

class PlayerPage extends StatefulWidget {
  final dynamic song; // 可以是Song或LocalSong类型
  final List<dynamic>? playlist; // 歌曲列表
  final int? initialIndex; // 初始索引

  const PlayerPage({
    super.key, 
    this.song,
    this.playlist,
    this.initialIndex,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with SingleTickerProviderStateMixin {
  // 使用全局音频服务
  final GlobalAudioService _audioService = GlobalAudioService();
  
  late AnimationController _rotationController;
  
  // 显示模式：true=显示歌词，false=显示封面
  bool _showLyrics = false;
  
  // 从全局服务获取状态
  dynamic get _currentSong => _audioService.currentSong;
  List<dynamic>? get _playlist => _audioService.playlist;
  bool get _isPlaying => _audioService.isPlaying;
  PlayMode get _playMode => _audioService.playMode;
  Duration get _duration => _audioService.totalDuration;

  // 获取歌曲标题
  String get _title {
    if (_currentSong == null) return '未知歌曲';
    if (_currentSong is OnlineSong) {
      return (_currentSong as OnlineSong).title;
    } else if (_currentSong is LocalSong) {
      return (_currentSong as LocalSong).title;
    }
    return '未知歌曲';
  }

  // 获取艺人
  String get _artist {
    if (_currentSong == null) return '未知艺人';
    if (_currentSong is OnlineSong) {
      return (_currentSong as OnlineSong).artist;
    } else if (_currentSong is LocalSong) {
      return (_currentSong as LocalSong).artist;
    }
    return '未知艺人';
  }

  // 获取专辑
  String get _album {
    if (_currentSong == null) return '未知专辑';
    if (_currentSong is OnlineSong) {
      return (_currentSong as OnlineSong).album;
    } else if (_currentSong is LocalSong) {
      return (_currentSong as LocalSong).album;
    }
    return '未知专辑';
  }

  // 获取专辑封面
  String? get _albumArt {
    if (_currentSong == null) return null;
    if (_currentSong is OnlineSong) {
      return (_currentSong as OnlineSong).albumArt;
    } else if (_currentSong is LocalSong) {
      return (_currentSong as LocalSong).albumArt;
    }
    return null;
  }
  
  // 获取当前歌曲的歌词内容（类似于封面的获取方式）
  String? get _lyricContent {
    if (_currentSong == null) return null;
    if (_currentSong is OnlineSong) {
      return (_currentSong as OnlineSong).lyric;
    } else if (_currentSong is LocalSong) {
      return (_currentSong as LocalSong).lyric;
    }
    return null;
  }
  

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    
    // 监听全局音频服务的状态变化
    _audioService.addListener(_onAudioServiceChanged);
    
    // 延迟到构建完成后隐藏悬浮播放器（因为已经在播放器页面了）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _audioService.setHideFloatingPlayer(true);
      }
    });
    
    // 初始化旋转动画
    if (_isPlaying) {
      _rotationController.repeat();
    }
  }
  
  /// 加载歌词（使用getter动态获取，类似于封面）
  List<LyricLine> _getLyrics() {
    // 使用getter获取当前歌曲的歌词内容
    String? lrcContent = _lyricContent;
    
    // 如果没有歌词，使用示例歌词来演示功能
    if (lrcContent == null || lrcContent.isEmpty) {
      const sampleLyric = '''
[00:00.00]欢迎使用歌词功能
[00:03.50]点击歌词可以切换回封面
[00:07.00]点击封面可以切换到歌词
[00:11.00]
[00:15.00]歌词会随着播放进度
[00:19.00]自动滚动到当前行
[00:23.00]
[00:27.00]当前高亮显示的
[00:31.00]就是正在播放的歌词
[00:35.00]
[00:39.00]支持标准的LRC格式
[00:43.00]时间轴精确到毫秒
[00:47.00]
[00:51.00]可以添加自己的歌词文件
[00:55.00]享受更好的音乐体验
[00:59.00]
[01:03.00]歌词功能已就绪
[01:07.00]让音乐更加生动
[01:11.00]
[01:15.00]谢谢使用
[01:19.00]🎵
''';
      lrcContent = sampleLyric;
    }
    
    return LyricParser.parse(lrcContent);
  }
  
  /// 切换显示模式（封面/歌词）
  void _toggleDisplayMode() {
    setState(() {
      _showLyrics = !_showLyrics;
    });
  }

  @override
  void dispose() {
    // 显示悬浮播放器（离开播放器页面）
    _audioService.setHideFloatingPlayer(false);
    
    _audioService.removeListener(_onAudioServiceChanged);
    _rotationController.dispose();
    super.dispose();
  }

  /// 音频服务状态变化回调
  void _onAudioServiceChanged() {
    if (!mounted) return;
    
    setState(() {
      // 状态会从getter自动获取
    });
    
    // 控制旋转动画
    if (_isPlaying) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop();
    }
  }

  void _togglePlayPause() async {
    await _audioService.togglePlayPause();
  }

  void _previousSong() {
    if (_playlist == null || _playlist!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可播放的歌曲列表')),
      );
      return;
    }

    // 循环播放上一首
    _audioService.playPrevious();
  }

  void _nextSong() {
    if (_playlist == null || _playlist!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可播放的歌曲列表')),
      );
      return;
    }

    // 循环播放下一首
    _audioService.playNext();
  }

  /// 获取播放模式对应的图标
  IconData _getPlayModeIcon() {
    switch (_playMode) {
      case PlayMode.sequence:
        return Icons.repeat; // 顺序循环
      case PlayMode.repeatOne:
        return Icons.repeat_one; // 单曲循环
      case PlayMode.shuffle:
        return Icons.shuffle; // 随机播放
    }
  }

  /// 切换播放模式
  void _togglePlayMode() {
    PlayMode newMode;
    switch (_playMode) {
      case PlayMode.sequence:
        newMode = PlayMode.repeatOne;
        break;
      case PlayMode.repeatOne:
        newMode = PlayMode.shuffle;
        break;
      case PlayMode.shuffle:
        newMode = PlayMode.sequence;
        break;
    }
    
    // 更新全局服务的播放模式
    _audioService.setPlayMode(newMode);
    
    // 显示提示
    String modeText;
    switch (newMode) {
      case PlayMode.sequence:
        modeText = '顺序循环';
        break;
      case PlayMode.repeatOne:
        modeText = '单曲循环';
        break;
      case PlayMode.shuffle:
        modeText = '随机播放';
        break;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(modeText),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  // 🎯 优化：使用 FormatUtils 统一格式化（带缓存）
  // String _formatDuration(Duration duration) { ... } 已移除

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        extendBody: true,
        body: Stack(
          children: [
            // 模糊背景
            _buildBlurredBackground(),
            
            // 主要内容
            _buildMainContent(),
          ],
        ),
      ),
    );
  }

  /// 构建模糊背景
  Widget _buildBlurredBackground() {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景图片
          if (_albumArt != null && _albumArt!.isNotEmpty)
            _buildBackgroundImage()
          else
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.getPrimaryGradient(context), // 使用主题渐变
              ),
            ),
          
          // 模糊效果
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(
              color: AppColors.getBackground(context).withOpacity(0.3),
            ),
          ),
          
          // 渐变遮罩
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.getBackground(context).withOpacity(0.3),
                  AppColors.getBackground(context).withOpacity(0.6),
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
  Widget _buildBackgroundImage() {
    return ImageLoader.loadAlbumArt(
      albumArt: _albumArt,
      fit: BoxFit.cover,
      errorWidget: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getPrimaryGradient(context),
        ),
      ),
    );
  }

  /// 构建主要内容
  Widget _buildMainContent() {
    return Scaffold(
      backgroundColor: Colors.transparent,
        appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.getTextPrimary(context),
        iconTheme: IconThemeData(
          color: AppColors.getTextPrimary(context),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              _title,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _artist,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreOptions(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 封面/歌词显示区域（占据所有剩余空间）
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingM,
                vertical: AppDimensions.spacingL,
              ),
              child: _buildCenterDisplay(),
            ),
          ),
          
          // 底部控制区域（固定位置）
          Container(
            padding: EdgeInsets.only(
              left: AppDimensions.spacingM,
              right: AppDimensions.spacingM,
              top: AppDimensions.spacingM,
              bottom: AppDimensions.spacingM + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 进度条（优化：使用 ValueListenableBuilder 只更新进度条部分）
                ValueListenableBuilder<Duration>(
                  valueListenable: _audioService.positionNotifier,
                  builder: (context, position, child) {
                    final currentProgress = _duration.inSeconds > 0 
                        ? position.inSeconds / _duration.inSeconds 
                        : 0.0;
                    
                    return Column(
                      children: [
                        // 进度条（使用渐变色）
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            activeTrackColor: AppColors.getPrimary(context),
                            inactiveTrackColor: AppColors.getTextSecondary(context).withOpacity(0.3),
                            thumbColor: AppColors.getPrimary(context),
                            overlayColor: AppColors.getPrimary(context).withOpacity(0.3),
                          ),
                          child: Slider(
                            value: currentProgress.clamp(0.0, 1.0),
                            onChanged: (value) async {
                              final newPosition = Duration(
                                seconds: (value * _duration.inSeconds).round()
                              );
                              await _audioService.seek(newPosition);
                            },
                          ),
                        ),
                        // 时间显示
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingM),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                FormatUtils.formatDuration(position),
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                              Text(
                                FormatUtils.formatDuration(_duration),
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: AppDimensions.spacingL),
                
                // 控制按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 播放模式按钮
                    IconButton(
                      icon: Icon(
                        _getPlayModeIcon(),
                        color: _playMode == PlayMode.sequence 
                            ? AppColors.getTextSecondary(context) 
                            : AppColors.getPrimary(context),
                        size: 28,
                      ),
                      onPressed: _togglePlayMode,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous,
                        color: AppColors.getTextPrimary(context),
                        size: 40,
                      ),
                      onPressed: _previousSong,
                    ),
                    // 播放/暂停按钮（带渐变背景）
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: AppColors.getPrimaryGradient(context),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.skip_next,
                        color: AppColors.getTextPrimary(context),
                        size: 40,
                      ),
                      onPressed: _nextSong,
                    ),
                    // 歌曲列表
                    IconButton(
                      icon: Icon(
                        Icons.list,
                        color: AppColors.getTextSecondary(context),
                        size: 28,
                      ),
                      onPressed: _showPlaylistDialog,
                    ),
                  ],
                ),
                
                const SizedBox(height: AppDimensions.spacingS),
                
                // 底部操作栏
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      // 收藏按钮
                      IconButton(
                        icon: Icon(
                          Icons.favorite_border,
                          color: AppColors.getTextSecondary(context),
                        ),
                        onPressed: _handleFavorite,
                      ),
                      const SizedBox(width: AppDimensions.spacingL),
                      // 下载按钮（仅在线歌曲显示）
                      if (_currentSong is OnlineSong)
                        SongActionHelper.buildDownloadButton(
                          context,
                          _currentSong as OnlineSong,
                          iconColor: AppColors.getTextSecondary(context),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getSurface(context),
      useRootNavigator: true,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info, color: Colors.white),
              title: const Text('歌曲信息', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                _showSongInfo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.album, color: Colors.white),
              title: const Text('查看专辑', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                // 跳转到专辑页面
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white),
              title: const Text('查看艺人', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                // 跳转到艺人页面
              },
            ),
          ],
        );
      },
    );
  }

  void _showSongInfo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('歌曲信息'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('标题: $_title'),
              Text('艺人: $_artist'),
              Text('专辑: $_album'),
              Text('时长: ${FormatUtils.formatDuration(_duration)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  /// 处理收藏操作
  void _handleFavorite() {
    if (_currentSong == null) return;

    if (_currentSong is OnlineSong) {
      // 在线歌曲：显示歌单选择并自动下载
      SongActionHelper.showFavoriteDialog(
        context,
        _currentSong as OnlineSong,
      );
    } else if (_currentSong is LocalSong) {
      // 本地歌曲：直接添加到歌单
      SongActionHelper.showFavoriteDialogForLocal(
        context,
        _currentSong as LocalSong,
      );
    }
  }

  /// 显示播放列表对话框
  void _showPlaylistDialog() {
    if (_playlist == null || _playlist!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前没有播放列表'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,  // ✅ 点击空白处关闭
      barrierColor: Colors.black54,  // ✅ 半透明遮罩
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        
        // 使用 Column 布局：上方空白 + 下方列表
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 上方空白区域 - 点击会关闭（由 isDismissible 自动处理）
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
            // 底部播放列表 - 固定高度 60%
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.6,
              ),
              child: const PlaylistDialog(),
            ),
          ],
        );
      },
    );
  }


  /// 构建中央显示区域（封面或歌词）
  Widget _buildCenterDisplay() {
    // 使用 PageView 实现左右滑动切换
    return GestureDetector(
      // 横向拖动手势
      onHorizontalDragEnd: (details) {
        // 根据滑动方向切换
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0) {
            // 向右滑动：切换到封面
            if (_showLyrics) {
              setState(() => _showLyrics = false);
            }
          } else if (details.primaryVelocity! < 0) {
            // 向左滑动：切换到歌词
            if (!_showLyrics) {
              setState(() => _showLyrics = true);
            }
          }
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _showLyrics ? _buildLyricWidget() : _buildCoverWidget(),
      ),
    );
  }

  /// 构建歌词组件
  Widget _buildLyricWidget() {
    return ValueListenableBuilder<Duration>(
      key: const ValueKey('lyrics'), // 用于 AnimatedSwitcher
      valueListenable: _audioService.positionNotifier,
      builder: (context, position, child) {
        return Stack(
          children: [
            // 歌词列表（占满整个区域）
            Positioned.fill(
              child: GestureDetector(
                // 长按切换回封面
                onLongPress: () {
                  setState(() => _showLyrics = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已切换到封面'),
                      duration: Duration(milliseconds: 800),
                    ),
                  );
                },
                child: LyricView(
                  lyrics: _getLyrics(),
                  currentPosition: position,
                  onSeek: (duration) async {
                    // 点击歌词跳转到指定时间
                    await _audioService.seek(duration);
                  },
                ),
              ),
            ),
            
            // 底部提示
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: AppColors.getTextSecondary(context).withOpacity(0.6),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '点击歌词跳转 | 长按或右滑返回',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.getTextSecondary(context).withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建封面组件
  Widget _buildCoverWidget() {
    return LayoutBuilder(
      key: const ValueKey('cover'), // 用于 AnimatedSwitcher
      builder: (context, constraints) {
        // 计算合适的封面尺寸（取宽高最小值，保持正方形）
        final size = constraints.maxWidth < constraints.maxHeight 
            ? constraints.maxWidth * 0.85 
            : constraints.maxHeight * 0.85;
        
        return Stack(
          alignment: Alignment.center,
          children: [
            // 专辑封面
            Center(
              child: GestureDetector(
                onTap: _toggleDisplayMode,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: AnimatedBuilder(
                      animation: _rotationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationController.value * 2 * 3.14159,
                          child: _buildAlbumArtWidget(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            
            // 底部提示（淡化显示）
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 14,
                      color: AppColors.getTextSecondary(context).withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '点击或左滑查看歌词',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.getTextSecondary(context).withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  /// 构建专辑封面组件
  Widget _buildAlbumArtWidget() {
    return ImageLoader.loadAlbumArt(
      albumArt: _albumArt,
      fit: BoxFit.cover,
    );
  }
}
