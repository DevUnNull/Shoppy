import 'package:flutter/material.dart';

import '../../../core/widgets/app_network_image.dart';
import '../models/admin_models.dart';
import 'admin_presentation.dart';

typedef AdminRecordAction = void Function(String action, AdminRecord record);

class AdminRecordList extends StatelessWidget {
  const AdminRecordList({
    super.key,
    required this.section,
    required this.items,
    required this.busy,
    required this.compact,
    required this.onAction,
  });

  final AdminSection section;
  final List<AdminRecord> items;
  final bool busy;
  final bool compact;
  final AdminRecordAction onAction;

  @override
  Widget build(BuildContext context) => compact
      ? Column(
          children: [
            for (final record in items)
              _AdminRecordCard(
                section: section,
                record: record,
                busy: busy,
                onAction: onAction,
              ),
          ],
        )
      : _AdminRecordTable(
          section: section,
          items: items,
          busy: busy,
          onAction: onAction,
        );
}

class _AdminRecordTable extends StatelessWidget {
  const _AdminRecordTable({
    required this.section,
    required this.items,
    required this.busy,
    required this.onAction,
  });

  final AdminSection section;
  final List<AdminRecord> items;
  final bool busy;
  final AdminRecordAction onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(Color(0xFFF6F8FB)),
          columnSpacing: 28,
          horizontalMargin: 16,
          dataRowMinHeight: 64,
          dataRowMaxHeight: 76,
          columns: [
            for (final column in section.columns)
              DataColumn(label: Text(column)),
            const DataColumn(label: Text('Trạng thái')),
            const DataColumn(label: Text('Thao tác')),
          ],
          rows: [
            for (final record in items)
              DataRow(
                key: ValueKey('admin-row-${record.id}'),
                cells: [
                  for (final (index, value) in section.values(record).indexed)
                    DataCell(
                      _AdminRecordCell(
                        record: record,
                        value: value,
                        primary: index == 0,
                        showImage: index == 0 && section != AdminSection.orders,
                      ),
                    ),
                  DataCell(_StatusBadge(status: record.status)),
                  DataCell(
                    _AdminRecordActions(
                      section: section,
                      record: record,
                      busy: busy,
                      onAction: onAction,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

class _AdminRecordCell extends StatelessWidget {
  const _AdminRecordCell({
    required this.record,
    required this.value,
    required this.primary,
    required this.showImage,
  });

  final AdminRecord record;
  final String value;
  final bool primary;
  final bool showImage;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: primary ? FontWeight.w600 : FontWeight.normal,
      ),
    );
    return SizedBox(
      width: primary ? 180 : 165,
      child: showImage
          ? Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AppNetworkImage(
                    url: record.imageUrl,
                    width: 34,
                    height: 34,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: text),
              ],
            )
          : text,
    );
  }
}

class _AdminRecordCard extends StatelessWidget {
  const _AdminRecordCard({
    required this.section,
    required this.record,
    required this.busy,
    required this.onAction,
  });

  final AdminSection section;
  final AdminRecord record;
  final bool busy;
  final AdminRecordAction onAction;

  @override
  Widget build(BuildContext context) {
    final values = section.values(record);
    final columns = section.columns;
    return Container(
      key: ValueKey('admin-row-${record.id}'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEBEEF3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  values.first,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _AdminRecordActions(
                section: section,
                record: record,
                busy: busy,
                onAction: onAction,
              ),
            ],
          ),
          Text(
            '#${record.id}',
            style: const TextStyle(color: adminMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final (index, value) in values.indexed.skip(1))
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('${columns[index]}: $value', softWrap: true),
            ),
          const SizedBox(height: 7),
          _StatusBadge(status: record.status),
        ],
      ),
    );
  }
}

class _AdminRecordActions extends StatelessWidget {
  const _AdminRecordActions({
    required this.section,
    required this.record,
    required this.busy,
    required this.onAction,
  });

  final AdminSection section;
  final AdminRecord record;
  final bool busy;
  final AdminRecordAction onAction;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: ValueKey('admin-actions-${record.id}'),
    tooltip: 'Thao tác #${record.id}',
    enabled: !busy,
    onSelected: (value) => onAction(value, record),
    itemBuilder: (_) => [
      if (section.supportsDetail)
        const PopupMenuItem(value: 'detail', child: Text('Xem chi tiết')),
      if (section.supportsEdit)
        const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
      if (section != AdminSection.orders)
        for (final status in section.statuses)
          if (status != record.status)
            PopupMenuItem(
              value: 'status:$status',
              child: Text(adminStatusActionLabel(section, status)),
            ),
      if (section == AdminSection.users)
        for (final role in adminRoles)
          if (role != record.role)
            PopupMenuItem(
              value: 'role:$role',
              child: Text('Đổi vai trò: ${adminRoleLabel(role)}'),
            ),
      if (section.supportsEdit)
        const PopupMenuItem(
          value: 'delete',
          child: Text('Xóa', style: TextStyle(color: Colors.red)),
        ),
      if (section == AdminSection.orders && record.status != 'CANCELLED')
        const PopupMenuItem(
          value: 'cancel',
          child: Text('Hủy đơn khẩn cấp', style: TextStyle(color: Colors.red)),
        ),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'ACTIVE' || 'DELIVERED' => const Color(0xFF15805D),
      'BLOCKED' || 'CANCELLED' => const Color(0xFFCB394B),
      'INACTIVE' => const Color(0xFF6B778C),
      _ => const Color(0xFF9C6500),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        adminStatusLabel(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
