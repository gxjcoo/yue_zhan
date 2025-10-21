import 'package:flutter/foundation.dart';

/// 音乐库刷新通知服务
/// 用于在下载歌曲后通知音乐库页面刷新
class LibraryRefreshNotifier extends ChangeNotifier {
  static final LibraryRefreshNotifier _instance = LibraryRefreshNotifier._internal();
  
  factory LibraryRefreshNotifier() {
    return _instance;
  }
  
  LibraryRefreshNotifier._internal();
  
  /// 通知音乐库需要刷新
  void notifyLibraryChanged() {
    notifyListeners();
    print('📢 通知音乐库刷新');
  }
}

