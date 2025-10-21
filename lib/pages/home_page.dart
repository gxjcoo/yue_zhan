import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../providers/download_provider.dart';
import '../services/global_audio_service.dart';
import '../utils/image_loader.dart';
import '../utils/song_action_helper.dart';
import '../models/online_song.dart';
import '../models/local_song.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalAudioService _audioService = GlobalAudioService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 顶部标题和大搜索框
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spacingM,
                  AppDimensions.spacingL,
                  AppDimensions.spacingM,
                  AppDimensions.spacingS,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 欢迎文字
                    Text(
                      '发现音乐',
                      style: AppTextStyles.displayLarge.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    
                    const SizedBox(height: 6),
                    
                    Text(
                      '探索无限音乐世界',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.getTextTertiary(context),
                        fontSize: 14,
                      ),
                    ),
                    
                    const SizedBox(height: AppDimensions.spacingL),
                    
                    // 大搜索框
                    _buildBigSearchBox(),
                    
                    const SizedBox(height: AppDimensions.spacingL),
                  ],
                ),
              ),
            ),

            // 最近播放
            _buildRecentlyPlayedSection(),

            // 间距
            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.spacingXl),
            ),

            // 最近下载
            _buildRecentDownloadsSection(),

            // 底部间距（为悬浮播放器和底部导航栏留空间）
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }

  /// 大搜索框 - 现代化设计
  Widget _buildBigSearchBox() {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.search),
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          gradient: AppColors.getPrimaryGradient(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              blurRadius: 32,
              offset: const Offset(0, 12),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push(AppRoutes.search),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 搜索图标
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  
                  const SizedBox(width: 14),
                  
                  // 提示文字
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '搜索音乐、歌手...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '发现你的下一首最爱',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 箭头图标
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 最近播放区域
  Widget _buildRecentlyPlayedSection() {
    // 暂时使用空列表，后续可以添加播放历史功能
    final List<dynamic> recentSongs = [];
    
    if (recentSongs.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppDimensions.pageHorizontalPaddingOnly,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '最近播放',
                  style: AppTextStyles.displayMedium.copyWith(
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.library),
                  child: Text(
                    '查看全部',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppDimensions.spacingM),
          
          SizedBox(
            height: 180,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingM,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: recentSongs.length > 10 ? 10 : recentSongs.length,
              itemBuilder: (context, index) {
                final song = recentSongs[index];
                return _buildRecentSongCard(song);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 最近播放歌曲卡片
  Widget _buildRecentSongCard(dynamic song) {
    String title = '未知歌曲';
    String artist = '未知艺人';
    String? albumArt;

    if (song is OnlineSong) {
      title = song.title;
      artist = song.artist;
      albumArt = song.albumArt;
    } else if (song is LocalSong) {
      title = song.title;
      artist = song.artist;
      albumArt = song.albumArt;
    }

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: AppDimensions.spacingM),
      child: InkWell(
        onTap: () => _playSong(song),
        borderRadius: AppDimensions.borderRadiusM,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: AppDimensions.borderRadiusM,
                boxShadow: AppDimensions.shadowM,
              ),
              child: ClipRRect(
                borderRadius: AppDimensions.borderRadiusM,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageLoader.loadAlbumArt(
                      albumArt: albumArt,
                      fit: BoxFit.cover,
                    ),
                    
                    // 渐变遮罩
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppDimensions.spacingS),
            
            // 歌名
            Text(
              title,
              style: AppTextStyles.songTitle.copyWith(
                color: AppColors.getTextPrimary(context),
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 2),
            
            // 歌手
            Text(
              artist,
              style: AppTextStyles.artistName.copyWith(
                color: AppColors.getTextSecondary(context),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 最近下载区域
  Widget _buildRecentDownloadsSection() {
    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, child) {
        // 从Map中获取values并转换为List，使用Provider中的onlineSongs
        final downloads = <OnlineSong>[];
        // 暂时显示空列表，实际应该从LocalSongRepository获取已下载歌曲
        
        if (downloads.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: AppDimensions.pagePadding,
              child: _buildEmptyDownloadsCard(),
            ),
          );
        }

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: AppDimensions.pageHorizontalPaddingOnly,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '最近下载',
                      style: AppTextStyles.displayMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.library),
                      child: Text(
                        '查看全部',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppDimensions.spacingM),
              
              ...downloads.map((song) => _buildDownloadItem(song)),
            ],
          ),
        );
      },
    );
  }

  /// 空下载提示卡片
  Widget _buildEmptyDownloadsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.download_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          
          const SizedBox(width: 14),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '还没有下载歌曲',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '搜索并下载你喜欢的音乐',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 下载项
  Widget _buildDownloadItem(OnlineSong song) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingXs,
      ),
      child: InkWell(
        onTap: () => _playSong(song),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spacingM),
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppDimensions.shadowS,
          ),
          child: Row(
            children: [
              // 封面
              ClipRRect(
                borderRadius: AppDimensions.borderRadiusS,
                child: ImageLoader.loadAlbumArt(
                  albumArt: song.albumArt,
                  width: AppDimensions.albumArtS,
                  height: AppDimensions.albumArtS,
                  fit: BoxFit.cover,
                ),
              ),
              
              const SizedBox(width: AppDimensions.spacingM),
              
              // 歌曲信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: AppTextStyles.songTitle.copyWith(
                        color: AppColors.getTextPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${song.artist} · ${song.album}',
                      style: AppTextStyles.artistName.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // 下载标识
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingS,
                  vertical: AppDimensions.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: AppDimensions.borderRadiusS,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '已下载',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: AppDimensions.spacingS),
              
              // 更多按钮
              IconButton(
                icon: const Icon(Icons.more_vert),
                color: AppColors.getTextSecondary(context),
                iconSize: 20,
                onPressed: () => _showSongOptions(song),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 播放歌曲（添加到播放队列）
  void _playSong(dynamic song) {
    if (song is OnlineSong || song is LocalSong) {
      _audioService.addToQueue(song);
    }
  }

  /// 显示歌曲选项
  void _showSongOptions(OnlineSong song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: AppDimensions.borderRadiusTopL,
      ),
      useRootNavigator: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow, color: Colors.white),
                title: const Text('播放', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  _playSong(song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.white),
                title: const Text('添加到歌单', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  SongActionHelper.showFavoriteDialog(context, song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: const Text('歌曲信息', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  // 显示歌曲信息
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

