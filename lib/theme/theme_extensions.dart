import 'package:flutter/material.dart';

/// 主题扩展 - 提供便捷的动态颜色获取方法
extension ThemeExtensions on BuildContext {
  /// 获取当前主题的配色方案
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  
  /// 获取主色
  Color get primaryColor => colorScheme.primary;
  
  /// 获取副色
  Color get secondaryColor => colorScheme.secondary;
  
  /// 获取错误色
  Color get errorColor => colorScheme.error;
  
  /// 获取表面色
  Color get surfaceColor => colorScheme.surface;
  
  /// 获取背景色
  Color get backgroundColor => Theme.of(this).scaffoldBackgroundColor;
  
  /// 获取文字颜色
  Color get textColor => colorScheme.onSurface;
  
  /// 判断是否为深色模式
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  
  /// 获取自适应颜色（根据深色/浅色模式）
  Color adaptiveColor({required Color dark, required Color light}) {
    return isDarkMode ? dark : light;
  }
}

/// 主题色辅助类 - 在无法使用扩展的地方使用
class ThemeColors {
  /// 从主题获取主色
  static Color primary(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }
  
  /// 从主题获取副色
  static Color secondary(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }
  
  /// 从主题获取错误色
  static Color error(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }
  
  /// 创建主题渐变
  static Gradient primaryGradient(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, secondary],
    );
  }
}

