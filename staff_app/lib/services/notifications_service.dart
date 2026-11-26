import 'api_service.dart';

class NotificationsFeed {
  final int unreadCount;
  final List<Map<String, dynamic>> notifications;
  final List<Map<String, dynamic>> watchOrders;

  const NotificationsFeed({
    required this.unreadCount,
    required this.notifications,
    required this.watchOrders,
  });

  int get dueReachedCount => watchOrders.where((o) => (int.tryParse('${o['days_left']}') ?? 99) <= 0).length;

  int get dueSoonCount => watchOrders.where((o) {
        final d = int.tryParse('${o['days_left']}') ?? 99;
        return d > 0 && d <= 2;
      }).length;
}

class NotificationsService {
  static final NotificationsService instance = NotificationsService._();
  NotificationsService._();

  Future<NotificationsFeed> fetchNotifications() async {
    final res = await ApiService.instance.get('/notifications');
    final rawNotifs = (res['notifications'] as List?) ?? [];
    final rawWatch = (res['scheduled_watch_orders'] as List?) ?? [];
    return NotificationsFeed(
      unreadCount: int.tryParse('${res['unread_count']}') ?? 0,
      notifications: rawNotifs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      watchOrders: rawWatch.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  Future<void> markAllRead() async {
    await ApiService.instance.post('/notifications/read-all', {});
  }

  Future<void> markOneRead(int id) async {
    await ApiService.instance.patch('/notifications/$id/read', {});
  }
}
