import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 图片加载工具类
/// 统一处理本地图片和网络图片的加载，自动使用缓存
/// 增强错误处理，解决 Android ImageDecoder 解码失败问题
class ImageLoader {
  /// 网络图片请求的 HTTP Headers
  /// 添加这些 headers 可以确保获取正确的图片格式
  static const Map<String, String> httpHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'image/webp,image/apng,image/jpeg,image/png,image/*,*/*;q=0.8',
    'Accept-Encoding': 'gzip, deflate',
    'Connection': 'keep-alive',
  };
  
  /// 加载专辑封面（自动判断本地/网络）
  static Widget loadAlbumArt({
    required String? albumArt,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    // 默认占位符
    final defaultPlaceholder = placeholder ?? Container(
      width: width,
      height: height,
      color: Colors.grey[800],
      child: const Icon(Icons.music_note, size: 50, color: Colors.white),
    );
    
    final defaultError = errorWidget ?? Container(
      width: width,
      height: height,
      color: Colors.grey[800],
      child: const Icon(Icons.music_note, size: 50, color: Colors.white),
    );
    
    // 没有封面
    if (albumArt == null || albumArt.isEmpty) {
      return defaultError;
    }
    
    // 网络图片 - 使用缓存并添加增强的错误处理
    if (albumArt.startsWith('http://') || albumArt.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: albumArt,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: width?.toInt() ?? 300,  // 限制内存缓存尺寸
        memCacheHeight: height?.toInt() ?? 300,
        httpHeaders: httpHeaders,  // 添加 HTTP headers
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) => defaultPlaceholder,
        errorWidget: (context, url, error) {
          // 增强的错误处理：打印详细错误信息
          if (kDebugMode) {
            print('❌ 图片加载失败: $url');
            print('   错误: $error');
          }
          return defaultError;
        },
      );
    }
    
    // 本地图片
    if (albumArt.endsWith('#metadata')) {
      // 元数据标识，显示默认图标
      return Container(
        width: width,
        height: height,
        color: Colors.grey[800],
        child: const Icon(Icons.album, size: 50, color: Colors.white),
      );
    }
    
    // 本地文件 - 限制解码尺寸以节省内存
    return Image.file(
      File(albumArt),
      width: width,
      height: height,
      fit: fit,
      cacheWidth: width?.toInt() ?? 300,  // 限制解码尺寸
      cacheHeight: height?.toInt() ?? 300,
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          print('❌ 本地图片加载失败: $albumArt');
          print('   错误: $error');
        }
        return defaultError;
      },
    );
  }
  
  /// 验证图片 URL 是否有效
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    // 检查是否是有效的 HTTP(S) URL
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return false;
    }
    
    // URL 有效（图片格式由服务器返回的 Content-Type 决定）
    return true;
  }
  
  /// 清理图片缓存
  static Future<void> clearCache() async {
    try {
      // 清理网络图片缓存
      await CachedNetworkImage.evictFromCache('');
      
      // 清理Flutter图片缓存
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      
      if (kDebugMode) {
        print('✅ 图片缓存已清理');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 清理图片缓存失败: $e');
      }
    }
  }
  
  /// 预加载图片
  static Future<void> preloadImage(String url, BuildContext context) async {
    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        await precacheImage(
          CachedNetworkImageProvider(url, headers: httpHeaders),
          context,
        );
      } else if (!url.endsWith('#metadata')) {
        await precacheImage(FileImage(File(url)), context);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 预加载图片失败: $url, 错误: $e');
      }
    }
  }
  
  /// 设置图片缓存限制
  static void configureCacheLimit({
    int maxCacheCount = 100,
    int maxCacheSize = 50 * 1024 * 1024, // 50MB
  }) {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = maxCacheCount;
    cache.maximumSizeBytes = maxCacheSize;
    
    if (kDebugMode) {
      print('✅ 图片缓存配置: 最大 $maxCacheCount 张, 最大 ${maxCacheSize ~/ (1024 * 1024)}MB');
    }
  }
  
  /// 获取缓存统计信息
  static Map<String, dynamic> getCacheStats() {
    final cache = PaintingBinding.instance.imageCache;
    return {
      'currentSize': cache.currentSize,
      'currentSizeBytes': cache.currentSizeBytes,
      'maximumSize': cache.maximumSize,
      'maximumSizeBytes': cache.maximumSizeBytes,
      'liveImageCount': cache.liveImageCount,
      'pendingImageCount': cache.pendingImageCount,
    };
  }
}

