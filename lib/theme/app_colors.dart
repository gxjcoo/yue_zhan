import 'package:flutter/material.dart';

/// 应用配色方案
class AppColors {
  AppColors._();

  // ==================== 主色调（默认/备用） ====================
  
  /// 主紫色 - 品牌色（默认）
  /// 注意：应优先使用 Theme.of(context).colorScheme.primary 来获取动态主题色
  static const Color primary = Color(0xFF8B5CF6);
  
  /// 粉色 - 强调色（默认）
  /// 注意：应优先使用 Theme.of(context).colorScheme.secondary 来获取动态主题色
  static const Color secondary = Color(0xFFEC4899);
  
  // ==================== 动态主题色获取方法 ====================
  
  /// 从上下文获取主色（推荐使用）
  static Color getPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }
  
  /// 从上下文获取副色（推荐使用）
  static Color getSecondary(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }
  
  /// 从上下文获取主题渐变（推荐使用）
  static Gradient getPrimaryGradient(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, secondary],
    );
  }
  
  // ==================== 自适应颜色获取方法 ====================
  
  /// 判断是否为深色模式
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
  
  /// 获取自适应背景色
  static Color getBackground(BuildContext context) {
    return isDark(context) ? backgroundDark : backgroundLight;
  }
  
  /// 获取自适应卡片背景色
  static Color getCard(BuildContext context) {
    return isDark(context) ? cardDark : cardLight;
  }
  
  /// 获取自适应表面色
  static Color getSurface(BuildContext context) {
    return isDark(context) ? surfaceDark : surfaceLight;
  }
  
  /// 获取自适应主文字色
  static Color getTextPrimary(BuildContext context) {
    return isDark(context) ? textPrimaryDark : textPrimaryLight;
  }
  
  /// 获取自适应次要文字色
  static Color getTextSecondary(BuildContext context) {
    return isDark(context) ? textSecondaryDark : textSecondaryLight;
  }
  
  /// 获取自适应说明文字色
  static Color getTextTertiary(BuildContext context) {
    return isDark(context) ? textTertiaryDark : textTertiaryLight;
  }
  
  /// 获取自适应分割线色
  static Color getDivider(BuildContext context) {
    return isDark(context) ? dividerDark : dividerLight;
  }
  
  /// 成功色（绿色）- 用于已下载、成功状态
  static const Color success = Color(0xFF22C55E);
  
  /// 警告色（橙色）
  static const Color warning = Color(0xFFF59E0B);
  
  /// 错误色（红色）
  static const Color error = Color(0xFFEF4444);
  
  /// 信息色（蓝色）
  static const Color info = Color(0xFF3B82F6);

  // ==================== 背景色（深色主题） ====================
  
  /// 主背景色 - 更现代的深灰色
  static const Color backgroundDark = Color(0xFF0F0F0F);
  
  /// 卡片背景色 - 与背景有更好的对比
  static const Color cardDark = Color(0xFF1C1C1E);
  
  /// 悬浮卡片背景 - 更柔和
  static const Color surfaceDark = Color(0xFF252527);
  
  /// 分割线颜色 - 更细腻
  static const Color dividerDark = Color(0xFF2C2C2E);

  // ==================== 背景色（浅色主题） ====================
  
  /// 主背景色 - 柔和的浅灰
  static const Color backgroundLight = Color(0xFFF8F9FA);
  
  /// 卡片背景色 - 纯白
  static const Color cardLight = Color(0xFFFFFFFF);
  
  /// 悬浮卡片背景
  static const Color surfaceLight = Color(0xFFF0F0F0);
  
  /// 分割线颜色 - 更细腻
  static const Color dividerLight = Color(0xFFE8E8E8);

  // ==================== 文字颜色（深色主题） ====================
  
  /// 主文字 - 略微柔和
  static const Color textPrimaryDark = Color(0xFFF5F5F7);
  
  /// 次要文字
  static const Color textSecondaryDark = Color(0xFFD1D1D6);
  
  /// 说明文字 - 更柔和
  static const Color textTertiaryDark = Color(0xFF8E8E93);
  
  /// 禁用文字
  static const Color textDisabledDark = Color(0xFF636366);

  // ==================== 文字颜色（浅色主题） ====================
  
  /// 主文字 - 略微柔和的黑
  static const Color textPrimaryLight = Color(0xFF1C1C1E);
  
  /// 次要文字
  static const Color textSecondaryLight = Color(0xFF3A3A3C);
  
  /// 说明文字 - iOS风格
  static const Color textTertiaryLight = Color(0xFF8E8E93);
  
  /// 禁用文字
  static const Color textDisabledLight = Color(0xFFC7C7CC);

  // ==================== 渐变色 ====================
  
  /// 主渐变（紫→粉）
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );
  
  /// 蓝紫渐变
  static const LinearGradient bluePurpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF667EEA), primary],
  );
  
  /// 红橙渐变
  static const LinearGradient redOrangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
  );
  
  /// 绿色渐变（用于下载相关）
  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4ADE80), success],
  );

  // ==================== 遮罩和透明度 ====================
  
  /// 模态背景遮罩
  static Color get modalBarrier => Colors.black.withOpacity(0.5);
  
  /// 毛玻璃遮罩（浅）
  static Color get glassLight => Colors.white.withOpacity(0.1);
  
  /// 毛玻璃遮罩（中）
  static Color get glassMedium => Colors.white.withOpacity(0.2);
  
  /// 毛玻璃遮罩（深）
  static Color get glassDark => Colors.black.withOpacity(0.3);

  // ==================== 特殊效果颜色 ====================
  
  /// 阴影颜色
  static Color get shadowColor => Colors.black.withOpacity(0.2);
  
  /// 高光颜色
  static Color get highlightColor => Colors.white.withOpacity(0.1);
  
  /// 波纹颜色
  static Color get rippleColor => primary.withOpacity(0.2);
  
  /// 焦点边框颜色
  static const Color focusBorder = primary;

  // ==================== 状态颜色 ====================
  
  /// 在线状态
  static const Color online = Color(0xFF10B981);
  
  /// 离线状态
  static const Color offline = Color(0xFF6B7280);
  
  /// 下载中
  static const Color downloading = Color(0xFF3B82F6);
  
  /// 已下载
  static const Color downloaded = success;
  
  /// 播放中
  static const Color playing = primary;
  
  /// 暂停
  static const Color paused = Color(0xFF9CA3AF);
}

