import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/shop_service.dart';
import '../widgets/shop_details_card.dart';
import '../widgets/shop_identity_card.dart';
import '../widgets/shop_summary_card.dart';

class MyShopScreen extends StatefulWidget {
  const MyShopScreen({
    super.key,
    required this.repository,
    this.showAppBar = true,
  });

  final ShopRepository repository;
  final bool showAppBar;

  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen> {
  late final ShopRepository _repository;
  Shop? _shop;
  Object? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _loadShop();
  }

  Future<void> _loadShop() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final shop = await _repository.getMyShop();
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Shop của tôi'),
              actions: [
                IconButton(
                  tooltip: 'Tải lại',
                  onPressed: _isLoading ? null : _loadShop,
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tải thông tin shop...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return _ShopLoadError(error: _error!, onRetry: _loadShop);
    }

    final shop = _shop;
    if (shop == null) {
      return _ShopLoadError(
        error: StateError('Không tìm thấy thông tin shop.'),
        onRetry: _loadShop,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadShop,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShopIdentityCard(shop: shop),
                  const SizedBox(height: 16),
                  ShopSummaryCard(shop: shop),
                  const SizedBox(height: 16),
                  ShopDetailsCard(shop: shop),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopLoadError extends StatelessWidget {
  const _ShopLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error.toString();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
