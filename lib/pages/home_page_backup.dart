import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routes/app_routes.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '音乐播放器',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 最近播放
            _buildSectionHeader('最近播放', () {
              // 可以添加查看全部的逻辑
            }),
            const SizedBox(height: 12),
            _buildRecentlyPlayed(),
            
            const SizedBox(height: 32),
            
            // 推荐歌单
            _buildSectionHeader('推荐歌单', () {
              context.push(AppRoutes.library);
            }),
            const SizedBox(height: 12),
            _buildRecommendedPlaylists(),
            
            const SizedBox(height: 32),
            
            // 为你推荐
            _buildSectionHeader('为你推荐', () {
              // 可以添加查看全部的逻辑
            }),
            const SizedBox(height: 12),
            _buildRecommendedSongs(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback? onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text('查看全部'),
          ),
      ],
    );
  }

  Widget _buildRecentlyPlayed() {
    // 最近播放功能待实现
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Text(
          '暂无最近播放记录',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildRecommendedPlaylists() {
    // 推荐歌单功能待实现
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Text(
          '暂无推荐歌单',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildRecommendedSongs() {
    // 推荐歌曲功能待实现
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Text(
          '暂无推荐歌曲',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

}
