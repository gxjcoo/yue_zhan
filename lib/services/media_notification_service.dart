import 'dart:async';
import 'package:audio_service/audio_service.dart';
import '../models/local_song.dart';
import '../models/online_song.dart';
import 'global_audio_service.dart';
import '../utils/logger.dart';

/// 系统媒体通知服务
/// 处理锁屏控制、通知栏播放控制、蓝牙耳机按键、车载系统（Android Auto/CarPlay）等
class MediaNotificationHandler extends BaseAudioHandler with SeekHandler, QueueHandler {
  final GlobalAudioService _audioService = GlobalAudioService();
  
  // 防止频繁更新的标记
  String? _lastSongId;
  bool? _lastPlayingState;
  
  // 节流控制（防止频繁切歌导致事件堆积）
  Timer? _updateThrottleTimer;
  bool _hasPendingUpdate = false;
  static const Duration _throttleDuration = Duration(milliseconds: 300);
  
  MediaNotificationHandler() {
    _init();
  }
  
  void _init() {
    // 监听 GlobalAudioService 的状态变化，更新媒体通知
    _audioService.addListener(_throttledUpdateMediaNotification);
    Logger.info('媒体通知服务已初始化（支持车载系统 + 节流优化）', tag: 'MediaNotification');
  }
  
  /// 节流更新（防止频繁切歌导致卡顿）
  void _throttledUpdateMediaNotification() {
    // 如果已经有待处理的更新，跳过
    if (_hasPendingUpdate) {
      return;
    }
    
    // 如果定时器正在运行，标记有待处理的更新
    if (_updateThrottleTimer?.isActive ?? false) {
      _hasPendingUpdate = true;
      return;
    }
    
    // 立即执行第一次更新
    _updateMediaNotification();
    
    // 启动节流定时器
    _updateThrottleTimer = Timer(_throttleDuration, () {
      if (_hasPendingUpdate) {
        _hasPendingUpdate = false;
        _updateMediaNotification();
      }
    });
  }
  
  /// 更新媒体通知（显示在锁屏和通知栏）
  void _updateMediaNotification() {
    final currentSong = _audioService.currentSong;
    if (currentSong == null) {
      if (_lastSongId != null) {
        _lastSongId = null;
        mediaItem.add(null);
        playbackState.add(PlaybackState(
          playing: false,
          controls: [],
          processingState: AudioProcessingState.idle,
        ));
      }
      return;
    }
    
    // 获取歌曲信息
    String title = '';
    String artist = '';
    String? artUri;
    String? id;
    
    if (currentSong is LocalSong) {
      title = currentSong.title;
      artist = currentSong.artist;
      artUri = currentSong.albumArt;
      id = currentSong.id.toString();
    } else if (currentSong is OnlineSong) {
      title = currentSong.title;
      artist = currentSong.artist;
      artUri = currentSong.albumArt;
      id = currentSong.id.toString();
    }
    
    // 检查是否需要更新
    final songChanged = _lastSongId != id;
    final playingStateChanged = _lastPlayingState != _audioService.isPlaying;
    
    // 歌曲切换时更新 mediaItem
    if (songChanged) {
      _lastSongId = id;
      Logger.info('📱 歌曲切换，更新锁屏/通知栏: $title - $artist', tag: 'MediaNotification');
      
      // 处理专辑封面 URI（本地文件路径需要转换为 file:// 协议）
      Uri? artUriParsed;
      if (artUri != null && artUri.isNotEmpty) {
        if (artUri.startsWith('http://') || artUri.startsWith('https://')) {
          // 网络图片
          artUriParsed = Uri.parse(artUri);
        } else if (artUri.startsWith('/')) {
          // 本地文件路径，转换为 file:// URI
          artUriParsed = Uri.file(artUri);
        }
      }
      
      // 创建并更新媒体项
      final mediaItemData = MediaItem(
        id: id ?? '0',
        title: title,
        artist: artist,
        artUri: artUriParsed,
        duration: _audioService.totalDuration,
      );
      
      mediaItem.add(mediaItemData);
      
      // 同时更新播放队列（Android Auto/CarPlay 需要）
      _updateQueue();
    }
    
    // 播放状态变化时更新 playbackState（必须更新，否则按钮图标不会变化）
    if (playingStateChanged) {
      _lastPlayingState = _audioService.isPlaying;
      Logger.info('📱 播放状态变化: ${_audioService.isPlaying ? "播放" : "暂停"}', tag: 'MediaNotification');
    }
    
    // 无论如何都要更新 playbackState（因为 controls 中的按钮图标依赖于 isPlaying）
    // 但为了避免过度频繁的更新，只在歌曲切换或播放状态变化时更新
    if (songChanged || playingStateChanged) {
      playbackState.add(PlaybackState(
        playing: _audioService.isPlaying,
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.rewind,  // 快退10秒
          _audioService.isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.fastForward,  // 快进10秒
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 2, 4],  // 紧凑视图：上一首、播放、下一首
        processingState: _audioService.isPlaying
            ? AudioProcessingState.ready
            : AudioProcessingState.idle,
        updatePosition: _audioService.currentPosition,
        bufferedPosition: _audioService.totalDuration,
        speed: _audioService.isPlaying ? 1.0 : 0.0,  // 播放速度
      ));
    }
  }
  
  /// 更新播放队列（Android Auto/CarPlay 需要显示完整播放列表）
  void _updateQueue() {
    final playlist = _audioService.playlist;
    if (playlist == null || playlist.isEmpty) {
      queue.add([]);
      return;
    }
    
    // 转换播放列表为 MediaItem 列表
    final queueItems = playlist.map((song) {
      String title = '';
      String artist = '';
      String? artUri;
      String? id;
      
      if (song is LocalSong) {
        title = song.title;
        artist = song.artist;
        artUri = song.albumArt;
        id = song.id.toString();
      } else if (song is OnlineSong) {
        title = song.title;
        artist = song.artist;
        artUri = song.albumArt;
        id = song.id.toString();
      }
      
      // 处理专辑封面 URI
      Uri? artUriParsed;
      if (artUri != null && artUri.isNotEmpty) {
        if (artUri.startsWith('http://') || artUri.startsWith('https://')) {
          artUriParsed = Uri.parse(artUri);
        } else if (artUri.startsWith('/')) {
          artUriParsed = Uri.file(artUri);
        }
      }
      
      return MediaItem(
        id: id ?? '0',
        title: title,
        artist: artist,
        artUri: artUriParsed,
      );
    }).toList();
    
    queue.add(queueItems);
    Logger.debug('🚗 更新车载系统播放队列: ${queueItems.length} 首歌曲', tag: 'MediaNotification');
  }
  
  // ========== 系统媒体控制回调 ==========
  
  /// 播放
  @override
  Future<void> play() async {
    Logger.info('系统媒体控制：播放', tag: 'MediaNotification');
    try {
      // 立即更新播放状态（不等待 AudioService）
      playbackState.add(PlaybackState(
        playing: true,  // 强制设置为播放状态
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.rewind,
          MediaControl.pause,  // 显示暂停按钮
          MediaControl.fastForward,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 2, 4],
        processingState: AudioProcessingState.ready,
        updatePosition: _audioService.currentPosition,
        bufferedPosition: _audioService.totalDuration,
        speed: 1.0,
      ));
      
      await _audioService.play();
      _lastPlayingState = true;
    } catch (e) {
      Logger.error('播放失败', error: e, tag: 'MediaNotification');
    }
  }
  
  /// 暂停
  @override
  Future<void> pause() async {
    Logger.info('系统媒体控制：暂停', tag: 'MediaNotification');
    try {
      // 立即更新播放状态（不等待 AudioService）
      playbackState.add(PlaybackState(
        playing: false,  // 强制设置为暂停状态
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.rewind,
          MediaControl.play,  // 显示播放按钮
          MediaControl.fastForward,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 2, 4],
        processingState: AudioProcessingState.ready,
        updatePosition: _audioService.currentPosition,
        bufferedPosition: _audioService.totalDuration,
        speed: 0.0,
      ));
      
      await _audioService.pause();
      _lastPlayingState = false;
    } catch (e) {
      Logger.error('暂停失败', error: e, tag: 'MediaNotification');
    }
  }
  
  /// 下一首
  @override
  Future<void> skipToNext() async {
    Logger.info('系统媒体控制：下一首', tag: 'MediaNotification');
    await _audioService.playNext();
  }
  
  /// 上一首
  @override
  Future<void> skipToPrevious() async {
    Logger.info('系统媒体控制：上一首', tag: 'MediaNotification');
    await _audioService.playPrevious();
  }
  
  /// 跳转到指定位置
  @override
  Future<void> seek(Duration position) async {
    Logger.info('系统媒体控制：跳转到 ${position.inSeconds}s', tag: 'MediaNotification');
    await _audioService.seek(position);
  }
  
  /// 停止
  @override
  Future<void> stop() async {
    Logger.info('系统媒体控制：停止', tag: 'MediaNotification');
    await _audioService.stop();
    await super.stop();
  }
  
  /// 快进（默认10秒）
  @override
  Future<void> fastForward() async {
    Logger.info('系统媒体控制：快进', tag: 'MediaNotification');
    final newPosition = _audioService.currentPosition + const Duration(seconds: 10);
    final maxPosition = _audioService.totalDuration;
    await _audioService.seek(newPosition > maxPosition ? maxPosition : newPosition);
  }
  
  /// 快退（默认10秒）
  @override
  Future<void> rewind() async {
    Logger.info('系统媒体控制：快退', tag: 'MediaNotification');
    final newPosition = _audioService.currentPosition - const Duration(seconds: 10);
    await _audioService.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }
  
  // ========== 队列管理（Android Auto/CarPlay 需要） ==========
  
  /// 跳转到队列中的指定歌曲（车载系统选歌）
  @override
  Future<void> skipToQueueItem(int index) async {
    Logger.info('🚗 车载系统选歌：第 ${index + 1} 首', tag: 'MediaNotification');
    
    final playlist = _audioService.playlist;
    if (playlist == null || index < 0 || index >= playlist.length) {
      Logger.warn('无效的队列索引: $index', tag: 'MediaNotification');
      return;
    }
    
    try {
      await _audioService.playSong(
        song: playlist[index],
        playlist: playlist,
        index: index,
      );
    } catch (e) {
      Logger.error('跳转到队列歌曲失败', error: e, tag: 'MediaNotification');
    }
  }
  
  /// 释放资源
  void dispose() {
    _updateThrottleTimer?.cancel();
    _audioService.removeListener(_throttledUpdateMediaNotification);
    Logger.info('媒体通知服务已释放', tag: 'MediaNotification');
  }
}
