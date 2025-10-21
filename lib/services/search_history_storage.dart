import 'package:hive_flutter/hive_flutter.dart';
import '../utils/logger.dart';

/// 搜索历史存储服务
class SearchHistoryStorage {
  static const String _boxName = 'search_history';
  static const int _maxHistoryCount = 50; // 最多保留 50 条
  
  /// 获取搜索历史 Box（支持延迟加载）
  static Future<Box<String>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
    return Hive.box<String>(_boxName);
  }
  
  /// 初始化搜索历史 Box
  static Future<void> init() async {
    await Hive.openBox<String>(_boxName);
    Logger.info('搜索历史存储初始化完成', tag: 'SearchHistory');
  }
  
  /// 添加搜索历史
  static Future<void> addHistory(String query) async {
    if (query.trim().isEmpty) return;
    
    try {
      final box = await _getBox();
      final histories = box.values.toList();
      
      // 如果已存在，先删除
      if (histories.contains(query)) {
        final index = histories.indexOf(query);
        await box.deleteAt(index);
      }
      
      // 插入到开头
      await box.add(query);
      
      // 保持最多 50 条，删除最旧的
      if (box.length > _maxHistoryCount) {
        await box.deleteAt(0);
      }
      
      Logger.debug('添加搜索历史: $query', tag: 'SearchHistory');
    } catch (e) {
      Logger.error('添加搜索历史失败', error: e, tag: 'SearchHistory');
    }
  }
  
  /// 获取所有搜索历史（最新的在前）
  static Future<List<String>> getHistories() async {
    try {
      final box = await _getBox();
      final histories = box.values.toList();
      // 反转列表，让最新的在前面
      return histories.reversed.toList();
    } catch (e) {
      print('获取搜索历史失败: $e');
      return [];
    }
  }
  
  /// 获取最近 N 条搜索历史
  static Future<List<String>> getRecentHistories(int count) async {
    final all = await getHistories();
    return all.take(count).toList();
  }
  
  /// 删除指定搜索历史
  static Future<void> removeHistory(String query) async {
    try {
      final box = await _getBox();
      final histories = box.values.toList();
      
      if (histories.contains(query)) {
        final reversedHistories = histories.reversed.toList();
        final index = reversedHistories.indexOf(query);
        final actualIndex = histories.length - 1 - index;
        await box.deleteAt(actualIndex);
        Logger.debug('删除搜索历史: $query', tag: 'SearchHistory');
      }
    } catch (e) {
      Logger.error('删除搜索历史失败', error: e, tag: 'SearchHistory');
    }
  }
  
  /// 清空所有搜索历史
  static Future<void> clearHistory() async {
    try {
      final box = await _getBox();
      await box.clear();
      Logger.info('清空搜索历史', tag: 'SearchHistory');
    } catch (e) {
      Logger.error('清空搜索历史失败', error: e, tag: 'SearchHistory');
    }
  }
  
  /// 获取搜索历史数量
  static Future<int> getHistoryCount() async {
    try {
      final box = await _getBox();
      return box.length;
    } catch (e) {
      Logger.error('获取搜索历史数量失败', error: e, tag: 'SearchHistory');
      return 0;
    }
  }
}

