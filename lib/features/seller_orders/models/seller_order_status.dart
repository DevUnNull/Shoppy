enum SellerOrderStatus {
  pending('PENDING', 'Chờ xác nhận'),
  processing('PROCESSING', 'Đang chuẩn bị'),
  readyToShip('READY_TO_SHIP', 'Chờ lấy hàng'),
  shipping('SHIPPING', 'Đang giao'),
  delivered('DELIVERED', 'Đã giao'),
  cancelled('CANCELLED', 'Đã hủy');

  const SellerOrderStatus(this.value, this.label);

  final String value;
  final String label;

  static String labelOf(String value) {
    for (final status in values) {
      if (status.value == value) return status.label;
    }
    return value;
  }
}
