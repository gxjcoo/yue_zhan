import 'package:flutter/material.dart';
import '../widgets/song_selector_dialog.dart';
import '../widgets/cover_selector.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// 歌单编辑器页面（全屏）
class PlaylistEditorPage extends StatefulWidget {
  final String title;
  final String confirmText;
  final String? initialName;
  final String? initialDescription;
  final String? initialCoverImage;
  final List<String>? initialSongIds;
  
  const PlaylistEditorPage({
    super.key,
    required this.title,
    required this.confirmText,
    this.initialName,
    this.initialDescription,
    this.initialCoverImage,
    this.initialSongIds,
  });

  @override
  State<PlaylistEditorPage> createState() => _PlaylistEditorPageState();
}

class _PlaylistEditorPageState extends State<PlaylistEditorPage> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  String? _coverImage;
  List<String> _selectedSongIds = [];
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descController = TextEditingController(text: widget.initialDescription);
    _coverImage = widget.initialCoverImage;
    _selectedSongIds = List.from(widget.initialSongIds ?? []);
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }
  
  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('歌单名称不能为空'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    // 返回结果
    Navigator.of(context).pop({
      'name': name,
      'description': _descController.text.trim().isEmpty 
          ? null 
          : _descController.text.trim(),
      'coverImage': _coverImage,
      'songIds': _selectedSongIds,
    });
  }
  
  Future<void> _selectSongs() async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (context) => SongSelectorDialog(
          initialSelectedSongIds: _selectedSongIds,
        ),
        fullscreenDialog: true,
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedSongIds = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 渐变背景
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.getPrimary(context).withOpacity(0.1),
                  AppColors.getBackground(context),
                  AppColors.getBackground(context),
                ],
              ),
            ),
          ),
          
          // 主要内容
          SafeArea(
            child: Column(
              children: [
                // 自定义顶部栏
                _buildCustomAppBar(),
                
                // 内容区域 - 使用固定高度
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题区域（简化）
                        _buildCompactTitleSection(),
                        
                        const SizedBox(height: 16),
                        
                        // 基本信息区域 - 调整高度
                        SizedBox(
                          height: 290,
                          child: _buildCompactBasicInfoSection(),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // 封面和歌曲选择区域 - 修复高度问题
                        SizedBox(
                          height: 140,
                          child: Row(
                            children: [
                              // 封面选择
                              Expanded(
                                child: _buildCompactCoverSection(),
                              ),
                              const SizedBox(width: 12),
                              // 歌曲选择
                              Expanded(
                                child: _buildCompactSongSection(),
                              ),
                            ],
                          ),
                        ),
                        
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 底部浮动按钮
          _buildFloatingActionButton(),
        ],
      ),
    );
  }
  
  /// 自定义顶部栏
  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 关闭按钮
          Container(
            decoration: BoxDecoration(
              color: AppColors.getSurface(context).withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.getTextPrimary(context),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          
          const Spacer(),
          
          // 保存按钮
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.getPrimaryGradient(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _save,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    widget.confirmText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 紧凑标题区域
  Widget _buildCompactTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.getTextPrimary(context),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '创建属于你的专属音乐收藏',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondary(context),
          ),
        ),
      ],
    );
  }

  /// 封面选择区域
  Widget _buildCoverSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.getPrimary(context).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.getPrimaryGradient(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.palette_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '歌单封面',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '选择一个好看的封面来展示你的歌单',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          CoverSelector(
            initialCoverImage: _coverImage,
            onCoverChanged: (newCover) {
              setState(() {
                _coverImage = newCover;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.getPrimary(context).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.getPrimaryGradient(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '基本信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 歌单名称 - 调整高度
          SizedBox(
            height: 80,
            child: _buildModernCompactTextField(
              controller: _nameController,
              label: '歌单名称',
              hint: '我的最爱、深夜电台...',
              icon: Icons.title_rounded,
              isRequired: true,
              maxLines: 1,
            ),
          ),
          
          const SizedBox(height: 10),
          
          // 歌单描述 - 调整高度
          SizedBox(
            height: 120,
            child: _buildModernCompactTextField(
              controller: _descController,
              label: '歌单描述',
              hint: '描述一下这个歌单的风格或心情...',
              icon: Icons.description_rounded,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// 现代化文本输入框
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.getDivider(context).withOpacity(0.3),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.getTextPrimary(context),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppColors.getTextTertiary(context),
              ),
              prefixIcon: Icon(
                icon,
                color: AppColors.getPrimary(context),
                size: 22,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 歌曲选择区域
  Widget _buildSongSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.getPrimary(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.library_music_rounded,
                  color: AppColors.getPrimary(context),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '歌曲选择',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '添加你喜欢的歌曲到歌单中',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              // 歌曲数量标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.getPrimaryGradient(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedSongIds.length} 首',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 选择歌曲按钮
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.getPrimary(context).withOpacity(0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _selectSongs,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.getPrimary(context).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _selectedSongIds.isEmpty ? Icons.add_rounded : Icons.edit_rounded,
                          color: AppColors.getPrimary(context),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedSongIds.isEmpty ? '选择歌曲' : '修改歌曲选择',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedSongIds.isEmpty 
                            ? '从你的音乐库中选择歌曲'
                            : '已选择 ${_selectedSongIds.length} 首歌曲',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextSecondary(context),
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
    );
  }

  /// 紧凑封面选择区域
  Widget _buildCompactCoverSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.getPrimary(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  color: AppColors.getPrimary(context),
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '封面',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 封面选择器 - 适应可用空间
          Expanded(
            child: Center(
              child: CoverSelector(
                initialCoverImage: _coverImage,
                onCoverChanged: (newCover) {
                  setState(() {
                    _coverImage = newCover;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 紧凑歌曲选择区域
  Widget _buildCompactSongSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和数量
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.getPrimary(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.library_music_rounded,
                  color: AppColors.getPrimary(context),
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '歌曲',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ),
              // 歌曲数量标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: AppColors.getPrimaryGradient(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedSongIds.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 选择歌曲按钮
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.getPrimary(context).withOpacity(0.05),
                border: Border.all(
                  color: AppColors.getPrimary(context).withOpacity(0.2),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _selectSongs,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppColors.getPrimaryGradient(context),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.getPrimary(context).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _selectedSongIds.isEmpty ? Icons.add_rounded : Icons.edit_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedSongIds.isEmpty ? '选择歌曲' : '修改选择',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getPrimary(context),
                          ),
                        ),
                        if (_selectedSongIds.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${_selectedSongIds.length} 首',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 现代化紧凑文本输入框
  Widget _buildModernCompactTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // 输入框 - 固定高度
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.getDivider(context).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              textAlignVertical: maxLines == 1 ? TextAlignVertical.center : TextAlignVertical.top,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.getTextPrimary(context),
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: AppColors.getTextTertiary(context),
                  fontSize: 14,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    icon,
                    color: AppColors.getPrimary(context),
                    size: 20,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: maxLines > 1 ? 16 : 12,
                ),
            ),
          ),
        ),)
      ],
    );
  }

  /// 浮动操作按钮
  Widget _buildFloatingActionButton() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 0,
      child: SafeArea(
        minimum: const EdgeInsets.only(bottom: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.getPrimaryGradient(context),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.getPrimary(context).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _save,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.confirmText,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

