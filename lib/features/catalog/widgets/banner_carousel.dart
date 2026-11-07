import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';

class PromoBanner {
  const PromoBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
}

/// Banner sự kiện tự vẽ (backend chưa có API banner).
const promoBanners = [
  PromoBanner(
    title: 'SIÊU SALE 11.11',
    subtitle: 'Voucher giảm đến 50% · Freeship toàn quốc',
    icon: Icons.local_fire_department,
    colors: [Color(0xFFEE4D2D), Color(0xFFFF7337)],
  ),
  PromoBanner(
    title: 'SHOPPY MALL',
    subtitle: 'Hàng chính hãng 100% · Đổi trả miễn phí 15 ngày',
    icon: Icons.verified,
    colors: [Color(0xFFD0011B), Color(0xFFF2486B)],
  ),
  PromoBanner(
    title: 'ĐIỆN TỬ GIÁ SỐC',
    subtitle: 'Điện thoại, laptop, phụ kiện giảm sâu mỗi ngày',
    icon: Icons.devices,
    colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
  ),
  PromoBanner(
    title: 'THỜI TRANG XU HƯỚNG',
    subtitle: 'Bộ sưu tập mới · Mua 2 giảm thêm 10%',
    icon: Icons.checkroom,
    colors: [Color(0xFF8E2DE2), Color(0xFFDA22FF)],
  ),
];

/// Carousel chính giữa trang chủ + 2 banner phụ bên phải (desktop).
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, this.banners = promoBanners});

  final List<PromoBanner> banners;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _go(_index + 1));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (!_controller.hasClients || widget.banners.isEmpty) return;
    _controller.animateToPage(
      index % widget.banners.length,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.desktop;
        final height = wide
            ? 235.0
            : (constraints.maxWidth * 0.36).clamp(130.0, 235.0);
        final slider = SizedBox(
          height: height,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.banners.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) =>
                    _BannerTile(banner: widget.banners[i], large: true),
              ),
              if (wide) ...[
                _arrow(
                  Alignment.centerLeft,
                  Icons.chevron_left,
                  () => _go(_index - 1 + widget.banners.length),
                ),
                _arrow(
                  Alignment.centerRight,
                  Icons.chevron_right,
                  () => _go(_index + 1),
                ),
              ],
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.banners.length; i++)
                      GestureDetector(
                        onTap: () => _go(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _index
                                ? AppColors.primary
                                : Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
        if (!wide) return slider;
        return Row(
          children: [
            Expanded(flex: 2, child: slider),
            const SizedBox(width: 5),
            Expanded(
              child: SizedBox(
                height: height,
                child: Column(
                  children: [
                    Expanded(
                      child: _BannerTile(
                        banner: widget.banners[1 % widget.banners.length],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: _BannerTile(
                        banner: widget.banners[2 % widget.banners.length],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _arrow(Alignment alignment, IconData icon, VoidCallback onTap) =>
      Align(
        alignment: alignment,
        child: Material(
          color: Colors.black26,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 34,
              height: 60,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
      );
}

class _BannerTile extends StatelessWidget {
  const _BannerTile({required this.banner, this.large = false});

  final PromoBanner banner;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(colors: banner.colors),
      ),
      padding: EdgeInsets.symmetric(horizontal: large ? 32 : 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    banner.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: large ? 32 : 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  banner.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: large ? 15 : 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(banner.icon, color: Colors.white24, size: large ? 120 : 48),
        ],
      ),
    );
  }
}
