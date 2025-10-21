import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../utils/logger.dart';

/// 专辑封面获取服务
/// 提供多级回退机制：元数据 -> 本地同名图片 -> 目录通用图片
class AlbumArtService {
  // 支持的图片格式
  static const List<String> _supportedImageExtensions = [
    '.jpg',
    '.jpeg', 
    '.png',
    '.bmp',
    '.gif',
    '.webp',
  ];
  
  // 常见的专辑封面文件名
  static const List<String> _commonAlbumArtNames = [
    'cover',
    'album',
    'albumart',
    'albumartwork',
    'folder',
    'front',
    'artwork',
  ];

  /// 获取音频文件的专辑封面
  /// 
  /// [audioFile] 音频文件
  /// [hasMetadataImage] 元数据中是否包含图片
  /// [artist] 艺人名称（用于匹配）
  /// [album] 专辑名称（用于匹配）
  /// 
  /// 返回封面图片的完整路径，如果找不到则返回null
  static Future<String?> getAlbumArt(
    File audioFile, {
    bool hasMetadataImage = false,
    String? artist,
    String? album,
  }) async {
    try {
      // Web环境下的处理
      if (kIsWeb) {
        Logger.debug('Web环境：跳过专辑封面获取', tag: 'AlbumArt');
        return hasMetadataImage ? '${audioFile.path}#metadata' : null;
      }
      
      Logger.debug('开始获取专辑封面: ${audioFile.path}', tag: 'AlbumArt');
      
      // 策略1: 如果元数据中有图片，优先使用
      if (hasMetadataImage) {
        final metadataImagePath = await _extractMetadataImage(audioFile);
        if (metadataImagePath != null) {
          Logger.debug('找到元数据封面: $metadataImagePath', tag: 'AlbumArt');
          return metadataImagePath;
        }
      }
      
      // 策略2: 查找同名图片文件
      final sameNameImage = await _findSameNameImage(audioFile);
      if (sameNameImage != null) {
        Logger.debug('找到同名封面: $sameNameImage', tag: 'AlbumArt');
        return sameNameImage;
      }
      
      // 策略3: 查找目录中的通用封面图片
      final commonImage = await _findCommonAlbumArt(audioFile);
      if (commonImage != null) {
        Logger.debug('找到通用封面: $commonImage', tag: 'AlbumArt');
        return commonImage;
      }
      
      // 策略4: 根据艺人和专辑名称查找
      if (artist != null && album != null) {
        final namedImage = await _findNamedAlbumArt(audioFile, artist, album);
        if (namedImage != null) {
          Logger.debug('找到命名封面: $namedImage', tag: 'AlbumArt');
          return namedImage;
        }
      }
      
      Logger.debug('未找到专辑封面: ${audioFile.path}', tag: 'AlbumArt');
      return null;
      
    } catch (e) {
      Logger.warn('获取专辑封面时出错: ${audioFile.path}', error: e, tag: 'AlbumArt');
      return null;
    }
  }
  
  /// 提取元数据中的图片（暂时返回音频文件路径作为标识）
  static Future<String?> _extractMetadataImage(File audioFile) async {
    try {
      // TODO: 实际实现中需要提取并保存元数据中的图片到缓存目录
      // 这里简化处理，返回一个标识表示元数据有图片
      return '${audioFile.path}#metadata';
    } catch (e) {
      print('提取元数据图片失败: $e');
      return null;
    }
  }
  
  /// 查找与音频文件同名的图片文件
  static Future<String?> _findSameNameImage(File audioFile) async {
    try {
      final audioDir = audioFile.parent;
      final audioBaseName = path.basenameWithoutExtension(audioFile.path);
      
      // 遍历支持的图片格式
      for (final ext in _supportedImageExtensions) {
        final imageFile = File(path.join(audioDir.path, '$audioBaseName$ext'));
        if (await imageFile.exists()) {
          return imageFile.path;
        }
      }
      
      return null;
    } catch (e) {
      Logger.warn('查找同名图片失败', error: e, tag: 'AlbumArt');
      return null;
    }
  }
  
  /// 查找目录中的通用专辑封面
  static Future<String?> _findCommonAlbumArt(File audioFile) async {
    try {
      final audioDir = audioFile.parent;
      
      // 遍历常见封面名称和图片格式的组合
      for (final name in _commonAlbumArtNames) {
        for (final ext in _supportedImageExtensions) {
          final imageFile = File(path.join(audioDir.path, '$name$ext'));
          if (await imageFile.exists()) {
            return imageFile.path;
          }
        }
      }
      
      return null;
    } catch (e) {
      Logger.warn('查找通用封面失败', error: e, tag: 'AlbumArt');
      return null;
    }
  }
  
  /// 根据艺人和专辑名称查找封面
  static Future<String?> _findNamedAlbumArt(
    File audioFile, 
    String artist, 
    String album,
  ) async {
    try {
      final audioDir = audioFile.parent;
      
      // 清理文件名中的特殊字符
      final cleanArtist = cleanFileName(artist);
      final cleanAlbum = cleanFileName(album);
      
      final possibleNames = [
        '$cleanArtist - $cleanAlbum',
        '$cleanAlbum - $cleanArtist',
        cleanAlbum,
        cleanArtist,
      ];
      
      // 遍历可能的文件名组合
      for (final name in possibleNames) {
        for (final ext in _supportedImageExtensions) {
          final imageFile = File(path.join(audioDir.path, '$name$ext'));
          if (await imageFile.exists()) {
            return imageFile.path;
          }
        }
      }
      
      return null;
    } catch (e) {
      Logger.warn('查找命名封面失败', error: e, tag: 'AlbumArt');
      return null;
    }
  }
  
  /// 清理文件名，移除不合法字符
  static String cleanFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '') // 移除不合法字符
        .replaceAll(RegExp(r'\s+'), ' ') // 合并多个空格
        .trim();
  }
  
  /// 检查文件是否为图片
  static bool isImageFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return _supportedImageExtensions.contains(ext);
  }
  
  /// 获取目录中所有图片文件
  static Future<List<String>> getImagesInDirectory(Directory directory) async {
    final images = <String>[];
    
    try {
      await for (final entity in directory.list()) {
        if (entity is File && isImageFile(entity.path)) {
          images.add(entity.path);
        }
      }
    } catch (e) {
      Logger.warn('获取目录图片失败', error: e, tag: 'AlbumArt');
    }
    
    return images;
  }
  
  /// 批量预加载目录中的专辑封面信息
  static Future<Map<String, String?>> preloadAlbumArts(
    List<File> audioFiles,
  ) async {
    final Map<String, String?> albumArts = {};
    
    for (final audioFile in audioFiles) {
      final albumArt = await getAlbumArt(audioFile);
      albumArts[audioFile.path] = albumArt;
    }
    
    return albumArts;
  }
}
