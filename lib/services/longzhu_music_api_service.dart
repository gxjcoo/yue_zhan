import 'package:dio/dio.dart';
import 'dart:io';
import '../models/online_song.dart';
import 'music_api_interface.dart';
import '../utils/logger.dart';

/// 龙珠七水音乐 API 服务
/// API 文档参考: https://static.esion.xyz/public/源/MusicFree/long-zhu-qi-shui.js
class LongzhuQishuiApiService implements MusicApiInterface {
  static const String _baseUrl = 'https://www.hhlqilongzhu.cn//api/dg_qishuimusic.php';
  static const String _platform = '龙珠汽水';
  
  @override
  String get platformName => _platform;
  
  @override
  int get priority => 2; // 第二优先级
  
  @override
  bool get isEnabled => true;
  
  final Dio _dio;

  LongzhuQishuiApiService() : _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ),
  ) {
    // 添加日志拦截器（开发环境）
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => Logger.debug('$obj', tag: 'API-LongZhu'),
    ));
  }

  /// 搜索歌曲
  /// 
  /// [keyword] 搜索关键字
  /// [limit] 限制数量
  @override
  Future<List<OnlineSong>> search(String keyword, {int limit = 30}) async {
    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          'msg': keyword,
          'type': 'json',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        // 检查返回的数据结构
        if (data is Map && data.containsKey('data')) {
          final List songList = data['data'] as List;
          
          return songList.map((item) {
            final title = item['title'] ?? '未知标题';
            final artist = item['singer'] ?? '未知艺术家';
            final album = item['album'] ?? '未知专辑';
            final apiId = item['n']?.toString() ?? ''; // 保存原始 API ID
            
            // 使用 title + artist 生成唯一稳定的 ID
            // 这样即使在不同的搜索中，同一首歌的 ID 也是相同的
            final uniqueId = _generateSongId(title, artist);
            
            return OnlineSong(
              id: uniqueId,
              apiId: apiId, // 保存原始 API ID，用于获取歌曲详情
              title: title,
              artist: artist,
              album: album,
              source: _platform,
            );
          }).toList().take(limit).toList();
        }
      }
      
      return [];
    } catch (e) {
      Logger.error('搜索歌曲失败', error: e, tag: 'API-LongZhu');
      rethrow;
    }
  }

  /// 获取歌曲详细信息（包括播放链接、歌词、封面）
  /// 
  /// [song] 歌曲对象
  @override
  Future<OnlineSong> getMusicInfo(OnlineSong song) async {
    try {
      print('正在获取歌曲详情: ${song.title}, API ID: ${song.apiId}');
      
      final response = await _dio.get(
        '',
        queryParameters: {
          'msg': song.title,
          'type': 'json',
          'n': song.apiId ?? '', // 使用 apiId 而不是 id
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        print('==================== 歌曲详情 API 返回数据 ====================');
        print('完整数据: $data');
        print('');
        print('========== 所有字段详情 ==========');
        data.forEach((key, value) {
          print('字段 [$key]: $value');
        });
        print('====================================');
        print('');
        
        // 使用 'music' 字段而不是 'link' 字段！
        // 'music' 是真实的音频文件 URL
        // 'link' 是分享页面链接
        var audioUrl = data['music'] as String?;
        print('🎵 [七水API] music 字段内容: $audioUrl');
        print('🔗 [七水API] link 字段内容: ${data['link']}');
        
        // 验证和清理 URL
        if (audioUrl != null && audioUrl.isNotEmpty) {
          try {
            // 解析 URL 并重新编码以确保所有特殊字符都被正确处理
            final uri = Uri.parse(audioUrl);
            audioUrl = uri.toString();
            print('✅ [七水API] 验证后的音频链接: $audioUrl');
            
            // 检查是否是直接的音频文件链接
            final isDirectAudioUrl = _isDirectAudioUrl(audioUrl);
            if (!isDirectAudioUrl) {
              print('⚠️ [七水API] 链接可能不是直接的音频文件');
            }
          } catch (e) {
            print('⚠️ [七水API] URL 解析失败，使用原始URL: $e');
          }
        } else {
          print('❌ [七水API] 未获取到音频链接');
        }
        
        return song.copyWith(
          title: data['title'] ?? song.title,
          artist: data['singer'] ?? song.artist,
          album: data['album'] ?? song.album,
          albumArt: data['cover'],
          audioUrl: audioUrl,
          lyric: data['lrc'],
        );
      }
      
      return song;
    } catch (e) {
      print('获取歌曲详情失败: $e');
      rethrow;
    }
  }
  
  /// 生成歌曲唯一 ID
  /// 使用 title + artist 的组合生成稳定的唯一标识符
  String _generateSongId(String title, String artist) {
    final combined = '${title.trim()}|${artist.trim()}';
    return combined.hashCode.abs().toString();
  }
  
  /// 根据 URL 获取合适的请求头
  Map<String, String> _getHeadersForUrl(String url) {
    final headers = <String, String>{};
    
    // 通用 User-Agent（模拟浏览器）
    const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    headers['User-Agent'] = userAgent;
    
    // 根据URL域名设置特定的 headers
    if (url.contains('migu.cn')) {
      // 咪咕音乐
      headers['Referer'] = 'https://music.migu.cn/';
      headers['Origin'] = 'https://music.migu.cn';
    } else if (url.contains('kugou.com')) {
      // 酷狗音乐
      headers['Referer'] = 'https://www.kugou.com/';
      headers['Origin'] = 'https://www.kugou.com';
    } else if (url.contains('qq.com')) {
      // QQ音乐
      headers['Referer'] = 'https://y.qq.com/';
      headers['Origin'] = 'https://y.qq.com';
    } else if (url.contains('163.com') || url.contains('music.126.net')) {
      // 网易云音乐
      headers['Referer'] = 'https://music.163.com/';
      headers['Origin'] = 'https://music.163.com';
    } else if (url.contains('douyin') || url.contains('douyinvod')) {
      // 抖音
      headers['Referer'] = 'https://www.douyin.com/';
    }
    
    print('📋 [七水API] 请求头: ${headers.keys.join(", ")}');
    return headers;
  }

  /// 检查是否是直接的音频文件 URL
  bool _isDirectAudioUrl(String url) {
    final lowerUrl = url.toLowerCase();
    
    // 检查常见的音频文件扩展名
    final hasAudioExtension = lowerUrl.contains('.mp3') ||
           lowerUrl.contains('.m4a') ||
           lowerUrl.contains('.flac') ||
           lowerUrl.contains('.wav') ||
           lowerUrl.contains('.aac') ||
           lowerUrl.contains('.ogg');
    
    // 检查是否是抖音的 VOD 链接（这些是有效的音频流）
    final isDouyinVod = lowerUrl.contains('douyinvod.com');
    
    // 如果有音频扩展名或者是抖音VOD链接，都认为是有效的
    return hasAudioExtension || isDouyinVod;
  }

  /// 获取歌曲播放 URL
  /// 
  /// [song] 歌曲对象
  @override
  Future<String?> getSongUrl(OnlineSong song) async {
    try {
      final detailedSong = await getMusicInfo(song);
      return detailedSong.audioUrl;
    } catch (e) {
      print('获取播放链接失败: $e');
      return null;
    }
  }

  /// 获取歌词
  /// 
  /// [song] 歌曲对象
  Future<String?> getLyric(OnlineSong song) async {
    try {
      final detailedSong = await getMusicInfo(song);
      return detailedSong.lyric;
    } catch (e) {
      print('获取歌词失败: $e');
      return null;
    }
  }

  /// 下载歌曲到本地
  /// 
  /// [song] 歌曲对象
  /// [savePath] 保存路径
  /// [onProgress] 下载进度回调
  @override
  Future<String?> downloadSong(
    OnlineSong song,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      // 先获取播放链接
      final audioUrl = await getSongUrl(song);
      
      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception('无法获取歌曲下载链接');
      }

      // 下载文件，添加必要的 headers
      await _dio.download(
        audioUrl,
        savePath,
        onReceiveProgress: onProgress,
        options: Options(
          headers: _getHeadersForUrl(audioUrl),
        ),
      );
      
      print('✅ [七水API] 下载成功: $savePath');
      return savePath;
    } catch (e) {
      print('下载歌曲失败: $e');
      rethrow;
    }
  }

  /// 下载专辑封面到本地
  /// 
  /// [coverUrl] 封面图片 URL
  /// [savePath] 保存路径
  @override
  Future<String?> downloadCover(
    String coverUrl,
    String savePath,
  ) async {
    try {
      if (coverUrl.isEmpty) {
        print('封面 URL 为空，跳过下载');
        return null;
      }

      print('开始下载封面: $coverUrl');
      
      // 下载封面图片
      await _dio.download(
        coverUrl,
        savePath,
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      print('封面下载成功: $savePath');
      return savePath;
    } catch (e) {
      print('下载封面失败: $e');
      // 封面下载失败不影响整体流程
      return null;
    }
  }

  /// 保存歌词到本地文件
  /// 
  /// [lyricContent] 歌词内容
  /// [savePath] 保存路径
  @override
  Future<String?> saveLyric(
    String lyricContent,
    String savePath,
  ) async {
    try {
      if (lyricContent.isEmpty) {
        print('歌词内容为空，跳过保存');
        return null;
      }

      print('开始保存歌词: $savePath');
      
      // 保存歌词到文件
      final file = File(savePath);
      await file.writeAsString(lyricContent);

      print('歌词保存成功: $savePath');
      return savePath;
    } catch (e) {
      print('保存歌词失败: $e');
      // 歌词保存失败不影响整体流程
      return null;
    }
  }
}

