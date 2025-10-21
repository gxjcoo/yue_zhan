import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/custom_bottom_nav_bar.dart';

/// 主Shell页面，包含底部导航栏
/// 使用 StatefulShellRoute 保持页面状态
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({
    super.key,
    required this.navigationShell,
  });

  void _onItemTapped(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      extendBody: true, // 让body延伸到底部导航栏下方
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onItemTapped(context, index),
        items: const [
          CustomBottomNavBarItem(
            icon: Icons.library_music_outlined,
            activeIcon: Icons.library_music,
            label: '音乐库',
          ),
          CustomBottomNavBarItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: '设置',
          ),
        ],
      ),
    );
  }
}

