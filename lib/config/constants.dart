/// 应用常量配置
/// 
/// 集中管理所有硬编码的常量，方便维护和修改
class Constants {
  // ============================================
  // 网络超时配置
  // ============================================
  
  /// 网络连接超时时间
  static const Duration networkConnectTimeout = Duration(seconds: 10);
  
  /// 网络接收超时时间
  static const Duration networkReceiveTimeout = Duration(seconds: 10);
  
  /// 长时间网络请求超时（如下载）
  static const Duration networkLongTimeout = Duration(seconds: 15);
  
  /// 歌词请求超时时间
  static const Duration lyricTimeout = Duration(seconds: 5);
  
  /// 元数据读取超时时间
  static const Duration metadataReadTimeout = Duration(seconds: 10);
  
  /// API 搜索超时时间（单个 API）
  static const Duration apiSearchTimeout = Duration(seconds: 10);
  
  // ============================================
  // 搜索配置
  // ============================================
  
  /// 默认搜索结果限制数量
  static const int defaultSearchLimit = 30;
  
  /// 最大搜索结果限制数量
  static const int maxSearchLimit = 100;
  
  /// 最大搜索历史记录数量
  static const int maxSearchHistory = 50;
  
  /// 显示的搜索历史数量（未展开时）
  static const int displayedHistoryCount = 6;
  
  /// 搜索防抖延迟时间
  static const Duration searchDebounceDelay = Duration(milliseconds: 500);
  
  // ============================================
  // UI 配置
  // ============================================
  
  /// 悬浮播放器大小
  static const double floatingPlayerSize = 60.0;
  
  /// 专辑封面圆角半径
  static const double albumArtRadius = 8.0;
  
  /// 卡片阴影高度
  static const double cardElevation = 2.0;
  
  /// 列表项高度
  static const double listTileHeight = 72.0;
  
  /// 标准间距
  static const double standardPadding = 16.0;
  
  /// 小间距
  static const double smallPadding = 8.0;
  
  /// 大间距
  static const double largePadding = 24.0;
  
  // ============================================
  // 文件配置
  // ============================================
  
  /// 支持的音频格式
  static const List<String> supportedAudioFormats = [
    'mp3',
    'wav',
    'flac',
    'm4a',
    'aac',
    'ogg',
  ];
  
  /// 支持的图片格式
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
  ];
  
  /// 音乐文件夹名称
  static const String musicFolderName = 'Music';
  
  /// 音频文件名
  static const String audioFileName = 'audio';
  
  /// 封面文件名
  static const String coverFileName = 'cover';
  
  /// 歌词文件名
  static const String lyricFileName = 'lyric';
  
  /// 歌词文件扩展名
  static const String lyricFileExtension = '.lrc';
  
  // ============================================
  // 下载配置
  // ============================================
  
  /// 最大并发下载数
  static const int maxConcurrentDownloads = 3;
  
  /// 下载重试次数
  static const int downloadRetryCount = 3;
  
  /// 下载进度更新间隔（毫秒）
  static const int downloadProgressInterval = 100;
  
  // ============================================
  // Hive 数据库配置
  // ============================================
  
  /// 本地歌曲数据库名称
  static const String localSongsBoxName = 'local_songs';
  
  /// 歌单数据库名称
  static const String playlistsBoxName = 'playlists';
  
  /// 搜索历史数据库名称
  static const String searchHistoryBoxName = 'search_history';
  
  // ============================================
  // Hive Type ID 配置
  // ============================================
  
  /// LocalSong Type ID
  static const int localSongTypeId = 0;
  
  /// Duration Adapter Type ID
  static const int durationAdapterTypeId = 1;
  
  /// HivePlaylist Type ID
  static const int hivePlaylistTypeId = 2;
  
  // ============================================
  // 播放配置
  // ============================================
  
  /// 默认音量
  static const double defaultVolume = 1.0;
  
  /// 进度条更新间隔（毫秒）
  static const int progressUpdateInterval = 100;
  
  // ============================================
  // 动画配置
  // ============================================
  
  /// 标准动画持续时间
  static const Duration standardAnimationDuration = Duration(milliseconds: 300);
  
  /// 快速动画持续时间
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  
  /// 慢速动画持续时间
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);
  
  /// 封面旋转动画持续时间
  static const Duration coverRotationDuration = Duration(seconds: 10);
  
  // ============================================
  // 主题配置
  // ============================================
  
  /// 主题色（温暖的米色）
  static const int primaryColorValue = 0xFFFFE8C8;
  
  /// 透明度值
  static const double opacity10 = 0.1;
  static const double opacity20 = 0.2;
  static const double opacity30 = 0.3;
  static const double opacity40 = 0.4;
  static const double opacity50 = 0.5;
  static const double opacity70 = 0.7;
  static const double opacity80 = 0.8;
  
  // ============================================
  // 错误消息
  // ============================================
  
  /// 网络错误消息
  static const String networkErrorMessage = '网络连接失败，请检查网络设置';
  
  /// 下载失败消息
  static const String downloadErrorMessage = '下载失败，请稍后重试';
  
  /// 播放失败消息
  static const String playbackErrorMessage = '播放失败，请稍后重试';
  
  /// 权限拒绝消息
  static const String permissionDeniedMessage = '需要相应权限才能继续操作';
  
  /// 文件不存在消息
  static const String fileNotFoundMessage = '文件不存在或已被删除';
  
  // ============================================
  // 成功消息
  // ============================================
  
  /// 下载成功消息
  static const String downloadSuccessMessage = '下载成功';
  
  /// 收藏成功消息
  static const String favoriteSuccessMessage = '收藏成功';
  
  /// 删除成功消息
  static const String deleteSuccessMessage = '删除成功';
  
  /// 添加成功消息
  static const String addSuccessMessage = '添加成功';
  
  // ============================================
  // 正则表达式
  // ============================================
  
  /// 文件名非法字符正则表达式
  static final RegExp illegalFileNameChars = RegExp(r'[<>:"/\\|?*]');
  
  /// URL 验证正则表达式
  static final RegExp urlPattern = RegExp(
    r'^https?://[\w\-]+(\.[\w\-]+)+[/#?]?.*$',
    caseSensitive: false,
  );
}

