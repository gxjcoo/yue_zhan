import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/wifi_transfer_service.dart';
import '../services/audio_metadata_processor.dart';
import '../services/hive_local_song_storage.dart';
import '../services/library_refresh_notifier.dart';
import '../models/local_song.dart';
import '../theme/app_colors.dart';
import '../utils/logger.dart';

/// WiFi 传输页面
class WiFiTransferPage extends StatefulWidget {
  const WiFiTransferPage({super.key});

  @override
  State<WiFiTransferPage> createState() => _WiFiTransferPageState();
}

class _WiFiTransferPageState extends State<WiFiTransferPage> {
  final WiFiTransferService _transferService = WiFiTransferService();
  
  bool _isStarting = false;
  bool _isRunning = false;
  String? _serverUrl;
  int _uploadedCount = 0;
  List<String> _uploadedFiles = [];

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
  }

  @override
  void dispose() {
    _stopServer();
    super.dispose();
  }

  /// 设置回调
  void _setupCallbacks() {
    _transferService.onFileUploaded = (filePath) async {
      if (mounted) {
        setState(() {
          _uploadedCount = _transferService.uploadedCount;
          _uploadedFiles = _transferService.uploadedFiles;
        });
        
        // 自动扫描并添加到音乐库
        await _scanAndAddFile(filePath);
        
        // 显示提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('文件上传成功: ${filePath.split('/').last}'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    };
  }
  
  /// 扫描并添加文件到音乐库
  Future<void> _scanAndAddFile(String filePath) async {
    try {
      // 检查是否已存在相同的歌曲（去重）
      final isDuplicate = await _checkDuplicate(filePath);
      if (isDuplicate) {
        Logger.info('文件已存在，跳过: $filePath', tag: 'WiFiTransferPage');
        return;
      }
      
      // 使用静态方法处理音频文件
      var song = await AudioMetadataProcessor.processAudioFile(filePath);
      
      if (song != null) {
        // 检查是否有同名的歌词和封面文件
        song = await _attachLyricAndCover(song);
        
        // 保存到数据库
        await LocalSongStorage.saveSongs([song]);
        
        // 通知音乐库刷新
        LibraryRefreshNotifier().notifyLibraryChanged();
        
        Logger.info('文件已添加到音乐库: ${song.title}', tag: 'WiFiTransferPage');
      } else {
        Logger.warn('无法处理文件: $filePath', tag: 'WiFiTransferPage');
        
        // 即使无法读取元数据，也尝试添加基本信息
        final file = File(filePath);
        final stat = await file.stat();
        final fileName = filePath.split('/').last;
        
        var basicSong = LocalSong(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
          artist: '未知艺术家',
          album: '未知专辑',
          filePath: filePath,
          duration: Duration.zero,
          lastModified: stat.modified,
          fileSize: stat.size,
        );
        
        // 检查是否有同名的歌词和封面文件
        basicSong = await _attachLyricAndCover(basicSong);
        
        await LocalSongStorage.saveSongs([basicSong]);
        LibraryRefreshNotifier().notifyLibraryChanged();
        
        Logger.info('文件已添加到音乐库（基本信息）: ${basicSong.title}', tag: 'WiFiTransferPage');
      }
    } catch (e) {
      Logger.error('添加文件到音乐库失败', error: e, tag: 'WiFiTransferPage');
    }
  }
  
  /// 检查是否为重复文件
  Future<bool> _checkDuplicate(String filePath) async {
    try {
      // 获取所有歌曲
      final allSongs = await LocalSongStorage.getSongs();
      
      // 获取文件名（不含扩展名）
      final fileName = filePath.split('/').last;
      final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      
      // 检查是否有相同文件路径或相同文件名的歌曲
      for (final song in allSongs) {
        // 检查文件路径
        if (song.filePath == filePath) {
          return true;
        }
        
        // 检查文件名（不含扩展名）
        final existingFileName = song.filePath.split('/').last;
        final existingNameWithoutExt = existingFileName.replaceAll(RegExp(r'\.[^.]+$'), '');
        
        if (existingNameWithoutExt == nameWithoutExt) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      Logger.error('检查重复文件失败', error: e, tag: 'WiFiTransferPage');
      return false;
    }
  }
  
  /// 关联歌词和封面文件
  Future<LocalSong> _attachLyricAndCover(LocalSong song) async {
    try {
      final musicDir = Directory(song.filePath).parent;
      final baseFileName = song.filePath.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
      
      String? lyricContent;
      String? coverPath;
      
      // 查找同名的歌词文件
      final lrcFile = File('${musicDir.path}/$baseFileName.lrc');
      if (await lrcFile.exists()) {
        try {
          // 读取歌词文件内容
          lyricContent = await lrcFile.readAsString();
          Logger.info('找到并读取歌词文件: ${lrcFile.path}', tag: 'WiFiTransferPage');
        } catch (e) {
          Logger.error('读取歌词文件失败', error: e, tag: 'WiFiTransferPage');
        }
      }
      
      // 查找同名的封面文件
      for (final ext in ['jpg', 'jpeg', 'png']) {
        final coverFile = File('${musicDir.path}/$baseFileName.$ext');
        if (await coverFile.exists()) {
          coverPath = coverFile.path;
          Logger.info('找到封面文件: $coverPath', tag: 'WiFiTransferPage');
          break;
        }
      }
      
      // 如果找到歌词或封面，更新歌曲信息
      if (lyricContent != null || coverPath != null) {
        return song.copyWith(
          lyric: lyricContent,  // 保存歌词内容，不是路径
          albumArt: coverPath ?? song.albumArt,
        );
      }
      
      return song;
    } catch (e) {
      Logger.error('关联歌词和封面失败', error: e, tag: 'WiFiTransferPage');
      return song;
    }
  }

  /// 启动服务器
  Future<void> _startServer() async {
    if (_isRunning) return;
    
    setState(() {
      _isStarting = true;
    });

    try {
      final url = await _transferService.startServer();
      
      if (mounted) {
        setState(() {
          _isRunning = true;
          _serverUrl = url;
          _uploadedCount = 0;
          _uploadedFiles = [];
        });
        
        Logger.info('服务器已启动: $url', tag: 'WiFiTransferPage');
      }
    } catch (e) {
      Logger.error('启动服务器失败', error: e, tag: 'WiFiTransferPage');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('启动失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  /// 停止服务器
  Future<void> _stopServer() async {
    if (!_isRunning) return;

    try {
      await _transferService.stopServer();
      
      if (mounted) {
        setState(() {
          _isRunning = false;
          _serverUrl = null;
        });
        
        // 如果有上传文件，显示提示
        if (_uploadedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已上传 $_uploadedCount 个文件到音乐库'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: '查看',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pop(context); // 返回音乐库页面
                },
              ),
            ),
          );
        }
        
        Logger.info('服务器已停止', tag: 'WiFiTransferPage');
      }
    } catch (e) {
      Logger.error('停止服务器失败', error: e, tag: 'WiFiTransferPage');
    }
  }

  /// 复制URL到剪贴板
  void _copyUrl() {
    if (_serverUrl != null) {
      Clipboard.setData(ClipboardData(text: _serverUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已复制到剪贴板'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('WiFi传输'),
        backgroundColor: AppColors.getCard(context),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 说明卡片
              _buildInfoCard(),
              
              const SizedBox(height: 20),
              
              // 服务器状态
              if (_isRunning) ...[
                _buildServerCard(),
                const SizedBox(height: 20),
                _buildQRCodeCard(),
                const SizedBox(height: 20),
                _buildStatsCard(),
                const SizedBox(height: 20),
                _buildUploadedFilesCard(),
              ],
              
              // 控制按钮
              const SizedBox(height: 20),
              _buildControlButtons(),
            ],
          ),
        ),
      ),
    );
  }

  /// 说明卡片
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.9),
            Theme.of(context).primaryColor.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.wifi,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'WiFi音乐传输',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '通过WiFi从电脑/手机或其他设备传输音乐到本机',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoStep('1', '确保本机和电脑/手机或其他设备连接同一WiFi'),
          const SizedBox(height: 8),
          _buildInfoStep('2', '点击"启动服务"按钮'),
          const SizedBox(height: 8),
          _buildInfoStep('3', '在电脑浏览器打开显示的网址'),
          const SizedBox(height: 8),
          _buildInfoStep('4', '选择音乐文件上传'),
        ],
      ),
    );
  }

  Widget _buildInfoStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  /// 服务器信息卡片
  Widget _buildServerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '服务运行中',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '在电脑浏览器中打开以下地址：',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _serverUrl ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _copyUrl,
                  tooltip: '复制',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 二维码卡片
  Widget _buildQRCodeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '扫描二维码访问',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: _serverUrl ?? '',
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 统计卡片
  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.upload_file,
            label: '已上传',
            value: _uploadedCount.toString(),
            color: Colors.green,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.withOpacity(0.3),
          ),
          _buildStatItem(
            icon: Icons.music_note,
            label: '音乐文件',
            value: _uploadedFiles.length.toString(),
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  /// 已上传文件列表
  Widget _buildUploadedFilesCard() {
    if (_uploadedFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '已上传文件',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._uploadedFiles.reversed.take(5).map((filePath) {
            return _buildUploadedFileItem(filePath);
          }),
          if (_uploadedFiles.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '还有 ${_uploadedFiles.length - 5} 个文件...',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// 构建已上传文件项
  Widget _buildUploadedFileItem(String filePath) {
    final fileName = filePath.split('/').last;
    final hasLyric = _checkFileExists(filePath, 'lrc');
    final hasCover = _checkFileExists(filePath, ['jpg', 'jpeg', 'png']);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Wrap(
              spacing: 6,
              children: [
                if (hasLyric)
                  _buildFileTag('📝 歌词', Colors.green),
                if (hasCover)
                  _buildFileTag('🖼️ 封面', Colors.orange),
                if (!hasLyric && !hasCover)
                  _buildFileTag('仅音频', Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建文件标签
  Widget _buildFileTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  /// 检查文件是否存在
  bool _checkFileExists(String audioPath, dynamic extensions) {
    final dir = Directory(audioPath).parent;
    final baseName = audioPath.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
    
    final extList = extensions is List ? extensions : [extensions];
    
    for (final ext in extList) {
      final file = File('${dir.path}/$baseName.$ext');
      if (file.existsSync()) {
        return true;
      }
    }
    
    return false;
  }

  /// 控制按钮
  Widget _buildControlButtons() {
    if (_isRunning) {
      return ElevatedButton(
        onPressed: _stopServer,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '停止服务',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: _isStarting ? null : _startServer,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isStarting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              '启动服务',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
