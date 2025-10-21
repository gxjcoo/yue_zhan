import '../models/online_song.dart';

/// 音乐API接口抽象类
/// 所有音乐API服务都应该实现此接口
abstract class MusicApiInterface {
  /// API 平台名称
  String get platformName;
  
  /// API 优先级（数字越小优先级越高）
  int get priority;
  
  /// 是否启用此API
  bool get isEnabled;
  
  /// 搜索歌曲
  /// 
  /// [keyword] 搜索关键字
  /// [limit] 限制数量
  /// 返回歌曲列表
  Future<List<OnlineSong>> search(String keyword, {int limit = 30});
  
  /// 获取歌曲详细信息（包括播放链接、歌词、封面）
  /// 
  /// [song] 歌曲对象
  /// 返回完整的歌曲信息
  Future<OnlineSong> getMusicInfo(OnlineSong song);
  
  /// 获取歌曲播放链接
  /// 
  /// [song] 歌曲对象
  /// 返回播放链接
  Future<String?> getSongUrl(OnlineSong song);
  
  /// 下载歌曲
  /// 
  /// [song] 歌曲对象
  /// [savePath] 保存路径
  /// [onProgress] 下载进度回调
  /// 返回保存的文件路径，失败抛出异常
  Future<String?> downloadSong(
    OnlineSong song,
    String savePath, {
    void Function(int received, int total)? onProgress,
  });
  
  /// 下载封面图片
  /// 
  /// [coverUrl] 封面URL
  /// [savePath] 保存路径
  /// 返回保存的文件路径，失败返回null
  Future<String?> downloadCover(String coverUrl, String savePath);
  
  /// 保存歌词文件
  /// 
  /// [lyric] 歌词内容
  /// [savePath] 保存路径
  /// 返回保存的文件路径，失败返回null
  Future<String?> saveLyric(String lyric, String savePath);
}

