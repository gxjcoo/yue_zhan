import 'package:flutter/foundation.dart';

/// 日志工具类
/// 
/// 提供统一的日志输出接口，支持不同日志级别。
/// 在生产环境（Release模式）自动禁用除错误外的所有日志。
/// 
/// 使用示例：
/// ```dart
/// Logger.debug('调试信息');
/// Logger.info('普通信息');
/// Logger.warn('警告信息');
/// Logger.error('错误信息', error, stackTrace);
/// ```
class Logger {
  /// 是否为调试模式
  /// 
  /// 在 Debug 模式下为 true，Release 模式下为 false
  static const bool _isDebug = kDebugMode;
  
  /// 是否启用日志输出
  /// 
  /// 可以通过修改此值来全局控制日志输出
  static bool _enabled = true;
  
  /// 获取当前日志是否启用
  static bool get isEnabled => _enabled;
  
  /// 设置日志是否启用
  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }
  
  /// 输出调试信息
  /// 
  /// 仅在 Debug 模式下输出
  /// 
  /// [message] 日志消息
  /// [error] 可选的错误对象
  /// [stackTrace] 可选的堆栈跟踪
  /// [tag] 可选的标签，用于标识日志来源
  static void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (!_enabled || !_isDebug) return;
    
    final prefix = tag != null ? '[$tag] ' : '';
    debugPrint('🐛 [DEBUG] $prefix$message');
    if (error != null) {
      debugPrint('   Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('   StackTrace: $stackTrace');
    }
  }
  
  /// 输出信息
  /// 
  /// 仅在 Debug 模式下输出
  /// 
  /// [message] 日志消息
  /// [error] 可选的错误对象
  /// [stackTrace] 可选的堆栈跟踪
  /// [tag] 可选的标签，用于标识日志来源
  static void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (!_enabled || !_isDebug) return;
    
    final prefix = tag != null ? '[$tag] ' : '';
    debugPrint('ℹ️ [INFO] $prefix$message');
    if (error != null) {
      debugPrint('   Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('   StackTrace: $stackTrace');
    }
  }
  
  /// 输出警告
  /// 
  /// 仅在 Debug 模式下输出
  /// 
  /// [message] 日志消息
  /// [error] 可选的错误对象
  /// [stackTrace] 可选的堆栈跟踪
  /// [tag] 可选的标签，用于标识日志来源
  static void warn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (!_enabled || !_isDebug) return;
    
    final prefix = tag != null ? '[$tag] ' : '';
    debugPrint('⚠️ [WARN] $prefix$message');
    if (error != null) {
      debugPrint('   Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('   StackTrace: $stackTrace');
    }
  }
  
  /// 输出错误
  /// 
  /// 在所有模式下都会输出（包括 Release 模式）
  /// 
  /// [message] 错误消息
  /// [error] 可选的错误对象
  /// [stackTrace] 可选的堆栈跟踪
  /// [tag] 可选的标签，用于标识日志来源
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (!_enabled) return;
    
    final prefix = tag != null ? '[$tag] ' : '';
    debugPrint('❌ [ERROR] $prefix$message');
    
    if (error != null) {
      debugPrint('   错误详情: $error');
    }
    
    if (stackTrace != null) {
      debugPrint('   堆栈跟踪:');
      debugPrint(stackTrace.toString());
    }
  }
  
  /// 输出成功信息
  /// 
  /// 仅在 Debug 模式下输出
  /// 
  /// [message] 日志消息
  /// [tag] 可选的标签，用于标识日志来源
  static void success(String message, {String? tag}) {
    if (!_enabled || !_isDebug) return;
    
    final prefix = tag != null ? '[$tag] ' : '';
    debugPrint('✅ [SUCCESS] $prefix$message');
  }
  
  /// 输出网络请求日志
  /// 
  /// 仅在 Debug 模式下输出
  /// 
  /// [method] HTTP 方法（GET, POST 等）
  /// [url] 请求 URL
  /// [statusCode] 可选的状态码
  /// [duration] 可选的请求耗时
  static void network(
    String method,
    String url, {
    int? statusCode,
    Duration? duration,
  }) {
    if (!_enabled || !_isDebug) return;
    
    final status = statusCode != null ? ' [$statusCode]' : '';
    final time = duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    debugPrint('🌐 [NETWORK] $method $url$status$time');
  }
  
  /// 输出分组开始标记
  /// 
  /// 用于将一组相关的日志归类
  /// 
  /// [title] 分组标题
  static void group(String title) {
    if (!_enabled || !_isDebug) return;
    
    debugPrint('\n═══════════════════════════════════════');
    debugPrint('📦 $title');
    debugPrint('═══════════════════════════════════════');
  }
  
  /// 输出分组结束标记
  static void groupEnd() {
    if (!_enabled || !_isDebug) return;
    
    debugPrint('═══════════════════════════════════════\n');
  }
  
  /// 输出 JSON 数据（格式化）
  /// 
  /// [json] JSON 字符串或对象
  /// [tag] 可选的标签
  static void json(dynamic json, {String? tag}) {
    if (!_enabled || !_isDebug) return;
    
    final prefix = tag != null ? '[$tag] ' : '';
    debugPrint('📄 [JSON] $prefix$json');
  }
}

