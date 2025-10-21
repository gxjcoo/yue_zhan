import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:network_info_plus/network_info_plus.dart';
import '../utils/logger.dart';

/// WiFi 传输服务
///
/// 功能：
/// - 启动 HTTP 服务器
/// - 提供网页上传界面
/// - 接收文件上传
/// - 自动保存到音乐目录
class WiFiTransferService {
  HttpServer? _server;
  String? _serverUrl;
  int _uploadedCount = 0;
  final List<String> _uploadedFiles = [];

  /// 服务器是否正在运行
  bool get isRunning => _server != null;

  /// 服务器URL
  String? get serverUrl => _serverUrl;

  /// 已上传文件数量
  int get uploadedCount => _uploadedCount;

  /// 已上传文件列表
  List<String> get uploadedFiles => List.unmodifiable(_uploadedFiles);

  /// 上传进度回调
  Function(String fileName, int current, int total)? onUploadProgress;

  /// 上传完成回调
  Function(String filePath)? onFileUploaded;

  /// 启动服务器
  ///
  /// [port] 端口号，默认 8080
  /// 返回服务器URL
  Future<String> startServer({int port = 8080}) async {
    if (_server != null) {
      Logger.warn('服务器已在运行', tag: 'WiFiTransfer');
      return _serverUrl!;
    }

    try {
      // 创建请求处理器
      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addMiddleware(_corsMiddleware())
          .addHandler(_handleRequest);

      // 启动服务器
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

      // 获取本机IP
      final ip = await _getLocalIP();
      _serverUrl = 'http://$ip:$port';

      Logger.info('WiFi传输服务已启动: $_serverUrl', tag: 'WiFiTransfer');

      return _serverUrl!;
    } catch (e) {
      Logger.error('启动服务器失败', error: e, tag: 'WiFiTransfer');
      rethrow;
    }
  }

  /// 停止服务器
  Future<void> stopServer() async {
    if (_server == null) {
      return;
    }

    try {
      await _server!.close(force: true);
      _server = null;
      _serverUrl = null;
      Logger.info('WiFi传输服务已停止', tag: 'WiFiTransfer');
    } catch (e) {
      Logger.error('停止服务器失败', error: e, tag: 'WiFiTransfer');
    }
  }

  /// 重置统计
  void resetStats() {
    _uploadedCount = 0;
    _uploadedFiles.clear();
  }

  /// 获取本机IP地址
  Future<String> _getLocalIP() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();

      if (wifiIP != null && wifiIP.isNotEmpty) {
        return wifiIP;
      }

      // 备用方案：遍历网络接口
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }

      return '127.0.0.1';
    } catch (e) {
      Logger.error('获取IP地址失败', error: e, tag: 'WiFiTransfer');
      return '127.0.0.1';
    }
  }

  /// CORS 中间件
  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }

        final response = await handler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  /// CORS 头部
  Map<String, String> get _corsHeaders => {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  /// 处理HTTP请求
  Future<Response> _handleRequest(Request request) async {
    final path = request.url.path;

    Logger.debug('收到请求: ${request.method} /$path', tag: 'WiFiTransfer');

    // 首页 - 上传界面
    if (request.method == 'GET' && path.isEmpty) {
      return Response.ok(
        _uploadPageHtml,
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );
    }

    // 文件上传
    if (request.method == 'POST' && path == 'upload') {
      return await _handleFileUpload(request);
    }

    // 获取上传统计
    if (request.method == 'GET' && path == 'stats') {
      return Response.ok(
        jsonEncode({
          'uploadedCount': _uploadedCount,
          'uploadedFiles': _uploadedFiles,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.notFound('Not Found');
  }

  /// 处理文件上传
  Future<Response> _handleFileUpload(Request request) async {
    try {
      // 读取请求体
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.contains('multipart/form-data')) {
        return Response.badRequest(
          body: jsonEncode({'error': '无效的Content-Type'}),
        );
      }

      // 解析 multipart 数据
      final boundary = _extractBoundary(contentType);
      if (boundary == null) {
        return Response.badRequest(body: jsonEncode({'error': '无法解析boundary'}));
      }

      // 读取并保存文件
      final bytes = await request.read().toList();
      final allBytes = bytes.expand((x) => x).toList();

      final result = await _parseMultipartData(allBytes, boundary);

      if (result == null) {
        return Response.badRequest(body: jsonEncode({'error': '文件解析失败'}));
      }

      // 保存文件
      final savedPath = await _saveUploadedFile(
        result['filename']!,
        result['data']!,
      );

      if (savedPath != null) {
        // 判断文件类型
        final fileType = _getFileType(result['filename']!);

        if (fileType == 'audio') {
          // 音频文件才计数和触发回调
          _uploadedCount++;
          _uploadedFiles.add(savedPath);

          // 触发回调
          onFileUploaded?.call(savedPath);

          Logger.info('音频文件上传成功: $savedPath', tag: 'WiFiTransfer');
        } else {
          // 歌词或封面文件
          Logger.info(
            '${fileType == 'lyric' ? '歌词' : '封面'}文件上传成功: $savedPath',
            tag: 'WiFiTransfer',
          );
        }

        return Response.ok(
          jsonEncode({
            'success': true,
            'message': '上传成功',
            'filename': result['filename'],
            'path': savedPath,
            'type': fileType,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode({'error': '保存文件失败'}),
        );
      }
    } catch (e, stackTrace) {
      Logger.error(
        '处理文件上传失败',
        error: e,
        stackTrace: stackTrace,
        tag: 'WiFiTransfer',
      );
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  /// 获取文件类型
  String _getFileType(String filename) {
    final ext = filename.toLowerCase().split('.').last;

    if (['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'wma'].contains(ext)) {
      return 'audio';
    } else if (ext == 'lrc') {
      return 'lyric';
    } else if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      return 'cover';
    }

    return 'other';
  }

  /// 提取 boundary
  String? _extractBoundary(String contentType) {
    final match = RegExp(r'boundary=(.+)').firstMatch(contentType);
    return match?.group(1);
  }

  /// 解析 multipart 数据
  Future<Map<String, dynamic>?> _parseMultipartData(
    List<int> bytes,
    String boundary,
  ) async {
    try {
      final boundaryBytes = utf8.encode('--$boundary');
      final boundaryLength = boundaryBytes.length;

      // 查找第一个boundary
      int pos = 0;
      while (pos < bytes.length - boundaryLength) {
        bool found = true;
        for (int i = 0; i < boundaryLength; i++) {
          if (bytes[pos + i] != boundaryBytes[i]) {
            found = false;
            break;
          }
        }

        if (found) {
          // 找到boundary，解析这个part
          pos += boundaryLength;

          // 跳过 \r\n
          if (pos + 2 <= bytes.length &&
              bytes[pos] == 13 &&
              bytes[pos + 1] == 10) {
            pos += 2;
          }

          // 查找header结束位置 (\r\n\r\n)
          int headerEnd = pos;
          while (headerEnd < bytes.length - 3) {
            if (bytes[headerEnd] == 13 &&
                bytes[headerEnd + 1] == 10 &&
                bytes[headerEnd + 2] == 13 &&
                bytes[headerEnd + 3] == 10) {
              break;
            }
            headerEnd++;
          }

          if (headerEnd >= bytes.length - 3) {
            pos++;
            continue;
          }

          // 提取header（使用UTF-8解码以正确处理中文文件名）
          final headerBytes = bytes.sublist(pos, headerEnd);
          final header = utf8.decode(headerBytes, allowMalformed: true);

          // 检查是否包含文件
          if (header.contains('Content-Disposition') &&
              header.contains('filename=')) {
            // 提取文件名（支持UTF-8编码的中文文件名）
            final filenameMatch = RegExp(
              r'filename="([^"]+)"',
            ).firstMatch(header);
            if (filenameMatch == null) {
              pos++;
              continue;
            }

            var filename = filenameMatch.group(1)!;

            // 尝试解码URL编码的文件名
            try {
              filename = Uri.decodeComponent(filename);
            } catch (e) {
              // 如果解码失败，使用原始文件名
              Logger.debug('文件名无需URL解码: $filename', tag: 'WiFiTransfer');
            }

            Logger.info('解析到文件名: $filename', tag: 'WiFiTransfer');

            // 文件数据开始位置
            final dataStart = headerEnd + 4;

            // 查找下一个boundary（文件数据结束位置）
            int dataEnd = dataStart;
            while (dataEnd < bytes.length - boundaryLength - 2) {
              // 检查是否是 \r\n--boundary
              if (bytes[dataEnd] == 13 && bytes[dataEnd + 1] == 10) {
                bool isBoundary = true;
                for (int i = 0; i < boundaryLength; i++) {
                  if (bytes[dataEnd + 2 + i] != boundaryBytes[i]) {
                    isBoundary = false;
                    break;
                  }
                }
                if (isBoundary) {
                  break;
                }
              }
              dataEnd++;
            }

            // 提取文件数据（保持原始字节，不进行编码转换）
            final fileBytes = bytes.sublist(dataStart, dataEnd);

            Logger.info('文件大小: ${fileBytes.length} 字节', tag: 'WiFiTransfer');

            return {'filename': filename, 'data': fileBytes};
          }
        }

        pos++;
      }

      return null;
    } catch (e, stackTrace) {
      Logger.error(
        '解析multipart数据失败',
        error: e,
        stackTrace: stackTrace,
        tag: 'WiFiTransfer',
      );
      return null;
    }
  }

  /// 保存上传的文件
  Future<String?> _saveUploadedFile(String filename, List<int> data) async {
    try {
      // 获取音乐目录
      final appDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory(path.join(appDir.path, 'Music'));

      // 确保目录存在
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      // 目标文件路径
      final savePath = path.join(musicDir.path, filename);
      final file = File(savePath);

      // 检查文件是否已存在
      if (await file.exists()) {
        // 文件已存在，检查是否为音频文件
        final ext = path.extension(filename).toLowerCase();
        final isAudioFile = [
          '.mp3',
          '.flac',
          '.wav',
          '.m4a',
          '.aac',
          '.ogg',
          '.wma',
        ].contains(ext);

        if (isAudioFile) {
          // 音频文件已存在，跳过保存（由APP端的去重逻辑处理）
          Logger.info('文件已存在，跳过保存: $savePath', tag: 'WiFiTransfer');
          return savePath;
        } else {
          // 非音频文件（歌词、封面），直接覆盖
          Logger.info('覆盖已存在的文件: $savePath', tag: 'WiFiTransfer');
        }
      }

      // 保存文件
      await file.writeAsBytes(data);

      Logger.info('文件已保存: $savePath', tag: 'WiFiTransfer');

      return savePath;
    } catch (e) {
      Logger.error('保存文件失败', error: e, tag: 'WiFiTransfer');
      return null;
    }
  }

  /// 上传页面 HTML
  static const String _uploadPageHtml = '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>📱 WiFi音乐传输 - 乐栈</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    
    .container {
      background: white;
      border-radius: 20px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
      max-width: 600px;
      width: 100%;
      padding: 40px;
    }
    
    h1 {
      text-align: center;
      color: #333;
      margin-bottom: 10px;
      font-size: 28px;
    }
    
    .subtitle {
      text-align: center;
      color: #666;
      margin-bottom: 30px;
      font-size: 14px;
    }
    
    .upload-area {
      border: 3px dashed #ddd;
      border-radius: 15px;
      padding: 60px 20px;
      text-align: center;
      transition: all 0.3s ease;
      cursor: pointer;
      background: #fafafa;
    }
    
    .upload-area:hover {
      border-color: #667eea;
      background: #f0f0ff;
    }
    
    .upload-area.dragover {
      border-color: #667eea;
      background: #e8ebff;
      transform: scale(1.02);
    }
    
    .upload-icon {
      font-size: 64px;
      margin-bottom: 20px;
    }
    
    .upload-text {
      font-size: 18px;
      color: #333;
      margin-bottom: 10px;
    }
    
    .upload-hint {
      font-size: 14px;
      color: #999;
    }
    
    .supported-formats {
      font-size: 12px;
      color: #999;
      margin-top: 15px;
      padding: 10px;
      background: #f9f9f9;
      border-radius: 8px;
    }
    
    .file-input {
      display: none;
    }
    
    .btn {
      display: inline-block;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 12px 30px;
      border-radius: 25px;
      border: none;
      font-size: 16px;
      cursor: pointer;
      margin-top: 20px;
      transition: transform 0.2s;
    }
    
    .btn:hover {
      transform: translateY(-2px);
    }
    
    .progress-container {
      margin-top: 30px;
      display: none;
    }
    
    .progress-item {
      background: #f5f5f5;
      border-radius: 10px;
      padding: 15px;
      margin-bottom: 10px;
    }
    
    .progress-filename {
      font-size: 14px;
      color: #333;
      margin-bottom: 8px;
      word-break: break-all;
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 8px;
    }
    
    .file-type-tag {
      display: inline-block;
      padding: 2px 8px;
      border-radius: 4px;
      font-size: 11px;
      font-weight: 600;
      white-space: nowrap;
    }
    
    .file-type-tag.audio {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
    }
    
    .file-type-tag.lyric {
      background: #4caf50;
      color: white;
    }
    
    .file-type-tag.cover {
      background: #ff9800;
      color: white;
    }
    
    .progress-bar-container {
      background: #e0e0e0;
      border-radius: 10px;
      height: 8px;
      overflow: hidden;
    }
    
    .progress-bar {
      background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
      height: 100%;
      width: 0%;
      transition: width 0.3s ease;
    }
    
    .progress-status {
      font-size: 12px;
      color: #666;
      margin-top: 5px;
    }
    
    .stats {
      text-align: center;
      margin-top: 30px;
      padding-top: 20px;
      border-top: 1px solid #eee;
    }
    
    .stats-number {
      font-size: 32px;
      font-weight: bold;
      color: #667eea;
    }
    
    .stats-label {
      font-size: 14px;
      color: #999;
      margin-top: 5px;
    }
    
    .success-icon {
      color: #4caf50;
    }
    
    .error-icon {
      color: #f44336;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>📱 WiFi音乐传输</h1>
    <p class="subtitle">将音乐文件从电脑/手机或其他设备传输到手机</p>
    
    <div class="upload-area" id="dropZone">
      <div class="upload-icon">🎵</div>
      <div class="upload-text">拖拽音乐文件到这里</div>
      <div class="upload-hint">或点击选择文件</div>
      <div class="supported-formats">
        <strong>音频:</strong> MP3, FLAC, WAV, M4A, AAC, OGG<br>
        <strong>歌词:</strong> LRC<br>
        <strong>封面:</strong> JPG, PNG
      </div>
      <input type="file" id="fileInput" class="file-input" multiple accept="audio/*,.mp3,.flac,.wav,.m4a,.aac,.ogg,.lrc,.jpg,.jpeg,.png">
      <button class="btn" onclick="document.getElementById('fileInput').click()">
        选择文件
      </button>
    </div>
    
    <div class="progress-container" id="progressContainer"></div>
    
    <div class="stats">
      <div class="stats-number" id="uploadCount">0</div>
      <div class="stats-label">已上传文件</div>
    </div>
  </div>
  
  <script>
    const dropZone = document.getElementById('dropZone');
    const fileInput = document.getElementById('fileInput');
    const progressContainer = document.getElementById('progressContainer');
    const uploadCount = document.getElementById('uploadCount');
    
    let totalUploaded = 0;
    
    // 拖拽事件
    dropZone.addEventListener('dragover', (e) => {
      e.preventDefault();
      dropZone.classList.add('dragover');
    });
    
    dropZone.addEventListener('dragleave', () => {
      dropZone.classList.remove('dragover');
    });
    
    dropZone.addEventListener('drop', (e) => {
      e.preventDefault();
      dropZone.classList.remove('dragover');
      const files = e.dataTransfer.files;
      uploadFiles(files);
    });
    
    // 点击选择文件
    dropZone.addEventListener('click', (e) => {
      if (e.target !== fileInput && e.target.tagName !== 'BUTTON') {
        fileInput.click();
      }
    });
    
    fileInput.addEventListener('change', (e) => {
      uploadFiles(e.target.files);
    });
    
    // 上传文件
    function uploadFiles(files) {
      if (files.length === 0) return;
      
      progressContainer.style.display = 'block';
      
      Array.from(files).forEach(file => {
        uploadFile(file, files);
      });
    }
    
    // 格式化文件大小
    function formatFileSize(bytes) {
      if (bytes < 1024) return bytes + ' B';
      if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
      if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
      return (bytes / (1024 * 1024 * 1024)).toFixed(1) + ' GB';
    }
    
    // 上传单个文件
    function uploadFile(file, allFiles) {
      const fileType = getFileType(file.name);
      let hasLyric = false;
      let hasCover = false;
      
      // 如果是音频文件，检查是否有对应的歌词和封面
      if (fileType === 'audio') {
        const related = checkRelatedFiles(allFiles, file);
        hasLyric = related.hasLyric;
        hasCover = related.hasCover;
      }
      
      const progressItem = createProgressItem(file.name, file.size, fileType, hasLyric, hasCover);
      progressContainer.appendChild(progressItem);
      
      const formData = new FormData();
      formData.append('file', file);
      
      const xhr = new XMLHttpRequest();
      
      // 上传进度
      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable) {
          const percent = (e.loaded / e.total) * 100;
          const loaded = formatFileSize(e.loaded);
          const total = formatFileSize(e.total);
          updateProgress(progressItem, percent, loaded, total);
        }
      });
      
      // 上传完成
      xhr.addEventListener('load', () => {
        if (xhr.status === 200) {
          try {
            const response = JSON.parse(xhr.responseText);
            if (response.success) {
              markSuccess(progressItem, file.size);
              totalUploaded++;
              uploadCount.textContent = totalUploaded;
            } else {
              markError(progressItem, response.error || '上传失败');
            }
          } catch (e) {
            markError(progressItem, '响应解析失败');
          }
        } else {
          markError(progressItem, \`上传失败 (HTTP \${xhr.status})\`);
        }
      });
      
      // 上传错误
      xhr.addEventListener('error', () => {
        markError(progressItem, '网络错误');
      });
      
      // 超时
      xhr.addEventListener('timeout', () => {
        markError(progressItem, '上传超时');
      });
      
      xhr.timeout = 300000; // 5分钟超时
      xhr.open('POST', '/upload');
      xhr.send(formData);
    }
    
    // 获取文件类型
    function getFileType(filename) {
      const ext = filename.toLowerCase().split('.').pop();
      if (['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'wma'].includes(ext)) {
        return 'audio';
      } else if (ext === 'lrc') {
        return 'lyric';
      } else if (['jpg', 'jpeg', 'png', 'webp'].includes(ext)) {
        return 'cover';
      }
      return 'other';
    }
    
    // 获取文件基础名（不含扩展名）
    function getBaseName(filename) {
      return filename.replace(/\.[^.]+\$/, '');
    }
    
    // 检查是否有对应的歌词和封面
    function checkRelatedFiles(files, audioFile) {
      const baseName = getBaseName(audioFile.name);
      let hasLyric = false;
      let hasCover = false;
      
      for (const file of files) {
        const fileBaseName = getBaseName(file.name);
        if (fileBaseName === baseName) {
          const type = getFileType(file.name);
          if (type === 'lyric') hasLyric = true;
          if (type === 'cover') hasCover = true;
        }
      }
      
      return { hasLyric, hasCover };
    }
    
    // 创建进度项
    function createProgressItem(filename, fileSize, fileType, hasLyric, hasCover) {
      const div = document.createElement('div');
      div.className = 'progress-item';
      
      // 创建文件名元素（使用textContent避免XSS）
      const filenameDiv = document.createElement('div');
      filenameDiv.className = 'progress-filename';
      
      // 文件名和大小
      const nameSpan = document.createElement('span');
      nameSpan.textContent = filename + ' (' + formatFileSize(fileSize) + ')';
      filenameDiv.appendChild(nameSpan);
      
      // 文件类型标签
      if (fileType === 'audio') {
        const typeTag = document.createElement('span');
        typeTag.className = 'file-type-tag audio';
        typeTag.textContent = '🎵 音频';
        filenameDiv.appendChild(typeTag);
        
        // 歌词标识
        if (hasLyric) {
          const lyricTag = document.createElement('span');
          lyricTag.className = 'file-type-tag lyric';
          lyricTag.textContent = '📝 有歌词';
          filenameDiv.appendChild(lyricTag);
        }
        
        // 封面标识
        if (hasCover) {
          const coverTag = document.createElement('span');
          coverTag.className = 'file-type-tag cover';
          coverTag.textContent = '🖼️ 有封面';
          filenameDiv.appendChild(coverTag);
        }
      } else if (fileType === 'lyric') {
        const typeTag = document.createElement('span');
        typeTag.className = 'file-type-tag lyric';
        typeTag.textContent = '📝 歌词';
        filenameDiv.appendChild(typeTag);
      } else if (fileType === 'cover') {
        const typeTag = document.createElement('span');
        typeTag.className = 'file-type-tag cover';
        typeTag.textContent = '🖼️ 封面';
        filenameDiv.appendChild(typeTag);
      }
      
      const barContainer = document.createElement('div');
      barContainer.className = 'progress-bar-container';
      barContainer.innerHTML = '<div class="progress-bar"></div>';
      
      const status = document.createElement('div');
      status.className = 'progress-status';
      status.textContent = '准备上传...';
      
      div.appendChild(filenameDiv);
      div.appendChild(barContainer);
      div.appendChild(status);
      
      return div;
    }
    
    // 更新进度
    function updateProgress(item, percent, loaded, total) {
      const bar = item.querySelector('.progress-bar');
      const status = item.querySelector('.progress-status');
      bar.style.width = percent + '%';
      status.textContent = \`上传中... \${Math.round(percent)}% (\${loaded} / \${total})\`;
    }
    
    // 标记成功
    function markSuccess(item, fileSize) {
      const status = item.querySelector('.progress-status');
      status.innerHTML = '<span class="success-icon">✓</span> 上传成功 (' + formatFileSize(fileSize) + ')';
      item.querySelector('.progress-bar').style.width = '100%';
    }
    
    // 标记失败
    function markError(item, message) {
      const status = item.querySelector('.progress-status');
      status.innerHTML = \`<span class="error-icon">✗</span> \${message}\`;
      item.querySelector('.progress-bar').style.background = '#f44336';
    }
  </script>
</body>
</html>
''';
}
