import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shipper_orders_provider.dart';
import '../widgets/shipper_order_card.dart';
import '../widgets/shipper_order_widgets.dart';
import 'shipper_order_detail_screen.dart';
import 'shipper_cod_screen.dart';

class ShipperOrdersScreen extends ConsumerStatefulWidget {
  const ShipperOrdersScreen({super.key});
  @override
  ConsumerState<ShipperOrdersScreen> createState() =>
      _ShipperOrdersScreenState();
}

class _ShipperOrdersScreenState extends ConsumerState<ShipperOrdersScreen> {
  int _tab = 0;
  Future<void> _refresh() async {
    final provider = switch (_tab) {
      1 => myShipperDeliveriesProvider,
      2 => shipperDeliveryHistoryProvider,
      _ => availableShipperOrdersProvider,
    };
    ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } catch (_) {
      /* Giao diện sẽ hiển thị lỗi và nút thử lại. */
    }
  }

  Future<void> _openDetail(int id) async {
    ref.invalidate(shipperOrderDetailProvider(id));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ShipperOrderDetailScreen(orderId: id),
      ),
    );
    if (!mounted) return;
    ref.invalidate(availableShipperOrdersProvider);
    ref.invalidate(myShipperDeliveriesProvider);
    ref.invalidate(shipperDeliveryHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(switch (_tab) {
      1 => myShipperDeliveriesProvider,
      2 => shipperDeliveryHistoryProvider,
      _ => availableShipperOrdersProvider,
    });
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(switch (_tab) {
            1 => 'Đơn đang giao',
            2 => 'Lịch sử giao hàng',
            _ => 'Đơn chờ nhận',
          }),
          actions: [
            IconButton(
              tooltip: 'Tiền thu hộ COD',
              icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const ShipperCodScreen(),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Làm mới',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            onTap: (index) {
              setState(() => _tab = index);
              _refresh();
            },
            tabs: const [
              Tab(text: 'Chờ nhận'),
              Tab(text: 'Đang giao'),
              Tab(text: 'Đã giao'),
            ],
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: orders.when(
                skipLoadingOnRefresh: false,
                loading: () =>
                    _message(const Center(child: CircularProgressIndicator())),
                error: (error, stack) => _message(
                  Center(
                    child: ShipperErrorView(error: error, onRetry: _refresh),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? _message(
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(switch (_tab) {
                                  1 => 'Bạn chưa có đơn đang giao.',
                                  2 => 'Chưa có lịch sử giao hàng.',
                                  _ => 'Chưa có đơn chờ nhận.',
                                }, textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) => ShipperOrderCard(
                          key: ValueKey(items[index].id),
                          order: items[index],
                          allowAssign: _tab == 0,
                          onTap: () => _openDetail(items[index].id),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(Widget child) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [SizedBox(height: constraints.maxHeight, child: child)],
    ),
  );
}
