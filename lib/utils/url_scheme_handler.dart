import 'package:flutter/services.dart';
import 'dart:async';
import 'logger.dart';

/// URL Scheme 处理器
/// 
/// 用于处理云盘OAuth回调
class UrlSchemeHandler {
  static const MethodChannel _channel = MethodChannel('com.xingchuiye.yuezhan/url_scheme');
  
  static StreamController<Uri>? _controller;
  
  /// 获取URL Scheme事件流
  static Stream<Uri> get urlStream {
    _controller ??= StreamController<Uri>.broadcast();
    return _controller!.stream;
  }
  
  /// 初始化URL Scheme监听
  static Future<void> initialize() async {
    try {
      // 设置方法调用处理器
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // 获取初始URL（应用启动时的URL）
      final String? initialUrl = await _channel.invokeMethod('getInitialUrl');
      if (initialUrl != null && initialUrl.isNotEmpty) {
        final uri = Uri.parse(initialUrl);
        _controller?.add(uri);
        Logger.info('收到初始URL: $initialUrl', tag: 'UrlScheme');
      }
      
      Logger.info('URL Scheme监听已初始化', tag: 'UrlScheme');
    } catch (e) {
      Logger.error('初始化URL Scheme失败', error: e, tag: 'UrlScheme');
    }
  }
  
  /// 处理方法调用
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onUrl') {
      final String? url = call.arguments as String?;
      if (url != null && url.isNotEmpty) {
        try {
          final uri = Uri.parse(url);
          _controller?.add(uri);
          Logger.info('收到URL回调: $url', tag: 'UrlScheme');
        } catch (e) {
          Logger.error('解析URL失败: $url', error: e, tag: 'UrlScheme');
        }
      }
    }
  }
  
  /// 解析OAuth回调URL
  /// 
  /// 返回授权码或错误信息
  static Map<String, String?> parseOAuthCallback(Uri uri) {
    final result = <String, String?>{};
    
    // 检查scheme
    if (uri.scheme != 'yuezhan') {
      result['error'] = 'Invalid scheme: ${uri.scheme}';
      return result;
    }
    
    // 检查host
    if (uri.host != 'oauth') {
      result['error'] = 'Invalid host: ${uri.host}';
      return result;
    }
    
    // 获取平台
    final platform = uri.path.replaceFirst('/', '');
    result['platform'] = platform;
    
    // 获取授权码
    final code = uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      result['code'] = code;
    }
    
    // 获取错误信息
    final error = uri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      result['error'] = error;
      result['error_description'] = uri.queryParameters['error_description'];
    }
    
    // 获取state
    final state = uri.queryParameters['state'];
    if (state != null && state.isNotEmpty) {
      result['state'] = state;
    }
    
    Logger.info('解析OAuth回调: platform=$platform, code=${code != null ? "***" : "null"}, error=$error', tag: 'UrlScheme');
    
    return result;
  }
  
  /// 清理资源
  static void dispose() {
    _controller?.close();
    _controller = null;
  }
}
