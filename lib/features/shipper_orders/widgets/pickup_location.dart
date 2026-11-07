import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Uri? pickupMapUri(String? address) {
  final uri = Uri.tryParse(address?.trim() ?? '');
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  return uri;
}

Future<bool> openPickupMap(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class PickupLocation extends StatelessWidget {
  const PickupLocation({
    super.key,
    required this.address,
    this.openUrl = openPickupMap,
  });
  final String? address;
  final Future<bool> Function(Uri) openUrl;

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      if (await openUrl(uri)) return;
    } catch (_) {
      /* Hiện cách sao chép địa chỉ bên dưới nếu không mở được. */
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không mở được bản đồ. Bạn có thể sao chép địa chỉ lấy hàng.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = address?.trim() ?? '';
    final uri = pickupMapUri(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (text.isEmpty)
          const Text('Chưa có địa chỉ lấy hàng')
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  uri == null ? text : 'Vị trí lấy hàng trên bản đồ',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Sao chép địa chỉ lấy hàng',
                icon: const Icon(Icons.copy_outlined, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép địa chỉ lấy hàng.'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          if (uri != null)
            OutlinedButton.icon(
              onPressed: () => _open(context, uri),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Mở vị trí lấy hàng'),
            ),
        ],
      ],
    );
  }
}
