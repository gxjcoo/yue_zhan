import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';

/// 下载队列状态卡片
/// 
/// 显示当前下载队列的统计信息和控制按钮
class DownloadQueueCard extends StatelessWidget {
  const DownloadQueueCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, child) {
        final queueManager = downloadProvider.queueManager;
        final stats = queueManager.getStats();
        
        // 如果队列为空且没有活跃任务，不显示
        if (queueManager.isQueueEmpty && stats['completed'] == 0 && stats['failed'] == 0) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题和操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.download_rounded,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '下载队列',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showQueueActions(context, queueManager),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 队列统计信息
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _buildStatChip(
                      context,
                      icon: Icons.schedule,
                      label: '等待中',
                      value: stats['pending'].toString(),
                      color: Colors.orange,
                    ),
                    _buildStatChip(
                      context,
                      icon: Icons.download,
                      label: '下载中',
                      value: stats['active'].toString(),
                      color: Colors.blue,
                    ),
                    _buildStatChip(
                      context,
                      icon: Icons.check_circle,
                      label: '已完成',
                      value: stats['completed'].toString(),
                      color: Colors.green,
                    ),
                    _buildStatChip(
                      context,
                      icon: Icons.error,
                      label: '失败',
                      value: stats['failed'].toString(),
                      color: Colors.red,
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // 成功率和并发限制
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '成功率: ${stats['successRate']}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '并发限制: ${stats['maxConcurrent']} 个',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                
                // 如果有活跃任务，显示进度条
                if (stats['active'] > 0) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '正在下载 ${stats['active']} 首歌曲...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建统计信息芯片
  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示队列操作菜单
  void _showQueueActions(BuildContext context, dynamic queueManager) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动指示器
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 标题
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.grey[700]),
                    const SizedBox(width: 12),
                    const Text(
                      '队列管理',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // 操作选项
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.orange),
                title: const Text('重试失败任务'),
                subtitle: Text(
                  '重新下载失败的歌曲 (${queueManager.failedCount} 个)',
                  style: const TextStyle(fontSize: 12),
                ),
                enabled: queueManager.failedCount > 0,
                onTap: () {
                  Navigator.pop(context);
                  queueManager.retryFailed();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已将 ${queueManager.failedCount} 个失败任务加入队列'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('清空已完成'),
                subtitle: Text(
                  '移除已完成的任务记录 (${queueManager.completedCount} 个)',
                  style: const TextStyle(fontSize: 12),
                ),
                enabled: queueManager.completedCount > 0,
                onTap: () {
                  Navigator.pop(context);
                  queueManager.clearCompleted();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已清空完成任务记录'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: const Text('清空失败记录'),
                subtitle: Text(
                  '移除失败的任务记录 (${queueManager.failedCount} 个)',
                  style: const TextStyle(fontSize: 12),
                ),
                enabled: queueManager.failedCount > 0,
                onTap: () {
                  Navigator.pop(context);
                  queueManager.clearFailed();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已清空失败记录'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.blue),
                title: const Text('重置统计信息'),
                subtitle: const Text(
                  '清除所有任务记录和统计数据',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showResetConfirmDialog(context, queueManager);
                },
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// 显示重置确认对话框
  void _showResetConfirmDialog(BuildContext context, dynamic queueManager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重置'),
        content: const Text(
          '这将清除所有任务记录和统计信息。\n\n注意：不会影响已下载的歌曲文件。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              queueManager.resetStats();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('统计信息已重置'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }
}

