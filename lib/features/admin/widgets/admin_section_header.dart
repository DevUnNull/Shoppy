import 'package:flutter/material.dart';

import '../models/admin_models.dart';
import 'admin_presentation.dart';

class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({super.key, required this.section, this.onCreate});

  final AdminSection section;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 12,
    children: [
      _AdminSectionTitle(section: section),
      if (section.supportsEdit)
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add, size: 19),
          label: Text(
            section == AdminSection.categories
                ? 'Thêm danh mục'
                : 'Thêm hãng vận chuyển',
          ),
        ),
    ],
  );
}

class _AdminSectionTitle extends StatelessWidget {
  const _AdminSectionTitle({required this.section});

  final AdminSection section;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        section.title,
        style: const TextStyle(
          color: adminNavy,
          fontSize: 25,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        section.subtitle,
        style: const TextStyle(color: adminMuted, fontSize: 13),
      ),
    ],
  );
}
