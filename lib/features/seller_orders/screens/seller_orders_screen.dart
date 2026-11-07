import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/seller_order.dart';
import '../models/seller_order_status.dart';
import '../providers/seller_orders_provider.dart';
import '../widgets/order_error_view.dart';
import '../widgets/seller_order_card.dart';
import 'seller_order_detail_screen.dart';

class SellerOrdersScreen extends ConsumerStatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  ConsumerState<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends ConsumerState<SellerOrdersScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNeeded);
    Future.microtask(() {
      if (mounted) ref.read(sellerOrdersProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMoreIfNeeded() {
    if (!mounted || !_scrollController.hasClients) return;
    final state = ref.read(sellerOrdersProvider);
    if (_scrollController.position.extentAfter < 240 &&
        state.loadMoreError.isEmpty) {
      ref.read(sellerOrdersProvider.notifier).loadMore();
    }
  }

  void _selectTab(int index) {
    final status = SellerOrderStatus.values[index];
    if (status == ref.read(sellerOrdersProvider).status) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    ref.read(sellerOrdersProvider.notifier).selectStatus(status);
  }

  Future<void> _openDetail(SellerOrder order) async {
    // Buộc tải lại chi tiết, tránh mở dữ liệu cũ nếu đơn vừa đổi trạng thái.
    ref.invalidate(sellerOrderDetailProvider(order.id));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SellerOrderDetailScreen(orderId: order.id),
      ),
    );
    if (mounted) await ref.read(sellerOrdersProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerOrdersProvider);
    // Nếu trang đầu quá ngắn để cuộn, tự tải tiếp cho đến khi đầy màn hình.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMoreIfNeeded());

    return DefaultTabController(
      length: SellerOrderStatus.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đơn hàng Shop'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey.shade700,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            indicatorWeight: 3,
            onTap: _selectTab,
            tabs: SellerOrderStatus.values
                .map((status) => Tab(text: status.label))
                .toList(),
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(sellerOrdersProvider.notifier).refresh(),
              child: _buildList(state),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(SellerOrdersState state) {
    if (state.isLoading || state.error.isNotEmpty || state.orders.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: state.isLoading
                    ? const CircularProgressIndicator()
                    : state.error.isNotEmpty
                    ? OrderErrorView(
                        message: state.error,
                        onRetry: () =>
                            ref.read(sellerOrdersProvider.notifier).refresh(),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Chưa có đơn ${state.status.label.toLowerCase()}.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (state.isLoadingMore)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          if (state.loadMoreError.isNotEmpty)
                            OrderErrorView(
                              message: state.loadMoreError,
                              onRetry: () => ref
                                  .read(sellerOrdersProvider.notifier)
                                  .loadMore(),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: state.orders.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index < state.orders.length) {
          final order = state.orders[index];
          return SellerOrderCard(
            key: ValueKey(order.id),
            order: order,
            onTap: () => _openDetail(order),
          );
        }
        if (state.isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.loadMoreError.isNotEmpty) {
          return OrderErrorView(
            message: state.loadMoreError,
            onRetry: () => ref.read(sellerOrdersProvider.notifier).loadMore(),
          );
        }
        if (state.hasNext) {
          return TextButton(
            onPressed: () => ref.read(sellerOrdersProvider.notifier).loadMore(),
            child: const Text('Tải thêm'),
          );
        }
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Đã hiển thị tất cả đơn hàng')),
        );
      },
    );
  }
}
