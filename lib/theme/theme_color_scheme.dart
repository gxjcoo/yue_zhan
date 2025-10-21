import 'package:flutter/material.dart';

/// 主题配色方案
enum ThemeColorScheme {
  purple,     // 紫粉渐变（默认）
  blue,       // 蓝色渐变
  green,      // 绿色渐变
  orange,     // 橙色渐变
  red,        // 红色渐变
  pink,       // 粉色渐变
}

/// 配色方案数据类
class ColorSchemeData {
  final String name;
  final String description;
  final Color primary;
  final Color secondary;
  final Gradient gradient;

  const ColorSchemeData({
    required this.name,
    required this.description,
    required this.primary,
    required this.secondary,
    required this.gradient,
  });
}

/// 配色方案配置
class ThemeColorSchemes {
  /// 紫粉渐变（默认）
  static const ColorSchemeData purple = ColorSchemeData(
    name: '紫粉渐变',
    description: '优雅神秘',
    primary: Color(0xFF8B5CF6),
    secondary: Color(0xFFEC4899),
    gradient: LinearGradient(
      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// 蓝色渐变
  static const ColorSchemeData blue = ColorSchemeData(
    name: '蓝色渐变',
    description: '清新科技',
    primary: Color(0xFF3B82F6),
    secondary: Color(0xFF06B6D4),
    gradient: LinearGradient(
      colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// 绿色渐变
  static const ColorSchemeData green = ColorSchemeData(
    name: '绿色渐变',
    description: '自然活力',
    primary: Color(0xFF10B981),
    secondary: Color(0xFF22C55E),
    gradient: LinearGradient(
      colors: [Color(0xFF10B981), Color(0xFF22C55E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// 橙色渐变
  static const ColorSchemeData orange = ColorSchemeData(
    name: '橙色渐变',
    description: '温暖活泼',
    primary: Color(0xFFF97316),
    secondary: Color(0xFFFBBF24),
    gradient: LinearGradient(
      colors: [Color(0xFFF97316), Color(0xFFFBBF24)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// 红色渐变
  static const ColorSchemeData red = ColorSchemeData(
    name: '红色渐变',
    description: '热情奔放',
    primary: Color(0xFFEF4444),
    secondary: Color(0xFFF43F5E),
    gradient: LinearGradient(
      colors: [Color(0xFFEF4444), Color(0xFFF43F5E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// 粉色渐变
  static const ColorSchemeData pink = ColorSchemeData(
    name: '粉色渐变',
    description: '甜美浪漫',
    primary: Color(0xFFEC4899),
    secondary: Color(0xFFF472B6),
    gradient: LinearGradient(
      colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// 获取配色方案数据
  static ColorSchemeData getScheme(ThemeColorScheme scheme) {
    switch (scheme) {
      case ThemeColorScheme.purple:
        return purple;
      case ThemeColorScheme.blue:
        return blue;
      case ThemeColorScheme.green:
        return green;
      case ThemeColorScheme.orange:
        return orange;
      case ThemeColorScheme.red:
        return red;
      case ThemeColorScheme.pink:
        return pink;
    }
  }

  /// 获取所有配色方案
  static List<MapEntry<ThemeColorScheme, ColorSchemeData>> getAllSchemes() {
    return [
      MapEntry(ThemeColorScheme.purple, purple),
      MapEntry(ThemeColorScheme.blue, blue),
      MapEntry(ThemeColorScheme.green, green),
      MapEntry(ThemeColorScheme.orange, orange),
      MapEntry(ThemeColorScheme.red, red),
      MapEntry(ThemeColorScheme.pink, pink),
    ];
  }
}

