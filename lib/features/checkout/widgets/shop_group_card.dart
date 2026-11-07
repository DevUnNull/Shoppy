import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../cart/providers/cart_provider.dart';
import '../models/checkout_models.dart';
import '../models/shipping_company.dart';

/// Một nhóm sản phẩm của 1 shop: bảng sản phẩm, lời nhắn, chọn ĐVVC.
class ShopGroupCard extends StatelessWidget {
  const ShopGroupCard({
    super.key,
    required this.group,
    required this.note,
    required this.companies,
    required this.selectedCompanyId,
    required this.onCompanyChanged,
    this.companiesLoading = false,
    this.companiesError,
    this.onRetryCompanies,
  });

  final ShopGroup group;
  final TextEditingController note;
  final List<ShippingCompany> companies;
  final int? selectedCompanyId;
  final ValueChanged<int> onCompanyChanged;
  final bool companiesLoading;
  final String? companiesError;
  final VoidCallback? onRetryCompanies;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    final selected = companies
        .where((c) => c.id == selectedCompanyId)
        .firstOrNull;
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
            child: Row(
              children: [
                const Icon(Icons.storefront, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.shopName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          for (final item in group.items) _ItemRow(item: item, wide: wide),
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFDFF),
              border: Border(
                top: BorderSide(
                  color: AppColors.divider,
                  style: BorderStyle.solid,
                ),
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lời nhắn
                Flexible(
                  flex: wide ? 2 : 0,
                  child: Row(
                    children: [
                      const Text('Lời nhắn:'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: note,
                          maxLength: 200,
                          decoration: const InputDecoration(
                            hintText: 'Lưu ý cho Người bán…',
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: wide ? 24 : 0, height: wide ? 0 : 16),
                // Đơn vị vận chuyển
                Flexible(
                  flex: wide ? 3 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đơn vị vận chuyển:',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (companiesLoading)
                        const LinearProgressIndicator(color: AppColors.primary)
                      else if (companiesError != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                companiesError!,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: onRetryCompanies,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in companies)
                              _CompanyOption(
                                company: c,
                                selected: c.id == selectedCompanyId,
                                onTap: () => onCompanyChanged(c.id),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(color: AppColors.caption),
                  children: [
                    TextSpan(
                      text: 'Tổng số tiền (${group.quantity} sản phẩm):  ',
                    ),
                    TextSpan(
                      text: formatVnd(
                        group.merchandiseTotal + (selected?.baseFee ?? 0),
                      ),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.wide});

  final CartItem item;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final variant = item.variant;
    final variantLabel =
        variant != null && variant.name.toLowerCase() != 'mặc định'
        ? 'Loại: ${variant.name}'
        : null;
    final image = SizedBox.square(
      dimension: 48,
      child: AppNetworkImage(
        url: variant?.imageUrl ?? item.product.thumbnailUrl,
      ),
    );
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (variantLabel != null)
          Text(
            variantLabel,
            style: const TextStyle(color: AppColors.caption, fontSize: 13),
          ),
      ],
    );
    final subtotal = formatVnd(item.unitPrice * item.quantity);
    if (!wide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            image,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  name,
                  const SizedBox(height: 4),
                  Text('${formatVnd(item.unitPrice)}  x${item.quantity}'),
                ],
              ),
            ),
            Text(subtotal, style: const TextStyle(color: AppColors.title)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                image,
                const SizedBox(width: 12),
                Expanded(child: name),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(formatVnd(item.unitPrice), textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text('${item.quantity}', textAlign: TextAlign.right),
          ),
          Expanded(flex: 2, child: Text(subtotal, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _CompanyOption extends StatelessWidget {
  const _CompanyOption({
    required this.company,
    required this.selected,
    required this.onTap,
  });

  final ShippingCompany company;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 190,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? AppColors.primary : AppColors.caption,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    company.estimatedDays == null
                        ? formatVnd(company.baseFee)
                        : '${formatVnd(company.baseFee)} · ${company.estimatedDays}',
                    style: const TextStyle(
                      color: AppColors.caption,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
