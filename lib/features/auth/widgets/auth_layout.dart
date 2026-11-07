import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/shoppy_logo.dart';

/// Layout Auth: header tối giản (logo + tiêu đề), body 2 cột
/// (banner quảng bá bên trái, form card trắng bên phải).
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= Breakpoints.desktop;
    final compact = width < Breakpoints.tablet;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Material(
            color: Colors.white,
            elevation: 1,
            shadowColor: Colors.black26,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Breakpoints.maxContentWidth,
                  ),
                  child: SizedBox(
                    height: compact ? 64 : 84,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          if (Navigator.of(context).canPop())
                            IconButton(
                              tooltip: 'Quay lại',
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(
                                Icons.arrow_back,
                                color: AppColors.primary,
                              ),
                            ),
                          InkWell(
                            onTap: () => AppRouter.backToHome(context),
                            child: ShoppyLogo.brand(size: compact ? 22 : 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: compact ? 18 : 24,
                                color: AppColors.title,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!compact)
                            const Text(
                              'Bạn cần giúp đỡ?',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: AppColors.primary,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 24,
                  vertical: compact ? 20 : 48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: wide
                        ? Row(
                            children: [
                              const Expanded(child: _PromoPanel()),
                              const SizedBox(width: 48),
                              SizedBox(
                                width: 400,
                                child: _FormCard(child: child),
                              ),
                            ],
                          )
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: _FormCard(child: child),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 8),
        ],
      ),
      child: child,
    );
  }
}

class _PromoPanel extends StatelessWidget {
  const _PromoPanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.shopping_bag, color: Colors.white, size: 160),
        SizedBox(height: 8),
        Text(
          'Shoppy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 64,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Mua sắm thả ga, giá tốt mỗi ngày\nFreeship · Hoàn tiền · Hàng chính hãng',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 20, height: 1.5),
        ),
      ],
    );
  }
}

/// Tiêu đề + đường kẻ "HOẶC" dùng trong các form auth.
class AuthFormTitle extends StatelessWidget {
  const AuthFormTitle(this.text, {super.key, this.leading});

  final String text;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          ?leading,
          Expanded(
            child: Text(
              text,
              textAlign: leading == null ? TextAlign.start : TextAlign.center,
              style: const TextStyle(fontSize: 20, color: AppColors.title),
            ),
          ),
          if (leading != null) const SizedBox(width: 40),
        ],
      ),
    );
  }
}
