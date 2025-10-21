import 'dart:html' as html;
import '../utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

/// Web环境专用的文件选择器服务
class WebFilePickerService {
  static const List<String> _supportedMimeTypes = [
    'audio/mpeg',     // MP3
    'audio/wav',      // WAV
    'audio/flac',     // FLAC
    'audio/mp4',      // M4A
    'audio/aac',      // AAC
    'audio/ogg',      // OGG
  ];
  
  static const List<String> _supportedExtensions = [
    '.mp3',
    '.wav', 
    '.flac',
    '.m4a',
    '.aac',
    '.ogg',
  ];

  /// 选择音频文件（Web环境专用）
  static Future<List<html.File>> pickAudioFiles() async {
    if (!kIsWeb) {
      throw UnsupportedError('此方法仅支持Web环境');
    }
    
    try {
      Logger.debug('Web环境：创建文件输入元素', tag: 'WebFilePicker');
      
      // 创建HTML文件输入元素
      final html.FileUploadInputElement input = html.FileUploadInputElement();
      input.accept = _supportedMimeTypes.join(',') + ',' + _supportedExtensions.join(',');
      input.multiple = true;
      
      // 触发文件选择对话框
      input.click();
      
      // 等待用户选择文件
      await input.onChange.first;
      
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        // 过滤音频文件
        final audioFiles = files.where(_isAudioFile).toList();
        Logger.info('Web环境：用户选择了 ${audioFiles.length} 个音频文件', tag: 'WebFilePicker');
        return audioFiles;
      } else {
        Logger.debug('Web环境：用户未选择文件', tag: 'WebFilePicker');
        return [];
      }
    } catch (e) {
      Logger.error('Web文件选择失败', error: e, tag: 'WebFilePicker');
      return [];
    }
  }
  
  /// 使用FilePicker作为备用方案
  static Future<FilePickerResult?> pickFilesWithFilePicker() async {
    try {
      Logger.debug('Web环境：尝试使用FilePicker', tag: 'WebFilePicker');
      
      // 等待一小段时间确保初始化完成
      await Future.delayed(const Duration(milliseconds: 200));
      
      return await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg'],
        allowMultiple: true,
        withData: false,
        withReadStream: false,
      );
    } catch (e) {
      Logger.error('FilePicker失败', error: e, tag: 'WebFilePicker');
      return null;
    }
  }
  
  /// 检查文件是否为音频文件
  static bool _isAudioFile(html.File file) {
    // 检查MIME类型
    if (_supportedMimeTypes.contains(file.type)) {
      return true;
    }
    
    // 检查文件扩展名
    final fileName = file.name.toLowerCase();
    return _supportedExtensions.any((ext) => fileName.endsWith(ext));
  }
  
  /// 将HTML File转换为PlatformFile
  static PlatformFile htmlFileToPlatformFile(html.File htmlFile) {
    return PlatformFile(
      name: htmlFile.name,
      size: htmlFile.size,
      path: null, // Web环境下没有路径
    );
  }
  
  /// 获取文件的基本信息
  static Map<String, dynamic> getFileInfo(html.File file) {
    return {
      'name': file.name,
      'size': file.size,
      'type': file.type,
      'lastModified': DateTime.fromMillisecondsSinceEpoch(file.lastModified ?? 0),
    };
  }
}
