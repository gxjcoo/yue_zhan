import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../models/local_song.dart';
import '../models/hive_playlist.dart';
import '../services/hive_local_song_storage.dart';
import '../services/playlist_storage.dart';
import '../services/global_audio_service.dart';
import '../services/library_refresh_notifier.dart';
import '../theme/app_colors.dart';
import '../utils/image_loader.dart';
import '../utils/permission_cache.dart';
import '../routes/app_routes.dart' show AppRoutes, rootNavigatorKey;
import '../pages/playlist_editor_page.dart';
import '../widgets/song_selector_dialog.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalAudioService _audioService = GlobalAudioService();

  List<LocalSong> _localSongs = [];
  List<HivePlaylist> _playlists = [];
  bool _loadingLocalSongs = false;
  bool _loadingPlaylists = false;
  
  // 🎯 优化：统计数据缓存（避免每次build都重新计算）
  int? _cachedTotalSongs;
  int? _cachedTotalPlaylists;
  int? _cachedTotalArtists;
  int _lastLocalSongsLength = -1;
  int _lastPlaylistsLength = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    LibraryRefreshNotifier().addListener(_onLibraryRefresh);
    _loadLocalSongs();
    _loadPlaylists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    LibraryRefreshNotifier().removeListener(_onLibraryRefresh);
    super.dispose();
  }

  void _onLibraryRefresh() {
    _loadLocalSongs();
    _loadPlaylists();
  }

  Future<void> _loadLocalSongs() async {
    if (_loadingLocalSongs) return;
    setState(() => _loadingLocalSongs = true);

    try {
      final localSongs = await LocalSongStorage.getSongs();
      if (mounted) {
        setState(() {
          _localSongs = localSongs;
          _loadingLocalSongs = false;
        });
        
        // 🎯 优化：后台预热封面文件缓存（不阻塞UI）
        _warmupAlbumArtCache(localSongs);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingLocalSongs = false);
      }
    }
  }
  
  /// 后台预热封面文件缓存
  void _warmupAlbumArtCache(List<LocalSong> songs) {
    // 提取所有封面路径
    final albumArtPaths = songs
        .map((s) => s.albumArt)
        .where((path) => path != null && path.isNotEmpty && !path.endsWith('#metadata'))
        .cast<String>()
        .toList();
    
    if (albumArtPaths.isEmpty) return;
    
    // 异步预热缓存（不阻塞UI）
    PermissionCache().warmupFileCache(albumArtPaths).then((_) {
      // 预热完成后打印统计
      PermissionCache().printStats();
    });
  }

  Future<void> _loadPlaylists() async {
    if (_loadingPlaylists) return;
    setState(() => _loadingPlaylists = true);

    try {
      final playlists = await PlaylistStorage.getPlaylists();
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _loadingPlaylists = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPlaylists = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // 标题栏
            SliverAppBar(
              floating: true,
              pinned: false,
              title: Text(
                '音乐库',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.getTextPrimary(context),
                  letterSpacing: -0.5,
                ),
              ),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: AppColors.getTextPrimary(context),
              iconTheme: IconThemeData(
                color: AppColors.getTextPrimary(context),
              ),
              elevation: 0,
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.add_rounded,
                      color: Theme.of(context).primaryColor,
                    ),
                    tooltip: '添加音乐',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'scan') {
                        _scanLocalMusic();
                      } else if (value == 'wifi') {
                        _openWiFiTransfer();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'scan',
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_rounded,
                              color: Theme.of(context).primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Text('扫描本地音乐'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'wifi',
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi_rounded,
                              color: Theme.of(context).primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Text('WiFi传输'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 统计卡片
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                child: _buildStatsCard(),
              ),
            ),

            // Tab栏
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: AppColors.getTextTertiary(context),
                  indicatorColor: Theme.of(context).primaryColor,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  dividerColor: Colors.transparent,
                  dividerHeight: 0,
                  tabs: const [
                    Tab(text: '歌曲'),
                    Tab(text: '歌单'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              // 🎯 优化：使用 AutomaticKeepAlive 保持tab状态
              _KeepAliveWrapper(child: _buildSongsList()),
              _KeepAliveWrapper(child: _buildPlaylistsList()),
            ],
          ),
        ),
      ),
    );
  }

  /// 统计卡片（带缓存优化）
  Widget _buildStatsCard() {
    // 🎯 优化：只在数据变化时重新计算统计
    if (_lastLocalSongsLength != _localSongs.length || 
        _lastPlaylistsLength != _playlists.length ||
        _cachedTotalSongs == null) {
      
      _cachedTotalSongs = _localSongs.length;
      _cachedTotalPlaylists = _playlists.length;
      
      // 计算艺人数量（最耗时的操作）
      _cachedTotalArtists = _localSongs.map((s) => s.artist).toSet().length;
      
      _lastLocalSongsLength = _localSongs.length;
      _lastPlaylistsLength = _playlists.length;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.9),
            Theme.of(context).primaryColor.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.music_note_rounded, _cachedTotalSongs.toString(), '首歌曲'),
          Container(
            width: 1,
            height: 50,
            color: Colors.white.withOpacity(0.2),
          ),
          _buildStatItem(Icons.playlist_play_rounded, _cachedTotalPlaylists.toString(), '个歌单'),
          Container(
            width: 1,
            height: 50,
            color: Colors.white.withOpacity(0.2),
          ),
          _buildStatItem(Icons.person_outline_rounded, _cachedTotalArtists.toString(), '位艺人'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }


  /// 歌曲列表
  Widget _buildSongsList() {
    if (_loadingLocalSongs) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '正在加载...',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.getTextSecondary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_localSongs.isEmpty) {
      return _buildEmptySongsState();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _localSongs.length,
      itemBuilder: (context, index) {
        final song = _localSongs[index];
        return _buildSongItem(song);
      },
    );
  }

  Widget _buildSongItem(LocalSong song) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playSong(song),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: ImageLoader.loadAlbumArt(
                      albumArt: song.albumArt,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              song.artist,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.getTextSecondary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '•',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.getTextTertiary(context),
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              song.album,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.getTextTertiary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.getTextSecondary(context),
                    ),
                    onPressed: () => _showSongOptions(song),
                    iconSize: 20,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySongsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.15),
                    Theme.of(context).primaryColor.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.music_off_rounded,
                size: 72,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '还没有本地歌曲',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '试试扫描本地音乐或下载在线歌曲',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: _scanLocalMusic,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.folder_open_rounded, size: 22, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          '扫描本地音乐',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 歌单列表
  Widget _buildPlaylistsList() {
    if (_loadingPlaylists) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '正在加载...',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.getTextSecondary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _playlists.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildCreatePlaylistCard();
        }
        final playlist = _playlists[index - 1];
        return _buildPlaylistCard(playlist);
      },
    );
  }

  Widget _buildCreatePlaylistCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _createNewPlaylist,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.15),
                      Theme.of(context).primaryColor.withOpacity(0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 36,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '新建歌单',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(HivePlaylist playlist) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPlaylist(playlist),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面
              Expanded(
                child: _buildPlaylistCover(playlist),
              ),
              // 信息
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.songIds.length}首歌曲',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextTertiary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playSong(LocalSong song) {
    // 添加到播放队列（只添加点击的歌曲）
    _audioService.addToQueue(song);
  }

  void _showSongOptions(LocalSong song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      useRootNavigator: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽指示器
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getTextTertiary(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                // 歌曲信息
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ImageLoader.loadAlbumArt(
                          albumArt: song.albumArt,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.getTextPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.getTextSecondary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.getDivider(context).withOpacity(0.3),
                ),
                const SizedBox(height: 8),
                // 选项列表
                _buildOptionItem(
                  icon: Icons.play_arrow_rounded,
                  title: '播放',
                  iconColor: Theme.of(context).primaryColor,
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    _playSong(song);
                  },
                ),
                _buildOptionItem(
                  icon: Icons.playlist_add_rounded,
                  title: '添加到歌单',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    _showAddToPlaylistDialog(song);
                  },
                ),
                _buildOptionItem(
                  icon: Icons.delete_rounded,
                  title: '删除',
                  iconColor: Colors.red,
                  textColor: Colors.red,
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    _deleteSong(song);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.getTextPrimary(context)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppColors.getTextPrimary(context),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor ?? AppColors.getTextPrimary(context),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.getTextTertiary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scanLocalMusic() {
    context.push(AppRoutes.localSongScan);
  }
  
  void _openWiFiTransfer() {
    context.push(AppRoutes.wifiTransfer);
  }

  void _createNewPlaylist() async {
    final result = await Navigator.of(rootNavigatorKey.currentContext!, rootNavigator: true).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => const PlaylistEditorPage(
          title: '新建歌单',
          confirmText: '创建',
        ),
      ),
    );
    
    if (result != null) {
      try {
        // 创建歌单
        await PlaylistStorage.createPlaylist(
          name: result['name'] as String,
          description: result['description'] as String?,
          coverImage: result['coverImage'] as String?,
        );
        
        // 刷新歌单列表
        _loadPlaylists();
        
        // 显示成功提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('歌单 "${result['name']}" 创建成功'),
              backgroundColor: Theme.of(context).primaryColor,
            ),
          );
        }
      } catch (e) {
        // 显示错误提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('创建歌单失败：$e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openPlaylist(HivePlaylist playlist) {
    context.push('${AppRoutes.hivePlaylistDetail}/${playlist.id}');
  }

  /// 构建歌单封面
  Widget _buildPlaylistCover(HivePlaylist playlist) {
    final coverImage = playlist.coverImage;
    
    // 默认背景色
    final defaultGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Theme.of(context).primaryColor.withOpacity(0.7),
        Theme.of(context).primaryColor.withOpacity(0.5),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        gradient: defaultGradient,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Stack(
        children: [
          // 封面内容
          if (coverImage != null && coverImage.isNotEmpty)
            _buildCoverContent(coverImage)
          else
            // 默认图标
            Center(
              child: Icon(
                Icons.music_note_rounded,
                size: 56,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          
          // 歌曲数量标签
          if (playlist.songIds.isNotEmpty)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${playlist.songIds.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建封面内容
  Widget _buildCoverContent(String coverImage) {
    if (coverImage.startsWith('color:')) {
      // 颜色封面
      final colorStr = coverImage.substring(6); // 移除 "color:" 前缀
      final color = Color(int.parse('FF$colorStr', radix: 16));
      
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(16),
          ),
        ),
        child: Center(
          child: Icon(
            Icons.music_note_rounded,
            size: 56,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      );
    } else {
      // 图片封面
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
        child: coverImage.startsWith('http')
          ? Image.network(
              coverImage,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 56,
                    color: Colors.white.withOpacity(0.7),
                  ),
                );
              },
            )
          : Image.file(
              File(coverImage),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 56,
                    color: Colors.white.withOpacity(0.7),
                  ),
                );
              },
            ),
      );
    }
  }

  /// 构建小尺寸歌单封面（用于列表显示）
  Widget _buildSmallPlaylistCover(HivePlaylist playlist) {
    final coverImage = playlist.coverImage;
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildSmallCoverContent(coverImage),
      ),
    );
  }

  /// 构建小尺寸封面内容
  Widget _buildSmallCoverContent(String? coverImage) {
    if (coverImage == null || coverImage.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.8),
              Theme.of(context).primaryColor.withOpacity(0.6),
            ],
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.music_note_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      );
    }
    
    if (coverImage.startsWith('color:')) {
      final colorStr = coverImage.substring(6);
      final color = Color(int.parse('FF$colorStr', radix: 16));
      
      return Container(
        decoration: BoxDecoration(
          color: color,
        ),
        child: const Center(
          child: Icon(
            Icons.music_note_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      );
    }
    
    // 图片封面
    return coverImage.startsWith('http')
      ? Image.network(
          coverImage,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Theme.of(context).primaryColor.withOpacity(0.6),
              child: const Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            );
          },
        )
      : Image.file(
          File(coverImage),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Theme.of(context).primaryColor.withOpacity(0.6),
              child: const Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            );
          },
        );
  }

  /// 显示添加到歌单对话框
  Future<void> _showAddToPlaylistDialog(LocalSong song) async {
    // 获取所有歌单
    final playlists = await PlaylistStorage.getPlaylists();
    
    if (!mounted) return;
    
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('还没有歌单，请先创建歌单'),
          backgroundColor: Theme.of(context).primaryColor,
          action: SnackBarAction(
            label: '创建歌单',
            textColor: Colors.white,
            onPressed: _createNewPlaylist,
          ),
        ),
      );
      return;
    }
    
    // 显示歌单选择对话框
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // 拖拽指示器
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.getTextTertiary(context).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 标题
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.playlist_add_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '添加到歌单',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.title,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 歌单列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  final isAlreadyInPlaylist = playlist.songIds.contains(song.id);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.getCard(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAlreadyInPlaylist 
                          ? Theme.of(context).primaryColor.withOpacity(0.3)
                          : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: _buildSmallPlaylistCover(playlist),
                      title: Text(
                        playlist.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${playlist.songIds.length} 首歌曲',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                      trailing: isAlreadyInPlaylist
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: Theme.of(context).primaryColor,
                          )
                        : Icon(
                            Icons.add_circle_outline_rounded,
                            color: AppColors.getTextTertiary(context),
                          ),
                      onTap: isAlreadyInPlaylist 
                        ? null 
                        : () async {
                            Navigator.of(context).pop();
                            await _addSongToPlaylist(song, playlist);
                          },
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 添加歌曲到歌单
  Future<void> _addSongToPlaylist(LocalSong song, HivePlaylist playlist) async {
    try {
      await PlaylistStorage.addSongToPlaylist(playlist.id, song.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('已添加到 "${playlist.name}"'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _deleteSong(LocalSong song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${song.title}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await LocalSongStorage.removeSong(song.id);
      _loadLocalSongs();
    }
  }
}

/// TabBar的SliverPersistentHeader代理
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: AppColors.getDivider(context).withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return true; // 允许主题切换时重新构建
  }
}

/// 🎯 优化：KeepAlive Wrapper - 保持Tab内容状态
/// 
/// 使用 AutomaticKeepAliveClientMixin 可以：
/// - 切换Tab时不销毁页面状态
/// - 避免重复加载数据
/// - 保持列表滚动位置
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用！
    return widget.child;
  }
}

