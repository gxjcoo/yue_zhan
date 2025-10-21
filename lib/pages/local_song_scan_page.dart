import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/local_song_scanner.dart';
import '../services/hive_local_song_storage.dart';
import '../services/permission_exception.dart';
import '../models/local_song.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';

class LocalSongScanPage extends StatefulWidget {
  const LocalSongScanPage({super.key});

  @override
  State<LocalSongScanPage> createState() => _LocalSongScanPageState();
}

class _LocalSongScanPageState extends State<LocalSongScanPage> {
  List<LocalSong> _songs = [];
  Set<String> _selectedSongIds = {}; // 选中的歌曲ID集合
  bool _isScanning = false;
  String _scanStatus = '';
  int _scannedCount = 0;

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedSongIds.length;
    final hasSelection = selectedCount > 0 && _songs.isNotEmpty;
    
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: hasSelection 
          ? Text('已选择 $selectedCount/${_songs.length} 首')
          : const Text('扫描本地歌曲'),
        backgroundColor: AppColors.getBackground(context),
        foregroundColor: AppColors.getTextPrimary(context),
        iconTheme: IconThemeData(
          color: AppColors.getTextPrimary(context),
        ),
        elevation: 0,
        actions: [
          if (!_isScanning && _songs.isEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _scanSongs,
            ),
          if (hasSelection)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                setState(() {
                  _selectedSongIds.clear();
                });
              },
              tooltip: '清除选择',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isScanning) {
      return _buildScanProgress();
    }

    if (_songs.isEmpty) {
      return _buildEmptyState();
    }

    return _buildSongList();
  }

  Widget _buildScanProgress() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.15),
                  Theme.of(context).primaryColor.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _scanStatus,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '已找到 $_scannedCount 首歌曲',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
                Icons.music_note_rounded,
                size: 72,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '未找到本地歌曲',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '点击下方按钮扫描本地音乐',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: _scanSongs,
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
                        Icon(Icons.search_rounded, size: 22, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          '扫描本地歌曲',
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

  Widget _buildSongList() {
    final selectedCount = _selectedSongIds.length;
    
    return Column(
      children: [
        // 顶部信息和操作栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          child: Column(
            children: [
              // 统计信息卡片
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.12),
                      Theme.of(context).primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '找到 ${_songs.length} 首歌曲',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedCount > 0 ? '已选 $selectedCount 首' : '点击歌曲选择',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$selectedCount/${ _songs.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 操作按钮区域 - 分两行布局
              Column(
                children: [
                  // 第一行：选择操作按钮
                  Row(
                    children: [
                      // 全选/全不选按钮
                      Expanded(
                        child: _buildActionButton(
                          onPressed: _toggleSelectAll,
                          icon: selectedCount == _songs.length 
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                          label: selectedCount == _songs.length ? '全不选' : '全选',
                          isSelected: selectedCount == _songs.length,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 反选按钮
                      Expanded(
                        child: _buildActionButton(
                          onPressed: _invertSelection,
                          icon: Icons.swap_horiz_rounded,
                          label: '反选',
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 快速筛选按钮
                      Expanded(
                        child: _buildActionButton(
                          onPressed: () => _showFilterMenu(context),
                          icon: Icons.filter_alt_rounded,
                          label: '筛选',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 第二行：保存按钮
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: selectedCount > 0 ? _saveSongs : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedCount > 0 
                          ? null
                          : AppColors.getCard(context),
                        foregroundColor: selectedCount > 0 
                          ? Colors.white 
                          : AppColors.getTextTertiary(context),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.zero,
                      ).copyWith(
                        backgroundColor: selectedCount > 0
                          ? MaterialStateProperty.all(null)
                          : MaterialStateProperty.all(AppColors.getCard(context)),
                      ),
                      child: selectedCount > 0
                        ? Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor,
                                  Theme.of(context).primaryColor.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.download_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '保存 $selectedCount 首到音乐库',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                size: 20,
                                color: AppColors.getTextTertiary(context),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '请选择要保存的歌曲',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.getTextTertiary(context),
                                ),
                              ),
                            ],
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: AppColors.getDivider(context).withOpacity(0.3),
        ),
        // 歌曲列表
        Expanded(
          child: ListView.builder(
            itemCount: _songs.length,
            // 🎯 性能优化参数
            cacheExtent: 200,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final song = _songs[index];
              final isSelected = _selectedSongIds.contains(song.id);
              
              return _buildSelectableSongTile(song, isSelected, index);
            },
          ),
        ),
      ],
    );
  }

  /// 构建可选择的歌曲瓦片
  Widget _buildSelectableSongTile(LocalSong song, bool isSelected, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(14),
        border: isSelected
          ? Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.5),
              width: 1.5,
            )
          : null,
        boxShadow: isSelected
          ? [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : [
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
          onTap: () => _toggleSongSelection(song.id),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                // 选择复选框
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.transparent,
                    border: Border.all(
                      color: isSelected 
                        ? Theme.of(context).primaryColor 
                        : AppColors.getTextTertiary(context),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
                ),
                const SizedBox(width: 10),
                // 歌曲封面或图标
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: song.albumArt != null && song.albumArt!.isNotEmpty
                        ? Image.file(
                            File(song.albumArt!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).primaryColor.withOpacity(0.2),
                                      Theme.of(context).primaryColor.withOpacity(0.1),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: Theme.of(context).primaryColor,
                                  size: 24,
                                ),
                              );
                            },
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor.withOpacity(0.2),
                                  Theme.of(context).primaryColor.withOpacity(0.1),
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.music_note_rounded,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // 歌曲信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.getTextPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${song.artist} • ${song.album}',
                              style: TextStyle(
                                fontSize: 12,
                                color: song.artist == '未知艺人' 
                                  ? Colors.orange 
                                  : AppColors.getTextSecondary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 歌词标签
                          if (song.lyric != null && song.lyric!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '词',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          // 未知艺人标签
                          if (song.artist == '未知艺人')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '未知',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 时长和大小
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      FormatUtils.formatDuration(song.duration),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatFileSize(song.fileSize),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.getTextTertiary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  /// 全选/全不选切换
  void _toggleSelectAll() {
    setState(() {
      if (_selectedSongIds.length == _songs.length) {
        // 当前全选，执行全不选
        _selectedSongIds.clear();
      } else {
        // 当前非全选，执行全选
        _selectedSongIds = _songs.map((song) => song.id).toSet();
      }
    });
  }

  /// 反选
  void _invertSelection() {
    setState(() {
      final allSongIds = _songs.map((song) => song.id).toSet();
      final newSelection = allSongIds.difference(_selectedSongIds);
      _selectedSongIds = newSelection;
    });
  }

  /// 快速筛选
  void _quickFilter(String filterType) {
    setState(() {
      Set<String> filteredIds = {};
      
      switch (filterType) {
        case 'has_cover':
          // 选择有封面的歌曲
          filteredIds = _songs
              .where((song) => song.albumArt != null && song.albumArt!.isNotEmpty)
              .map((song) => song.id)
              .toSet();
          break;
          
        case 'high_quality':
          // 选择高质量音频（FLAC, WAV, M4A）
          filteredIds = _songs
              .where((song) {
                final ext = song.filePath.toLowerCase();
                return ext.endsWith('.flac') || 
                       ext.endsWith('.wav') || 
                       ext.endsWith('.m4a');
              })
              .map((song) => song.id)
              .toSet();
          break;
          
        case 'large_files':
          // 选择大文件（>5MB）
          filteredIds = _songs
              .where((song) => song.fileSize > 5 * 1024 * 1024)
              .map((song) => song.id)
              .toSet();
          break;
          
        case 'has_artist':
          // 选择识别出艺人的歌曲
          filteredIds = _songs
              .where((song) => _hasKnownArtist(song))
              .map((song) => song.id)
              .toSet();
          break;
      }
      
      _selectedSongIds = filteredIds;
    });
    
    // 显示筛选结果
    final filterNames = {
      'has_cover': '有封面的歌曲',
      'high_quality': '高质量音频',
      'large_files': '大文件(>5MB)',
      'has_artist': '识别出艺人的歌曲',
    };
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已选择 ${_selectedSongIds.length} 首${filterNames[filterType]}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  // 🎯 优化：使用 FormatUtils 统一格式化（带缓存）
  // String _formatDuration(Duration duration) { ... } 已移除

  /// 检查歌曲是否有识别出的艺人信息
  bool _hasKnownArtist(LocalSong song) {
    return song.artist != '未知艺人' && song.artist.trim().isNotEmpty;
  }

  /// 显示筛选菜单
  void _showFilterMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 拖拽指示器
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.getTextTertiary(context).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 标题
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.2),
                            Theme.of(context).primaryColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.filter_alt_rounded,
                        size: 24,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '快速筛选',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 筛选选项
                _buildFilterOption(
                  context,
                  icon: Icons.image_rounded,
                  title: '有封面的歌曲',
                  subtitle: '选择有专辑封面的歌曲',
                  onTap: () {
                    Navigator.pop(context);
                    _quickFilter('has_cover');
                  },
                ),
                const SizedBox(height: 8),
                _buildFilterOption(
                  context,
                  icon: Icons.high_quality_rounded,
                  title: '高质量音频',
                  subtitle: 'FLAC、WAV、M4A格式',
                  onTap: () {
                    Navigator.pop(context);
                    _quickFilter('high_quality');
                  },
                ),
                const SizedBox(height: 8),
                _buildFilterOption(
                  context,
                  icon: Icons.storage_rounded,
                  title: '大文件',
                  subtitle: '文件大小 > 5MB',
                  onTap: () {
                    Navigator.pop(context);
                    _quickFilter('large_files');
                  },
                ),
                const SizedBox(height: 8),
                _buildFilterOption(
                  context,
                  icon: Icons.person_rounded,
                  title: '识别出艺人',
                  subtitle: '有明确艺人信息的歌曲',
                  onTap: () {
                    Navigator.pop(context);
                    _quickFilter('has_artist');
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

  /// 构建筛选选项
  Widget _buildFilterOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.getDivider(context).withOpacity(0.5),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.15),
                      Theme.of(context).primaryColor.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
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

  /// 构建操作按钮
  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    bool isSelected = false,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        gradient: isSelected
          ? LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.15),
                Theme.of(context).primaryColor.withOpacity(0.08),
              ],
            )
          : null,
        color: isSelected ? null : AppColors.getCard(context),
        borderRadius: BorderRadius.circular(12),
        border: isSelected
          ? Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.4),
              width: 1,
            )
          : null,
        boxShadow: isSelected
          ? [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                    ? Theme.of(context).primaryColor
                    : AppColors.getTextSecondary(context),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                        ? Theme.of(context).primaryColor
                        : AppColors.getTextSecondary(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _scanSongs() async {
    // 检查是否已经在扫描
    if (_isScanning) return;
    
    // Web环境显示特殊提示
    if (kIsWeb) {
      _showWebInstructions();
    }
    
    setState(() {
      _isScanning = true;
      _scanStatus = kIsWeb ? '请选择音频文件...' : '正在扫描本地歌曲...';
      _scannedCount = 0;
    });

    try {
      // 🎯 使用 Isolate 优化版本（非Web环境）
      final List<LocalSong> songs;
      
      if (kIsWeb) {
        // Web环境使用原始方法
        songs = await LocalSongScanner.scanSongs();
      } else {
        // 非Web环境使用 Isolate 优化版本
        songs = await LocalSongScanner.scanSongsWithIsolate(
          onProgress: (current, total) {
            // 实时更新进度（不阻塞主线程！）
            if (mounted) {
              setState(() {
                _scannedCount = current;
                _scanStatus = '正在读取元数据... ($current/$total)';
              });
            }
          },
          onStatusUpdate: (status) {
            // 更新状态文本
            if (mounted) {
              setState(() {
                _scanStatus = status;
              });
            }
          },
        );
      }
      
      if (mounted) {
        setState(() {
          _songs = songs;
          _isScanning = false;
          _scanStatus = '扫描完成';
          _scannedCount = songs.length;
          // 默认只选中识别出艺人的歌曲
          _selectedSongIds = songs
              .where((song) => _hasKnownArtist(song))
              .map((song) => song.id)
              .toSet();
        });
        
        // 显示扫描结果
        if (songs.isNotEmpty) {
          final selectedCount = _selectedSongIds.length;
          final unknownArtistCount = songs.length - selectedCount;
          
          String message;
          if (kIsWeb) {
            message = '选择 ${songs.length} 首歌曲';
          } else {
            message = '扫描完成 ${songs.length} 首歌曲（已智能合并重复项）🚀\n';
            message += '默认选中 $selectedCount 首有艺人信息的歌曲';
            if (unknownArtistCount > 0) {
              message += '，$unknownArtistCount 首未知艺人';
            }
            message += '\n✨ 使用 Isolate 优化，主线程保持流畅！';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(kIsWeb ? '未选择任何文件' : '未找到本地歌曲'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } on PermissionDeniedException {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        
        // 显示权限设置提示
        _showPermissionDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        print('扫描失败: $e');
        
        // Web环境显示更友好的错误信息
        final errorMessage = kIsWeb 
            ? '文件选择失败，请重试或刷新页面后再试'
            : '扫描失败: $e';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _saveSongs() async {
    if (_selectedSongIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少选择一首歌曲'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // 只保存选中的歌曲
      final selectedSongs = _songs.where((song) => _selectedSongIds.contains(song.id)).toList();
      
      await LocalSongStorage.saveSongs(selectedSongs);
      final totalCount = await LocalSongStorage.getSongCount();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存 ${selectedSongs.length} 首歌曲到音乐库，当前共有 $totalCount 首歌曲'),
            duration: const Duration(seconds: 3),
          ),
        );
        
        // 返回音乐库页面，使用pushReplacement确保页面重新创建
        context.pushReplacement(AppRoutes.library);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.getSurface(context),
          title: Text('需要存储权限', style: TextStyle(color: AppColors.getTextPrimary(context))),
          content: Text('此功能需要访问您的存储权限来扫描本地音乐文件。请在设置中授予权限。',
            style: TextStyle(color: AppColors.getTextSecondary(context))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('去设置'),
            ),
          ],
        );
      },
    );
  }
  
  void _showWebInstructions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.getSurface(context),
          title: Text('🌐 Web环境说明', style: TextStyle(color: AppColors.getTextPrimary(context))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('在Web环境中，您需要手动选择音频文件：',
                style: TextStyle(color: AppColors.getTextPrimary(context))),
              const SizedBox(height: 12),
              Text('1. 点击"扫描本地歌曲"按钮',
                style: TextStyle(color: AppColors.getTextPrimary(context))),
              Text('2. 在弹出的文件选择器中选择音频文件',
                style: TextStyle(color: AppColors.getTextPrimary(context))),
              Text('3. 支持同时选择多个文件',
                style: TextStyle(color: AppColors.getTextPrimary(context))),
              const SizedBox(height: 12),
              Text('支持的格式：MP3, WAV, FLAC, M4A, AAC, OGG', 
                   style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }
}