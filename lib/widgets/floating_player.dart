import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../services/global_audio_service.dart';
import '../utils/image_loader.dart';
import '../routes/app_routes.dart';
import '../pages/player_page.dart';
import '../theme/app_dimensions.dart';

/// 全局悬浮播放器组件（增强版）
class FloatingPlayer extends StatefulWidget {
  const FloatingPlayer({super.key});

  @override
  State<FloatingPlayer> createState() => _FloatingPlayerState();
}

class _FloatingPlayerState extends State<FloatingPlayer>
    with SingleTickerProviderStateMixin {
  final GlobalAudioService _audioService = GlobalAudioService();

  // 悬浮球位置
  double? _left;
  double? _top;

  // 悬浮球大小
  static const double _size = 68; // 稍微增大

  // 拖动状态
  bool _isDragging = false;
  bool _hasMoved = false;
  Offset _startPosition = Offset.zero;

  // 是否已设置初始位置
  bool _hasSetInitialPosition = false;

  // 动画控制器
  late AnimationController _rotationController;
  
  // 🎯 优化：缓存需要监听的状态，避免不必要的重建
  Object? _lastSong;
  bool _lastIsPlaying = false;
  bool _lastHideFloatingPlayer = false;
  String? _lastAlbumArt;

  @override
  void initState() {
    super.initState();

    // 旋转动画
    _rotationController = AnimationController(
      duration: AppDimensions.durationRotation,
      vsync: this,
    );

    // 🎯 优化：选择性监听，只在关键状态变化时重建
    _audioService.addListener(_onAudioServiceChanged);
    
    // 初始化缓存状态
    _lastSong = _audioService.currentSong;
    _lastIsPlaying = _audioService.isPlaying;
    _lastHideFloatingPlayer = _audioService.hideFloatingPlayer;
    _lastAlbumArt = _audioService.currentAlbumArt;

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
    if (!mounted) return;
    
    // 🎯 优化：只在关键状态变化时才重建 Widget
    final currentSong = _audioService.currentSong;
    final currentIsPlaying = _audioService.isPlaying;
    final currentHideFloatingPlayer = _audioService.hideFloatingPlayer;
    final currentAlbumArt = _audioService.currentAlbumArt;
    
    // 检查是否有实质性变化
    final songChanged = currentSong != _lastSong;
    final playingChanged = currentIsPlaying != _lastIsPlaying;
    final hideChanged = currentHideFloatingPlayer != _lastHideFloatingPlayer;
    final albumArtChanged = currentAlbumArt != _lastAlbumArt;
    
    // 如果没有任何变化，不触发重建（避免position变化导致的重建）
    if (!songChanged && !playingChanged && !hideChanged && !albumArtChanged) {
      return;
    }
    
    // 更新缓存
    _lastSong = currentSong;
    _lastIsPlaying = currentIsPlaying;
    _lastHideFloatingPlayer = currentHideFloatingPlayer;
    _lastAlbumArt = currentAlbumArt;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // 只有在需要时才重建
      setState(() {});

      // 控制旋转动画
      if (currentIsPlaying) {
        if (!_rotationController.isAnimating) {
          _rotationController.repeat();
        }
      } else {
        _rotationController.stop();
      }
    });
  }

  void _openPlayerPage() {
    final currentSong = _audioService.currentSong;
    final playlist = _audioService.playlist;
    final currentIndex = _audioService.currentIndex;

    if (currentSong == null) return;

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
    if (!_audioService.hasSong || _audioService.hideFloatingPlayer) {
      return const SizedBox.shrink();
    }

    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return const SizedBox.shrink();
    }

    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // 设置初始位置（右下角）
    if (!_hasSetInitialPosition) {
      _left = screenWidth - _size - AppDimensions.spacingM;
      _top = screenHeight - _size - 100; // 留出底部导航栏空间
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
            _left = (_left! + details.delta.dx)
                .clamp(0.0, screenWidth - _size);
            _top = (_top! + details.delta.dy)
                .clamp(0.0, screenHeight - _size);

            final distance =
                (details.globalPosition - _startPosition).distance;
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
        child: AnimatedScale(
          scale: _isDragging ? 1.05 : 1.0,
          duration: AppDimensions.durationFast,
          child: _buildFloatingPlayer(),
        ),
      ),
    );
  }

  /// 构建悬浮播放器
  Widget _buildFloatingPlayer() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(_isDragging ? 0.4 : 0.3),
            blurRadius: _isDragging ? 20 : 15,
            spreadRadius: _isDragging ? 3 : 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              // 背景渐变
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // 专辑封面（带旋转）
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * math.pi,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: ClipOval(
                        child: ImageLoader.loadAlbumArt(
                          albumArt: _audioService.currentAlbumArt,
                          width: _size - 8,
                          height: _size - 8,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // 半透明遮罩
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
                    ],
                  ),
                ),
              ),

              // 播放/暂停图标
              Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(
                      _audioService.isPlaying ? 0 : 0.6,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(
                        _audioService.isPlaying ? 0.6 : 0,
                      ),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _audioService.isPlaying
                        ? Icons.music_note
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: _audioService.isPlaying ? 18 : 20,
                  ),
                ),
              ),

              // 进度环（圆形进度条）
              _buildProgressRing(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建进度环
  Widget _buildProgressRing() {
    return ValueListenableBuilder<Duration>(
      valueListenable: _audioService.positionNotifier,
      builder: (context, position, child) {
        final progress = _audioService.totalDuration.inSeconds > 0
            ? position.inSeconds / _audioService.totalDuration.inSeconds
            : 0.0;

        return CustomPaint(
          size: const Size(_size, _size),
          painter: _ProgressRingPainter(
            progress: progress,
            color: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.2),
          ),
        );
      },
    );
  }
}

/// 进度环绘制器
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // 背景圆环
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // 进度圆环
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2; // 从顶部开始
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

