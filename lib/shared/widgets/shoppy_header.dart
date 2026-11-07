import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/breakpoints.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/content_container.dart';
import '../../core/widgets/shoppy_logo.dart';
import '../../core/widgets/skeleton.dart';
import '../../features/account/widgets/account_shell.dart';
import '../../features/auth/models/user.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/cart/providers/cart_provider.dart';
import '../../features/catalog/providers/product_list_provider.dart';
import '../../features/notifications/providers/notification_providers.dart';
import 'cart_sheet.dart';

/// Header cam kiểu Shopee: logo, thanh tìm kiếm lớn + gợi ý trending,
/// icon giỏ hàng và khu vực tài khoản.
class ShoppyHeader extends ConsumerStatefulWidget {
  const ShoppyHeader({
    super.key,
    this.initialQuery = '',
    this.replaceOnSearch = false,
    this.showBack,
  });

  final String initialQuery;

  /// true khi đang ở trang kết quả tìm kiếm (thay vì chồng thêm trang mới).
  final bool replaceOnSearch;

  /// Hiện nút quay lại; mặc định tự nhận biết theo Navigator.
  final bool? showBack;

  @override
  ConsumerState<ShoppyHeader> createState() => _ShoppyHeaderState();
}

class _ShoppyHeaderState extends ConsumerState<ShoppyHeader> {
  late final _controller = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search([String? value]) {
    final keyword = (value ?? _controller.text).trim();
    if (keyword.isEmpty) {
      AppToast.info(context, 'Vui lòng nhập từ khoá tìm kiếm');
      return;
    }
    _controller.text = keyword;
    FocusScope.of(context).unfocus();
    AppRouter.search(context, keyword, replace: widget.replaceOnSearch);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < Breakpoints.tablet;
    final canPop = widget.showBack ?? Navigator.of(context).canPop();
    final trending = ref.watch(trendingKeywordsProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF53D2D), Color(0xFFFF6633)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ContentContainer(
          padding: EdgeInsets.fromLTRB(
            compact ? 4 : 12,
            8,
            compact ? 4 : 12,
            10,
          ),
          child: Column(
            children: [
              if (!compact)
                Align(alignment: Alignment.centerRight, child: _AccountArea()),
              Row(
                children: [
                  if (canPop)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Quay lại',
                    ),
                  if (!compact || !canPop)
                    InkWell(
                      onTap: () => AppRouter.backToHome(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ShoppyLogo(size: compact ? 20 : 30),
                      ),
                    ),
                  SizedBox(width: compact ? 4 : 24),
                  Expanded(child: _searchBox()),
                  SizedBox(width: compact ? 0 : 16),
                  const _BellButton(),
                  const _CartButton(),
                  if (compact) _AccountArea(compact: true),
                ],
              ),
              if (!compact)
                Padding(
                  padding: EdgeInsets.only(
                    left: (canPop ? 48 : 0) + 170,
                    right: 64,
                    top: 6,
                  ),
                  child: SizedBox(
                    height: 18,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: trending.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) => InkWell(
                        onTap: () => _search(trending[index]),
                        child: Text(
                          trending[index],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBox() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              style: const TextStyle(fontSize: 14, color: AppColors.title),
              decoration: const InputDecoration(
                hintText: 'Tìm sản phẩm, thương hiệu, và tên shop',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 60,
            height: double.infinity,
            child: FilledButton(
              onPressed: _search,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
              ),
              child: const Icon(Icons.search, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _BellButton extends ConsumerWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(authProvider.select((s) => s.isLoggedIn))) {
      return const SizedBox.shrink();
    }
    final count = ref.watch(unreadCountProvider).value ?? 0;
    return IconButton(
      tooltip: 'Thông báo',
      onPressed: () => AppRouter.account(context, AccountSection.notifications),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: Colors.white,
        textColor: AppColors.primary,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(
          Icons.notifications_none,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

class _CartButton extends ConsumerWidget {
  const _CartButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    return IconButton(
      tooltip: 'Giỏ hàng',
      onPressed: () => showCartSheet(context),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: Colors.white,
        textColor: AppColors.primary,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(
          Icons.shopping_cart_outlined,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

class _AccountArea extends ConsumerWidget {
  const _AccountArea({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    const linkStyle = TextStyle(color: Colors.white, fontSize: 13);

    switch (auth.status) {
      case AuthStatus.restoring:
        return const Padding(
          padding: EdgeInsets.all(8),
          child: Skeleton(width: 80, height: 16),
        );
      case AuthStatus.guest:
        if (compact) {
          return IconButton(
            tooltip: 'Đăng nhập',
            onPressed: () => AppRouter.login(context),
            icon: const Icon(Icons.person_outline, color: Colors.white),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => AppRouter.register(context),
              child: const Text('Đăng ký', style: linkStyle),
            ),
            Container(width: 1, height: 12, color: Colors.white54),
            TextButton(
              onPressed: () => AppRouter.login(context),
              child: const Text('Đăng nhập', style: linkStyle),
            ),
          ],
        );
      case AuthStatus.authenticated:
        return _UserMenu(user: auth.user!, compact: compact);
    }
  }
}

class _UserMenu extends ConsumerWidget {
  const _UserMenu({required this.user, required this.compact});

  final User user;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = CircleAvatar(
      radius: 12,
      backgroundColor: Colors.white,
      backgroundImage: user.avatarUrl == null
          ? null
          : NetworkImage(user.avatarUrl!),
      child: user.avatarUrl == null
          ? Text(
              user.displayName.characters.first.toUpperCase(),
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
            )
          : null,
    );
    return PopupMenuButton<String>(
      tooltip: 'Tài khoản',
      position: PopupMenuPosition.under,
      onSelected: (value) async {
        switch (value) {
          case 'seller':
            AppRouter.sellerChannel(context);
          case 'logout':
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) AppToast.success(context, 'Đã đăng xuất');
          default:
            final section = AccountSection.values.byName(value);
            AppRouter.account(context, section);
        }
      },
      itemBuilder: (_) => [
        for (final s in [
          AccountSection.profile,
          AccountSection.orders,
          AccountSection.wallet,
          AccountSection.notifications,
          AccountSection.partner,
        ])
          PopupMenuItem(
            value: s.name,
            child: Row(
              children: [
                Icon(s.icon, size: 18, color: AppColors.body),
                const SizedBox(width: 10),
                Text(
                  s == AccountSection.profile ? 'Tài khoản của tôi' : s.label,
                ),
              ],
            ),
          ),
        if (user.isSeller)
          const PopupMenuItem(
            value: 'seller',
            child: Row(
              children: [
                Icon(
                  Icons.store_mall_directory_outlined,
                  size: 18,
                  color: AppColors.body,
                ),
                SizedBox(width: 10),
                Text('Kênh người bán'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: AppColors.body),
              SizedBox(width: 10),
              Text('Đăng xuất'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar,
            if (!compact) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  user.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
