import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/online_song.dart';
import '../providers/online_music_provider.dart';
import '../utils/song_action_helper.dart';
import '../utils/image_loader.dart';

/// 在线歌曲列表项组件
class OnlineSongTile extends StatelessWidget {
  final OnlineSong song;
  final VoidCallback? onTap;
  final bool showAlbumArt;
  final bool showDownload;

  const OnlineSongTile({
    super.key,
    required this.song,
    this.onTap,
    this.showAlbumArt = true,
    this.showDownload = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<OnlineMusicProvider>(
      builder: (context, provider, child) {
        final isDownloaded = provider.isDownloaded(song.id);

        return InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 专辑封面
                if (showAlbumArt) ...[
                  _buildAlbumArt(),
                  const SizedBox(width: 12),
                ],

                // 歌曲信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 显示来源标签
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              song.source,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                          if (isDownloaded) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.download_done,
                              size: 14,
                              color: Colors.green[600],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // 收藏按钮
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () => SongActionHelper.showFavoriteDialog(context, song),
                  tooltip: '收藏到歌单',
                ),
                
                // 下载按钮
                if (showDownload) ...[
                  SongActionHelper.buildDownloadButton(context, song),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建专辑封面
  Widget _buildAlbumArt() {
    if (song.albumArt != null && song.albumArt!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: song.albumArt!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          httpHeaders: ImageLoader.httpHeaders,  // 添加 HTTP headers
          placeholder: (context, url) => Container(
            width: 56,
            height: 56,
            color: Colors.grey[300],
            child: const Icon(Icons.music_note, color: Colors.grey),
          ),
          errorWidget: (context, url, error) => Container(
            width: 56,
            height: 56,
            color: Colors.grey[300],
            child: const Icon(Icons.music_note, color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note, color: Colors.grey, size: 32),
    );
  }

}

