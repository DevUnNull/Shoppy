import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/content_container.dart';
import '../../../core/widgets/shoppy_logo.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../orders/models/order.dart';
import '../../orders/providers/order_providers.dart';
import '../../wallet/widgets/deposit_dialog.dart';
import '../models/checkout_models.dart';
import '../providers/address_provider.dart';
import '../providers/checkout_controller.dart';
import '../widgets/address_card.dart';
import '../widgets/shop_group_card.dart';

/// Trang thanh toán. [items]: các dòng sản phẩm cần mua (từ giỏ hoặc "Mua ngay").
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.items});

  final List<CartItem> items;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late List<ShopGroup> _groups = ShopGroup.fromItems(widget.items);
  final _shippingByShop = <int, int>{};
  final _notes = <int, TextEditingController>{};
  PaymentMethod _payment = PaymentMethod.cod;
  bool _submitting = false;
  String? _errorField;

  @override
  void initState() {
    super.initState();
    // Làm mới số dư ví để kiểm tra thanh toán bằng ví chính xác.
    Future.microtask(() {
      if (mounted) ref.read(authProvider.notifier).refreshProfile().ignore();
    });
  }

  @override
  void dispose() {
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _noteFor(int shopId) =>
      _notes.putIfAbsent(shopId, TextEditingController.new);

  Future<void> _editAddress(DeliveryAddress? current) async {
    final result = await showAddressDialog(context, current);
    if (result == null) return;
    await ref.read(addressProvider.notifier).save(result);
    if (mounted) setState(() => _errorField = null);
  }

  Future<void> _placeOrder(CheckoutTotals totals) async {
    final address = ref.read(addressProvider).value;
    final balance = ref.read(authProvider).user?.balance ?? 0;
    final List<(ShopGroup, CreateOrderRequest)> requests;
    try {
      requests = buildOrderRequests(
        groups: _groups,
        address: address,
        shippingByShop: _shippingByShop,
        notes: {for (final e in _notes.entries) e.key: e.value.text},
        payment: _payment,
        walletBalance: balance,
        total: totals.total,
      );
    } on CheckoutValidationError catch (e) {
      if (!mounted) return;
      setState(() => _errorField = e.field);
      AppToast.error(context, e.message);
      if (e.field == 'address') await _editAddress(address);
      return;
    }

    setState(() {
      _submitting = true;
      _errorField = null;
    });
    final result = await submitOrders(ref.read(orderServiceProvider), requests);
    if (!mounted) return;

    // Gỡ các sản phẩm đã đặt thành công khỏi giỏ.
    final cart = ref.read(cartProvider.notifier);
    for (final g in result.placedGroups) {
      for (final item in g.items) {
        cart.remove(item.key);
      }
    }
    if (result.placedGroups.isNotEmpty) {
      ref.invalidate(myOrdersProvider);
      if (_payment == PaymentMethod.wallet) {
        ref.read(authProvider.notifier).refreshProfile().ignore();
      }
    }

    if (result.isComplete) {
      AppToast.success(
        context,
        result.placedGroups.length > 1
            ? 'Đặt ${result.placedGroups.length} đơn hàng thành công!'
            : 'Đặt hàng thành công!',
      );
      AppRouter.ordersAfterCheckout(context);
      return;
    }

    setState(() {
      _submitting = false;
      _groups = _groups.where((g) => !result.placedGroups.contains(g)).toList();
    });
    AppToast.error(
      context,
      result.placedGroups.isEmpty
          ? result.error.toString()
          : 'Đã đặt ${result.placedGroups.length} đơn. Đơn còn lại lỗi: ${result.error}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final companiesAsync = ref.watch(shippingCompaniesProvider);
    final companies = companiesAsync.value ?? const [];
    final addressAsync = ref.watch(addressProvider);
    final balance = ref.watch(authProvider.select((s) => s.user?.balance)) ?? 0;

    // Chọn sẵn ĐVVC đầu tiên cho mỗi shop khi danh sách đã tải.
    if (companies.isNotEmpty) {
      for (final g in _groups) {
        _shippingByShop.putIfAbsent(g.shopId, () => companies.first.id);
      }
    }
    final totals = CheckoutTotals.of(_groups, _shippingByShop, companies);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

    return Scaffold(
      body: Column(
        children: [
          const _CheckoutHeader(),
          Expanded(
            child: _groups.isEmpty
                ? EmptyStateView(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Không có sản phẩm để thanh toán',
                    actionLabel: 'Tiếp tục mua sắm',
                    onAction: () => AppRouter.backToHome(context),
                  )
                : SingleChildScrollView(
                    child: ContentContainer(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AddressCard(
                            address: addressAsync.value,
                            highlightError: _errorField == 'address',
                            onChange: () => _editAddress(addressAsync.value),
                          ),
                          const SizedBox(height: 12),
                          if (wide) const _ColumnHeader(),
                          for (final g in _groups)
                            ShopGroupCard(
                              group: g,
                              note: _noteFor(g.shopId),
                              companies: companies,
                              selectedCompanyId: _shippingByShop[g.shopId],
                              companiesLoading: companiesAsync.isLoading,
                              companiesError: companiesAsync.hasError
                                  ? 'Không tải được đơn vị vận chuyển'
                                  : null,
                              onRetryCompanies: () =>
                                  ref.invalidate(shippingCompaniesProvider),
                              onCompanyChanged: (id) => setState(
                                () => _shippingByShop[g.shopId] = id,
                              ),
                            ),
                          _PaymentCard(
                            method: _payment,
                            balance: balance,
                            total: totals.total,
                            highlight: _errorField == 'wallet',
                            onChanged: (m) => setState(() {
                              _payment = m;
                              _errorField = null;
                            }),
                            onTopUp: (shortage) =>
                                showDepositDialog(context, suggested: shortage),
                          ),
                          _SummaryCard(
                            totals: totals,
                            submitting: _submitting,
                            onSubmit: () => _placeOrder(totals),
                          ),
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

class _CheckoutHeader extends StatelessWidget {
  const _CheckoutHeader();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black26,
      child: SafeArea(
        bottom: false,
        child: ContentContainer(
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                ),
                InkWell(
                  onTap: () => AppRouter.backToHome(context),
                  child: const ShoppyLogo.brand(size: 24),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.primary,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),
                const Flexible(
                  child: Text(
                    'Thanh Toán',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.primary, fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppColors.caption);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
      child: const Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              'Sản phẩm',
              style: TextStyle(fontSize: 18, color: AppColors.title),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('Đơn giá', textAlign: TextAlign.right, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text('Số lượng', textAlign: TextAlign.right, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text('Thành tiền', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.method,
    required this.balance,
    required this.total,
    required this.highlight,
    required this.onChanged,
    required this.onTopUp,
  });

  final PaymentMethod method;
  final double balance;
  final double total;
  final bool highlight;
  final ValueChanged<PaymentMethod> onChanged;
  final ValueChanged<int> onTopUp;

  @override
  Widget build(BuildContext context) {
    final shortage = (total - balance).ceil();
    final insufficient = method == PaymentMethod.wallet && shortage > 0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const Text(
                'Phương thức thanh toán',
                style: TextStyle(fontSize: 18, color: AppColors.title),
              ),
              const SizedBox(width: 20),
              for (final m in PaymentMethod.values)
                _MethodPill(
                  label: m == PaymentMethod.cod
                      ? 'Thanh toán khi nhận hàng'
                      : 'Ví Shoppy',
                  icon: m == PaymentMethod.cod
                      ? Icons.local_shipping_outlined
                      : Icons.account_balance_wallet_outlined,
                  selected: m == method,
                  onTap: () => onChanged(m),
                ),
            ],
          ),
          if (method == PaymentMethod.wallet) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: insufficient
                    ? const Color(0xFFFFF5F5)
                    : const Color(0xFFF2FBF9),
                border: Border.all(
                  color: insufficient || highlight
                      ? AppColors.primary
                      : AppColors.success,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Số dư Ví Shoppy khả dụng: '),
                        TextSpan(
                          text: formatVnd(balance),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (insufficient) ...[
                    Text(
                      'Số dư không đủ, cần nạp thêm ${formatVnd(shortage)}',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                    TextButton.icon(
                      onPressed: () => onTopUp(shortage),
                      icon: const Icon(Icons.bolt, size: 18),
                      label: const Text('Nạp tiền ngay'),
                    ),
                  ] else
                    const Text(
                      '✓ Đủ để thanh toán đơn hàng',
                      style: TextStyle(color: AppColors.success),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MethodPill extends StatelessWidget {
  const _MethodPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.body,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.title,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check, size: 16, color: AppColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totals,
    required this.submitting,
    required this.onSubmit,
  });

  final CheckoutTotals totals;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool big = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.caption),
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120),
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: big
                  ? const TextStyle(
                      color: AppColors.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    )
                  : const TextStyle(color: AppColors.title),
            ),
          ),
        ],
      ),
    );

    return Container(
      color: const Color(0xFFFFFEFB),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          row('Tổng tiền hàng', formatVnd(totals.merchandise)),
          row('Tổng phí vận chuyển', formatVnd(totals.shipping)),
          row('Giảm giá', '-${formatVnd(totals.discount)}'),
          row('Tổng thanh toán', formatVnd(totals.total), big: true),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              const Text(
                'Nhấn "Đặt hàng" đồng nghĩa với việc bạn đồng ý tuân theo Điều khoản Shoppy',
                style: TextStyle(color: AppColors.caption, fontSize: 13),
              ),
              SizedBox(
                width: 210,
                height: 44,
                child: FilledButton(
                  onPressed: submitting ? null : onSubmit,
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Đặt hàng'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
