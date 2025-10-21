import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/online_song.dart';
import '../models/download_task_model.dart';
import '../utils/logger.dart';
import '../config/constants.dart';

/// 下载任务
class DownloadTask {
  final String id;
  final OnlineSong song;
  final Function(DownloadTask task) onStart;
  final Function(DownloadTask task, bool success) onComplete;
  final Function(DownloadTask task, Object error) onError;
  
  DownloadTaskStatus status = DownloadTaskStatus.pending;
  DateTime createdAt = DateTime.now();
  DateTime? startedAt;
  DateTime? completedAt;
  
  DownloadTask({
    required this.id,
    required this.song,
    required this.onStart,
    required this.onComplete,
    required this.onError,
  });
}

/// 下载任务状态
enum DownloadTaskStatus {
  pending,    // 等待中
  running,    // 下载中
  completed,  // 已完成
  failed,     // 失败
  cancelled,  // 已取消
}

/// 下载队列管理器
/// 
/// 功能：
/// - 限制并发下载数量
/// - 自动队列管理
/// - 任务优先级
/// - 下载统计
class DownloadQueueManager extends ChangeNotifier {
  // 单例模式
  static final DownloadQueueManager _instance = DownloadQueueManager._internal();
  factory DownloadQueueManager() => _instance;
  DownloadQueueManager._internal();
  
  /// 确保初始化完成
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await _initializePersistence();
  }

  // 队列配置
  final int maxConcurrent = Constants.maxConcurrentDownloads; // 最大并发数
  
  // 任务队列
  final Queue<DownloadTask> _pendingQueue = Queue<DownloadTask>();
  final List<DownloadTask> _activeDownloads = [];
  final List<DownloadTask> _completedTasks = [];
  final List<DownloadTask> _failedTasks = [];
  
  // 统计信息
  int _totalTasksCreated = 0;
  int _totalSuccessful = 0;
  int _totalFailed = 0;
  
  // Hive 持久化
  Box<DownloadTaskModel>? _queueBox;
  bool _isInitialized = false;
  
  /// 获取等待中的任务数
  int get pendingCount => _pendingQueue.length;
  
  /// 获取正在下载的任务数
  int get activeCount => _activeDownloads.length;
  
  /// 获取已完成的任务数
  int get completedCount => _completedTasks.length;
  
  /// 获取失败的任务数
  int get failedCount => _failedTasks.length;
  
  /// 获取总任务数
  int get totalTasks => _totalTasksCreated;
  
  /// 是否有空闲槽位
  bool get hasAvailableSlot => _activeDownloads.length < maxConcurrent;
  
  /// 是否队列为空
  bool get isQueueEmpty => _pendingQueue.isEmpty && _activeDownloads.isEmpty;
  
  /// 初始化持久化
  Future<void> _initializePersistence() async {
    try {
      _queueBox = await Hive.openBox<DownloadTaskModel>('download_queue');
      await _restoreQueue();
      _isInitialized = true;
      Logger.info('队列持久化初始化成功', tag: 'DownloadQueue');
    } catch (e) {
      Logger.error('队列持久化初始化失败', error: e, tag: 'DownloadQueue');
    }
  }
  
  /// 从持久化存储恢复队列
  Future<void> _restoreQueue() async {
    try {
      if (_queueBox == null || _queueBox!.isEmpty) {
        Logger.info('无需恢复队列（队列为空）', tag: 'DownloadQueue');
        return;
      }
      
      final savedTasks = _queueBox!.values.toList();
      Logger.info('开始恢复队列: ${savedTasks.length} 个任务', tag: 'DownloadQueue');
      
      int pendingRestored = 0;
      int completedRestored = 0;
      int failedRestored = 0;
      
      for (final taskModel in savedTasks) {
        if (taskModel.status == 'pending' || taskModel.status == 'running') {
          // 将未完成的任务状态重置为 pending
          taskModel.status = 'pending';
          await taskModel.save();
          pendingRestored++;
        } else if (taskModel.status == 'completed') {
          _totalSuccessful++;
          completedRestored++;
        } else if (taskModel.status == 'failed') {
          _totalFailed++;
          failedRestored++;
        }
        
        _totalTasksCreated++;
      }
      
      Logger.info(
        '队列恢复完成: 待处理=$pendingRestored, 已完成=$completedRestored, 失败=$failedRestored',
        tag: 'DownloadQueue',
      );
      
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('恢复队列失败', error: e, stackTrace: stackTrace, tag: 'DownloadQueue');
    }
  }
  
  /// 保存任务到持久化存储
  Future<void> _saveTask(DownloadTask task) async {
    try {
      await ensureInitialized();
      if (_queueBox == null) return;
      
      final taskModel = DownloadTaskModel(
        id: task.id,
        songId: task.song.id,
        songTitle: task.song.title,
        songArtist: task.song.artist,
        songSource: task.song.source,
        status: task.status.toString().split('.').last,
        createdAt: task.createdAt,
        startedAt: task.startedAt,
        completedAt: task.completedAt,
      );
      
      await _queueBox!.put(task.id, taskModel);
      Logger.debug('任务已保存: ${task.song.title}', tag: 'DownloadQueue');
    } catch (e) {
      Logger.error('保存任务失败: ${task.song.title}', error: e, tag: 'DownloadQueue');
    }
  }
  
  /// 更新任务状态
  Future<void> _updateTaskStatus(DownloadTask task, DownloadTaskStatus status, {String? errorMessage}) async {
    try {
      await ensureInitialized();
      if (_queueBox == null) return;
      
      final taskModel = _queueBox!.get(task.id);
      if (taskModel != null) {
        taskModel.status = status.toString().split('.').last;
        
        if (status == DownloadTaskStatus.running) {
          taskModel.startedAt = DateTime.now();
        } else if (status == DownloadTaskStatus.completed || status == DownloadTaskStatus.failed) {
          taskModel.completedAt = DateTime.now();
        }
        
        if (errorMessage != null) {
          taskModel.errorMessage = errorMessage;
        }
        
        await taskModel.save();
        Logger.debug('任务状态已更新: ${task.song.title} -> $status', tag: 'DownloadQueue');
      }
    } catch (e) {
      Logger.error('更新任务状态失败', error: e, tag: 'DownloadQueue');
    }
  }
  
  /// 删除任务记录
  Future<void> _deleteTask(String taskId) async {
    try {
      await ensureInitialized();
      if (_queueBox == null) return;
      
      await _queueBox!.delete(taskId);
      Logger.debug('任务记录已删除: $taskId', tag: 'DownloadQueue');
    } catch (e) {
      Logger.error('删除任务记录失败', error: e, tag: 'DownloadQueue');
    }
  }
  
  /// 添加下载任务
  /// 
  /// 返回任务 ID，可用于取消任务
  Future<String> addTask({
    required OnlineSong song,
    required Function(DownloadTask task) onStart,
    required Function(DownloadTask task, bool success) onComplete,
    required Function(DownloadTask task, Object error) onError,
  }) async {
    final taskId = '${song.id}_${DateTime.now().millisecondsSinceEpoch}';
    
    final task = DownloadTask(
      id: taskId,
      song: song,
      onStart: onStart,
      onComplete: onComplete,
      onError: onError,
    );
    
    _pendingQueue.add(task);
    _totalTasksCreated++;
    
    // 保存到持久化存储
    await _saveTask(task);
    
    Logger.info('下载任务已添加到队列: ${song.title} (队列: ${_pendingQueue.length}, 活跃: ${_activeDownloads.length})', tag: 'DownloadQueue');
    
    notifyListeners();
    
    // 尝试处理队列
    _processQueue();
    
    return taskId;
  }
  
  /// 取消任务
  bool cancelTask(String taskId) {
    // 从等待队列中查找并移除
    final pendingTask = _pendingQueue.firstWhere(
      (task) => task.id == taskId,
      orElse: () => throw StateError('Task not found'),
    );
    
    try {
      if (_pendingQueue.contains(pendingTask)) {
        _pendingQueue.remove(pendingTask);
        pendingTask.status = DownloadTaskStatus.cancelled;
        Logger.info('已取消等待中的任务: ${pendingTask.song.title}', tag: 'DownloadQueue');
        notifyListeners();
        return true;
      }
    } catch (e) {
      // 任务不在等待队列中
    }
    
    // 注意：正在下载的任务无法取消（需要在 OnlineMusicProvider 中实现）
    Logger.warn('无法取消任务 $taskId（可能正在下载或已完成）', tag: 'DownloadQueue');
    return false;
  }
  
  /// 处理队列
  void _processQueue() {
    // 如果有空闲槽位且队列不为空，则启动新任务
    while (hasAvailableSlot && _pendingQueue.isNotEmpty) {
      final task = _pendingQueue.removeFirst();
      _startTask(task);
    }
  }
  
  /// 启动任务
  void _startTask(DownloadTask task) async {
    try {
      task.status = DownloadTaskStatus.running;
      task.startedAt = DateTime.now();
      _activeDownloads.add(task);
      
      // 更新持久化状态
      await _updateTaskStatus(task, DownloadTaskStatus.running);
      
      Logger.info('开始下载: ${task.song.title} (活跃: ${_activeDownloads.length}/$maxConcurrent)', tag: 'DownloadQueue');
      notifyListeners();
      
      // 调用开始回调
      task.onStart(task);
      
      // 注意：实际下载由 OnlineMusicProvider 处理
      // 这里只是队列管理，不直接执行下载
      
    } catch (e) {
      Logger.error('启动下载任务失败: ${task.song.title}', error: e, tag: 'DownloadQueue');
      _handleTaskError(task, e);
    }
  }
  
  /// 任务完成回调（由外部调用）
  Future<void> onTaskCompleted(String taskId, bool success) async {
    final task = _activeDownloads.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw StateError('Task not found in active downloads'),
    );
    
    try {
      _activeDownloads.remove(task);
      task.completedAt = DateTime.now();
      
      if (success) {
        task.status = DownloadTaskStatus.completed;
        _completedTasks.add(task);
        _totalSuccessful++;
        await _updateTaskStatus(task, DownloadTaskStatus.completed);
        Logger.info('下载完成: ${task.song.title} ✅', tag: 'DownloadQueue');
      } else {
        task.status = DownloadTaskStatus.failed;
        _failedTasks.add(task);
        _totalFailed++;
        await _updateTaskStatus(task, DownloadTaskStatus.failed);
        Logger.warn('下载失败: ${task.song.title} ❌', tag: 'DownloadQueue');
      }
      
      // 调用完成回调
      task.onComplete(task, success);
      
      // 处理下一个任务
      _processQueue();
      
      notifyListeners();
    } catch (e) {
      Logger.error('处理任务完成状态失败', error: e, tag: 'DownloadQueue');
    }
  }
  
  /// 处理任务错误
  void _handleTaskError(DownloadTask task, Object error) {
    _activeDownloads.remove(task);
    task.status = DownloadTaskStatus.failed;
    task.completedAt = DateTime.now();
    _failedTasks.add(task);
    _totalFailed++;
    
    Logger.error('任务失败: ${task.song.title}', error: error, tag: 'DownloadQueue');
    
    // 调用错误回调
    task.onError(task, error);
    
    // 处理下一个任务
    _processQueue();
    
    notifyListeners();
  }
  
  /// 清空已完成的任务
  void clearCompleted() async {
    // 从持久化存储中删除已完成任务
    for (final task in _completedTasks) {
      await _deleteTask(task.id);
    }
    
    _completedTasks.clear();
    Logger.debug('已清空完成任务列表', tag: 'DownloadQueue');
    notifyListeners();
  }
  
  /// 清空失败的任务
  void clearFailed() async {
    // 从持久化存储中删除失败任务
    for (final task in _failedTasks) {
      await _deleteTask(task.id);
    }
    
    _failedTasks.clear();
    Logger.debug('已清空失败任务列表', tag: 'DownloadQueue');
    notifyListeners();
  }
  
  /// 重试失败的任务
  void retryFailed() {
    for (final task in List.from(_failedTasks)) {
      _failedTasks.remove(task);
      task.status = DownloadTaskStatus.pending;
      task.startedAt = null;
      task.completedAt = null;
      _pendingQueue.add(task);
    }
    
    Logger.info('重试 ${_failedTasks.length} 个失败任务', tag: 'DownloadQueue');
    notifyListeners();
    
    _processQueue();
  }
  
  /// 获取队列统计信息
  Map<String, dynamic> getStats() {
    return {
      'pending': pendingCount,
      'active': activeCount,
      'completed': completedCount,
      'failed': failedCount,
      'total': totalTasks,
      'successful': _totalSuccessful,
      'successRate': totalTasks > 0 ? '${(_totalSuccessful / totalTasks * 100).toStringAsFixed(1)}%' : 'N/A',
      'maxConcurrent': maxConcurrent,
    };
  }
  
  /// 重置统计信息
  Future<void> resetStats() async {
    // 清空持久化存储
    await ensureInitialized();
    if (_queueBox != null) {
      await _queueBox!.clear();
      Logger.debug('持久化存储已清空', tag: 'DownloadQueue');
    }
    
    _totalTasksCreated = 0;
    _totalSuccessful = 0;
    _totalFailed = 0;
    _completedTasks.clear();
    _failedTasks.clear();
    Logger.debug('统计信息已重置', tag: 'DownloadQueue');
    notifyListeners();
  }
  
  /// 检查特定歌曲是否下载失败
  bool hasFailed(String songId) {
    return _failedTasks.any((task) => task.song.id == songId);
  }
}

