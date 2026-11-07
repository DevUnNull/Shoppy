import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/content_container.dart';
import '../../../core/widgets/skeleton.dart';
import '../providers/catalog_providers.dart';

const _icons = <IconData>[
  Icons.devices_other,
  Icons.checkroom,
  Icons.home_outlined,
  Icons.spa_outlined,
  Icons.sports_soccer,
  Icons.child_care,
  Icons.menu_book,
  Icons.local_grocery_store_outlined,
  Icons.pets,
  Icons.directions_car_outlined,
];

/// Khối "DANH MỤC" trên trang chủ — bấm để mở Category Browser.
class CategoryStrip extends ConsumerWidget {
  const CategoryStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(categoryTreeProvider);
    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'DANH MỤC',
                    style: TextStyle(color: AppColors.caption, fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: () => AppRouter.category(context),
                  child: const Text('Xem tất cả >'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 120,
            child: tree.when(
              loading: () => ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 8,
                itemBuilder: (_, _) => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Skeleton.circle(size: 64),
                      SizedBox(height: 8),
                      Skeleton(width: 64, height: 12),
                    ],
                  ),
                ),
              ),
              error: (error, _) => Center(
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(categoryTreeProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text('Không tải được danh mục. Thử lại'),
                ),
              ),
              data: (categories) => ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return InkWell(
                    onTap: () =>
                        AppRouter.category(context, categoryId: category.id),
                    child: SizedBox(
                      width: 120,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _icons[index % _icons.length],
                              color: AppColors.primary,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              category.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.title,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
