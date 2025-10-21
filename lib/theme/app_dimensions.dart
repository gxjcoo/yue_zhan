import 'package:flutter/material.dart';

/// 应用尺寸规范
class AppDimensions {
  AppDimensions._();

  // ==================== 间距系统（基于8px） ====================
  
  /// 超小间距 - 4px
  static const double spacingXs = 4.0;
  
  /// 小间距 - 8px
  static const double spacingS = 8.0;
  
  /// 中间距 - 16px
  static const double spacingM = 16.0;
  
  /// 大间距 - 24px
  static const double spacingL = 24.0;
  
  /// 超大间距 - 32px
  static const double spacingXl = 32.0;
  
  /// 极大间距 - 48px
  static const double spacingXxl = 48.0;

  // ==================== 圆角系统（Material Design 3风格） ====================
  
  /// 小圆角 - 8px（按钮、标签）
  static const double radiusS = 8.0;
  
  /// 中圆角 - 12px（封面、卡片内部）
  static const double radiusM = 12.0;
  
  /// 大圆角 - 20px（主卡片）- 更现代的圆角
  static const double radiusL = 20.0;
  
  /// 超大圆角 - 28px（特殊卡片）- 更圆润
  static const double radiusXl = 28.0;
  
  /// 全圆角 - 9999px（圆形元素）
  static const double radiusFull = 9999.0;

  // ==================== BorderRadius预定义 ====================
  
  static BorderRadius get borderRadiusS => BorderRadius.circular(radiusS);
  static BorderRadius get borderRadiusM => BorderRadius.circular(radiusM);
  static BorderRadius get borderRadiusL => BorderRadius.circular(radiusL);
  static BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);
  static BorderRadius get borderRadiusFull => BorderRadius.circular(radiusFull);
  
  /// 顶部圆角
  static BorderRadius get borderRadiusTopM => const BorderRadius.vertical(
        top: Radius.circular(radiusM),
      );
  
  static BorderRadius get borderRadiusTopL => const BorderRadius.vertical(
        top: Radius.circular(radiusL),
      );
  
  /// 底部圆角
  static BorderRadius get borderRadiusBottomM => const BorderRadius.vertical(
        bottom: Radius.circular(radiusM),
      );

  // ==================== 图标尺寸 ====================
  
  /// 超小图标 - 16px
  static const double iconXs = 16.0;
  
  /// 小图标 - 20px
  static const double iconS = 20.0;
  
  /// 中图标 - 24px
  static const double iconM = 24.0;
  
  /// 大图标 - 28px
  static const double iconL = 28.0;
  
  /// 超大图标 - 32px
  static const double iconXl = 32.0;
  
  /// 主按钮图标 - 48px
  static const double iconXxl = 48.0;

  // ==================== 按钮尺寸 ====================
  
  /// 小按钮高度 - 32px
  static const double buttonHeightS = 32.0;
  
  /// 中按钮高度 - 40px
  static const double buttonHeightM = 40.0;
  
  /// 大按钮高度 - 48px
  static const double buttonHeightL = 48.0;
  
  /// 超大按钮高度 - 56px
  static const double buttonHeightXl = 56.0;
  
  /// 播放按钮尺寸 - 72px
  static const double playButtonSize = 72.0;
  
  /// 次要控制按钮 - 48px
  static const double controlButtonSize = 48.0;

  // ==================== 封面尺寸 ====================
  
  /// 极小封面 - 40x40px（列表缩略图）
  static const double albumArtXs = 40.0;
  
  /// 小封面 - 56x56px（列表项）
  static const double albumArtS = 56.0;
  
  /// 中封面 - 80x80px（mini播放器）
  static const double albumArtM = 80.0;
  
  /// 大封面 - 120x120px（卡片）
  static const double albumArtL = 120.0;
  
  /// 超大封面 - 160x160px（歌单）
  static const double albumArtXl = 160.0;
  
  /// 播放器封面（屏幕宽度的75%）
  static double albumArtPlayer(BuildContext context) {
    return MediaQuery.of(context).size.width * 0.75;
  }

  // ==================== 列表项尺寸 ====================
  
  /// 列表项高度 - 72px
  static const double listItemHeight = 72.0;
  
  /// 紧凑列表项高度 - 56px
  static const double listItemHeightCompact = 56.0;
  
  /// 大列表项高度 - 88px
  static const double listItemHeightLarge = 88.0;

  // ==================== 卡片尺寸 ====================
  
  /// 小卡片高度 - 120px
  static const double cardHeightS = 120.0;
  
  /// 中卡片高度 - 160px
  static const double cardHeightM = 160.0;
  
  /// 大卡片高度 - 200px
  static const double cardHeightL = 200.0;

  // ==================== 导航栏高度 ====================
  
  /// 底部导航栏高度 - 72px
  static const double bottomNavHeight = 72.0;
  
  /// AppBar高度 - 56px（默认）
  static const double appBarHeight = 56.0;
  
  /// Mini播放器高度 - 64px
  static const double miniPlayerHeight = 64.0;

  // ==================== 页面边距 ====================
  
  /// 页面水平边距 - 16px
  static const double pageHorizontalPadding = spacingM;
  
  /// 页面垂直边距 - 16px
  static const double pageVerticalPadding = spacingM;
  
  /// 页面完整边距
  static const EdgeInsets pagePadding = EdgeInsets.all(pageHorizontalPadding);
  
  /// 页面水平边距
  static const EdgeInsets pageHorizontalPaddingOnly = EdgeInsets.symmetric(
    horizontal: pageHorizontalPadding,
  );

  // ==================== 阴影（Material Design 3风格） ====================
  
  /// 小阴影 - 轻微提升
  static List<BoxShadow> get shadowS => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 1),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 4,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];
  
  /// 中阴影 - 中等提升
  static List<BoxShadow> get shadowM => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 6,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];
  
  /// 大阴影 - 明显提升
  static List<BoxShadow> get shadowL => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 10,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];
  
  /// 超大阴影 - 高层提升
  static List<BoxShadow> get shadowXl => [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 32,
          offset: const Offset(0, 16),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.14),
          blurRadius: 16,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
      ];
  
  /// 唱片阴影（多层）
  static List<BoxShadow> get shadowAlbum => [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 30,
          offset: const Offset(0, 15),
          spreadRadius: 5,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 60,
          offset: const Offset(0, 25),
          spreadRadius: 10,
        ),
      ];

  // ==================== 动画时长 ====================
  
  /// 快速动画 - 100ms
  static const Duration durationFast = Duration(milliseconds: 100);
  
  /// 正常动画 - 200ms
  static const Duration durationNormal = Duration(milliseconds: 200);
  
  /// 中等动画 - 300ms
  static const Duration durationMedium = Duration(milliseconds: 300);
  
  /// 慢速动画 - 500ms
  static const Duration durationSlow = Duration(milliseconds: 500);
  
  /// 唱片旋转 - 10s
  static const Duration durationRotation = Duration(seconds: 10);

  // ==================== 其他 ====================
  
  /// 分割线粗细
  static const double dividerThickness = 1.0;
  
  /// 进度条高度（未触摸）
  static const double progressBarHeight = 3.0;
  
  /// 进度条高度（触摸时）
  static const double progressBarHeightActive = 6.0;
  
  /// 搜索框高度
  static const double searchBarHeight = 48.0;
  
  /// 标签高度
  static const double chipHeight = 36.0;
}

