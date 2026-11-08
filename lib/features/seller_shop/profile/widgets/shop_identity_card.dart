import 'package:flutter/material.dart';

import '../models/shop.dart';

class ShopIdentityCard extends StatelessWidget {
  const ShopIdentityCard({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          _ShopLogo(url: shop.logoUrl),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Shop #${shop.id}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopLogo extends StatelessWidget {
  const _ShopLogo({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final validUrl = Uri.tryParse(url ?? '');
    final hasImage =
        validUrl != null &&
        (validUrl.scheme == 'https' || validUrl.scheme == 'http') &&
        validUrl.host.isNotEmpty;

    return CircleAvatar(
      radius: 36,
      backgroundColor: Colors.white,
      foregroundImage: hasImage ? NetworkImage(url!) : null,
      onForegroundImageError: hasImage ? (_, _) {} : null,
      child: Icon(
        Icons.storefront,
        size: 34,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
