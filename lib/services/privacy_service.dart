import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// 隐私协议服务
///
/// 管理用户隐私协议的同意状态
class PrivacyService {
  static const String _tag = 'PrivacyService';
  static const String _keyAgreementAccepted = 'privacy_agreement_accepted';
  static const String _keyAgreementVersion = 'privacy_agreement_version';
  static const String _keyAgreementDate = 'privacy_agreement_date';

  /// 当前协议版本
  /// 如果协议有重大更新，增加版本号，用户需要重新同意
  static const String currentVersion = '1.0.1';

  // 单例模式
  static final PrivacyService _instance = PrivacyService._internal();
  factory PrivacyService() => _instance;
  PrivacyService._internal();

  SharedPreferences? _prefs;

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    Logger.info('PrivacyService 初始化完成', tag: _tag);
  }

  /// 检查用户是否已同意隐私协议
  ///
  /// 如果协议版本已更新，即使之前同意过也会返回 false
  Future<bool> hasAgreed() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;

      final accepted = prefs.getBool(_keyAgreementAccepted) ?? false;
      final version = prefs.getString(_keyAgreementVersion) ?? '';

      // 检查是否同意且版本一致
      final agreed = accepted && version == currentVersion;

      Logger.info(
        '用户隐私协议状态: ${agreed ? "已同意" : "未同意"} (版本: $version, 当前版本: $currentVersion)',
        tag: _tag,
      );

      return agreed;
    } catch (e) {
      Logger.error('检查隐私协议状态失败', error: e, tag: _tag);
      return false;
    }
  }

  /// 保存用户同意状态
  Future<void> saveAgreementStatus(bool agreed) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;

      await prefs.setBool(_keyAgreementAccepted, agreed);
      await prefs.setString(_keyAgreementVersion, currentVersion);
      await prefs.setString(
        _keyAgreementDate,
        DateTime.now().toIso8601String(),
      );

      Logger.info(
        '已保存隐私协议同意状态: $agreed (版本: $currentVersion)',
        tag: _tag,
      );
    } catch (e) {
      Logger.error('保存隐私协议状态失败', error: e, tag: _tag);
    }
  }

  /// 获取用户同意的日期
  Future<DateTime?> getAgreementDate() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;

      final dateStr = prefs.getString(_keyAgreementDate);
      if (dateStr != null) {
        return DateTime.parse(dateStr);
      }
    } catch (e) {
      Logger.error('获取隐私协议同意日期失败', error: e, tag: _tag);
    }
    return null;
  }

  /// 获取用户同意的协议版本
  Future<String?> getAgreementVersion() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;

      return prefs.getString(_keyAgreementVersion);
    } catch (e) {
      Logger.error('获取隐私协议版本失败', error: e, tag: _tag);
    }
    return null;
  }

  /// 重置隐私协议状态（仅用于测试）
  Future<void> reset() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;

      await prefs.remove(_keyAgreementAccepted);
      await prefs.remove(_keyAgreementVersion);
      await prefs.remove(_keyAgreementDate);

      Logger.info('已重置隐私协议状态', tag: _tag);
    } catch (e) {
      Logger.error('重置隐私协议状态失败', error: e, tag: _tag);
    }
  }
}

