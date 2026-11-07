import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../account/widgets/account_shell.dart';
import '../models/notification_item.dart';
import '../providers/notification_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationCategory _category = NotificationCategory.all;

  Future<void> _open(NotificationItem item) async {
    try {
      await ref.read(notificationsProvider.notifier).markRead(item);
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    }
    if (!mounted) return;
    final ref0 = item.referenceId;
    if (item.category == NotificationCategory.order && ref0 != null) {
      item.isSellerOrder
          ? AppRouter.sellerChannel(context)
          : AppRouter.orderDetail(context, ref0);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        icon: Icon(item.visual.icon, color: item.visual.color, size: 40),
        title: Text(item.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.message, textAlign: TextAlign.center),
            if (item.createdAt != null) ...[
              const SizedBox(height: 12),
              Text(
                formatDateTime(item.createdAt!),
                style: const TextStyle(color: AppColors.caption, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ĐÓNG'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAll() async {
    try {
      await ref.read(notificationsProvider.notifier).markAllRead();
      if (mounted) AppToast.success(context, 'Đã đánh dấu tất cả là đã đọc');
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final items = state.of(_category);
    final hasUnread = state.items.any((n) => !n.read);

    return AccountShell(
      section: AccountSection.notifications,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountPageHeader(
            title: 'Thông báo',
            subtitle: 'Cập nhật đơn hàng, khuyến mãi và tin hệ thống',
            trailing: TextButton.icon(
              onPressed: hasUnread ? _markAll : null,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Đánh dấu tất cả đã đọc'),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in NotificationCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(
                        c.icon,
                        size: 16,
                        color: c == _category
                            ? Colors.white
                            : AppColors.primary,
                      ),
                      label: Text(_label(state, c)),
                      selected: c == _category,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: c == _category ? Colors.white : AppColors.title,
                      ),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (state.isLoading)
            ...List.generate(4, (_) => const _NotificationSkeleton())
          else if (state.error != null)
            ErrorBanner(
              message: state.error!,
              onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
            )
          else if (items.isEmpty)
            EmptyStateView(
              icon: Icons.notifications_off_outlined,
              title: 'Chưa có thông báo',
              message:
                  'Thông báo về ${_category.label.toLowerCase()} sẽ xuất hiện ở đây',
            )
          else ...[
            for (final n in items)
              _NotificationTile(item: n, onTap: () => _open(n)),
            if (state.hasNext)
              Center(
                child: TextButton(
                  onPressed: state.isLoadingMore
                      ? null
                      : () =>
                            ref.read(notificationsProvider.notifier).loadMore(),
                  child: Text(state.isLoadingMore ? 'Đang tải…' : 'Xem thêm'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _label(NotificationsState state, NotificationCategory c) {
    final unread = state.of(c).where((n) => !n.read).length;
    return unread > 0 ? '${c.label} ($unread)' : c.label;
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = item.visual;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: item.read ? Colors.white : const Color(0xFFFFF6F4),
          border: const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: visual.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(visual.icon, color: visual.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.title,
                      fontWeight: item.read ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.body),
                  ),
                  if (item.createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        formatRelative(item.createdAt!),
                        style: const TextStyle(
                          color: AppColors.caption,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!item.read)
              Semantics(
                label: 'Chưa đọc',
                child: Container(
                  margin: const EdgeInsets.only(left: 8, top: 6),
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    child: Row(
      children: [
        Skeleton(width: 48, height: 48),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 180, height: 14),
              SizedBox(height: 8),
              Skeleton(height: 12),
            ],
          ),
        ),
      ],
    ),
  );
}
