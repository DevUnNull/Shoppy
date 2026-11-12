import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';
import '../services/admin_service.dart';
import '../widgets/admin_cancel_order_dialog.dart';
import '../widgets/admin_catalog_form.dart';
import '../widgets/admin_detail_dialog.dart';
import '../widgets/admin_list_panel.dart';
import '../widgets/admin_presentation.dart';
import '../widgets/admin_section_header.dart';

class AdminSectionPage extends ConsumerStatefulWidget {
  const AdminSectionPage({super.key, required this.section});
  final AdminSection section;

  @override
  ConsumerState<AdminSectionPage> createState() => _AdminSectionPageState();
}

class _AdminSectionPageState extends ConsumerState<AdminSectionPage> {
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
              baseFee: fields['baseFee'] as num,
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
      final reason = await showAdminCancelOrderDialog(context, record.id);
      if (reason != null && mounted) {
        await _mutate((service) => service.cancelOrder(record.id, reason));
      }
      return;
    }
    final isRole = action.startsWith('role:');
    final isStatus = action.startsWith('status:');
    final value = action.split(':').last;
    final label = isRole
        ? 'Đổi vai trò thành ${adminRoleLabel(value)}'
        : isStatus
        ? adminStatusActionLabel(section, value)
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
    final busy = ref.watch(
      adminListProvider(section).select((state) => state.isMutating),
    );
    final compact = MediaQuery.sizeOf(context).width < 760;
    return SingleChildScrollView(
      key: const ValueKey('admin-content-scroll'),
      padding: EdgeInsets.all(compact ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeader(
            section: section,
            onCreate: busy ? null : () => _edit(),
          ),
          const SizedBox(height: 24),
          AdminListPanel(
            section: section,
            searchController: _search,
            compact: compact,
            onAction: _action,
          ),
        ],
      ),
    );
  }
}
