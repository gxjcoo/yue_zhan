import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../providers/theme_provider.dart';
import '../theme/theme_color_scheme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _wifiOnlyDownload = true;
  bool _autoPlay = false;
  String _audioQuality = '高品质';
  int _maxDownloads = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '设置',
          style: TextStyle(
            color: AppColors.getTextPrimary(context),
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        foregroundColor: AppColors.getTextPrimary(context),
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppColors.getTextPrimary(context),
            iconSize: 20,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        elevation: 0,
        toolbarHeight: 56,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingM,
          vertical: AppDimensions.spacingM,
        ),
        children: [
          // 播放设置
          _buildSectionHeader('播放设置'),
          _buildCard([
            _buildListTile(
              icon: Icons.high_quality,
              title: '音质偏好',
              trailing: Text(
                _audioQuality,
                style: AppTextStyles.labelLarge.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: _showQualitySelector,
            ),
            _buildDivider(),
            _buildSwitchTile(
              icon: Icons.play_circle,
              title: '自动播放',
              subtitle: '打开应用时自动播放上次歌曲',
              value: _autoPlay,
              onChanged: (value) => setState(() => _autoPlay = value),
            ),
          ]),

          const SizedBox(height: AppDimensions.spacingL),

          // 下载设置
          _buildSectionHeader('下载设置'),
          _buildCard([
            _buildSwitchTile(
              icon: Icons.wifi,
              title: '仅WiFi下载',
              subtitle: '使用移动数据时暂停下载',
              value: _wifiOnlyDownload,
              onChanged: (value) => setState(() => _wifiOnlyDownload = value),
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.numbers,
              title: '最大同时下载数',
              trailing: Text(
                '$_maxDownloads个',
                style: AppTextStyles.labelLarge.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: _showDownloadCountSelector,
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.cleaning_services,
              title: '清理缓存',
              subtitle: '删除临时文件和缓存',
              trailing: Icon(
                Icons.chevron_right,
                color: AppColors.getTextSecondary(context),
              ),
              onTap: _clearCache,
            ),
          ]),

          const SizedBox(height: AppDimensions.spacingL),

          // 外观设置
          _buildSectionHeader('外观设置'),
          _buildCard([
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return _buildListTile(
                  icon: themeProvider.currentThemeModeIcon,
                  title: '主题模式',
                  subtitle: themeProvider.currentThemeModeName,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.getTextSecondary(context),
                  ),
                  onTap: () => _showThemeModeSelector(context),
                );
              },
            ),
            _buildDivider(),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return _buildListTile(
                  icon: Icons.palette,
                  title: '主题色',
                  subtitle: themeProvider.currentColorSchemeData.name,
                  trailing: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: themeProvider.currentGradient,
                      shape: BoxShape.circle,
                    ),
                  ),
                  onTap: () => _showThemeColorSelector(context),
                );
              },
            ),
          ]),

          const SizedBox(height: AppDimensions.spacingL),

          // 关于
          _buildSectionHeader('关于'),
          _buildCard([
            _buildListTile(
              icon: Icons.info_outline,
              title: '版本信息',
              trailing: Text(
                'v1.0.0',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              onTap: () {},
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.description_outlined,
              title: '用户协议',
              trailing: Icon(
                Icons.chevron_right,
                color: AppColors.getTextSecondary(context),
              ),
              onTap: () {},
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.privacy_tip_outlined,
              title: '隐私政策',
              trailing: Icon(
                Icons.chevron_right,
                color: AppColors.getTextSecondary(context),
              ),
              onTap: () {},
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.book_outlined,
              title: '使用帮助',
              trailing: Icon(
                Icons.chevron_right,
                color: AppColors.getTextSecondary(context),
              ),
              onTap: () {},
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.bug_report_outlined,
              title: '反馈问题',
              trailing: Icon(
                Icons.chevron_right,
                color: AppColors.getTextSecondary(context),
              ),
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppDimensions.spacingXs,
        bottom: AppDimensions.spacingS,
        top: AppDimensions.spacingM,
      ),
      child: Text(
        title,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.getTextTertiary(context),
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: AppDimensions.borderRadiusL,
        boxShadow: AppDimensions.shadowS,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingM,
            vertical: 12,
          ),
          child: Row(
            children: [
              // 图标容器
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 14),
              
              // 文字内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.getTextTertiary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 尾部
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _buildListTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppDimensions.spacingM + 40 + 14,
      ),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: AppColors.getDivider(context).withOpacity(0.5),
      ),
    );
  }

  void _showQualitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽指示器
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getTextTertiary(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    '音质偏好',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildQualityOption('标准品质', '128kbps'),
                _buildQualityOption('高品质', '320kbps'),
                _buildQualityOption('无损品质', 'FLAC'),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQualityOption(String title, String subtitle) {
    final isSelected = _audioQuality == title;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textPrimary = AppColors.getTextPrimary(context);
    final textSecondary = AppColors.getTextSecondary(context);
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryColor : textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isSelected ? primaryColor.withOpacity(0.7) : textSecondary,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: primaryColor)
          : null,
      onTap: () {
        setState(() => _audioQuality = title);
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
  }

  void _showDownloadCountSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽指示器
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getTextTertiary(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    '最大同时下载数',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (int i = 1; i <= 5; i++)
                  _buildDownloadCountOption(i),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadCountOption(int count) {
    final isSelected = _maxDownloads == count;
    final primaryColor = AppColors.getPrimary(context);
    final textPrimary = AppColors.getTextPrimary(context);
    return ListTile(
      title: Text(
        '$count个',
        style: TextStyle(
          color: isSelected ? primaryColor : textPrimary,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: primaryColor)
          : null,
      onTap: () {
        setState(() => _maxDownloads = count);
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        title: Text(
          '清理缓存',
          style: TextStyle(
            color: AppColors.getTextPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '确定要清理所有缓存吗？这将删除临时文件和缓存数据。',
          style: TextStyle(
            color: AppColors.getTextSecondary(context),
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              '取消',
              style: TextStyle(
                color: AppColors.getTextSecondary(context),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('缓存已清理'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              backgroundColor: AppColors.getPrimary(context).withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '确定',
              style: TextStyle(
                color: AppColors.getPrimary(context),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeModeSelector(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽指示器
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getTextTertiary(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    '主题模式',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildThemeModeOption(
                  AppThemeMode.light,
                  Icons.light_mode_rounded,
                  '浅色',
                  '明亮清新',
                  themeProvider,
                ),
                _buildThemeModeOption(
                  AppThemeMode.dark,
                  Icons.dark_mode_rounded,
                  '深色',
                  '护眼舒适',
                  themeProvider,
                ),
                _buildThemeModeOption(
                  AppThemeMode.system,
                  Icons.brightness_auto_rounded,
                  '跟随系统',
                  '自动切换',
                  themeProvider,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeModeOption(
    AppThemeMode mode,
    IconData icon,
    String title,
    String subtitle,
    ThemeProvider themeProvider,
  ) {
    final isSelected = themeProvider.themeMode == mode;
    final primaryColor = AppColors.getPrimary(context);
    final textPrimary = AppColors.getTextPrimary(context);
    final textSecondary = AppColors.getTextSecondary(context);
    final cardColor = AppColors.getCard(context);
    
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.2)
              : cardColor,
          borderRadius: AppDimensions.borderRadiusS,
        ),
        child: Icon(
          icon,
          color: isSelected ? primaryColor : textSecondary,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryColor : textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isSelected ? primaryColor.withOpacity(0.7) : textSecondary,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: primaryColor)
          : null,
      onTap: () async {
        await themeProvider.setThemeMode(mode);
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
    );
  }

  void _showThemeColorSelector(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽指示器
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getTextTertiary(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Text(
                    '选择主题色',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: ThemeColorSchemes.getAllSchemes().length,
                    itemBuilder: (context, index) {
                      final entry = ThemeColorSchemes.getAllSchemes()[index];
                      return _buildColorSchemeOption(
                        entry.key,
                        entry.value,
                        themeProvider,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorSchemeOption(
    ThemeColorScheme scheme,
    ColorSchemeData schemeData,
    ThemeProvider themeProvider,
  ) {
    final isSelected = themeProvider.colorScheme == scheme;
    final borderColor = AppColors.getTextPrimary(context);
    
    return GestureDetector(
      onTap: () async {
        await themeProvider.setColorScheme(scheme);
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: schemeData.gradient,
          borderRadius: AppDimensions.borderRadiusM,
          border: Border.all(
            color: isSelected ? borderColor : Colors.transparent,
            width: 3,
          ),
        ),
        child: Stack(
          children: [
            // 半透明遮罩
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: AppDimensions.borderRadiusM,
              ),
            ),
            // 文字和图标
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 32,
                    ),
                  if (isSelected) const SizedBox(height: 8),
                  Text(
                    schemeData.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    schemeData.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
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
}

