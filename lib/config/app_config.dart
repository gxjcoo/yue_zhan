/// 应用配置类
/// 
/// 管理应用级别的配置，包括 API 地址、环境变量等。
/// 支持通过环境变量覆盖默认配置。
/// 
/// 使用示例：
/// ```dart
/// final apiUrl = AppConfig.xiaofenApiUrl;
/// final timeout = AppConfig.networkTimeout;
/// ```
class AppConfig {
  // ============================================
  // 环境配置
  // ============================================
  
  /// 是否为调试模式
  static const bool isDebug = bool.fromEnvironment(
    'DEBUG',
    defaultValue: true,
  );
  
  /// 应用版本
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
  
  // ============================================
  // API 配置
  // ============================================
  
  /// 龙珠小粉 API 地址（咪咕音乐）
  /// 
  /// 可通过环境变量 XIAOFEN_API_URL 覆盖
  static const String xiaofenApiUrl = String.fromEnvironment(
    'XIAOFEN_API_URL',
    defaultValue: 'https://www.hhlqilongzhu.cn/api/dg_mgmusic.php',
  );
  
  /// 龙珠汽水 API 地址（抖音音乐）
  /// 
  /// 可通过环境变量 QISHUI_API_URL 覆盖
  static const String qishuiApiUrl = String.fromEnvironment(
    'QISHUI_API_URL',
    defaultValue: 'https://www.hhlqilongzhu.cn/api/dg_dymusic.php',
  );
  
  // ============================================
  // 超时配置
  // ============================================
  
  /// 网络连接超时时间（秒）
  static const int networkConnectTimeoutSeconds = int.fromEnvironment(
    'NETWORK_CONNECT_TIMEOUT',
    defaultValue: 10,
  );
  
  /// 网络接收超时时间（秒）
  static const int networkReceiveTimeoutSeconds = int.fromEnvironment(
    'NETWORK_RECEIVE_TIMEOUT',
    defaultValue: 10,
  );
  
  /// 长时间请求超时时间（秒）
  static const int networkLongTimeoutSeconds = int.fromEnvironment(
    'NETWORK_LONG_TIMEOUT',
    defaultValue: 15,
  );
  
  /// 歌词请求超时时间（秒）
  static const int lyricTimeoutSeconds = int.fromEnvironment(
    'LYRIC_TIMEOUT',
    defaultValue: 5,
  );
  
  /// 获取网络连接超时 Duration
  static Duration get networkConnectTimeout => 
      Duration(seconds: networkConnectTimeoutSeconds);
  
  /// 获取网络接收超时 Duration
  static Duration get networkReceiveTimeout => 
      Duration(seconds: networkReceiveTimeoutSeconds);
  
  /// 获取长时间请求超时 Duration
  static Duration get networkLongTimeout => 
      Duration(seconds: networkLongTimeoutSeconds);
  
  /// 获取歌词请求超时 Duration
  static Duration get lyricTimeout => 
      Duration(seconds: lyricTimeoutSeconds);
  
  // ============================================
  // 搜索配置
  // ============================================
  
  /// 默认搜索限制数量
  static const int defaultSearchLimit = int.fromEnvironment(
    'DEFAULT_SEARCH_LIMIT',
    defaultValue: 30,
  );
  
  /// 最大搜索历史记录数量
  static const int maxSearchHistory = int.fromEnvironment(
    'MAX_SEARCH_HISTORY',
    defaultValue: 50,
  );
  
  // ============================================
  // 下载配置
  // ============================================
  
  /// 最大并发下载数
  static const int maxConcurrentDownloads = int.fromEnvironment(
    'MAX_CONCURRENT_DOWNLOADS',
    defaultValue: 3,
  );
  
  /// 下载重试次数
  static const int downloadRetryCount = int.fromEnvironment(
    'DOWNLOAD_RETRY_COUNT',
    defaultValue: 3,
  );
  
  // ============================================
  // 功能开关
  // ============================================
  
  /// 是否启用日志
  static const bool enableLogging = bool.fromEnvironment(
    'ENABLE_LOGGING',
    defaultValue: true,
  );
  
  /// 是否启用网络日志
  static const bool enableNetworkLogging = bool.fromEnvironment(
    'ENABLE_NETWORK_LOGGING',
    defaultValue: true,
  );
  
  /// 是否启用性能监控
  static const bool enablePerformanceMonitoring = bool.fromEnvironment(
    'ENABLE_PERFORMANCE_MONITORING',
    defaultValue: false,
  );
  
  // ============================================
  // API 优先级配置
  // ============================================
  
  /// 龙珠小粉 API 优先级
  static const int xiaofenApiPriority = int.fromEnvironment(
    'XIAOFEN_API_PRIORITY',
    defaultValue: 1,
  );
  
  /// 龙珠汽水 API 优先级
  static const int qishuiApiPriority = int.fromEnvironment(
    'QISHUI_API_PRIORITY',
    defaultValue: 2,
  );
  
  // ============================================
  // HTTP Headers 配置
  // ============================================
  
  /// 默认 User-Agent
  static const String defaultUserAgent = String.fromEnvironment(
    'DEFAULT_USER_AGENT',
    defaultValue: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  );
  
  // ============================================
  // 辅助方法
  // ============================================
  
  /// 打印当前配置（用于调试）
  static void printConfig() {
    if (!isDebug) return;
    
    print('========== 应用配置 ==========');
    print('环境: ${isDebug ? "Debug" : "Release"}');
    print('版本: $appVersion');
    print('');
    print('API 配置:');
    print('  小粉 API: $xiaofenApiUrl (优先级: $xiaofenApiPriority)');
    print('  汽水 API: $qishuiApiUrl (优先级: $qishuiApiPriority)');
    print('');
    print('超时配置:');
    print('  连接超时: $networkConnectTimeoutSeconds 秒');
    print('  接收超时: $networkReceiveTimeoutSeconds 秒');
    print('  长超时: $networkLongTimeoutSeconds 秒');
    print('  歌词超时: $lyricTimeoutSeconds 秒');
    print('');
    print('功能开关:');
    print('  日志: ${enableLogging ? "启用" : "禁用"}');
    print('  网络日志: ${enableNetworkLogging ? "启用" : "禁用"}');
    print('  性能监控: ${enablePerformanceMonitoring ? "启用" : "禁用"}');
    print('=============================');
  }
}

