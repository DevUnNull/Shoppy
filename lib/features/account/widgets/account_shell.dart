import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/content_container.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/widgets/shoppy_header.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/providers/notification_providers.dart';

enum AccountSection {
  profile('Hồ sơ', Icons.person_outline),
  password('Đổi mật khẩu', Icons.lock_outline),
  orders('Đơn mua', Icons.receipt_long_outlined),
  wallet('Ví Shoppy', Icons.account_balance_wallet_outlined),
  notifications('Thông báo', Icons.notifications_none),
  partner('Đăng ký Shop / Shipper', Icons.storefront_outlined);

  const AccountSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Layout trang tài khoản kiểu Shopee: sidebar trái (avatar + menu dọc),
/// content card trắng bên phải. Mobile: thanh chọn mục cuộn ngang.
class AccountShell extends ConsumerWidget {
  const AccountShell({
    super.key,
    required this.section,
    required this.child,
    this.padded = true,
  });

  final AccountSection section;
  final Widget child;

  /// false: con tự vẽ các card riêng (vd. danh sách đơn mua).
  final bool padded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

    final Widget content = switch (auth.status) {
      AuthStatus.restoring => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      AuthStatus.guest => Container(
        color: Colors.white,
        child: EmptyStateView(
          icon: Icons.lock_person_outlined,
          title: 'Vui lòng đăng nhập',
          message: 'Bạn cần đăng nhập để xem ${section.label.toLowerCase()}',
          actionLabel: 'Đăng nhập',
          onAction: () => AppRouter.login(context),
        ),
      ),
      AuthStatus.authenticated =>
        padded
            ? Container(
                width: double.infinity,
                padding: EdgeInsets.all(wide ? 24 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: child,
              )
            : child,
    };

    return Scaffold(
      body: Column(
        children: [
          const ShoppyHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: ContentContainer(
                padding: EdgeInsets.fromLTRB(12, wide ? 20 : 8, 12, 40),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 200,
                            child: _Sidebar(section: section, user: auth.user),
                          ),
                          const SizedBox(width: 24),
                          Expanded(child: content),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MobileSectionBar(section: section),
                          const SizedBox(height: 8),
                          content,
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.section, required this.user});

  final AccountSection section;
  final User? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final u = user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.border,
                backgroundImage: u?.avatarUrl == null
                    ? null
                    : NetworkImage(u!.avatarUrl!),
                child: u?.avatarUrl == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u?.displayName ?? 'Khách',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.title,
                      ),
                    ),
                    InkWell(
                      onTap: () => AppRouter.account(
                        context,
                        AccountSection.profile,
                        replace: true,
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.edit, size: 13, color: AppColors.caption),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Sửa hồ sơ',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppColors.caption),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 16),
        _group(
          context,
          icon: Icons.person_outline,
          label: 'Tài khoản của tôi',
          color: const Color(0xFF0046AB),
          children: [AccountSection.profile, AccountSection.password],
        ),
        for (final s in [
          AccountSection.orders,
          AccountSection.wallet,
          AccountSection.notifications,
          AccountSection.partner,
        ])
          _item(
            context,
            s,
            badge: s == AccountSection.notifications ? unread : 0,
          ),
      ],
    );
  }

  Widget _group(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required List<AccountSection> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(icon: icon, iconColor: color, label: label, selected: false),
        for (final s in children)
          InkWell(
            onTap: s == section
                ? null
                : () => AppRouter.account(context, s, replace: true),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(34, 6, 0, 6),
              child: Text(
                s.label,
                style: TextStyle(
                  color: s == section ? AppColors.primary : AppColors.body,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _item(BuildContext context, AccountSection s, {int badge = 0}) {
    return InkWell(
      onTap: s == section
          ? null
          : () => AppRouter.account(context, s, replace: true),
      child: _row(
        icon: s.icon,
        iconColor: AppColors.primary,
        label: s.label,
        selected: s == section,
        badge: badge,
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool selected,
    int badge = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.title,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (badge > 0) ...[
            const SizedBox(width: 6),
            _CountBadge(count: badge),
          ],
        ],
      ),
    );
  }
}

class _MobileSectionBar extends StatefulWidget {
  const _MobileSectionBar({required this.section});

  final AccountSection section;

  @override
  State<_MobileSectionBar> createState() => _MobileSectionBarState();
}

class _MobileSectionBarState extends State<_MobileSectionBar> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Cuộn chip của mục đang mở vào khung nhìn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selectedKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.5, duration: Duration.zero);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    // SingleChildScrollView (không lazy) để chip ở cuối vẫn có context
    // cho ensureVisible.
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final s in AccountSection.values)
              Padding(
                key: s == section ? _selectedKey : null,
                padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                child: ChoiceChip(
                  label: Text(s.label),
                  avatar: Icon(
                    s.icon,
                    size: 16,
                    color: s == section ? Colors.white : AppColors.primary,
                  ),
                  selected: s == section,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: s == section ? Colors.white : AppColors.title,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onSelected: (_) {
                    if (s != section) {
                      AppRouter.account(context, s, replace: true);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

/// Tiêu đề trang trong content card ("Hồ Sơ Của Tôi" + mô tả + divider).
class AccountPageHeader extends StatelessWidget {
  const AccountPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.title,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(color: AppColors.body),
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const Divider(height: 32),
      ],
    );
  }
}
