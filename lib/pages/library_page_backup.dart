import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/local_song.dart';
import '../models/hive_playlist.dart';
import '../services/hive_local_song_storage.dart';
import '../services/playlist_storage.dart';
import '../services/global_audio_service.dart';
import '../services/library_refresh_notifier.dart';
import '../providers/online_music_provider.dart';
import '../widgets/song_tile.dart';
import '../pages/playlist_editor_page.dart';
import '../routes/app_routes.dart';
import '../pages/player_page.dart';
import '../utils/logger.dart';
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  List<LocalSong> _localSongs = [];
  bool _loadingLocalSongs = false;
  
  // 歌单相关状态
  List<HivePlaylist> _playlists = [];
  bool _loadingPlaylists = false;
  
  // 删除功能相关状态
  bool _isSelectionMode = false;
  Set<String> _selectedSongIds = {};
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    
    // 监听音乐库刷新通知
    LibraryRefreshNotifier().addListener(_onLibraryRefresh);
    
    _loadLocalSongs();
    _loadPlaylists();
  }
  
  /// 当收到刷新通知时，重新加载本地歌曲
  void _onLibraryRefresh() {
    Logger.info('收到音乐库刷新通知，重新加载歌曲...', tag: 'LibraryPage');
    _loadLocalSongs();
  }

  Future<void> _loadLocalSongs() async {
    if (_loadingLocalSongs) return;
    
    setState(() {
      _loadingLocalSongs = true;
    });
    
    try {
      final localSongs = await LocalSongStorage.getSongs();
      if (mounted) {
        setState(() {
          _localSongs = localSongs;
          _loadingLocalSongs = false;
        });
      }
    } catch (e) {
      print('加载本地歌曲失败: $e');
      if (mounted) {
        setState(() {
          _loadingLocalSongs = false;
        });
      }
    }
  }

  Future<void> _loadPlaylists() async {
    if (_loadingPlaylists) return;
    
    setState(() {
      _loadingPlaylists = true;
    });
    
    try {
      final playlists = await PlaylistStorage.getPlaylists();
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _loadingPlaylists = false;
        });
      }
    } catch (e) {
      print('加载歌单失败: $e');
      if (mounted) {
        setState(() {
          _loadingPlaylists = false;
        });
      }
    }
  }

  /// 刷新本地歌曲数据
  void refreshLocalSongs() {
    _loadLocalSongs();
  }
  
  /// 刷新歌单数据
  void refreshPlaylists() {
    _loadPlaylists();
  }

  @override
  void dispose() {
    // 移除监听器
    LibraryRefreshNotifier().removeListener(_onLibraryRefresh);
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 当应用从后台回到前台时，刷新数据
    if (state == AppLifecycleState.resumed) {
      _loadLocalSongs();
      _loadPlaylists();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode 
          ? Text('已选择 ${_selectedSongIds.length} 首')
          : const Text(
              '音乐库',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        leading: _isSelectionMode 
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
            )
          : null,
        actions: _isSelectionMode 
          ? [
              if (_selectedSongIds.isNotEmpty)
                IconButton(
                  icon: _isDeleting 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete),
                  onPressed: _isDeleting ? null : _deleteSelectedSongs,
                  tooltip: '删除选中歌曲',
                ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'select_all':
                      _selectAllLocalSongs();
                      break;
                    case 'deselect_all':
                      _deselectAllSongs();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'select_all',
                    child: Row(
                      children: [
                        Icon(Icons.select_all, size: 20),
                        SizedBox(width: 8),
                        Text('全选'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'deselect_all',
                    child: Row(
                      children: [
                        Icon(Icons.deselect, size: 20),
                        SizedBox(width: 8),
                        Text('取消全选'),
                      ],
                    ),
                  ),
                ],
              ),
            ]
          : [
              if (_localSongs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _enterSelectionMode,
                  tooltip: '管理歌曲',
                ),
            ],
        bottom: _isSelectionMode 
          ? null 
          : TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '歌单'),
                Tab(text: '歌曲'),
              ],
            ),
      ),
      body: _isSelectionMode 
        ? _buildSongsTab()  // 选择模式下只显示歌曲页面
        : TabBarView(
            controller: _tabController,
            children: [
              _buildPlaylistsTab(),
              _buildSongsTab(),
            ],
          ),
    );
  }

  Widget _buildPlaylistsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadPlaylists();
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 创建歌单按钮
            Card(
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, size: 30),
                ),
                title: const Text('创建歌单'),
                subtitle: const Text('创建你的专属歌单'),
                onTap: _createPlaylist,
              ),
            ),
            const SizedBox(height: 16),
            // 歌单列表
            Expanded(
              child: _loadingPlaylists
                ? const Center(child: CircularProgressIndicator())
                : _playlists.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.library_music_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '还没有歌单',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '点击上方按钮创建你的第一个歌单',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _playlists.length,
                      itemBuilder: (context, index) {
                        final hivePlaylist = _playlists[index];
                        return _buildPlaylistCard(hivePlaylist);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadLocalSongs();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
          if (!_isSelectionMode) ...[
            const SizedBox(height: 16),
            // 扫描本地歌曲按钮
            Card(
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.folder,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                title: const Text('扫描本地歌曲'),
                subtitle: const Text('从设备导入音乐文件'),
                onTap: _scanLocalSongs,
              ),
            ),
            const SizedBox(height: 16),
            // 播放全部按钮
            Card(
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                title: const Text('播放全部'),
                subtitle: Text('${_localSongs.length} 首歌曲'),
                onTap: () => _playAllSongs(),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 16),
            // 选择模式提示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '选择要删除的歌曲，点击歌曲来切换选择状态',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // 歌曲列表
          Expanded(
            child: _localSongs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_note_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '还没有歌曲',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '点击上方按钮扫描本地歌曲',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _localSongs.length,
                  // 🎯 性能优化参数
                  cacheExtent: 200,  // 预渲染200像素外的内容
                  addAutomaticKeepAlives: false,  // 不保持已滚动出屏幕的widget状态
                  addRepaintBoundaries: true,  // 减少重绘范围
                  itemBuilder: (context, index) {
                    final localSong = _localSongs[index];
                    final isSelected = _selectedSongIds.contains(localSong.id);
                    
                    return SongTile(
                      song: localSong,
                      onTap: _isSelectionMode 
                        ? () => _toggleSongSelection(localSong.id)
                        : () => _playSong(localSong),
                      onLongPress: _isSelectionMode 
                        ? null 
                        : () => _startSelectionWithSong(localSong.id),
                      showAlbumArt: true,
                      showIndex: !_isSelectionMode,
                      index: index + 1,
                      isSelectable: _isSelectionMode,
                      isSelected: isSelected,
                    );
                  },
                ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(HivePlaylist hivePlaylist) {
    return GestureDetector(
      onTap: () => _openHivePlaylist(hivePlaylist),
      onLongPress: () => _showPlaylistMenu(hivePlaylist),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图
            Expanded(
              child: _buildPlaylistCover(hivePlaylist),
            ),
            // 歌单信息
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hivePlaylist.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${hivePlaylist.songCount} 首歌曲',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建歌单封面
  Widget _buildPlaylistCover(HivePlaylist playlist) {
    final coverImage = playlist.coverImage;
    
    // 默认背景色
    final defaultColor = Colors.primaries[
        playlist.name.hashCode % Colors.primaries.length];
    
    if (coverImage == null) {
      // 没有封面，使用默认颜色
      return Container(
        width: double.infinity,
        color: defaultColor,
        child: const Icon(
          Icons.library_music,
          size: 60,
          color: Colors.white,
        ),
      );
    }
    
    if (coverImage.startsWith('color:')) {
      // 颜色封面（colorStr 应该是不带 # 的十六进制字符串，如 "FF6B6B"）
      final colorStr = coverImage.substring(6);
      final color = Color(int.parse('FF$colorStr', radix: 16));
      return Container(
        width: double.infinity,
        color: color,
        child: const Icon(
          Icons.library_music,
          size: 60,
          color: Colors.white,
        ),
      );
    }
    
    if (coverImage.startsWith('http')) {
      // 网络图片
      return Container(
        width: double.infinity,
        color: defaultColor,
        child: Image.network(
          coverImage,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.library_music,
              size: 60,
              color: Colors.white,
            );
          },
        ),
      );
    }
    
    // 本地图片
    return Container(
      width: double.infinity,
      color: defaultColor,
      child: Image.file(
        File(coverImage),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.library_music,
            size: 60,
            color: Colors.white,
          );
        },
      ),
    );
  }

  Future<void> _createPlaylist() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const PlaylistEditorPage(
          title: '创建歌单',
          confirmText: '创建',
        ),
      ),
    );
    
    if (result != null) {
      final name = result['name'] as String;
      final description = result['description'] as String?;
      final coverImage = result['coverImage'] as String?;
      final songIds = result['songIds'] as List<String>;
      
      try {
        final playlist = await PlaylistStorage.createPlaylist(
          name: name,
          description: description,
          coverImage: coverImage,
        );
        
        // 添加选中的歌曲
        if (songIds.isNotEmpty) {
          await PlaylistStorage.addSongsToPlaylist(playlist.id, songIds);
        }
        
        await _loadPlaylists();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('歌单 "$name" 创建成功${songIds.isNotEmpty ? '，已添加 ${songIds.length} 首歌曲' : ''}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('创建失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _scanLocalSongs() {
    context.push(AppRoutes.localSongScan);
  }
  
  Future<void> _openHivePlaylist(HivePlaylist hivePlaylist) async {
    final result = await context.push('${AppRoutes.hivePlaylistDetail}/${hivePlaylist.id}');
    
    // 如果返回 true，表示需要刷新歌单列表
    if (result == true) {
      _loadPlaylists();
    }
  }
  
  void _showPlaylistMenu(HivePlaylist playlist) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('编辑歌单'),
                onTap: () {
                  Navigator.pop(context);
                  _editPlaylist(playlist);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除歌单', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deletePlaylist(playlist);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('取消'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Future<void> _editPlaylist(HivePlaylist playlist) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistEditorPage(
          title: '编辑歌单',
          confirmText: '保存',
          initialName: playlist.name,
          initialDescription: playlist.description,
          initialCoverImage: playlist.coverImage,
          initialSongIds: playlist.songIds,
        ),
      ),
    );
    
    if (result != null) {
      final name = result['name'] as String;
      final description = result['description'] as String?;
      final coverImage = result['coverImage'] as String?;
      final songIds = result['songIds'] as List<String>;
      
      try {
        final updatedPlaylist = playlist.copyWith(
          name: name,
          description: description,
          coverImage: coverImage,
          songIds: songIds,
        );
        
        await PlaylistStorage.updatePlaylist(updatedPlaylist);
        await _loadPlaylists();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('歌单更新成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  void _deletePlaylist(HivePlaylist playlist) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除歌单 "${playlist.name}" 吗？\n\n这不会删除歌单中的歌曲文件。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                
                try {
                  await PlaylistStorage.deletePlaylist(playlist.id);
                  await _loadPlaylists();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('歌单 "${playlist.name}" 已删除'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('删除失败: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  void _playSong(dynamic song, {int? index}) {
    // 找到歌曲在列表中的索引
    final songIndex = index ?? _localSongs.indexWhere((s) => s.id == (song as LocalSong).id);
    
    // 使用全局播放服务
    final audioService = GlobalAudioService();
    audioService.playSong(
      song: song,
      playlist: _localSongs,
      index: songIndex >= 0 ? songIndex : 0,
    );
    
    // 打开播放器页面
    context.push(
      AppRoutes.player,
      extra: PlayerArguments(
        song: song,
        playlist: _localSongs,
        initialIndex: songIndex >= 0 ? songIndex : 0,
      ),
    );
  }

  void _playAllSongs() {
    if (_localSongs.isNotEmpty) {
      _playSong(_localSongs.first, index: 0);
    }
  }

  // ==================== 删除功能相关方法 ====================

  /// 进入选择模式
  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedSongIds.clear();
    });
  }

  /// 退出选择模式
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedSongIds.clear();
    });
  }

  /// 开始选择模式并选中指定歌曲
  void _startSelectionWithSong(String songId) {
    setState(() {
      _isSelectionMode = true;
      _selectedSongIds.clear();
      _selectedSongIds.add(songId);
    });
  }

  /// 切换歌曲选择状态
  void _toggleSongSelection(String songId) {
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  /// 选择所有本地歌曲
  void _selectAllLocalSongs() {
    setState(() {
      _selectedSongIds = _localSongs.map((song) => song.id).toSet();
    });
  }

  /// 取消选择所有歌曲
  void _deselectAllSongs() {
    setState(() {
      _selectedSongIds.clear();
    });
  }


  /// 删除选中的歌曲
  void _deleteSelectedSongs() {
    if (_selectedSongIds.isEmpty) return;

    final selectedCount = _selectedSongIds.length;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除选中的 $selectedCount 首歌曲吗？\n\n注意：这只会从音乐库中移除，不会删除原文件。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performDeleteSongs(_selectedSongIds.toList());
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  /// 执行删除操作
  Future<void> _performDeleteSongs(List<String> songIds) async {
    setState(() {
      _isDeleting = true;
    });

    try {
      // 同步清理下载记录
      final onlineMusicProvider = Provider.of<OnlineMusicProvider>(context, listen: false);
      for (final songId in songIds) {
        onlineMusicProvider.cleanupDownloadRecordByPath(songId);
      }
      
      // 从所有歌单中移除这些歌曲
      int totalPlaylistRemovals = 0;
      for (final songId in songIds) {
        final count = await PlaylistStorage.removeSongFromAllPlaylists(songId);
        totalPlaylistRemovals += count;
      }
      
      // 从本地数据库删除
      await LocalSongStorage.removeSongs(songIds);
      
      // 重新加载本地歌曲列表和歌单
      await _loadLocalSongs();
      await _loadPlaylists();
      
      // 退出选择模式
      _exitSelectionMode();
      
      // 显示成功消息
      if (mounted) {
        String message = '已删除 ${songIds.length} 首歌曲';
        if (totalPlaylistRemovals > 0) {
          message += '，并从 $totalPlaylistRemovals 个歌单中移除';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 显示错误消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }
}
