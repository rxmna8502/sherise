import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return NotificationRepository(dio: dioClient.dio);
});

class NotificationsState {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;

  const NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationRepository _repository;
  final Ref _ref;

  NotificationsNotifier({
    required NotificationRepository repository,
    required Ref ref,
  })  : _repository = repository,
        _ref = ref,
        super(const NotificationsState()) {
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    final user = _ref.read(authProvider).user;
    if (user == null) {
      state = const NotificationsState();
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final list = await _repository.getNotifications(user.id);
      final unread = list.where((n) => !n.read).length;
      state = state.copyWith(
        notifications: list,
        unreadCount: unread,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markRead(String notificationId) async {
    await _repository.markRead(notificationId);
    await fetchNotifications();
  }

  Future<void> markAllRead() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    await _repository.markAllRead(user.id);
    await fetchNotifications();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return NotificationsNotifier(repository: repo, ref: ref);
});
