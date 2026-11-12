import 'package:flutter/material.dart';

import '../models/admin_models.dart';
import '../providers/admin_providers.dart';
import 'admin_presentation.dart';

class AdminListFilters extends StatelessWidget {
  const AdminListFilters({
    super.key,
    required this.section,
    required this.state,
    required this.compact,
    required this.searchController,
    required this.notifier,
  });
  final AdminSection section;
  final AdminListState state;
  final bool compact;
  final TextEditingController searchController;
  final AdminListNotifier notifier;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (section.supportsSearch)
        SizedBox(
          width: compact ? double.infinity : 300,
          child: TextField(
            key: const ValueKey('admin-search'),
            controller: searchController,
            enabled: !state.isMutating,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) =>
                notifier.setFilters(search: searchController.text),
            decoration: InputDecoration(
              hintText: section == AdminSection.users
                  ? 'Tên, email hoặc số điện thoại'
                  : 'Tìm theo tên hoặc mã',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(
                tooltip: 'Tìm kiếm',
                onPressed: state.isMutating
                    ? null
                    : () => notifier.setFilters(search: searchController.text),
                icon: const Icon(Icons.arrow_forward, size: 18),
              ),
            ),
          ),
        ),
      SizedBox(
        width: compact ? double.infinity : 210,
        child: DropdownButtonFormField<String>(
          key: ValueKey('admin-status-${state.query.status}'),
          initialValue: state.query.status,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Trạng thái'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Tất cả trạng thái')),
            for (final s in section.statuses)
              DropdownMenuItem(value: s, child: Text(adminStatusLabel(s))),
          ],
          onChanged: state.isMutating
              ? null
              : (value) => notifier.setFilters(status: value),
        ),
      ),
      if (section.supportsRole)
        SizedBox(
          width: compact ? double.infinity : 190,
          child: DropdownButtonFormField<String>(
            key: ValueKey('admin-role-${state.query.role}'),
            initialValue: state.query.role,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vai trò'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Tất cả vai trò')),
              for (final r in adminRoles)
                DropdownMenuItem(value: r, child: Text(adminRoleLabel(r))),
            ],
            onChanged: state.isMutating
                ? null
                : (value) => notifier.setFilters(role: value),
          ),
        ),
      TextButton.icon(
        onPressed: state.isMutating
            ? null
            : () {
                searchController.clear();
                notifier.setFilters(search: '', status: '', role: '');
              },
        icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
        label: const Text('Đặt lại'),
      ),
    ],
  );
}
