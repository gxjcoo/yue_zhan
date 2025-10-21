import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_color_scheme.dart';

/// 主题模式枚举
enum AppThemeMode {
  light,   // 浅色主题
  dark,    // 深色主题
  system,  // 跟随系统
}

/// 主题管理Provider
class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _colorSchemeKey = 'color_scheme';
  
  AppThemeMode _themeMode = AppThemeMode.light;
  ThemeColorScheme _colorScheme = ThemeColorScheme.green;
  SharedPreferences? _prefs;

  AppThemeMode get themeMode => _themeMode;
  ThemeColorScheme get colorScheme => _colorScheme;

  /// 获取当前实际使用的ThemeMode
  ThemeMode get currentThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadThemeMode();
    await _loadColorScheme();
  }

  /// 从本地存储加载主题模式
  Future<void> _loadThemeMode() async {
    final modeIndex = _prefs?.getInt(_themeModeKey);
    if (modeIndex != null && modeIndex < AppThemeMode.values.length) {
      _themeMode = AppThemeMode.values[modeIndex];
      notifyListeners();
    }
  }

  /// 从本地存储加载配色方案
  Future<void> _loadColorScheme() async {
    final schemeIndex = _prefs?.getInt(_colorSchemeKey);
    if (schemeIndex != null && schemeIndex < ThemeColorScheme.values.length) {
      _colorScheme = ThemeColorScheme.values[schemeIndex];
      notifyListeners();
    }
  }

  /// 设置主题模式
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    await _prefs?.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  /// 切换到浅色主题
  Future<void> setLightTheme() => setThemeMode(AppThemeMode.light);

  /// 切换到深色主题
  Future<void> setDarkTheme() => setThemeMode(AppThemeMode.dark);

  /// 跟随系统主题
  Future<void> setSystemTheme() => setThemeMode(AppThemeMode.system);

  /// 获取主题模式的显示名称
  String getThemeModeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return '浅色';
      case AppThemeMode.dark:
        return '深色';
      case AppThemeMode.system:
        return '跟随系统';
    }
  }

  /// 获取当前主题模式的显示名称
  String get currentThemeModeName => getThemeModeName(_themeMode);

  /// 获取主题模式的图标
  IconData getThemeModeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  /// 获取当前主题模式的图标
  IconData get currentThemeModeIcon => getThemeModeIcon(_themeMode);

  /// 设置配色方案
  Future<void> setColorScheme(ThemeColorScheme scheme) async {
    if (_colorScheme == scheme) return;
    
    _colorScheme = scheme;
    await _prefs?.setInt(_colorSchemeKey, scheme.index);
    notifyListeners();
  }

  /// 获取当前配色方案数据
  ColorSchemeData get currentColorSchemeData => ThemeColorSchemes.getScheme(_colorScheme);

  /// 获取当前主色
  Color get currentPrimaryColor => currentColorSchemeData.primary;

  /// 获取当前副色
  Color get currentSecondaryColor => currentColorSchemeData.secondary;

  /// 获取当前渐变
  Gradient get currentGradient => currentColorSchemeData.gradient;
}

