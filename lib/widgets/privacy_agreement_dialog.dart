import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/logger.dart';
import '../services/privacy_service.dart';

/// 隐私协议和用户协议弹窗
///
/// 在首次启动应用时显示，用户必须同意后才能使用
class PrivacyAgreementDialog extends StatefulWidget {
  /// 用户同意后的回调
  final VoidCallback onAgree;

  /// 用户拒绝后的回调
  final VoidCallback onDisagree;

  const PrivacyAgreementDialog({
    super.key,
    required this.onAgree,
    required this.onDisagree,
  });

  @override
  State<PrivacyAgreementDialog> createState() => _PrivacyAgreementDialogState();
}

class _PrivacyAgreementDialogState extends State<PrivacyAgreementDialog> {
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 禁止返回键关闭弹窗
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部图标
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.privacy_tip_outlined,
                  size: 32,
                  color: Color(0xFF10B981),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 标题
              const Text(
                '用户协议和隐私政策',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 协议内容
              Container(
                constraints: const BoxConstraints(maxHeight: 350),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 欢迎文字
                      const Text(
                        '欢迎使用乐栈音乐！',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 协议说明文本
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                          children: [
                            const TextSpan(
                              text: '我们非常重视您的隐私和个人信息保护。在使用本应用前，请您仔细阅读并充分理解',
                            ),
                            TextSpan(
                              text: '《用户协议》',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _openUserAgreement(),
                            ),
                            const TextSpan(text: '和'),
                            TextSpan(
                              text: '《隐私政策》',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _openPrivacyPolicy(),
                            ),
                            const TextSpan(
                              text: '的全部内容。',
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 底部说明
                      const Text(
                        '点击"同意"即表示您已阅读并同意上述协议的全部内容。如不同意，您将无法使用本应用。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              
              // 同意勾选框
              InkWell(
                onTap: () {
                  setState(() {
                    _isChecked = !_isChecked;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _isChecked
                              ? const Color(0xFF10B981)
                              : Colors.white,
                          border: Border.all(
                            color: _isChecked
                                ? const Color(0xFF10B981)
                                : Colors.grey[400]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _isChecked
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '我已阅读并同意以上协议',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 按钮区域
              Row(
                children: [
                  // 不同意按钮
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onDisagree();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: Colors.grey,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '不同意',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // 同意按钮
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isChecked
                          ? () async {
                              // 保存同意状态
                              await PrivacyService().saveAgreementStatus(true);
                              widget.onAgree();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[500],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '同意并继续',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 打开用户协议
  Future<void> _openUserAgreement() async {
    try {
      final url = Uri.parse(
        'https://your-domain.com/legal/user-agreement.html',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开用户协议页面')),
          );
        }
      }
    } catch (e) {
      Logger.error('打开用户协议失败', error: e, tag: 'PrivacyDialog');
    }
  }

  /// 打开隐私政策
  Future<void> _openPrivacyPolicy() async {
    try {
      final url = Uri.parse(
        'https://your-domain.com/legal/privacy-policy.html',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开隐私政策页面')),
          );
        }
      }
    } catch (e) {
      Logger.error('打开隐私政策失败', error: e, tag: 'PrivacyDialog');
    }
  }
}

