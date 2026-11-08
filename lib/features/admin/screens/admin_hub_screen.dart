import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';
import '../services/admin_service.dart';
import '../widgets/admin_catalog_form.dart';
import '../widgets/admin_detail_dialog.dart';

const _navy = Color(0xFF17243C);
const _muted = Color(0xFF6B778C);

IconData _sectionIcon(AdminSection section) => switch (section) {
  AdminSection.users => Icons.people_outline,
  AdminSection.shops => Icons.storefront_outlined,
  AdminSection.categories => Icons.category_outlined,
  AdminSection.shippingCompanies => Icons.local_shipping_outlined,
  AdminSection.orders => Icons.receipt_long_outlined,
};

String adminStatusLabel(String value) => switch (value) {
  'ACTIVE' => 'Đang hoạt động',
  'INACTIVE' => 'Tạm ngưng',
  'BLOCKED' => 'Đã khóa',
  'PENDING' => 'Chờ xác nhận',
  'PROCESSING' => 'Đang chuẩn bị',
  'READY_TO_SHIP' => 'Chờ lấy hàng',
  'SHIPPING' => 'Đang giao',
  'DELIVERED' => 'Đã giao',
  'CANCELLED' => 'Đã hủy',
  _ => value.isEmpty ? 'Chưa xác định' : value,
};

String _roleLabel(String value) => switch (value) {
  'CUSTOMER' => 'Khách hàng',
  'SELLER' => 'Người bán',
  'SHIPPER' => 'Shipper',
  'ADMIN' => 'Quản trị viên',
  _ => value,
};

String _statusActionLabel(AdminSection section, String status) =>
    switch ((section, status)) {
      (AdminSection.users, 'ACTIVE') => 'Kích hoạt tài khoản',
      (AdminSection.users, 'INACTIVE') => 'Tạm ngưng tài khoản',
      (AdminSection.users, 'BLOCKED') => 'Khóa tài khoản',
      (AdminSection.shops, 'ACTIVE') => 'Mở cửa hàng',
      (AdminSection.shops, 'INACTIVE') => 'Tạm ngưng cửa hàng',
      (AdminSection.shops, 'BLOCKED') => 'Khóa cửa hàng',
      (_, 'ACTIVE') => 'Bật hoạt động',
      (_, 'INACTIVE') => 'Tắt hoạt động',
      _ => adminStatusLabel(status),
    };

class AdminHubScreen extends ConsumerStatefulWidget {
  const AdminHubScreen({super.key});

  @override
  ConsumerState<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends ConsumerState<AdminHubScreen> {
  AdminSection _section = AdminSection.users;

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) AppRouter.backToHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.status == AuthStatus.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isLoggedIn || auth.user?.role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Hub')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 64,
                  color: _muted,
                ),
                const SizedBox(height: 16),
                const Text('Khu vực dành cho quản trị viên'),
                const SizedBox(height: 8),
                const Text(
                  'Vui lòng đăng nhập bằng tài khoản có quyền ADMIN.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => AppRouter.login(context),
                  child: const Text('Đăng nhập'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    final busy = ref.watch(
      adminListProvider(_section).select((s) => s.isMutating),
    );
    final sidebar = _sidebar(busy, wide);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          title: Text(wide ? 'Quản trị toàn sàn' : 'Admin Hub'),
          leading: wide
              ? const Icon(Icons.admin_panel_settings_outlined)
              : null,
          actions: [
            if (MediaQuery.sizeOf(context).width > 650)
              Center(
                child: Text(
                  auth.user!.displayName,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            IconButton(
              tooltip: 'Về trang mua sắm',
              onPressed: busy ? null : () => AppRouter.backToHome(context),
              icon: const Icon(Icons.storefront_outlined),
            ),
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: busy ? null : _logout,
              icon: const Icon(Icons.logout),
            ),
            const SizedBox(width: 12),
          ],
        ),
        drawer: wide ? null : Drawer(child: sidebar),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide) SizedBox(width: 238, child: sidebar),
            Expanded(
              child: _AdminSectionPage(
                key: ValueKey(_section),
                section: _section,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebar(bool busy, bool wide) => Material(
    color: _navy,
    child: SafeArea(
      child: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shoppy',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 29,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'ADMIN HUB',
                  style: TextStyle(
                    color: Color(0xFFA6B6D0),
                    fontSize: 11,
                    letterSpacing: 2.4,
                  ),
                ),
              ],
            ),
          ),
          for (final section in AdminSection.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: ListTile(
                key: ValueKey('admin-nav-${section.name}'),
                selected: _section == section,
                selectedTileColor: const Color(0xFF30405B),
                selectedColor: Colors.white,
                textColor: const Color(0xFFBECAE0),
                iconColor: const Color(0xFFBECAE0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: Icon(_sectionIcon(section), size: 21),
                title: Text(
                  section.title,
                  style: const TextStyle(fontSize: 13),
                ),
                onTap: busy
                    ? null
                    : () {
                        setState(() => _section = section);
                        if (!wide) Navigator.of(context).pop();
                      },
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Quản lý hoạt động trên toàn sàn',
              style: TextStyle(
                color: Color(0xFF9CAEC9),
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AdminSectionPage extends ConsumerStatefulWidget {
  const _AdminSectionPage({super.key, required this.section});
  final AdminSection section;

  @override
  ConsumerState<_AdminSectionPage> createState() => _AdminSectionPageState();
}

class _AdminSectionPageState extends ConsumerState<_AdminSectionPage> {
  final _search = TextEditingController();
  AdminSection get section => widget.section;
  AdminListNotifier get _notifier =>
      ref.read(adminListProvider(section).notifier);

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(adminListProvider(section)).query.search;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<bool> _mutate(Future<void> Function(AdminService) action) async {
    final notifier = _notifier;
    final ok = await notifier.mutate(action);
    if (!mounted) return ok;
    if (ok) {
      AppToast.success(context, 'Đã cập nhật thành công');
    } else {
      final error = ref.read(adminListProvider(section)).mutationError;
      if (error != null) AppToast.error(context, error);
    }
    return ok;
  }

  Future<void> _edit([AdminRecord? record]) async {
    Map<String, dynamic>? initial = record?.raw;
    // Shipping list responses omit editable contact fields: load full detail
    // before editing so saving a name does not erase existing contact data.
    if (record != null && section == AdminSection.shippingCompanies) {
      try {
        initial = (await ref.read(
          adminDetailProvider((section, record.id)).future,
        )).raw;
      } catch (e) {
        if (mounted) AppToast.error(context, e.toString());
        return;
      }
    }
    if (!mounted) return;
    await showAdminCatalogForm(
      context,
      isCategory: section == AdminSection.categories,
      initial: initial,
      onSave: (fields, bytes, fileName) async {
        if (!mounted) {
          throw const ApiException(
            'Phiên quản trị đã thay đổi. Vui lòng mở lại form.',
          );
        }
        final upload = bytes == null
            ? null
            : AdminUpload(bytes: bytes, fileName: fileName!);
        final ok = await _notifier.mutate((service) async {
          if (section == AdminSection.categories) {
            await service.saveCategory(
              id: record?.id,
              name: fields['name'] as String,
              slug: fields['slug'] as String,
              parentId: fields['parentId'] as int?,
              displayOrder: fields['displayOrder'] as int,
              image: upload,
            );
          } else {
            await service.saveShippingCompany(
              id: record?.id,
              name: fields['name'] as String,
              code: fields['code'] as String,
              phone: fields['phone'] as String?,
              email: fields['email'] as String?,
              website: fields['website'] as String?,
              logo: upload,
            );
          }
        });
        if (!ok) {
          if (!mounted) {
            throw const ApiException('Phiên quản trị đã thay đổi.');
          }
          throw ApiException(
            ref.read(adminListProvider(section)).mutationError ??
                'Không thể lưu thay đổi. Vui lòng kiểm tra phiên đăng nhập.',
          );
        }
      },
    ).then((saved) {
      if (saved && mounted) AppToast.success(context, 'Đã lưu thành công');
    });
  }

  Future<void> _action(String action, AdminRecord record) async {
    if (action == 'detail') {
      await showAdminDetail(context, section, record.id);
      return;
    }
    if (action == 'edit') {
      await _edit(record);
      return;
    }
    if (action == 'cancel') {
      final reason = await _cancelReason(context, record.id);
      if (reason != null && mounted) {
        await _mutate((service) => service.cancelOrder(record.id, reason));
      }
      return;
    }
    final isRole = action.startsWith('role:');
    final isStatus = action.startsWith('status:');
    final value = action.split(':').last;
    final label = isRole
        ? 'Đổi vai trò thành ${_roleLabel(value)}'
        : isStatus
        ? _statusActionLabel(section, value)
        : 'Xóa';
    final self =
        section == AdminSection.users &&
        record.id == ref.read(authProvider).user?.id;
    final ok = await showConfirmDialog(
      context,
      title: '$label?',
      message:
          '$label ${record.name} (#${record.id}).${self ? '\nĐây là tài khoản đang đăng nhập. Thay đổi quyền hoặc khóa tài khoản sẽ kết thúc phiên quản trị.' : ''}${section == AdminSection.shippingCompanies && value == 'INACTIVE' ? '\nShipper thuộc hãng sẽ không thể tiếp tục nhận đơn.' : ''}',
      confirmLabel: 'Xác nhận',
      destructive: action == 'delete' || value == 'BLOCKED',
    );
    if (!ok || !mounted) return;
    final saved = await _mutate((service) {
      if (isRole) return service.setUserRole(record.id, value);
      if (isStatus) return service.setStatus(section, record.id, value);
      return service.delete(section, record.id);
    });
    if (saved &&
        self &&
        ((isRole && value != 'ADMIN') || (isStatus && value != 'ACTIVE'))) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminListProvider(section));
    final compact = MediaQuery.sizeOf(context).width < 760;
    return SingleChildScrollView(
      key: const ValueKey('admin-content-scroll'),
      padding: EdgeInsets.all(compact ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _subtitle,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
              if (section.supportsEdit)
                FilledButton.icon(
                  onPressed: state.isMutating ? null : () => _edit(),
                  icon: const Icon(Icons.add, size: 19),
                  label: Text(
                    section == AdminSection.categories
                        ? 'Thêm danh mục'
                        : 'Thêm hãng vận chuyển',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(_sectionIcon(section), color: _muted, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Danh sách · ${state.totalElements} bản ghi',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Làm mới',
                      onPressed: state.isLoading || state.isMutating
                          ? null
                          : _notifier.refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _filters(state, compact),
                const SizedBox(height: 20),
                if (state.isMutating)
                  const LinearProgressIndicator(minHeight: 2),
                if (state.error != null)
                  ErrorBanner(
                    message: state.error!,
                    onRetry: _notifier.refresh,
                  ),
                if (state.mutationError != null) ...[
                  ErrorBanner(message: state.mutationError!),
                  const SizedBox(height: 12),
                ],
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.items.isEmpty && state.error == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 56),
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 42, color: _muted),
                        SizedBox(height: 12),
                        Text('Không tìm thấy dữ liệu'),
                        SizedBox(height: 6),
                        Text(
                          'Thử thay đổi bộ lọc hoặc từ khóa.',
                          style: TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  )
                else if (!state.isLoading && state.items.isNotEmpty)
                  compact ? _cards(state) : _table(state),
                if (!state.isLoading && state.error == null)
                  _AdminPagination(
                    page: state.page,
                    totalPages: state.totalPages,
                    onChanged: state.isMutating ? null : _notifier.goToPage,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _subtitle => switch (section) {
    AdminSection.users => 'Quản lý tài khoản, trạng thái và phân quyền.',
    AdminSection.shops => 'Theo dõi cửa hàng và hoạt động kinh doanh.',
    AdminSection.categories => 'Sắp xếp hệ thống danh mục sản phẩm.',
    AdminSection.shippingCompanies => 'Quản lý các đối tác giao nhận trên sàn.',
    AdminSection.orders =>
      'Giám sát đơn hàng và xử lý các tình huống khẩn cấp.',
  };

  Widget _filters(AdminListState state, bool compact) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (section.supportsSearch)
        SizedBox(
          width: compact ? double.infinity : 300,
          child: TextField(
            key: const ValueKey('admin-search'),
            controller: _search,
            enabled: !state.isMutating,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _notifier.setFilters(search: _search.text),
            decoration: InputDecoration(
              hintText: section == AdminSection.users
                  ? 'Tên, email hoặc số điện thoại'
                  : 'Tìm theo tên hoặc mã',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(
                tooltip: 'Tìm kiếm',
                onPressed: state.isMutating
                    ? null
                    : () => _notifier.setFilters(search: _search.text),
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
              : (value) => _notifier.setFilters(status: value),
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
                DropdownMenuItem(value: r, child: Text(_roleLabel(r))),
            ],
            onChanged: state.isMutating
                ? null
                : (value) => _notifier.setFilters(role: value),
          ),
        ),
      TextButton.icon(
        onPressed: state.isMutating
            ? null
            : () {
                _search.clear();
                _notifier.setFilters(search: '', status: '', role: '');
              },
        icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
        label: const Text('Đặt lại'),
      ),
    ],
  );

  List<String> get _columns => switch (section) {
    AdminSection.users => ['Người dùng', 'Email', 'Vai trò'],
    AdminSection.shops => ['Cửa hàng', 'Chủ sở hữu', 'Địa chỉ'],
    AdminSection.categories => ['Danh mục', 'Slug', 'Danh mục cha', 'Thứ tự'],
    AdminSection.shippingCompanies => [
      'Đơn vị vận chuyển',
      'Mã hãng',
      'Phí cơ bản',
    ],
    AdminSection.orders => ['Đơn hàng', 'Cửa hàng', 'Thanh toán', 'Tổng tiền'],
  };

  List<String> _values(AdminRecord record) {
    final r = record.raw;
    String text(Object? v) =>
        v == null || v.toString().isEmpty ? '—' : v.toString();
    return switch (section) {
      AdminSection.users => [
        record.name,
        text(r['email']),
        _roleLabel(record.role),
      ],
      AdminSection.shops => [
        record.name,
        text(r['ownerName'] ?? r['userId']),
        text(r['address']),
      ],
      AdminSection.categories => [
        record.name,
        record.slug,
        text(r['parentId']),
        '${record.displayOrder}',
      ],
      AdminSection.shippingCompanies => [
        record.name,
        record.code,
        r['baseFee'] is num ? formatVnd(r['baseFee']) : '—',
      ],
      AdminSection.orders => [
        'Đơn #${record.id}',
        text(r['shopName'] ?? r['shopId']),
        text(r['paymentMethod']),
        r['grandTotal'] is num ? formatVnd(r['grandTotal']) : '—',
      ],
    };
  }

  Widget _table(AdminListState state) => LayoutBuilder(
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
            for (final c in _columns) DataColumn(label: Text(c)),
            const DataColumn(label: Text('Trạng thái')),
            const DataColumn(label: Text('Thao tác')),
          ],
          rows: [
            for (final row in state.items)
              DataRow(
                key: ValueKey('admin-row-${row.id}'),
                cells: [
                  for (final (index, value) in _values(row).indexed)
                    DataCell(
                      SizedBox(
                        width: index == 0 ? 180 : 165,
                        child: index == 0 && section != AdminSection.orders
                            ? Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: AppNetworkImage(
                                      url: row.imageUrl,
                                      width: 34,
                                      height: 34,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      value,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: index == 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                      ),
                    ),
                  DataCell(_StatusBadge(status: row.status)),
                  DataCell(_actions(row, state.isMutating)),
                ],
              ),
          ],
        ),
      ),
    ),
  );

  Widget _cards(AdminListState state) => Column(
    children: [
      for (final row in state.items)
        Container(
          key: ValueKey('admin-row-${row.id}'),
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
                      _values(row).first,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _actions(row, state.isMutating),
                ],
              ),
              Text(
                '#${row.id}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              for (final (i, value) in _values(row).indexed.skip(1))
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('${_columns[i]}: $value', softWrap: true),
                ),
              const SizedBox(height: 7),
              _StatusBadge(status: row.status),
            ],
          ),
        ),
    ],
  );

  Widget _actions(AdminRecord record, bool busy) => PopupMenuButton<String>(
    key: ValueKey('admin-actions-${record.id}'),
    tooltip: 'Thao tác #${record.id}',
    enabled: !busy,
    onSelected: (value) => _action(value, record),
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
              child: Text(_statusActionLabel(section, status)),
            ),
      if (section == AdminSection.users)
        for (final role in adminRoles)
          if (role != record.role)
            PopupMenuItem(
              value: 'role:$role',
              child: Text('Đổi vai trò: ${_roleLabel(role)}'),
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

class _AdminPagination extends StatelessWidget {
  const _AdminPagination({
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    final pages = <int>{0, totalPages - 1};
    for (var i = page - 1; i <= page + 1; i++) {
      if (i >= 0 && i < totalPages) {
        pages.add(i);
      }
    }
    if (totalPages <= 7) {
      pages.addAll(List.generate(totalPages, (i) => i));
    }
    final sorted = pages.toList()..sort();
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 8,
        children: [
          IconButton(
            tooltip: 'Trang trước',
            onPressed: onChanged != null && page > 0
                ? () => onChanged!(page - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0 && sorted[i] - sorted[i - 1] > 1)
              const SizedBox(
                width: 20,
                child: Text('…', textAlign: TextAlign.center),
              ),
            SizedBox(
              width: 36,
              height: 36,
              child: TextButton(
                onPressed: onChanged == null || sorted[i] == page
                    ? null
                    : () => onChanged!(sorted[i]),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                  backgroundColor: sorted[i] == page ? primary : null,
                  foregroundColor: _navy,
                  disabledForegroundColor: sorted[i] == page
                      ? Colors.white
                      : _muted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text('${sorted[i] + 1}'),
              ),
            ),
          ],
          IconButton(
            tooltip: 'Trang sau',
            onPressed: onChanged != null && page + 1 < totalPages
                ? () => onChanged!(page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

Future<String?> _cancelReason(BuildContext context, int id) async {
  return showDialog<String>(
    context: context,
    builder: (_) => _CancelOrderDialog(id: id),
  );
}

class _CancelOrderDialog extends StatefulWidget {
  const _CancelOrderDialog({required this.id});
  final int id;

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  final _controller = TextEditingController();
  final _key = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Hủy khẩn cấp đơn #${widget.id}?'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Đơn sẽ bị hủy. Nếu đã thanh toán, hệ thống sẽ xử lý hoàn tiền vào ví.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                autofocus: true,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Lý do hủy đơn'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Vui lòng nhập lý do hủy đơn'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Trở lại'),
      ),
      FilledButton(
        onPressed: () {
          if (_key.currentState!.validate()) {
            Navigator.of(context).pop(_controller.text.trim());
          }
        },
        child: const Text('Xác nhận hủy đơn'),
      ),
    ],
  );
}
