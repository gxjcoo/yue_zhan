import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import '../services/privacy_service.dart';
import '../utils/logger.dart';
import '../widgets/privacy_agreement_dialog.dart';

/// 应用启动页
///
/// 负责：
/// 1. 决定是否展示开屏广告
/// 2. 跳转到主页
class AppStartupPage extends StatefulWidget {
  /// 启动完成后的回调
  final VoidCallback onStartupComplete;

  const AppStartupPage({
    super.key,
    required this.onStartupComplete,
  });

  @override
  State<AppStartupPage> createState() => _AppStartupPageState();
}

class _AppStartupPageState extends State<AppStartupPage> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// 初始化流程
  Future<void> _initialize() async {
    try {
      Logger.info('开始应用启动流程...', tag: 'AppStartup');

      // 1. 首先检查隐私协议
      final hasAgreedPrivacy = await PrivacyService().hasAgreed();
      if (!hasAgreedPrivacy) {
        Logger.info('用户尚未同意隐私协议，显示协议弹窗', tag: 'AppStartup');
        if (mounted) {
          await _showPrivacyDialog();
        }
        // 如果用户拒绝，这里就会退出应用，不会继续执行
      }

      // 2. 直接进入主页
      Logger.info('启动完成，进入主页', tag: 'AppStartup');
      _completeStartup();
    } catch (e, stackTrace) {
      Logger.error('应用启动流程异常', error: e, stackTrace: stackTrace, tag: 'AppStartup');
      _completeStartup();
    }
  }

  /// 显示隐私协议弹窗
  Future<void> _showPrivacyDialog() async {
    if (!mounted) return;

    final completer = Completer<void>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PrivacyAgreementDialog(
        onAgree: () {
          Navigator.of(context).pop();
          Logger.info('用户已同意隐私协议', tag: 'AppStartup');
          completer.complete();
        },
        onDisagree: () {
          Navigator.of(context).pop();
          _handlePrivacyDisagree();
        },
      ),
    );

    return completer.future;
  }

  /// 处理用户拒绝隐私协议
  void _handlePrivacyDisagree() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: const Text(
          '您需要同意用户协议和隐私政策才能使用本应用。\n\n如果不同意，应用将退出。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showPrivacyDialog();
            },
            child: const Text('重新阅读'),
          ),
          TextButton(
            onPressed: () {
              Logger.info('用户拒绝隐私协议，应用退出', tag: 'AppStartup');
              exit(0);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('退出应用'),
          ),
        ],
      ),
    );
  }

  /// 完成启动流程
  void _completeStartup() {
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });

      // 延迟一帧执行回调
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onStartupComplete();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 初始化中，显示加载页面
    if (_isInitializing) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          extendBody: true,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 应用Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '乐栈音乐',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '让音乐触手可及',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 启动完成，返回空页面（会立即被主页替换）
    return const SizedBox.shrink();
  }
}
