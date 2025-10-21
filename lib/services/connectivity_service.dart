import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// 网络连接状态服务
/// 
/// 提供：
/// - 实时网络连接状态监听
/// - 连接类型检测（WiFi、移动数据、以太网等）
/// - 状态变化通知
class ConnectivityService extends ChangeNotifier {
  // 单例模式
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  List<ConnectivityResult> get connectionStatus => _connectionStatus;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  /// 是否在线（有任何网络连接）
  /// 
  /// 注意：如果未初始化，默认假设有网络连接
  bool get isOnline {
    // 未初始化时假设有网络（避免阻止功能使用）
    if (!_isInitialized) {
      return true;
    }
    return _connectionStatus.any((result) => result != ConnectivityResult.none);
  }
  
  /// 是否使用 WiFi
  bool get isWiFi {
    return _connectionStatus.contains(ConnectivityResult.wifi);
  }
  
  /// 是否使用移动数据
  bool get isMobile {
    return _connectionStatus.contains(ConnectivityResult.mobile);
  }
  
  /// 是否使用以太网
  bool get isEthernet {
    return _connectionStatus.contains(ConnectivityResult.ethernet);
  }
  
  /// 初始化连接监听
  Future<void> initialize() async {
    if (_isInitialized) {
      Logger.debug('ConnectivityService 已初始化', tag: 'Connectivity');
      return;
    }
    
    try {
      // 获取初始连接状态
      _connectionStatus = await _connectivity.checkConnectivity();
      Logger.info('初始网络状态: ${_getStatusString()}', tag: 'Connectivity');
      
      // 监听连接状态变化
      _subscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          Logger.error('连接状态监听出错', error: error, tag: 'Connectivity');
        },
      );
      
      _isInitialized = true;
      Logger.info('ConnectivityService 初始化完成', tag: 'Connectivity');
    } catch (e) {
      Logger.error('ConnectivityService 初始化失败', error: e, tag: 'Connectivity');
    }
  }
  
  /// 处理连接状态变化
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = isOnline;
    _connectionStatus = results;
    final nowOnline = isOnline;
    
    // 记录状态变化
    if (wasOnline != nowOnline) {
      if (nowOnline) {
        Logger.info('📶 网络已连接: ${_getStatusString()}', tag: 'Connectivity');
      } else {
        Logger.warn('📵 网络已断开', tag: 'Connectivity');
      }
    } else {
      Logger.debug('网络状态变化: ${_getStatusString()}', tag: 'Connectivity');
    }
    
    notifyListeners();
  }
  
  /// 手动检查连接状态
  Future<void> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _onConnectivityChanged(results);
    } catch (e) {
      Logger.error('检查网络状态失败', error: e, tag: 'Connectivity');
    }
  }
  
  /// 获取状态字符串描述
  String _getStatusString() {
    if (_connectionStatus.isEmpty || 
        _connectionStatus.first == ConnectivityResult.none) {
      return '无连接';
    }
    
    final types = <String>[];
    for (final result in _connectionStatus) {
      switch (result) {
        case ConnectivityResult.wifi:
          types.add('WiFi');
          break;
        case ConnectivityResult.mobile:
          types.add('移动数据');
          break;
        case ConnectivityResult.ethernet:
          types.add('以太网');
          break;
        case ConnectivityResult.vpn:
          types.add('VPN');
          break;
        case ConnectivityResult.bluetooth:
          types.add('蓝牙');
          break;
        case ConnectivityResult.other:
          types.add('其他');
          break;
        case ConnectivityResult.none:
          break;
      }
    }
    
    return types.isEmpty ? '未知' : types.join(' + ');
  }
  
  /// 获取连接状态描述（用于UI显示）
  String getConnectionDescription() {
    if (!isOnline) {
      return '离线';
    }
    
    return _getStatusString();
  }
  
  /// 释放资源
  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
    Logger.debug('ConnectivityService 已释放', tag: 'Connectivity');
    super.dispose();
  }
}

