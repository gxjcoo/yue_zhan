import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/online_song.dart';
import '../services/search_history_storage.dart';
import '../services/global_audio_service.dart';
import '../providers/search_provider.dart';
import '../providers/download_provider.dart';
import '../routes/app_routes.dart';
import '../pages/player_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../utils/song_action_helper.dart';
import '../config/constants.dart';

class SearchPage extends StatefulWidget {
  final String initialQuery;

  const SearchPage({super.key, this.initialQuery = ''});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalAudioService _audioService = GlobalAudioService();
  Timer? _debounceTimer;

  List<String> _searchHistory = [];
  bool _isSearching = false;
  
  // Tab 控制器
  TabController? _tabController;
  List<String> _musicSources = [];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    if (widget.initialQuery.isNotEmpty) {
      _performSearch(widget.initialQuery);
    }
    _loadSearchHistory();
    _initTabController();
    
    // 监听搜索框文本变化以更新UI
    _searchController.addListener(() {
      setState(() {});
    });
  }
  
  void _initTabController() {
    // 从 SearchProvider 获取可用音乐源
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final searchProvider = context.read<SearchProvider>();
        setState(() {
          _musicSources = ['全部', ...searchProvider.availableSources];
          _tabController = TabController(
            length: _musicSources.length,
            vsync: this,
          );
          // 添加监听器以更新Tab状态
          _tabController!.addListener(() {
            if (mounted) {
              setState(() {});
            }
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final histories = await SearchHistoryStorage.getHistories();
    setState(() {
      _searchHistory = histories;
    });
  }

  void _onSearchTextChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      Constants.searchDebounceDelay,
      () {
        if (mounted) {
          if (value.isNotEmpty) {
            _performSearch(value);
          } else {
            _clearSearch();
          }
        }
      },
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      _clearSearch();
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // 保存搜索历史
    await SearchHistoryStorage.addHistory(query);
    await _loadSearchHistory();

    // 执行在线搜索
    await context.read<SearchProvider>().search(query);

    if (mounted) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _isSearching = false;
    });
    context.read<SearchProvider>().clearSearch();
  }

  Future<void> _clearHistory() async {
    await SearchHistoryStorage.clearHistory();
    setState(() {
      _searchHistory = [];
    });
  }

  Future<void> _removeHistoryItem(String query) async {
    await SearchHistoryStorage.removeHistory(query);
    await _loadSearchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Column(
          children: [
            // 搜索框
            _buildSearchBar(),

            // 搜索结果或历史
            Expanded(
              child: _searchController.text.isEmpty
                  ? _buildSearchHistory()
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  /// 搜索框
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [

          // 搜索输入框容器
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      autofocus: false,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.getTextPrimary(context),
                      ),
                      decoration: InputDecoration(
                        hintText: '搜索歌曲、歌手、专辑...',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: AppColors.getTextTertiary(context),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _onSearchTextChanged,
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _performSearch(value);
                        }
                      },
                    ),
                  ),
                  // 清除按钮
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _clearSearch();
                        _focusNode.requestFocus();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.getTextTertiary(context).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 搜索历史
  Widget _buildSearchHistory() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (_searchHistory.isNotEmpty) ...[
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '搜索历史',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextPrimary(context),
                    letterSpacing: -0.3,
                  ),
                ),
                TextButton(
                  onPressed: _clearHistory,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '清空全部',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextTertiary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 历史列表
          ..._searchHistory.map((query) => _buildHistoryItem(query)),

          const SizedBox(height: 24),
        ],

        // 提示卡片
        _buildEmptyStateCard(),
      ],
    );
  }

  /// 历史项
  Widget _buildHistoryItem(String query) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _searchController.text = query;
            _performSearch(query);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: AppColors.getTextTertiary(context),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    query,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _removeHistoryItem(query),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.getTextTertiary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 空状态卡片
  Widget _buildEmptyStateCard() {
    return Container(
      padding: const EdgeInsets.all(32),
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '发现好音乐',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '搜索你喜欢的歌曲、歌手或专辑',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 搜索结果
  Widget _buildSearchResults() {
    return Consumer2<SearchProvider, DownloadProvider>(
      builder: (context, searchProvider, downloadProvider, child) {
        if (_isSearching) {
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
                  '正在搜索...',
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

        if (searchProvider.errorMessage != null) {
          return _buildErrorState(searchProvider.errorMessage ?? '搜索失败');
        }

        final results = searchProvider.searchResults;
        final resultsBySource = searchProvider.searchResultsBySource;

        if (results.isEmpty) {
          return _buildNoResultsState();
        }

        // 如果 TabController 还未初始化，显示加载状态
        if (_tabController == null) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.getPrimary(context),
            ),
          );
        }

        return Column(
          children: [
            // Tab 栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.getCard(context),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _musicSources.asMap().entries.map((entry) {
                    final index = entry.key;
                    final source = entry.value;
                    // 计算每个源的歌曲数量
                    int count;
                    if (source == '全部') {
                      count = results.length;
                    } else {
                      count = resultsBySource[source]?.length ?? 0;
                    }
                    
                    final isSelected = _tabController!.index == index;
                    
                    return Padding(
                      padding: EdgeInsets.only(right: index < _musicSources.length - 1 ? 8 : 0),
                      child: _buildSourceTab(source, count, isSelected, index),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            // TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _musicSources.map((source) {
                  List<OnlineSong> songs;
                  if (source == '全部') {
                    songs = results;
                  } else {
                    songs = resultsBySource[source] ?? [];
                  }
                  
                  if (songs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.getTextTertiary(context).withOpacity(0.1),
                                  AppColors.getTextTertiary(context).withOpacity(0.05),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.music_off_rounded,
                              size: 56,
                              color: AppColors.getTextTertiary(context).withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '$source 暂无结果',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingM,
                    ),
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      final isDownloaded = downloadProvider.isDownloaded(song.id);
                      return _buildSongItem(song, isDownloaded);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建音乐源Tab
  Widget _buildSourceTab(String source, int count, bool isSelected, int index) {
    return GestureDetector(
      onTap: () {
        _tabController!.animateTo(index);
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.8),
                  ],
                )
              : null,
          color: isSelected ? null : AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              source,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected 
                    ? Colors.white 
                    : AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.25)
                    : Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 歌曲项
  Widget _buildSongItem(OnlineSong song, bool isDownloaded) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
                // 歌曲信息
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

                // 下载按钮
                _buildDownloadButton(song, isDownloaded),

                const SizedBox(width: 4),

                // 更多按钮
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

  /// 下载按钮
  Widget _buildDownloadButton(OnlineSong song, bool isDownloaded) {
    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, child) {
        final isDownloading = downloadProvider.isDownloading(song.id);
        final downloadProgress = downloadProvider.getDownloadProgress(song.id);
        final hasFailed = downloadProvider.hasDownloadFailed(song.id);

        // 已下载成功
        if (isDownloaded && !hasFailed) {
          return Container(
            padding: const EdgeInsets.all(AppDimensions.spacingS),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 20,
            ),
          );
        }

        // 正在下载
        if (isDownloading) {
          return SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    value: downloadProgress > 0 ? downloadProgress : null,
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.getPrimary(context)),
                    backgroundColor: AppColors.getTextTertiary(context).withOpacity(0.2),
                  ),
                ),
                Text(
                  '${(downloadProgress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getPrimary(context),
                  ),
                ),
              ],
            ),
          );
        }

        // 下载失败 - 显示重试图标
        if (hasFailed) {
          return IconButton(
            icon: const Icon(Icons.refresh),
            color: AppColors.error,
            iconSize: 24,
            tooltip: '下载失败，点击重试',
            onPressed: () {
              SongActionHelper.downloadSong(context, song);
            },
          );
        }

        // 未下载
        return IconButton(
          icon: const Icon(Icons.download_outlined),
          color: AppColors.getTextSecondary(context),
          iconSize: 24,
          onPressed: () {
            SongActionHelper.downloadSong(context, song);
          },
        );
      },
    );
  }

  /// 错误状态
  Widget _buildErrorState(String message) {
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
                  colors: [
                    Colors.red.withOpacity(0.15),
                    Colors.red.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 72,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '搜索失败',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 160,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _performSearch(_searchController.text),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '重试',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 无结果状态
  Widget _buildNoResultsState() {
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
            const Text(
              '未找到结果',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '试试其他关键词',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 播放歌曲（添加到播放队列）
  void _playSong(OnlineSong song) {
    // 添加到播放队列
    _audioService.addToQueue(song);
    
    // 跳转到播放页
    context.push(
      AppRoutes.player,
      extra: PlayerArguments(
        song: song,
        playlist: _audioService.playlist,
        initialIndex: _audioService.currentIndex,
      ),
    );
  }

  /// 显示歌曲选项
  void _showSongOptions(OnlineSong song) {
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
                // 歌曲信息头部
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
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
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.getDivider(context).withOpacity(0.3),
                ),
                const SizedBox(height: 8),
                // 选项列表
                _buildSongOption(
                  icon: Icons.play_arrow_rounded,
                  title: '播放',
                  iconColor: Theme.of(context).primaryColor,
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    _playSong(song);
                  },
                ),
                _buildSongOption(
                  icon: Icons.favorite_rounded,
                  title: '收藏到歌单',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    SongActionHelper.showFavoriteDialog(context, song);
                  },
                ),
                _buildSongOption(
                  icon: Icons.download_rounded,
                  title: '下载到本地',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    SongActionHelper.downloadSong(context, song);
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

  Widget _buildSongOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
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
                    color: AppColors.getTextPrimary(context),
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
}

