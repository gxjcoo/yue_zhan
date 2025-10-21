import 'package:flutter/material.dart';
import '../models/lyric.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 歌词显示组件
class LyricView extends StatefulWidget {
  final List<LyricLine> lyrics; // 歌词列表
  final Duration currentPosition; // 当前播放位置
  final Function(Duration)? onSeek; // 跳转回调（点击歌词跳转）

  const LyricView({
    super.key,
    required this.lyrics,
    required this.currentPosition,
    this.onSeek,
  });

  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView> {
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = -1;
  DateTime? _lastUserInteraction; // 最后一次用户交互时间
  bool _isUserDragging = false; // 标记用户是否正在拖动

  @override
  void initState() {
    super.initState();
    // 不再需要监听滚动事件，改用手势检测
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 用户开始拖动歌词
  void _onUserDragStart() {
    _isUserDragging = true;
    _lastUserInteraction = DateTime.now();
  }

  /// 用户结束拖动歌词
  void _onUserDragEnd() {
    _isUserDragging = false;
  }

  @override
  void didUpdateWidget(LyricView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.currentPosition != oldWidget.currentPosition) {
      _updateCurrentLine();
    }
  }

  /// 更新当前歌词行
  void _updateCurrentLine() {
    if (widget.lyrics.isEmpty) return;

    final newIndex = LyricParser.findCurrentIndex(
      widget.lyrics,
      widget.currentPosition,
    );

    if (newIndex != _currentIndex && newIndex >= 0) {
      setState(() {
        _currentIndex = newIndex;
      });

      // 自动滚动到当前歌词
      _scrollToIndex(newIndex);
    }
  }

  /// 滚动到指定索引
  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;

    // 只有在用户正在拖动歌词时才阻止自动滚动
    if (_isUserDragging) {
      return;
    }

    // 如果用户最近2秒内拖动过歌词，则不自动滚动
    if (_lastUserInteraction != null) {
      final timeSinceInteraction = DateTime.now().difference(_lastUserInteraction!);
      if (timeSinceInteraction.inSeconds < 2) {
        return;
      } else {
        // 超过2秒，恢复自动滚动
        _lastUserInteraction = null;
      }
    }

    const itemHeight = 50.0; // 每行歌词的高度
    final offset = index * itemHeight - 50; // 偏移，让当前歌词显示在靠上的位置

    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic, // 更平滑的曲线
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return Container(
        color: Colors.transparent,
        child: Center(
          child: Text(
            '暂无歌词',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.getTextSecondary(context).withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // 检测用户手动拖动
        if (notification is ScrollStartNotification) {
          // 检查是否是用户手势触发的滚动（有 dragDetails）
          if (notification.dragDetails != null) {
            _onUserDragStart();
          }
        } else if (notification is ScrollEndNotification) {
          // 用户结束拖动
          if (_isUserDragging) {
            _onUserDragEnd();
          }
        }
        return false; // 不拦截事件，继续传递
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.lyrics.length,
        padding: const EdgeInsets.symmetric(vertical: 50),
        physics: const BouncingScrollPhysics(), // 弹性滚动
        itemBuilder: (context, index) {
          final isCurrentLine = index == _currentIndex;
          final lyric = widget.lyrics[index];

          return GestureDetector(
            onTap: () {
              // 点击跳转到该歌词对应的时间点
              if (widget.onSeek != null) {
                widget.onSeek!(lyric.timestamp);
                // 立即更新当前行，提供即时反馈
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            child: Container(
              height: 50,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTextStyles.bodyLarge.copyWith(
                  fontSize: isCurrentLine ? 20 : 16,
                  fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.normal,
                  color: isCurrentLine
                      ? AppColors.getTextPrimary(context)
                      : AppColors.getTextSecondary(context).withOpacity(0.5),
                  height: 1.5,
                ),
                child: Text(
                  lyric.text,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

