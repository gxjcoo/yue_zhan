import '../models/online_song.dart';
import 'music_api_interface.dart';
import 'longzhu_music_api_service.dart';
import 'longzhu_xiaofen_api_service.dart';
import '../utils/logger.dart';
import '../config/constants.dart';

/// 音乐API管理器
/// 统一管理多个音乐API源，支持同时搜索和智能路由
class MusicApiManager {
  // 单例模式
  static final MusicApiManager _instance = MusicApiManager._internal();
  factory MusicApiManager() => _instance;
  MusicApiManager._internal() {
    _initializeApis();
  }

  /// 所有注册的API服务
  final List<MusicApiInterface> _apis = [];
  
  /// 根据平台名称查找API服务的映射
  final Map<String, MusicApiInterface> _apiByPlatform = {};

  /// 初始化所有API服务
  void _initializeApis() {
    // 注册龙珠汽水API
    final qishuiApi = LongzhuQishuiApiService();
    _apis.add(qishuiApi);
    _apiByPlatform[qishuiApi.platformName] = qishuiApi;

    // 注册龙珠小粉API
    final xiaofenApi = LongzhuXiaofenApiService();
    _apis.add(xiaofenApi);
    _apiByPlatform[xiaofenApi.platformName] = xiaofenApi;

    // 按优先级排序
    _apis.sort((a, b) => a.priority.compareTo(b.priority));

    print('🎵 API管理器初始化完成，已注册 ${_apis.length} 个API源:');
    for (final api in _apis) {
      print('   - ${api.platformName} (优先级: ${api.priority}, 启用: ${api.isEnabled})');
    }
  }

  /// 获取所有启用的API
  List<MusicApiInterface> get enabledApis {
    return _apis.where((api) => api.isEnabled).toList();
  }

  /// 获取所有API平台名称
  List<String> get platformNames {
    return _apis.map((api) => api.platformName).toList();
  }

  /// 根据平台名称获取API服务
  MusicApiInterface? getApiByPlatform(String platformName) {
    return _apiByPlatform[platformName];
  }

  /// 按源搜索歌曲（返回每个源的独立结果）
  /// 
  /// [keyword] 搜索关键字
  /// [limit] 每个API的限制数量
  /// 返回 Map<平台名称, 歌曲列表>
  Future<Map<String, List<OnlineSong>>> searchBySource(String keyword, {int limit = 30}) async {
    final activeApis = enabledApis;
    
    if (activeApis.isEmpty) {
      Logger.warn('没有启用的API源', tag: 'API');
      return {};
    }

    Logger.info('开始分源搜索: "$keyword"，使用 ${activeApis.length} 个API源', tag: 'Search');

    final results = <String, List<OnlineSong>>{};

    // 并发搜索所有API（带超时控制）
    await Future.wait(
      activeApis.map((api) async {
        try {
          Logger.debug('正在搜索 ${api.platformName}...', tag: 'Search');
          
          // 为每个 API 添加超时控制
          final songs = await api.search(keyword, limit: limit).timeout(
            Constants.apiSearchTimeout,
            onTimeout: () {
              Logger.warn('${api.platformName} 搜索超时', tag: 'Search');
              return <OnlineSong>[];
            },
          );
          
          results[api.platformName] = songs;
          Logger.info('${api.platformName} 返回 ${songs.length} 首歌曲', tag: 'Search');
        } catch (e) {
          Logger.error('${api.platformName} 搜索失败', error: e, tag: 'Search');
          results[api.platformName] = [];
        }
      }),
    );

    return results;
  }

  /// 搜索歌曲（同时搜索所有启用的API并合并）
  /// 
  /// [keyword] 搜索关键字
  /// [limit] 每个API的限制数量
  /// 返回所有API的搜索结果合并后的列表
  Future<List<OnlineSong>> search(String keyword, {int limit = 30}) async {
    final resultsBySource = await searchBySource(keyword, limit: limit);
    
    // 合并所有源的结果
    final allSongs = <OnlineSong>[];
    for (final songs in resultsBySource.values) {
      allSongs.addAll(songs);
    }

    // 去重（基于 id）- 使用优化的逻辑，保留第一个（优先级高的API）
    final uniqueSongs = <String, OnlineSong>{};
    for (final song in allSongs) {
      uniqueSongs[song.id] ??= song;  // 只在不存在时赋值
    }

    final finalResults = uniqueSongs.values.toList();
    Logger.info('搜索完成，共找到 ${finalResults.length} 首不重复歌曲', tag: 'Search');

    return finalResults;
  }

  /// 获取歌曲详细信息
  /// 
  /// [song] 歌曲对象
  /// 自动根据歌曲来源选择对应的API
  Future<OnlineSong> getMusicInfo(OnlineSong song) async {
    final api = getApiByPlatform(song.source);
    
    if (api == null) {
      throw Exception('找不到对应的API源: ${song.source}');
    }

    return await api.getMusicInfo(song);
  }

  /// 获取歌曲播放链接
  /// 
  /// [song] 歌曲对象
  /// 自动根据歌曲来源选择对应的API
  Future<String?> getSongUrl(OnlineSong song) async {
    final api = getApiByPlatform(song.source);
    
    if (api == null) {
      throw Exception('找不到对应的API源: ${song.source}');
    }

    return await api.getSongUrl(song);
  }

  /// 下载歌曲
  /// 
  /// [song] 歌曲对象
  /// [savePath] 保存路径
  /// [onProgress] 下载进度回调
  /// 自动根据歌曲来源选择对应的API
  Future<String?> downloadSong(
    OnlineSong song,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    final api = getApiByPlatform(song.source);
    
    if (api == null) {
      throw Exception('找不到对应的API源: ${song.source}');
    }

    return await api.downloadSong(song, savePath, onProgress: onProgress);
  }

  /// 下载封面
  /// 
  /// [coverUrl] 封面URL
  /// [savePath] 保存路径
  /// [sourcePlatform] 来源平台（用于选择API）
  Future<String?> downloadCover(
    String coverUrl,
    String savePath,
    String sourcePlatform,
  ) async {
    final api = getApiByPlatform(sourcePlatform);
    
    if (api == null) {
      throw Exception('找不到对应的API源: $sourcePlatform');
    }

    return await api.downloadCover(coverUrl, savePath);
  }

  /// 保存歌词
  /// 
  /// [lyric] 歌词内容
  /// [savePath] 保存路径
  /// [sourcePlatform] 来源平台（用于选择API）
  Future<String?> saveLyric(
    String lyric,
    String savePath,
    String sourcePlatform,
  ) async {
    final api = getApiByPlatform(sourcePlatform);
    
    if (api == null) {
      throw Exception('找不到对应的API源: $sourcePlatform');
    }

    return await api.saveLyric(lyric, savePath);
  }

  /// 启用指定的API
  void enableApi(String platformName) {
    // 注意：由于当前API接口的isEnabled是getter，无法直接修改
    // 如果需要运行时启用/禁用API，需要在API接口中添加可修改的状态
    print('启用API: $platformName (需要在API实现中添加状态管理)');
  }

  /// 禁用指定的API
  void disableApi(String platformName) {
    // 注意：由于当前API接口的isEnabled是getter，无法直接修改
    // 如果需要运行时启用/禁用API，需要在API接口中添加可修改的状态
    print('禁用API: $platformName (需要在API实现中添加状态管理)');
  }
}

