import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 应用文字样式
class AppTextStyles {
  AppTextStyles._();

  // ==================== 标题样式 ====================
  
  /// 超大标题 - 32px
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
    height: 1.2,
  );
  
  /// 大标题 - 24px
  static const TextStyle displayMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.3,
    height: 1.3,
  );
  
  /// 小标题 - 20px
  static const TextStyle displaySmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.2,
    height: 1.3,
  );

  // ==================== 标题样式（Headline） ====================
  
  /// 一级标题 - 18px
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.4,
  );
  
  /// 二级标题 - 16px
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.4,
  );
  
  /// 三级标题 - 14px
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
  );

  // ==================== 正文样式 ====================
  
  /// 大正文 - 16px
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.5,
    height: 1.5,
  );
  
  /// 中正文 - 14px
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.25,
    height: 1.5,
  );
  
  /// 小正文 - 12px
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.4,
    height: 1.5,
  );

  // ==================== 标签样式 ====================
  
  /// 大标签 - 14px
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  );
  
  /// 中标签 - 12px
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );
  
  /// 小标签 - 10px
  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );

  // ==================== 特殊用途样式 ====================
  
  /// 按钮文字
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );
  
  /// 歌曲标题
  static const TextStyle songTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.3,
  );
  
  /// 歌手名
  static const TextStyle artistName = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.4,
  );
  
  /// 时长/时间
  static const TextStyle duration = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    fontFeatures: [FontFeature.tabularFigures()], // 等宽数字
  );
  
  /// 播放器标题
  static const TextStyle playerTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
    height: 1.2,
  );
  
  /// 播放器副标题
  static const TextStyle playerSubtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.3,
  );

  // ==================== 带颜色的样式（深色主题） ====================
  
  static TextStyle get displayLargeDark => displayLarge.copyWith(
        color: AppColors.textPrimaryDark,
      );
  
  static TextStyle get displayMediumDark => displayMedium.copyWith(
        color: AppColors.textPrimaryDark,
      );
  
  static TextStyle get bodyLargeDark => bodyLarge.copyWith(
        color: AppColors.textSecondaryDark,
      );
  
  static TextStyle get bodyMediumDark => bodyMedium.copyWith(
        color: AppColors.textSecondaryDark,
      );
  
  static TextStyle get captionDark => bodySmall.copyWith(
        color: AppColors.textTertiaryDark,
      );

  // ==================== 带颜色的样式（浅色主题） ====================
  
  static TextStyle get displayLargeLight => displayLarge.copyWith(
        color: AppColors.textPrimaryLight,
      );
  
  static TextStyle get displayMediumLight => displayMedium.copyWith(
        color: AppColors.textPrimaryLight,
      );
  
  static TextStyle get bodyLargeLight => bodyLarge.copyWith(
        color: AppColors.textSecondaryLight,
      );
  
  static TextStyle get bodyMediumLight => bodyMedium.copyWith(
        color: AppColors.textSecondaryLight,
      );
  
  static TextStyle get captionLight => bodySmall.copyWith(
        color: AppColors.textTertiaryLight,
      );
}

