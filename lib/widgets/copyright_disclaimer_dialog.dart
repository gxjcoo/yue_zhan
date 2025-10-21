import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

/// 版权声明对话框
class CopyrightDisclaimerDialog extends StatelessWidget {
  const CopyrightDisclaimerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Text('重要声明', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSection(
              '关于本应用',
              '乐栈音乐播放器是一款音乐播放工具，仅提供技术服务。',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '关于音乐内容',
              '• 本应用不提供音乐内容本身\n'
              '• 音乐内容由用户自行提供或通过第三方音乐源获取\n'
              '• 音乐版权归原创作者和版权方所有',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '用户责任',
              '• 仅可在个人、非商业用途下欣赏音乐\n'
              '• 不得用于商业用途或二次传播\n'
              '• 版权责任由用户自行承担',
              isImportant: true,
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: '详细内容请查看 '),
                  TextSpan(
                    text: '《用户协议》',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _launchUrl('https://www.xingchuiye.com/yunzhan/legal/user-agreement.html'),
                  ),
                  const TextSpan(text: ' 和 '),
                  TextSpan(
                    text: '《隐私政策》',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _launchUrl('https://www.xingchuiye.com/yunzhan/legal/privacy-policy.html'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('不同意'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('同意并继续'),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content, {bool isImportant = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isImportant ? Colors.red[700] : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isImportant ? Colors.red[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isImportant ? Colors.red[200]! : Colors.grey[300]!,
            ),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: isImportant ? Colors.red[900] : Colors.grey[800],
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// 显示版权声明对话框
Future<bool> showCopyrightDisclaimer(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const CopyrightDisclaimerDialog(),
  );
  return result ?? false;
}
