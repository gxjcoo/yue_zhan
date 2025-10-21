import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'routes/app_routes.dart';
import 'services/hive_initialization.dart';
import 'services/global_audio_service.dart';
import 'services/media_notification_service.dart';
import 'services/privacy_service.dart';
// ignore: unused_import
import 'services/preload_service.dart'; // 用于智能预加载功能（可选启用）
import 'providers/online_music_provider.dart';
import 'providers/search_provider.dart';
import 'providers/download_provider.dart';
import 'providers/theme_provider.dart';
import 'widgets/floating_player.dart';
import 'utils/logger.dart';

import 'utils/image_loader.dart';
import 'utils/permission_cache.dart';
import 'repositories/local_song_repository.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化Hive
  await HiveInitialization.init();
  
  // 初始化隐私服务
  await PrivacyService().init();
  
  // 🎯 配置图片缓存策略（优化内存使用和性能）
  ImageLoader.configureCacheLimit(
    maxCacheCount: 200,  // 最多缓存200张图片
    maxCacheSize: 100 * 1024 * 1024,  // 最大100MB
  );
  Logger.info('图片缓存配置完成', tag: 'Main');
  
  // 🎯 初始化权限缓存（后台检查权限，不阻塞启动）
  PermissionCache().hasPhotoPermission().then((hasPermission) {
    Logger.info('权限检查完成: ${hasPermission ? "有权限" : "无权限"}', tag: 'Main');
  }).catchError((e) {
    Logger.warn('权限检查失败', error: e, tag: 'Main');
  });
  
  // 🎯 预热数据库索引（优化查询性能）
  if (kDebugMode) {
    LocalSongRepository().warmupIndexes().then((_) {
      Logger.info('数据库索引预热完成', tag: 'Main');
    }).catchError((e) {
      Logger.error('数据库索引预热失败', error: e, tag: 'Main');
    });
  }
  
  // 初始化全局音频服务
  GlobalAudioService().initListeners();
  
  // 🎯 启动智能预加载服务（可选 - 取消注释以启用）
  // PreloadService().startSmartPreload();
  // Logger.info('智能预加载服务已启动', tag: 'Main');
  
  // 🎯 优化：异步初始化系统媒体通知服务（不阻塞启动）
  // AudioService是重量级初始化，异步加载不阻塞首屏，预估节省：~100ms
  AudioService.init(
    builder: () => MediaNotificationHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.xingchuiye.yuezhan.audio',
      androidNotificationChannelName: '音乐播放',
      androidNotificationChannelDescription: '音乐播放器通知',
      androidNotificationOngoing: false,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: true,
      androidStopForegroundOnPause: false,  // 暂停时保持通知显示
    ),
  ).then((_) {
    Logger.info('系统媒体通知服务初始化成功（异步）', tag: 'Main');
  }).catchError((e) {
    Logger.error('系统媒体通知服务初始化失败', error: e, tag: 'Main');
  });
  
  // 初始化 Provider
  final onlineMusicProvider = OnlineMusicProvider();
  final searchProvider = SearchProvider();
  final downloadProvider = DownloadProvider();
  final themeProvider = ThemeProvider();
  
  // 初始化主题设置
  await themeProvider.init();
  Logger.info('主题设置已加载', tag: 'Main');
  
  // 🎯 优化：异步加载下载记录（不阻塞启动）
  // 延迟加载下载数据，预估节省：~100ms
  onlineMusicProvider.loadDownloadedSongs().then((_) {
    Logger.info('在线音乐下载记录已加载', tag: 'Main');
    // 加载完成后再验证文件
    return onlineMusicProvider.validateAllDownloads();
  }).then((_) {
    Logger.info('下载文件缓存预热完成', tag: 'Main');
  }).catchError((e) {
    Logger.warn('下载数据加载失败', error: e, tag: 'Main');
  });
  
  downloadProvider.loadDownloadedSongs().then((_) {
    Logger.info('下载队列已加载', tag: 'Main');
  }).catchError((e) {
    Logger.warn('下载队列加载失败', error: e, tag: 'Main');
  });
  
  final app = MusicPlayerApp(
    onlineMusicProvider: onlineMusicProvider,
    searchProvider: searchProvider,
    downloadProvider: downloadProvider,
    themeProvider: themeProvider,
  );
  
  runApp(app);
}

class MusicPlayerApp extends StatefulWidget {
  final OnlineMusicProvider onlineMusicProvider;
  final SearchProvider searchProvider;
  final DownloadProvider downloadProvider;
  final ThemeProvider themeProvider;
  
  const MusicPlayerApp({
    super.key,
    required this.onlineMusicProvider,
    required this.searchProvider,
    required this.downloadProvider,
    required this.themeProvider,
  });

  @override
  State<MusicPlayerApp> createState() => _MusicPlayerAppState();
}

class _MusicPlayerAppState extends State<MusicPlayerApp> {

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: GlobalAudioService(),
        ),
        ChangeNotifierProvider.value(
          value: widget.onlineMusicProvider,
        ),
        ChangeNotifierProvider.value(
          value: widget.searchProvider,
        ),
        ChangeNotifierProvider.value(
          value: widget.downloadProvider,
        ),
        ChangeNotifierProvider.value(
          value: widget.themeProvider,
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp.router(
            title: '乐栈',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getLightThemeWithScheme(theme.currentColorSchemeData), // 动态浅色主题
            darkTheme: AppTheme.getDarkThemeWithScheme(theme.currentColorSchemeData), // 动态深色主题
            themeMode: theme.currentThemeMode, // 动态主题模式
            routerConfig: router,
            builder: (context, child) {
              // 根据当前主题模式设置系统UI样式
              final isDarkMode = Theme.of(context).brightness == Brightness.dark;
              // 使用页面背景色作为导航栏颜色，确保和页面背景一致
              final backgroundColor = isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight;
              final systemUiOverlayStyle = SystemUiOverlayStyle(
                statusBarColor: Colors.transparent, // 状态栏透明，显示应用背景色
                statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark, // 图标颜色
                statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light, // iOS用
                systemNavigationBarColor: backgroundColor, // 导航栏使用背景色，与页面一致
                systemNavigationBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark, // 导航栏图标颜色
                systemNavigationBarContrastEnforced: false, // 禁用系统强制对比度
                systemNavigationBarDividerColor: Colors.transparent, // 分割线透明
              );
              
              // 确保有 MediaQuery 上下文
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: systemUiOverlayStyle,
                child: MediaQuery(
                  data: MediaQuery.of(context),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Stack(
                      children: [
                        child ?? const SizedBox.shrink(),
                        // 全局悬浮播放器
                        const FloatingPlayer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
