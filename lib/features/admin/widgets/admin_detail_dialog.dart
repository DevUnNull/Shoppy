import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';

Future<void> showAdminDetail(
  BuildContext context,
  AdminSection section,
  int id,
) => showDialog<void>(
  context: context,
  builder: (_) => _AdminDetailDialog(section: section, id: id),
);

class _AdminDetailDialog extends ConsumerWidget {
  const _AdminDetailDialog({required this.section, required this.id});

  final AdminSection section;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = adminDetailProvider((section, id));
    return AlertDialog(
      title: Text('Chi tiết ${section.title.toLowerCase()} #$id'),
      content: SizedBox(
        width: 620,
        child: ref
            .watch(provider)
            .when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => ErrorBanner(
                message: error.toString(),
                onRetry: () => ref.invalidate(provider),
              ),
              data: (record) => SingleChildScrollView(
                child: AdminDetailContent(section: section, data: record.raw),
              ),
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

/// Only known business fields are displayed; absent information stays explicit.
class AdminDetailContent extends StatelessWidget {
  const AdminDetailContent({
    super.key,
    required this.section,
    required this.data,
  });

  final AdminSection section;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void field(String label, Object? value, {bool money = false}) {
      final text = value == null || value.toString().trim().isEmpty
          ? 'Chưa có thông tin'
          : money && value is num
          ? formatVnd(value)
          : value.toString();
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: Colors.blueGrey),
              ),
              const SizedBox(height: 3),
              SelectableText(text),
            ],
          ),
        ),
      );
    }

    Map<String, dynamic> nested(Object? value) =>
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    void person(String label, Object? value) {
      final info = nested(value);
      if (info.isEmpty) return;
      rows.add(const Divider(height: 24));
      rows.add(Text(label, style: Theme.of(context).textTheme.titleMedium));
      field('Họ tên', info['fullName'] ?? info['name']);
      field('Email', info['email']);
      field('Điện thoại', info['phone']);
    }

    final image =
        data['avatarUrl'] ??
        data['logoUrl'] ??
        data['imageUrl'] ??
        data['iconUrl'];
    if (image is String && image.isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppNetworkImage(url: image, width: 80, height: 80),
          ),
        ),
      );
    }
    field('Mã', data['id']);
    field('Trạng thái', data['status']);
    switch (section) {
      case AdminSection.users:
        field('Họ tên', data['fullName'] ?? data['name']);
        field('Email', data['email']);
        field('Điện thoại', data['phone']);
        field('Vai trò', data['role']);
        field('Số dư ví', data['balance'], money: true);
        final shop = nested(data['shop']);
        field(
          'Shop liên kết',
          shop['name'] ?? data['shopName'] ?? data['shopId'],
        );
        final shipper = nested(data['shipper']);
        final vehicle = nested(data['vehicle'] ?? shipper['vehicle']);
        final company = nested(
          data['shippingCompany'] ?? shipper['shippingCompany'],
        );
        field(
          'Hãng vận chuyển',
          company['name'] ??
              data['shippingCompanyName'] ??
              shipper['shippingCompanyName'],
        );
        field(
          'Loại xe',
          data['vehicleType'] ??
              shipper['vehicleType'] ??
              vehicle['vehicleType'] ??
              vehicle['type'],
        );
        field(
          'Biển số xe',
          data['vehiclePlate'] ??
              data['licensePlate'] ??
              shipper['vehiclePlate'] ??
              shipper['licensePlate'] ??
              vehicle['vehiclePlate'] ??
              vehicle['licensePlate'] ??
              vehicle['plateNumber'],
        );
      case AdminSection.shops:
        field('Tên cửa hàng', data['name']);
        field('Mô tả', data['description']);
        field('Địa chỉ / Google Maps', data['address']);
        field('Mã chủ sở hữu', data['userId'] ?? data['ownerId']);
        person('Chủ sở hữu', data['owner'] ?? data['user']);
        field(
          'Tổng sản phẩm',
          data['totalProductsCount'] ??
              data['totalProducts'] ??
              data['productCount'],
        );
        field(
          'Tổng đơn đã bán',
          data['totalOrdersCount'] ??
              data['totalOrders'] ??
              data['orderCount'] ??
              data['totalSoldOrders'],
        );
        field('Số dư cửa hàng', data['balance'], money: true);
      case AdminSection.categories:
        field('Tên danh mục', data['name']);
        field('Slug', data['slug']);
        field('Danh mục cha', data['parentId']);
        field('Thứ tự hiển thị', data['displayOrder']);
      case AdminSection.shippingCompanies:
        field('Tên hãng', data['name']);
        field('Mã hãng', data['code']);
        field('Điện thoại', data['phone']);
        field('Email', data['email']);
        field('Website', data['website']);
        field('Phí cơ bản', data['baseFee'], money: true);
      case AdminSection.orders:
        field('Mã người mua', data['userId'] ?? data['customerId']);
        person('Người mua', data['user'] ?? data['customer'] ?? data['buyer']);
        field('Người nhận', data['receiverName'] ?? data['recipientName']);
        field(
          'Điện thoại nhận hàng',
          data['receiverPhone'] ?? data['recipientPhone'],
        );
        field('Địa chỉ giao hàng', data['shippingAddress']);
        final shop = nested(data['shop']);
        field('Cửa hàng', shop['name'] ?? data['shopName'] ?? data['shopId']);
        person('Shipper', data['shipper']);
        field('Mã shipper', data['shipperId']);
        field(
          'Hãng vận chuyển',
          data['shippingCompanyName'] ?? data['shippingCompanyId'],
        );
        field('Phương thức thanh toán', data['paymentMethod']);
        field('Tiền hàng', data['totalAmount'], money: true);
        field('Phí vận chuyển', data['shippingFee'], money: true);
        field('Tổng thanh toán', data['grandTotal'], money: true);
        field('Mã vận đơn', data['trackingNumber']);
        field('Ghi chú', data['note']);
        field('Lý do hủy', data['cancelReason']);
        final items = data['items'];
        if (items is List && items.isNotEmpty) {
          rows.add(const Divider(height: 24));
          rows.add(
            Text('Sản phẩm', style: Theme.of(context).textTheme.titleMedium),
          );
          for (final raw in items) {
            final item = nested(raw);
            field(
              (item['productNameSnapshot'] ?? item['productName'] ?? 'Sản phẩm')
                  .toString(),
              '${item['variantNameSnapshot'] ?? item['variantName'] ?? ''} · Số lượng: ${item['quantity'] ?? '—'} · ${item['priceSnapshot'] is num
                  ? formatVnd(item['priceSnapshot'])
                  : item['price'] is num
                  ? formatVnd(item['price'])
                  : '—'}',
            );
          }
        }
        final tracking = data['trackings'] ?? data['trackingHistory'];
        if (tracking is List && tracking.isNotEmpty) {
          rows.add(const Divider(height: 24));
          rows.add(
            Text(
              'Lịch sử đơn hàng',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
          for (final raw in tracking) {
            final item = nested(raw);
            field(
              '${item['status'] ?? ''} · ${item['createdAt'] ?? item['timestamp'] ?? ''}',
              item['description'] ?? item['message'] ?? item['note'],
            );
          }
        }
    }
    field('Ngày tạo', data['createdAt']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}
