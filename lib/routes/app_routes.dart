import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/library_page.dart';
import '../pages/player_page.dart';
import '../pages/hive_playlist_detail_page.dart';
import '../pages/search_page.dart';
import '../pages/local_song_scan_page.dart';
import '../pages/settings_page.dart';
import '../pages/main_shell.dart';
import '../pages/wifi_transfer_page.dart';
import '../pages/app_startup_page.dart';

class AppRoutes {
  static const String startup = '/';
  static const String home = '/home';
  static const String search = '/search';
  static const String library = '/library';
  static const String settings = '/settings';
  static const String player = '/player';
  static const String playlistDetail = '/playlist';
  static const String hivePlaylistDetail = '/hive-playlist';
  static const String localSongScan = '/local_songs';
  static const String wifiTransfer = '/wifi-transfer';
}

// 全局 navigator key，用于无 context 的导航
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.startup, // 从启动页开始
  routes: [
    // 应用启动页
    GoRoute(
      path: AppRoutes.startup,
      name: 'startup',
      builder: (context, state) => AppStartupPage(
        onStartupComplete: () {
          // 启动完成后跳转到音乐库
          router.go(AppRoutes.library);
        },
      ),
    ),
    // 使用 StatefulShellRoute 来保持底部导航栏状态
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        // 音乐库分支（index 0）
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.library,
              name: 'library',
              pageBuilder: (context, state) =>
                  NoTransitionPage(child: const LibraryPage()),
            ),
          ],
        ),
        // 设置分支（index 1）
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              name: 'settings',
              pageBuilder: (context, state) =>
                  NoTransitionPage(child: const SettingsPage()),
            ),
          ],
        ),
      ],
    ),
    // 不在底部导航栏中的页面（全屏显示）
    // 首页（独立路由，不在底部导航栏显示）
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    // 搜索页（独立路由，不在底部导航栏显示）
    GoRoute(
      path: AppRoutes.search,
      name: 'search',
      builder: (context, state) =>
          SearchPage(initialQuery: state.uri.queryParameters['q'] ?? ''),
    ),
    GoRoute(
      path: AppRoutes.player,
      name: 'player',
      builder: (context, state) {
        final extra = state.extra;

        // 兼容旧的传参方式（直接传song）和新的传参方式（传PlayerArguments）
        if (extra is PlayerArguments) {
          return PlayerPage(
            song: extra.song,
            playlist: extra.playlist,
            initialIndex: extra.initialIndex,
          );
        } else {
          // 向后兼容：直接传入单个歌曲
          return PlayerPage(song: extra);
        }
      },
    ),
    // 旧的 PlaylistDetailPage 路由已删除，使用 HivePlaylistDetailPage 替代
    GoRoute(
      path: AppRoutes.localSongScan,
      name: 'localSongScan',
      builder: (context, state) => const LocalSongScanPage(),
    ),
    GoRoute(
      path: '${AppRoutes.hivePlaylistDetail}/:playlistId',
      name: 'hivePlaylistDetail',
      builder: (context, state) {
        final playlistId = state.pathParameters['playlistId']!;
        return HivePlaylistDetailPage(playlistId: playlistId);
      },
    ),
    GoRoute(
      path: AppRoutes.wifiTransfer,
      name: 'wifiTransfer',
      builder: (context, state) => const WiFiTransferPage(),
    ),
  ],
);
