import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/notification_model.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _isLoading = true);
    final repo = ref.read(notificationRepositoryProvider);
    final items = await repo.getNotifications(user.id);
    if (mounted) {
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    }
  }

  void _markAllRead() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final repo = ref.read(notificationRepositoryProvider);
    await repo.markAllRead(user.id);
    _fetch();
  }

  void _markSingleRead(NotificationModel notif) async {
    if (notif.read) return;
    final repo = ref.read(notificationRepositoryProvider);
    await repo.markRead(notif.id);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFB),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          if (_notifications.any((n) => !n.read))
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppTheme.rosePrimary),
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.rosePrimary))
          : RefreshIndicator(
              color: AppTheme.rosePrimary,
              onRefresh: _fetch,
              child: _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: AppTheme.pinkSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_none, size: 48, color: AppTheme.rosePrimary),
                          ),
                          const SizedBox(height: 14),
                          const Text('No notifications yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Activity alerts and job matches will appear here',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        IconData icon;
                        Color iconColor;

                        switch (notif.type) {
                          case 'accept':
                            icon = Icons.check_circle;
                            iconColor = AppTheme.emeraldGreen;
                            break;
                          case 'reject':
                            icon = Icons.cancel;
                            iconColor = AppTheme.errorRed;
                            break;
                          case 'message':
                            icon = Icons.chat;
                            iconColor = AppTheme.purplePrimary;
                            break;
                          default:
                            icon = Icons.info;
                            iconColor = AppTheme.rosePrimary;
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: notif.read ? Colors.white : const Color(0xFFFFF7F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: notif.read ? AppTheme.cardBorder : AppTheme.roseLight.withAlpha(80),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: iconColor.withAlpha(20),
                              child: Icon(icon, color: iconColor, size: 20),
                            ),
                            title: Text(
                              notif.message,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: notif.read ? FontWeight.normal : FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              notif.timestamp,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            trailing: notif.read
                                ? null
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.rosePrimary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            onTap: () => _markSingleRead(notif),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
