import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/global_audio_service.dart';
import '../utils/image_loader.dart';
import '../routes/app_routes.dart';
import '../pages/player_page.dart';

/// 全局悬浮播放器组件
class FloatingPlayer extends StatefulWidget {
  const FloatingPlayer({super.key});

  @override
  State<FloatingPlayer> createState() => _FloatingPlayerState();
}

class _FloatingPlayerState extends State<FloatingPlayer> with SingleTickerProviderStateMixin {
  final GlobalAudioService _audioService = GlobalAudioService();
  
  // 悬浮球位置（初始值会在第一次build时设置为右下角）
  double? _left;
  double? _top;

  // 悬浮球大小
  static const double _size = 60;
  
  // 拖动状态
  bool _isDragging = false;
  bool _hasMoved = false;
  Offset _startPosition = Offset.zero;
  
  // 是否已经设置初始位置
  bool _hasSetInitialPosition = false;

  // 旋转动画控制器
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    
    // 初始化旋转动画控制器
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10), // 旋转一圈需要10秒
      vsync: this,
    );
    
    // 监听音频服务变化
    _audioService.addListener(_onAudioServiceChanged);
    
    // 根据初始播放状态决定是否开始动画
    if (_audioService.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _audioService.removeListener(_onAudioServiceChanged);
    super.dispose();
  }

  void _onAudioServiceChanged() {
    if (mounted) {
      // 延迟到当前帧构建完成后再调用 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
          
          // 根据播放状态控制旋转动画
          if (_audioService.isPlaying) {
            if (!_rotationController.isAnimating) {
              _rotationController.repeat();
            }
          } else {
            _rotationController.stop();
          }
        }
      });
    }
  }

  /// 打开播放器页面
  void _openPlayerPage() {
    final currentSong = _audioService.currentSong;
    final playlist = _audioService.playlist;
    final currentIndex = _audioService.currentIndex;
    
    if (currentSong == null) return;
    
    // 使用 PlayerPage 直接导航
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext != null) {
      navigatorContext.push(
        AppRoutes.player,
        extra: PlayerArguments(
          song: currentSong,
          playlist: playlist ?? [currentSong],
          initialIndex: currentIndex,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果没有歌曲在播放，不显示
    if (!_audioService.hasSong) {
      return const SizedBox.shrink();
    }

    // 如果设置了隐藏悬浮球（在播放器页面），不显示
    if (_audioService.hideFloatingPlayer) {
      return const SizedBox.shrink();
    }

    // 获取屏幕尺寸
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return const SizedBox.shrink();
    }
    
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // 第一次构建时设置初始位置为右下角
    if (!_hasSetInitialPosition) {
      _left = screenWidth - _size - 20; // 距离右边20像素
      _top = screenHeight - _size - 80; // 距离底部80像素（留出底部导航栏空间）
      _hasSetInitialPosition = true;
    }

    return Positioned(
      left: _left!,
      top: _top!,
      child: GestureDetector(
        onTapDown: (details) {
          _startPosition = details.globalPosition;
          _hasMoved = false;
        },
        onTapUp: (details) {
          // 如果没有移动（或移动很小），就打开播放器
          if (!_hasMoved) {
            _openPlayerPage();
          }
        },
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
            _hasMoved = false;
            _startPosition = details.globalPosition;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            // 更新位置，确保不超出屏幕边界
            _left = (_left! + details.delta.dx).clamp(0.0, screenWidth - _size);
            _top = (_top! + details.delta.dy).clamp(0.0, screenHeight - _size);
            
            // 检查是否真的移动了
            final distance = (details.globalPosition - _startPosition).distance;
            if (distance > 10) {
              _hasMoved = true;
            }
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        child: _buildPlayerCircle(isDragging: _isDragging),
      ),
    );
  }

  /// 构建播放器圆形组件
  Widget _buildPlayerCircle({bool isDragging = false}) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( isDragging ? 0.5 : 0.3),
            blurRadius: isDragging ? 15 : 10,
            spreadRadius: isDragging ? 2 : 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // 专辑封面（带旋转动画）
          RotationTransition(
            turns: _rotationController,
            child: ClipOval(
              child: _buildAlbumArt(),
            ),
          ),
          
          // 播放状态指示器
          if (!_audioService.isPlaying)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity( 0.5),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          
          // 旋转动画边框（播放时）
          if (_audioService.isPlaying)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity( 0.8),
                  width: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建专辑封面
  Widget _buildAlbumArt() {
    return ImageLoader.loadAlbumArt(
      albumArt: _audioService.currentAlbumArt,
      width: _size,
      height: _size,
      fit: BoxFit.cover,
    );
  }

}

