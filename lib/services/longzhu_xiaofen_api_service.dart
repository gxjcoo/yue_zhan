import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:async';
import '../models/online_song.dart';
import 'music_api_interface.dart';
import '../utils/logger.dart';

/// 龙珠小粉高品质音乐 API 服务
/// API 文档参考: https://static.esion.xyz/public/源/MusicFree/long-zhu-xiao-fen.js
class LongzhuXiaofenApiService implements MusicApiInterface {
  static const String _baseUrl = 'https://www.hhlqilongzhu.cn/api/dg_mgmusic.php';
  static const String _platform = '龙珠小粉';
  static const String _paramKey = 'gm'; // 注意：这个API使用 'gm' 而不是 'msg'
  
  @override
  String get platformName => _platform;
  
  @override
  int get priority => 1; // 最高优先级，搜索结果排在最前
  
  @override
  bool get isEnabled => true;
  
  final Dio _dio;

  LongzhuXiaofenApiService() : _dio = Dio(
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
      logPrint: (obj) => Logger.debug('$obj', tag: 'API-XiaoFen'),
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
          _paramKey: keyword, // 使用 'gm' 而不是 'msg'
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
      Logger.error('搜索歌曲失败', error: e, tag: 'API-XiaoFen');
      rethrow;
    }
  }

  /// 获取歌曲详细信息（包括播放链接、歌词、封面）
  /// 
  /// [song] 歌曲对象
  @override
  Future<OnlineSong> getMusicInfo(OnlineSong song) async {
    try {
      Logger.info('正在获取歌曲详情: ${song.title}, API ID: ${song.apiId}', tag: 'API-XiaoFen');
      
      final response = await _dio.get(
        '',
        queryParameters: {
          _paramKey: song.title, // 使用 'gm' 而不是 'msg'
          'type': 'json',
          'n': song.apiId ?? '', // 使用 apiId
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 10), // 🆕 主请求10秒超时
        ),
      ).timeout(
        const Duration(seconds: 15), // 🆕 总超时15秒
        onTimeout: () {
          Logger.warn('获取歌曲详情超时', tag: 'API-XiaoFen');
          throw TimeoutException('获取歌曲详情超时');
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        print('==================== 歌曲详情 API 返回数据 (小粉API) ====================');
        print('完整数据: $data');
        print('');
        print('========== 所有字段详情 ==========');
        data.forEach((key, value) {
          print('字段 [$key]: $value');
        });
        print('====================================');
        print('');
        
        // 音频链接字段
        var audioUrl = data['music_url'] as String? ?? data['url'] as String?;
        print('🎵 [小粉API] music_url 字段: ${data['music_url']}');
        print('🎵 [小粉API] url 字段: ${data['url']}');
        print('🎵 [小粉API] 使用的音频链接: $audioUrl');
        
        // 验证和清理 URL
        if (audioUrl != null && audioUrl.isNotEmpty) {
          try {
            // 解析 URL 并重新编码以确保所有特殊字符都被正确处理
            final uri = Uri.parse(audioUrl);
            // 如果 URL 已经是有效的，保持原样
            // 如果包含空格或其他问题，Uri.parse 会处理
            audioUrl = uri.toString();
            print('✅ [小粉API] 验证后的音频链接: $audioUrl');
          } catch (e) {
            print('⚠️ [小粉API] URL 解析失败，使用原始URL: $e');
            // 如果解析失败，使用原始 URL
          }
        } else {
          print('❌ [小粉API] 未获取到音频链接');
        }
        
        // 歌词URL（需要额外请求）
        final lyricUrl = data['lrc_url'] as String?;
        String? lyricContent;
        
        // 如果有歌词URL，获取歌词内容（带超时）
        if (lyricUrl != null && lyricUrl.isNotEmpty) {
          try {
            Logger.debug('开始获取歌词: $lyricUrl', tag: 'API-XiaoFen');
            final lyricResponse = await _dio.get(
              lyricUrl,
              options: Options(
                responseType: ResponseType.plain,
                receiveTimeout: const Duration(seconds: 3), // 🆕 3秒超时
                sendTimeout: const Duration(seconds: 3),
              ),
            ).timeout(
              const Duration(seconds: 5), // 🆕 总超时5秒
              onTimeout: () {
                print('⏱️ [小粉API] 歌词获取超时，跳过');
                throw TimeoutException('歌词获取超时');
              },
            );
            lyricContent = lyricResponse.data as String?;
            print('✅ [小粉API] 歌词获取成功 (${lyricContent?.length ?? 0} 字符)');
          } catch (e) {
            print('⚠️ [小粉API] 获取歌词失败: $e');
            // 歌词失败不影响主流程，继续返回音频链接
          }
        } else {
          print('ℹ️ [小粉API] 无歌词URL，跳过歌词获取');
        }
        
        final result = song.copyWith(
          title: data['title'] ?? song.title,
          artist: data['singer'] ?? song.artist,
          album: data['album'] ?? song.album,
          albumArt: data['cover'],
          audioUrl: audioUrl,
          lyric: lyricContent, // 已经获取了歌词内容
        );
        
        print('✅ [小粉API] 歌曲详情获取完成');
        return result;
      }
      
      print('⚠️ [小粉API] API响应状态码异常: ${response.statusCode}');
      return song;
    } catch (e) {
      print('❌ [小粉API] 获取歌曲详情失败: $e');
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
    
    print('📋 [小粉API] 请求头: ${headers.keys.join(", ")}');
    return headers;
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
      
      print('✅ [小粉API] 下载成功: $savePath');
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
      
      await _dio.download(
        coverUrl,
        savePath,
      );
      
      print('封面下载成功: $savePath');
      return savePath;
    } catch (e) {
      print('封面下载失败: $e');
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

