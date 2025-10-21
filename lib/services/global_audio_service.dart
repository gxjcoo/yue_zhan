import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/local_song.dart';
import '../models/online_song.dart';
import '../utils/logger.dart';
import '../services/music_api_manager.dart';

/// 播放模式枚举
enum PlayMode {
  sequence,  // 顺序循环
  repeatOne, // 单曲循环
  shuffle,   // 随机播放
}

/// 全局音频播放服务
class GlobalAudioService extends ChangeNotifier {
  static final GlobalAudioService _instance = GlobalAudioService._internal();
  factory GlobalAudioService() => _instance;
  GlobalAudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final MusicApiManager _apiManager = MusicApiManager();
  
  Object? _currentSong; // 当前播放的歌曲 (LocalSong 或 OnlineSong)
  List<Object>? _playlist; // 播放列表
  int _currentIndex = 0; // 当前索引
  bool _isPlaying = false; // 是否正在播放
  Duration _currentPosition = Duration.zero; // 当前播放位置
  Duration _totalDuration = Duration.zero; // 总时长
  
  // 🎯 优化：位置变化通知器（不触发整个页面重建）
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  
  // 播放模式
  PlayMode _playMode = PlayMode.sequence;
  PlayMode get playMode => _playMode;
  
  // 🎲 随机播放相关状态
  List<Object>? _shuffledPlaylist; // 洗牌后的播放列表
  int _shuffledIndex = 0; // 洗牌列表的当前索引
  final List<Object> _playHistory = []; // 播放历史（用于"上一首"功能）
  
  // 🎵 播放队列管理（新增）
  bool _isQueueMode = true; // 是否使用队列模式（true: 添加到队列, false: 替换队列）
  bool get isQueueMode => _isQueueMode;
  
  // 🚀 操作取消控制（防止频繁切歌导致堆积）
  int _playOperationId = 0; // 播放操作ID
  
  // ⚡ 节流控制（降低后台更新频率，节省电池）
  Timer? _positionThrottleTimer;
  DateTime? _lastPositionUpdate;
  static const _positionUpdateInterval = Duration(milliseconds: 33); // 30fps (节省电池)

  // Getters
  Object? get currentSong => _currentSong;
  List<Object>? get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  bool get hasSong => _currentSong != null;
  
  // 控制悬浮播放器显示
  bool _hideFloatingPlayer = false;
  bool get hideFloatingPlayer => _hideFloatingPlayer;
  
  /// 安全地通知监听器（避免在 build 期间调用）
  void _safeNotifyListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  
  void setHideFloatingPlayer(bool hide) {
    _hideFloatingPlayer = hide;
    _safeNotifyListeners();
  }
  
  /// 设置播放模式
  void setPlayMode(PlayMode mode) {
    final oldMode = _playMode;
    _playMode = mode;
    Logger.info('播放模式已切换: ${_getPlayModeName(mode)}', tag: 'Audio');
    
    // 切换到随机模式时，初始化洗牌
    if (mode == PlayMode.shuffle && oldMode != PlayMode.shuffle) {
      _initializeShuffle();
    }
    
    // 从随机模式切换出去时，恢复原始索引
    if (oldMode == PlayMode.shuffle && mode != PlayMode.shuffle) {
      if (_currentSong != null && _playlist != null) {
        _currentIndex = _playlist!.indexOf(_currentSong!);
        if (_currentIndex == -1) _currentIndex = 0;
      }
    }
    
    _safeNotifyListeners();
  }
  
  /// 初始化随机播放（洗牌）
  void _initializeShuffle() {
    if (_playlist == null || _playlist!.isEmpty) {
      Logger.warn('播放列表为空，无法初始化洗牌', tag: 'Audio');
      return;
    }
    
    Logger.info('🎲 初始化随机播放，歌曲数量: ${_playlist!.length}', tag: 'Audio');
    
    // 创建洗牌列表
    _shuffledPlaylist = List.from(_playlist!);
    _shuffledPlaylist!.shuffle();
    
    // 如果当前有正在播放的歌曲，确保它在第一个位置
    if (_currentSong != null) {
      final currentSongIndex = _shuffledPlaylist!.indexOf(_currentSong!);
      if (currentSongIndex != -1 && currentSongIndex != 0) {
        // 将当前歌曲移到第一个位置
        final temp = _shuffledPlaylist![0];
        _shuffledPlaylist![0] = _shuffledPlaylist![currentSongIndex];
        _shuffledPlaylist![currentSongIndex] = temp;
        Logger.info('将当前播放的歌曲移到洗牌列表首位', tag: 'Audio');
      }
    }
    
    _shuffledIndex = 0;
    _playHistory.clear();
    
    Logger.info('洗牌完成，洗牌列表: [${_getShufflePreview()}]', tag: 'Audio');
  }
  
  /// 获取洗牌列表预览（调试用）
  String _getShufflePreview() {
    if (_shuffledPlaylist == null || _shuffledPlaylist!.isEmpty) return '';
    
    final preview = _shuffledPlaylist!.take(5).map((song) {
      if (song is LocalSong) return song.title;
      if (song is OnlineSong) return song.title;
      return '?';
    }).join(', ');
    
    final remaining = _shuffledPlaylist!.length > 5 
        ? ', ... (共${_shuffledPlaylist!.length}首)' 
        : '';
    
    return preview + remaining;
  }
  
  /// 获取播放模式名称
  String _getPlayModeName(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequence:
        return '顺序循环';
      case PlayMode.repeatOne:
        return '单曲循环';
      case PlayMode.shuffle:
        return '随机播放';
    }
  }

  // 获取歌曲标题
  String get currentTitle {
    if (_currentSong == null) return '';
    if (_currentSong is OnlineSong) return (_currentSong as OnlineSong).title;
    if (_currentSong is LocalSong) return (_currentSong as LocalSong).title;
    return '';
  }

  // 获取歌曲艺人
  String get currentArtist {
    if (_currentSong == null) return '';
    if (_currentSong is OnlineSong) return (_currentSong as OnlineSong).artist;
    if (_currentSong is LocalSong) return (_currentSong as LocalSong).artist;
    return '';
  }

  // 获取专辑封面
  String? get currentAlbumArt {
    if (_currentSong == null) return null;
    if (_currentSong is OnlineSong) return (_currentSong as OnlineSong).albumArt;
    if (_currentSong is LocalSong) return (_currentSong as LocalSong).albumArt;
    return null;
  }

  /// 初始化监听器
  void initListeners() {
    // 监听播放状态
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      _safeNotifyListeners();
    });

    // 监听播放进度（优化：节流更新，节省电池）
    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      
      // 🎯 电池优化：节流更新进度条，从60fps降低到30fps
      // 降低更新频率可以减少CPU唤醒次数，节省电池
      final now = DateTime.now();
      if (_lastPositionUpdate == null ||
          now.difference(_lastPositionUpdate!) >= _positionUpdateInterval) {
        _lastPositionUpdate = now;
        positionNotifier.value = position;
      }
      // 不调用 _safeNotifyListeners()，避免整个页面重建
    });

    // 监听总时长
    _audioPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      _safeNotifyListeners();
    });
    
    // 监听播放完成事件
    _audioPlayer.onPlayerComplete.listen((event) {
      Logger.info('歌曲播放完成，执行自动播放逻辑', tag: 'Audio');
      _handlePlaybackComplete();
    });
  }
  
  /// 处理播放完成后的逻辑
  Future<void> _handlePlaybackComplete() async {
    switch (_playMode) {
      case PlayMode.sequence:
        // 顺序循环：播放下一首，最后一首后回到第一首（无限循环）
        await _playNextInLoop();
        break;
        
      case PlayMode.repeatOne:
        // 单曲循环：重复播放当前歌曲（无限循环）
        await _repeatCurrentSong();
        break;
        
      case PlayMode.shuffle:
        // 随机播放：随机选择下一首播放（无限循环）
        await _playRandomNext();
        break;
    }
  }
  
  /// 单曲循环模式：重复播放当前歌曲
  Future<void> _repeatCurrentSong() async {
    if (_currentSong == null) return;
    
    Logger.info('单曲循环：重复播放当前歌曲', tag: 'Audio');
    await playSong(
      song: _currentSong!,
      playlist: _playlist,
      index: _currentIndex,
    );
  }
  
  /// 顺序循环模式：播放下一首（循环）
  Future<void> _playNextInLoop() async {
    if (_playlist == null || _playlist!.isEmpty) {
      Logger.info('播放列表为空，停止播放', tag: 'Audio');
      return;
    }
    
    // 计算下一首的索引（循环）
    _currentIndex = (_currentIndex + 1) % _playlist!.length;
    Logger.info('顺序循环：播放第 ${_currentIndex + 1} 首（循环）', tag: 'Audio');
    
    await playSong(
      song: _playlist![_currentIndex],
      playlist: _playlist,
      index: _currentIndex,
    );
  }
  
  /// 随机播放模式：随机选择下一首
  Future<void> _playRandomNext() async {
    if (_playlist == null || _playlist!.isEmpty) {
      Logger.info('播放列表为空，停止播放', tag: 'Audio');
      return;
    }
    
    // 如果没有初始化洗牌列表，先初始化
    if (_shuffledPlaylist == null || _shuffledPlaylist!.isEmpty) {
      _initializeShuffle();
    }
    
    // 如果只有一首歌，相当于单曲循环
    if (_shuffledPlaylist!.length == 1) {
      Logger.info('随机播放：只有一首歌，重复播放', tag: 'Audio');
      await _repeatCurrentSong();
      return;
    }
    
    // 记录当前歌曲到历史（用于"上一首"功能）
    if (_shuffledIndex < _shuffledPlaylist!.length) {
      final currentSong = _shuffledPlaylist![_shuffledIndex];
      if (!_playHistory.contains(currentSong)) {
        _playHistory.add(currentSong);
        // 限制历史长度，避免内存占用过大
        if (_playHistory.length > _shuffledPlaylist!.length) {
          _playHistory.removeAt(0);
        }
      }
    }
    
    // 移动到下一首
    _shuffledIndex++;
    
    // 播放完一轮，重新洗牌
    if (_shuffledIndex >= _shuffledPlaylist!.length) {
      Logger.info('🎲 随机播放完一轮（${_shuffledPlaylist!.length}首），重新洗牌', tag: 'Audio');
      
      final lastSong = _shuffledPlaylist!.last;
      _shuffledPlaylist!.shuffle();
      
      // 🔥 关键优化：确保新一轮的第一首不是上一轮的最后一首
      if (_shuffledPlaylist![0] == lastSong && _shuffledPlaylist!.length > 1) {
        final temp = _shuffledPlaylist![0];
        _shuffledPlaylist![0] = _shuffledPlaylist![1];
        _shuffledPlaylist![1] = temp;
        Logger.info('优化：交换第1和第2首，避免轮次边界重复', tag: 'Audio');
      }
      
      _shuffledIndex = 0;
      Logger.info('新一轮洗牌列表: [${_getShufflePreview()}]', tag: 'Audio');
    }
    
    final nextSong = _shuffledPlaylist![_shuffledIndex];
    
    // 更新原始列表的索引（用于UI显示）
    _currentIndex = _playlist!.indexOf(nextSong);
    if (_currentIndex == -1) _currentIndex = 0;
    
    Logger.info('随机播放：第${_shuffledIndex + 1}/${_shuffledPlaylist!.length}首', tag: 'Audio');
    
    await playSong(
      song: nextSong,
      playlist: _playlist,
      index: _currentIndex,
    );
  }

  /// 添加歌曲到播放队列（队列模式）
  /// 如果是第一首或队列为空，立即播放；否则添加到队列末尾
  Future<void> addToQueue(Object song) async {
    if (_playlist == null || _playlist!.isEmpty) {
      // 队列为空，初始化队列并播放
      Logger.info('🎵 队列为空，初始化队列并播放: ${_getSongTitle(song)}', tag: 'Audio');
      await playSong(
        song: song,
        playlist: [song],
        index: 0,
      );
    } else {
      // 检查歌曲是否已在队列中
      final songId = _getSongId(song);
      final existingIndex = _playlist!.indexWhere((s) => _getSongId(s) == songId);
      
      if (existingIndex >= 0) {
        // 歌曲已存在，直接播放
        Logger.info('🎵 歌曲已在队列中，直接播放: ${_getSongTitle(song)}', tag: 'Audio');
        await playSongAtIndex(existingIndex);
      } else {
        // 添加到队列末尾并立即播放
        _playlist!.add(song);
        Logger.info('🎵 添加到播放队列并立即播放: ${_getSongTitle(song)} (队列长度: ${_playlist!.length})', tag: 'Audio');
        
        // 立即播放新添加的歌曲
        await playSongAtIndex(_playlist!.length - 1);
      }
    }
  }
  
  /// 播放整个歌单（替换模式）
  /// 清空当前队列，用新的歌单替换
  Future<void> playPlaylist({
    required List<Object> playlist,
    int initialIndex = 0,
  }) async {
    if (playlist.isEmpty) {
      Logger.warn('尝试播放空歌单', tag: 'Audio');
      return;
    }
    
    Logger.info('🎵 播放歌单: ${playlist.length} 首歌曲，从第 ${initialIndex + 1} 首开始', tag: 'Audio');
    
    await playSong(
      song: playlist[initialIndex],
      playlist: playlist,
      index: initialIndex,
    );
  }
  
  /// 播放指定索引的歌曲
  Future<void> playSongAtIndex(int index) async {
    if (_playlist == null || index < 0 || index >= _playlist!.length) {
      Logger.warn('无效的索引: $index', tag: 'Audio');
      return;
    }
    
    await playSong(
      song: _playlist![index],
      playlist: _playlist,
      index: index,
    );
  }
  
  /// 获取歌曲标题（辅助方法）
  String _getSongTitle(Object song) {
    if (song is LocalSong) return song.title;
    if (song is OnlineSong) return song.title;
    return '未知歌曲';
  }
  
  /// 获取歌曲ID（辅助方法）
  String _getSongId(Object song) {
    if (song is LocalSong) return song.id;
    if (song is OnlineSong) return song.id;
    return song.hashCode.toString();
  }
  
  /// 播放歌曲（内部方法）
  Future<void> playSong({
    required Object song,
    List<Object>? playlist,
    int? index,
  }) async {
    // 🚀 生成新的操作ID（取消之前的播放操作）
    _playOperationId++;
    final currentOperationId = _playOperationId;
    
    final oldSong = _currentSong;
    _currentSong = song;
    _playlist = playlist;
    _currentIndex = index ?? 0;
    
    // 只在歌曲真正变化时才通知（避免频繁更新导致卡顿）
    if (oldSong != song) {
      notifyListeners();
    }

    try {
      // ⚡ 检查操作是否已被新操作取消
      if (currentOperationId != _playOperationId) {
        Logger.info('播放操作已被取消（有新的切歌请求）', tag: 'Audio');
        return;
      }
      
      String? audioPath;
      
      if (song is LocalSong) {
        // 本地歌曲：使用本地文件路径
        audioPath = song.filePath;
        await _audioPlayer.play(DeviceFileSource(audioPath));
        
        // ⚡ 播放后再次检查（防止播放期间被新操作取代）
        if (currentOperationId != _playOperationId) {
          Logger.info('播放已完成，但操作已被新请求取消', tag: 'Audio');
          return;
        }
      } else if (song is OnlineSong) {
        // 在线歌曲：使用网络URL
        audioPath = song.audioUrl;
        
        // 🎵 如果没有 audioUrl，先获取详细信息
        if (audioPath == null || audioPath.isEmpty) {
          Logger.info('在线歌曲缺少播放链接，正在获取详细信息: ${song.title}', tag: 'Audio');
          try {
            final detailedSong = await _apiManager.getMusicInfo(song);
            audioPath = detailedSong.audioUrl;
            
            // 更新当前歌曲信息（包含完整的 audioUrl 和歌词）
            _currentSong = detailedSong;
            
            // ⚡ 检查操作是否已被取消
            if (currentOperationId != _playOperationId) {
              Logger.info('获取详细信息成功，但操作已被新请求取消', tag: 'Audio');
              return;
            }
            
            Logger.info('✅ 成功获取播放链接: ${detailedSong.title}', tag: 'Audio');
          } catch (e) {
            Logger.error('❌ 获取在线歌曲详细信息失败', error: e, tag: 'Audio');
            audioPath = null;
          }
        }
        
        if (audioPath != null && audioPath.isNotEmpty) {
          Logger.info('播放在线歌曲: ${song.title} [来源: ${song.source}]', tag: 'Audio');
          Logger.debug('播放 URL: $audioPath', tag: 'Audio');
          
          // 注意：audioplayers 在 Android 上可能不支持直接设置 headers
          // 如果需要 headers，可能需要使用代理服务器或其他方案
          await _audioPlayer.play(UrlSource(audioPath));
          
          // ⚡ 播放后再次检查（防止播放期间被新操作取代）
          if (currentOperationId != _playOperationId) {
            Logger.info('播放已完成，但操作已被新请求取消', tag: 'Audio');
            return;
          }
        } else {
          Logger.warn('❌ OnlineSong 没有有效的 audioUrl，无法播放', tag: 'Audio');
        }
      } else {
        Logger.warn('未知的歌曲类型: ${song.runtimeType}', tag: 'Audio');
      }
    } catch (e) {
      Logger.error('全局播放失败', error: e, tag: 'Audio');
    }
  }

  /// 暂停/恢复播放
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  /// 播放/暂停
  Future<void> play() async {
    await _audioPlayer.resume();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// 停止播放
  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentSong = null;
    _isPlaying = false;
    _safeNotifyListeners();
  }

  /// 播放下一首（根据播放模式）
  Future<void> playNext() async {
    if (_playlist == null || _playlist!.isEmpty) return;
    
    // 根据播放模式决定播放逻辑
    switch (_playMode) {
      case PlayMode.sequence:
        // 顺序模式：播放下一首
        _currentIndex = (_currentIndex + 1) % _playlist!.length;
        Logger.info('手动切换（顺序）：播放下一首（第 ${_currentIndex + 1} 首）', tag: 'Audio');
        
        await playSong(
          song: _playlist![_currentIndex],
          playlist: _playlist,
          index: _currentIndex,
        );
        break;
        
      case PlayMode.repeatOne:
        // 单曲循环：重复播放当前歌曲
        Logger.info('手动切换（单曲循环）：重复播放当前歌曲', tag: 'Audio');
        
        await playSong(
          song: _currentSong!,
          playlist: _playlist,
          index: _currentIndex,
        );
        break;
        
      case PlayMode.shuffle:
        // 随机模式：使用洗牌列表播放下一首
        await _playNextInShuffle();
        break;
    }
  }
  
  /// 随机模式下播放下一首（基于洗牌列表）
  Future<void> _playNextInShuffle() async {
    // 确保洗牌列表已初始化
    if (_shuffledPlaylist == null || _shuffledPlaylist!.isEmpty) {
      _initializeShuffle();
      if (_shuffledPlaylist == null || _shuffledPlaylist!.isEmpty) {
        return;
      }
    }
    
    // 记录当前歌曲到历史
    if (_shuffledIndex < _shuffledPlaylist!.length) {
      final currentSong = _shuffledPlaylist![_shuffledIndex];
      if (_playHistory.isEmpty || _playHistory.last != currentSong) {
        _playHistory.add(currentSong);
        if (_playHistory.length > _shuffledPlaylist!.length) {
          _playHistory.removeAt(0);
        }
      }
    }
    
    // 移动到下一首
    _shuffledIndex++;
    
    // 播放完一轮，重新洗牌
    if (_shuffledIndex >= _shuffledPlaylist!.length) {
      Logger.info('🎲 手动播放完一轮，重新洗牌', tag: 'Audio');
      
      final lastSong = _shuffledPlaylist!.last;
      _shuffledPlaylist!.shuffle();
      
      // 避免新旧轮次重复
      if (_shuffledPlaylist![0] == lastSong && _shuffledPlaylist!.length > 1) {
        final temp = _shuffledPlaylist![0];
        _shuffledPlaylist![0] = _shuffledPlaylist![1];
        _shuffledPlaylist![1] = temp;
      }
      
      _shuffledIndex = 0;
    }
    
    final nextSong = _shuffledPlaylist![_shuffledIndex];
    _currentIndex = _playlist!.indexOf(nextSong);
    if (_currentIndex == -1) _currentIndex = 0;
    
    Logger.info('手动切换（随机）：播放第${_shuffledIndex + 1}/${_shuffledPlaylist!.length}首', tag: 'Audio');
    
    await playSong(
      song: nextSong,
      playlist: _playlist,
      index: _currentIndex,
    );
  }

  /// 播放上一首（根据播放模式）
  Future<void> playPrevious() async {
    if (_playlist == null || _playlist!.isEmpty) return;
    
    // 根据播放模式决定播放逻辑
    switch (_playMode) {
      case PlayMode.sequence:
        // 顺序模式：播放上一首
        _currentIndex = (_currentIndex - 1 + _playlist!.length) % _playlist!.length;
        Logger.info('手动切换（顺序）：播放上一首（第 ${_currentIndex + 1} 首）', tag: 'Audio');
        
        await playSong(
          song: _playlist![_currentIndex],
          playlist: _playlist,
          index: _currentIndex,
        );
        break;
        
      case PlayMode.repeatOne:
        // 单曲循环：重复播放当前歌曲
        Logger.info('手动切换（单曲循环）：重复播放当前歌曲', tag: 'Audio');
        
        await playSong(
          song: _currentSong!,
          playlist: _playlist,
          index: _currentIndex,
        );
        break;
        
      case PlayMode.shuffle:
        // 随机模式：从历史记录中获取上一首
        await _playPreviousInShuffle();
        break;
    }
  }
  
  /// 随机模式下播放上一首（基于历史记录）
  Future<void> _playPreviousInShuffle() async {
    // 确保洗牌列表已初始化
    if (_shuffledPlaylist == null || _shuffledPlaylist!.isEmpty) {
      Logger.warn('洗牌列表未初始化', tag: 'Audio');
      return;
    }
    
    // 检查是否有历史记录
    if (_playHistory.length < 2) {
      // 没有足够的历史，重复播放当前歌曲
      Logger.info('手动切换（随机）：没有历史，重复当前歌曲', tag: 'Audio');
      if (_currentSong != null) {
        await playSong(
          song: _currentSong!,
          playlist: _playlist,
          index: _currentIndex,
        );
      }
      return;
    }
    
    // 从历史中移除当前歌曲
    _playHistory.removeLast();
    
    // 获取上一首歌曲
    final previousSong = _playHistory.last;
    
    // 在洗牌列表中找到这首歌的位置
    _shuffledIndex = _shuffledPlaylist!.indexOf(previousSong);
    if (_shuffledIndex == -1) {
      _shuffledIndex = 0;
    }
    
    // 更新原始索引
    _currentIndex = _playlist!.indexOf(previousSong);
    if (_currentIndex == -1) _currentIndex = 0;
    
    Logger.info('手动切换（随机）：返回上一首（历史中第${_playHistory.length}首）', tag: 'Audio');
    
    await playSong(
      song: previousSong,
      playlist: _playlist,
      index: _currentIndex,
    );
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// 从播放列表中移除指定索引的歌曲
  void removeFromPlaylist(int index) {
    if (_playlist == null || _playlist!.isEmpty) return;
    if (index < 0 || index >= _playlist!.length) return;
    
    // 如果移除的是当前播放的歌曲
    if (index == _currentIndex) {
      // 停止播放
      stop();
    } else if (index < _currentIndex) {
      // 如果移除的歌曲在当前歌曲之前，需要调整索引
      _currentIndex--;
    }
    
    // 从列表中移除
    _playlist!.removeAt(index);
    _safeNotifyListeners();
  }

  /// 清空播放列表
  void clearPlaylist() {
    stop();
    _playlist = null;
    _currentIndex = 0;
    _safeNotifyListeners();
  }

  /// 添加歌曲到播放列表末尾
  void addToPlaylist(Object song) {
    if (_playlist == null) {
      _playlist = [song];
    } else {
      _playlist!.add(song);
    }
    _safeNotifyListeners();
  }

  /// 插入歌曲到下一首位置
  void insertNextToPlay(Object song) {
    if (_playlist == null) {
      _playlist = [song];
      _currentIndex = 0;
    } else {
      final insertIndex = _currentIndex + 1;
      if (insertIndex <= _playlist!.length) {
        _playlist!.insert(insertIndex, song);
      } else {
        _playlist!.add(song);
      }
    }
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _positionThrottleTimer?.cancel();
    positionNotifier.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}

