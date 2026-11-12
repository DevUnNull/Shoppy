import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';
import 'admin_list_filters.dart';
import 'admin_pagination.dart';
import 'admin_presentation.dart';
import 'admin_record_list.dart';

class AdminListPanel extends ConsumerWidget {
  const AdminListPanel({
    super.key,
    required this.section,
    required this.searchController,
    required this.compact,
    required this.onAction,
  });

  final AdminSection section;
  final TextEditingController searchController;
  final bool compact;
  final AdminRecordAction onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminListProvider(section));
    final notifier = ref.read(adminListProvider(section).notifier);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminListToolbar(
            section: section,
            total: state.totalElements,
            onRefresh: state.isLoading || state.isMutating
                ? null
                : notifier.refresh,
          ),
          const SizedBox(height: 16),
          AdminListFilters(
            section: section,
            state: state,
            compact: compact,
            searchController: searchController,
            notifier: notifier,
          ),
          const SizedBox(height: 20),
          if (state.isMutating) const LinearProgressIndicator(minHeight: 2),
          if (state.error != null)
            ErrorBanner(message: state.error!, onRetry: notifier.refresh),
          if (state.mutationError != null) ...[
            ErrorBanner(message: state.mutationError!),
            const SizedBox(height: 12),
          ],
          _AdminListBody(
            section: section,
            state: state,
            compact: compact,
            onAction: onAction,
          ),
          if (!state.isLoading && state.error == null)
            AdminPagination(
              page: state.page,
              totalPages: state.totalPages,
              onChanged: state.isMutating ? null : notifier.goToPage,
            ),
        ],
      ),
    );
  }
}

class _AdminListToolbar extends StatelessWidget {
  const _AdminListToolbar({
    required this.section,
    required this.total,
    required this.onRefresh,
  });

  final AdminSection section;
  final int total;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(adminSectionIcon(section), color: adminMuted, size: 22),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Danh sách · $total bản ghi',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      IconButton(
        tooltip: 'Làm mới',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
      ),
    ],
  );
}

class _AdminListBody extends StatelessWidget {
  const _AdminListBody({
    required this.section,
    required this.state,
    required this.compact,
    required this.onAction,
  });

  final AdminSection section;
  final AdminListState state;
  final bool compact;
  final AdminRecordAction onAction;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.items.isEmpty && state.error == null) {
      return const _AdminEmptyList();
    }
    if (state.items.isEmpty) return const SizedBox.shrink();
    return AdminRecordList(
      section: section,
      items: state.items,
      busy: state.isMutating,
      compact: compact,
      onAction: onAction,
    );
  }
}

class _AdminEmptyList extends StatelessWidget {
  const _AdminEmptyList();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 56),
    child: Column(
      children: [
        Icon(Icons.search_off, size: 42, color: adminMuted),
        SizedBox(height: 12),
        Text('Không tìm thấy dữ liệu'),
        SizedBox(height: 6),
        Text(
          'Thử thay đổi bộ lọc hoặc từ khóa.',
          style: TextStyle(color: adminMuted),
        ),
      ],
    ),
  );
}
