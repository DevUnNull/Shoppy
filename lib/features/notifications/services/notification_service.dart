import '../../../core/network/api_client.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/page_result.dart';
import '../models/notification_item.dart';

class NotificationService {
  NotificationService(this._client);

  final ApiClient _client;

  /// `GET /notifications?page=&size=`
  Future<PageResult<NotificationItem>> getNotifications({
    int page = 0,
    int size = 20,
  }) async {
    final data = await _client.get(
      '/notifications',
      query: {'page': page, 'size': size},
    );
    return PageResult.fromJson(data, NotificationItem.fromJson);
  }

  /// `GET /notifications/unread-count` — backend trả về một số nguyên.
  Future<int> getUnreadCount() async {
    final data = await _client.get('/notifications/unread-count');
    if (data is Map) return asInt(data['count'] ?? data['unreadCount']);
    return asInt(data);
  }

  /// `PATCH /notifications/{id}/read`
  Future<void> markRead(int id) async {
    await _client.patch('/notifications/$id/read');
  }

  /// `PATCH /notifications/read-all`
  Future<void> markAllRead() async {
    await _client.patch('/notifications/read-all');
  }
}
