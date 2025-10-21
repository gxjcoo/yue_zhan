import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';

/// 封面选择器
class CoverSelector extends StatefulWidget {
  final String? initialCoverImage;
  final Function(String? coverImage) onCoverChanged;
  
  const CoverSelector({
    super.key,
    this.initialCoverImage,
    required this.onCoverChanged,
  });

  @override
  State<CoverSelector> createState() => _CoverSelectorState();
}

class _CoverSelectorState extends State<CoverSelector> {
  String? _coverImage;
  
  // 预设颜色
  static const List<Color> _presetColors = [
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFF45B7D1),
    Color(0xFF96CEB4),
    Color(0xFFFECA57),
    Color(0xFFFF9FF3),
    Color(0xFFFFA07A),
    Color(0xFF98D8C8),
    Color(0xFFF7B731),
    Color(0xFF5F27CD),
    Color(0xFFEE5A6F),
    Color(0xFF00D2D3),
  ];
  
  @override
  void initState() {
    super.initState();
    _coverImage = widget.initialCoverImage;
    
    // 如果没有初始封面，随机选择一个颜色（延迟执行避免在build期间调用setState）
    if (_coverImage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setRandomColor();
        }
      });
    }
  }
  
  /// 设置随机颜色
  void _setRandomColor() {
    final random = Random();
    final randomColor = _presetColors[random.nextInt(_presetColors.length)];
    _selectColor(randomColor);
  }
  
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          setState(() {
            _coverImage = path;
          });
          widget.onCoverChanged(path);
        }
      }
    } catch (e) {
      print('选择图片失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择图片失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _selectColor(Color color) {
    // 使用颜色的十六进制值作为标识（不带 # 符号）
    // 提取 RGB 部分（忽略 Alpha 通道）
    final r = ((color.red * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    final g = ((color.green * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    final b = ((color.blue * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
    final colorValue = '$r$g$b'.toUpperCase();
    setState(() {
      _coverImage = 'color:$colorValue';
    });
    widget.onCoverChanged(_coverImage);
  }
  

  
  bool _isColorCover() {
    return _coverImage?.startsWith('color:') ?? false;
  }
  
  Color? _getColorFromCover() {
    if (_isColorCover()) {
      final colorStr = _coverImage!.substring(6); // 移除 "color:" 前缀
      // colorStr 应该是不带 # 的十六进制字符串，如 "FF6B6B"
      return Color(int.parse('FF$colorStr', radix: 16));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用空间调整尺寸，确保不超出约束
        final maxSize = constraints.biggest.shortestSide;
        final size = maxSize.clamp(30.0, 70.0);
        final iconSize = (size * 0.4).clamp(16.0, 28.0);
        
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: _buildCoverContent(iconSize),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建封面内容
  Widget _buildCoverContent(double iconSize) {
    if (_coverImage == null) {
      return Center(
        child: Icon(
          Icons.add_photo_alternate_rounded,
          size: iconSize,
          color: Colors.grey,
        ),
      );
    }
    
    if (_isColorCover()) {
      return Container(
        decoration: BoxDecoration(
          color: _getColorFromCover(),
        ),
        child: Center(
          child: Icon(
            Icons.music_note_rounded,
            size: iconSize,
            color: Colors.white,
          ),
        ),
      );
    }
    
    // 图片封面
    return _coverImage!.startsWith('http')
      ? Image.network(
          _coverImage!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.broken_image_rounded,
                size: iconSize,
                color: Colors.grey,
              ),
            );
          },
        )
      : Image.file(
          File(_coverImage!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.broken_image_rounded,
                size: iconSize,
                color: Colors.grey,
              ),
            );
          },
        );
  }
}

