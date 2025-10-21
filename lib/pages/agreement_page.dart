import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 协议查看页面
/// 
/// 在外部浏览器中打开协议链接
class AgreementPage extends StatelessWidget {
  final AgreementType type;
  
  const AgreementPage({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    // 自动打开浏览器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchURL(context, type.url);
      Navigator.of(context).pop();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(type.title),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '正在打开浏览器...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 打开外部链接
  static Future<void> _launchURL(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法打开链接：$url')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开链接失败：$e')),
        );
      }
    }
  }
}

/// 协议类型枚举
enum AgreementType {
  privacy('隐私政策', 'https://www.xingchuiye.com/yunzhan/legal/privacy-policy.html'),
  userAgreement('用户协议', 'https://www.xingchuiye.com/yunzhan/legal/user-agreement.html');
  
  final String title;
  final String url;
  
  const AgreementType(this.title, this.url);
  
  /// 获取本地开发 URL（用于开发测试）
  String get localUrl {
    switch (this) {
      case AgreementType.privacy:
        return 'http://localhost:8000/legal/privacy-policy.html';
      case AgreementType.userAgreement:
        return 'http://localhost:8000/legal/user-agreement.html';
    }
  }
}

/// 首次启动协议同意对话框
class AgreementDialog extends StatefulWidget {
  final VoidCallback onAgree;
  final VoidCallback onDisagree;
  
  const AgreementDialog({
    super.key,
    required this.onAgree,
    required this.onDisagree,
  });

  @override
  State<AgreementDialog> createState() => _AgreementDialogState();
}

class _AgreementDialogState extends State<AgreementDialog> {
  bool _hasRead = false;
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400 || screenSize.height < 700;
    
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: isSmallScreen ? 24 : 40,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: screenSize.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.privacy_tip,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '欢迎使用乐栈音乐',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '在使用本应用前，请您仔细阅读并同意以下协议：',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 用户协议链接
                    _buildAgreementLink(
                      context,
                      icon: Icons.description,
                      title: '《用户协议》',
                      type: AgreementType.userAgreement,
                      isSmallScreen: isSmallScreen,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // 隐私政策链接
                    _buildAgreementLink(
                      context,
                      icon: Icons.privacy_tip,
                      title: '《隐私政策》',
                      type: AgreementType.privacy,
                      isSmallScreen: isSmallScreen,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '我们将按照上述协议保护您的个人信息安全。',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: Theme.of(context).primaryColor,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 已读确认
                    InkWell(
                      onTap: () {
                        setState(() {
                          _hasRead = !_hasRead;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _hasRead,
                                onChanged: (value) {
                                  setState(() {
                                    _hasRead = value ?? false;
                                  });
                                },
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '我已阅读并同意上述协议',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 按钮区域
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onDisagree,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                      ),
                      child: Text(
                        '不同意',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _hasRead ? widget.onAgree : null,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                      ),
                      child: Text(
                        '同意并继续',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建协议链接
  Widget _buildAgreementLink(
    BuildContext context, {
    required IconData icon,
    required String title,
    required AgreementType type,
    bool isSmallScreen = false,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AgreementPage(type: type),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isSmallScreen ? 10 : 12,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: isSmallScreen ? 18 : 20,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: isSmallScreen ? 13 : 14,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: isSmallScreen ? 12 : 14,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
