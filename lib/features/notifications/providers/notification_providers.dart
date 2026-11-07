import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_item.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(apiClientProvider)),
);

/// Số thông báo chưa đọc (badge chuông trên header). 0 khi chưa đăng nhập.
final unreadCountProvider = FutureProvider<int>((ref) async {
  final loggedIn = ref.watch(authProvider.select((s) => s.isLoggedIn));
  if (!loggedIn) return 0;
  try {
    return await ref.watch(notificationServiceProvider).getUnreadCount();
  } catch (_) {
    return 0;
  }
});

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.page = -1,
    this.hasNext = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<NotificationItem> items;
  final int page;
  final bool hasNext;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    int? page,
    bool? hasNext,
    bool? isLoadingMore,
  }) => NotificationsState(
    items: items ?? this.items,
    page: page ?? this.page,
    hasNext: hasNext ?? this.hasNext,
    isLoading: isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: error,
  );

  List<NotificationItem> of(NotificationCategory category) =>
      category == NotificationCategory.all
      ? items
      : items.where((n) => n.category == category).toList();
}

final notificationsProvider =
    NotifierProvider.autoDispose<NotificationsNotifier, NotificationsState>(
      NotificationsNotifier.new,
    );

class NotificationsNotifier extends Notifier<NotificationsState> {
  int _requestId = 0;

  NotificationService get _service => ref.read(notificationServiceProvider);

  @override
  NotificationsState build() {
    Future.microtask(refresh);
    return const NotificationsState(isLoading: true);
  }

  Future<void> refresh() async {
    final id = ++_requestId;
    state = const NotificationsState(isLoading: true);
    try {
      final result = await _service.getNotifications();
      if (!ref.mounted || id != _requestId) return;
      state = NotificationsState(
        items: result.content,
        page: 0,
        hasNext: result.hasNext,
      );
    } catch (e) {
      if (!ref.mounted || id != _requestId) return;
      state = NotificationsState(error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasNext) return;
    final id = _requestId;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _service.getNotifications(page: state.page + 1);
      if (!ref.mounted || id != _requestId) return;
      final seen = state.items.map((n) => n.id).toSet();
      state = state.copyWith(
        items: [...state.items, ...result.content.where((n) => seen.add(n.id))],
        page: state.page + 1,
        hasNext: result.hasNext,
        isLoadingMore: false,
      );
    } catch (_) {
      if (ref.mounted && id == _requestId) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  /// Đánh dấu 1 thông báo đã đọc (cập nhật lạc quan, hoàn tác nếu lỗi).
  Future<void> markRead(NotificationItem item) async {
    if (item.read) return;
    _replace(item.id, item.markRead());
    try {
      await _service.markRead(item.id);
      ref.invalidate(unreadCountProvider);
    } catch (e) {
      _replace(item.id, item);
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final before = state.items;
    state = state.copyWith(items: [for (final n in before) n.markRead()]);
    try {
      await _service.markAllRead();
      ref.invalidate(unreadCountProvider);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(items: before);
      rethrow;
    }
  }

  void _replace(int id, NotificationItem value) {
    if (!ref.mounted) return;
    state = state.copyWith(
      items: [for (final n in state.items) n.id == id ? value : n],
    );
  }
}
