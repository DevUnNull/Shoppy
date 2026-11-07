import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/skeleton.dart';
import '../models/shop.dart';
import 'shop_avatar.dart';

/// Header shop kiểu Shopee: khối tối có avatar/tên/nút + lưới chỉ số.
class ShopHeaderCard extends StatelessWidget {
  const ShopHeaderCard({
    super.key,
    required this.shop,
    required this.isFollowing,
    required this.onFollow,
    required this.onChat,
  });

  final Shop shop;
  final bool isFollowing;
  final VoidCallback onFollow;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    final identity = Container(
      width: wide ? 370 : double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2B2B), Color(0xFF555555)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ShopAvatar(url: shop.logoUrl, name: shop.name, size: 76),
                  if (shop.name.toLowerCase().contains('official'))
                    Positioned(
                      bottom: -6,
                      left: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD0011B),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          'Mall',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shop.isActive ? 'Đang hoạt động' : 'Tạm nghỉ',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GhostButton(
                  icon: isFollowing ? Icons.check : Icons.add,
                  label: isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                  onTap: onFollow,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GhostButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat ngay',
                  onTap: onChat,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final stats = Wrap(
      runSpacing: 18,
      children: [
        _stat(
          Icons.storefront_outlined,
          'Sản phẩm',
          shop.productCount?.toString(),
        ),
        _stat(
          Icons.chat_outlined,
          'Tỉ lệ phản hồi',
          shop.responseRate == null ? null : '${shop.responseRate!.round()}%',
        ),
        _stat(
          Icons.person_add_alt,
          'Tham gia',
          shop.createdAt == null ? null : formatJoinedAgo(shop.createdAt!),
        ),
        _stat(
          Icons.people_outline,
          'Người theo dõi',
          shop.followerCount?.toString(),
        ),
        _stat(Icons.star_border, 'Đánh giá', shop.rating?.toStringAsFixed(1)),
      ],
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: wide
          ? Row(
              children: [
                identity,
                const SizedBox(width: 32),
                Expanded(child: stats),
              ],
            )
          : Column(children: [identity, const SizedBox(height: 18), stats]),
    );
  }

  Widget _stat(IconData icon, String label, String? value) => SizedBox(
    width: 260,
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.title),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: AppColors.title)),
        Text(value ?? '—', style: const TextStyle(color: AppColors.primary)),
      ],
    ),
  );
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        side: const BorderSide(color: Colors.white),
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class ShopHeaderSkeleton extends StatelessWidget {
  const ShopHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: const Row(
        children: [
          Expanded(child: Skeleton(height: 150, radius: 4)),
          SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 220, height: 16),
                SizedBox(height: 16),
                Skeleton(width: 220, height: 16),
                SizedBox(height: 16),
                Skeleton(width: 220, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
