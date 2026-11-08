# Admin Hub

Admin Hub quản lý người dùng, cửa hàng, danh mục, đối tác vận chuyển và đơn hàng toàn sàn. Mã giao diện, model, provider và service mới nằm trong `lib/features/admin/`.

## Truy cập

Đăng nhập bằng tài khoản có role `ADMIN` để mở Admin Hub. Phiên admin đã được khôi phục có thể mở lại khu quản trị từ menu tài khoản. Người dùng không có quyền admin không được tải dữ liệu quản trị. Admin dùng JWT của phiên đăng nhập hiện tại qua `apiClientProvider`, không dùng JWT cố định trong cấu hình Seller/Shipper.

## Các phân hệ

- **Người dùng:** tìm theo tên/email/số điện thoại; lọc role và trạng thái; xem hồ sơ, ví và thông tin liên kết do API trả về; đổi trạng thái và vai trò.
- **Cửa hàng:** tìm theo tên và lọc trạng thái; xem chi tiết shop, chủ sở hữu và thống kê do backend cung cấp; đổi trạng thái hoạt động.
- **Danh mục:** danh sách phẳng có phân trang; tạo/sửa tên, slug, danh mục cha, thứ tự hiển thị và ảnh; bật/tắt hoặc xóa.
- **Đối tác vận chuyển:** tìm kiếm, lọc trạng thái; tạo/sửa tên, mã hãng, thông tin liên hệ, website và logo; bật/tắt hoặc xóa.
- **Đơn hàng:** lọc trạng thái, xem đơn bất kỳ và lịch sử tracking; hủy khẩn cấp có lý do và xác nhận. Backend quyết định quyền hủy và hoàn tiền.

## Hợp đồng API

Base URL lấy từ `ApiConfig.baseUrl`. Mọi request gửi `Authorization: Bearer <JWT hiện tại>`. `ApiClient` xử lý lớp response `{status, message, data}` và trả phần `data` cho service.

Danh sách dùng `page` bắt đầu từ 0 và `size` mặc định 10. Response phân trang có `content`, `page`, `size`, `totalElements`, `totalPages`, `hasNext`.

| Thực thể | Danh sách và chi tiết | Thao tác |
| --- | --- | --- |
| User | `GET /admin/users`, `GET /admin/users/{id}` | `PATCH /admin/users/{id}/status`, `PATCH /admin/users/{id}/role` |
| Shop | `GET /admin/shops`, `GET /admin/shops/{id}` | `PATCH /admin/shops/{id}/status` |
| Danh mục | `GET /admin/categories` | `POST /admin/categories`, `PUT /admin/categories/{id}`, `PATCH /admin/categories/{id}/status`, `DELETE /admin/categories/{id}` |
| ĐVVC | `GET /admin/shipping-companies`, `GET /admin/shipping-companies/{id}` | `POST /admin/shipping-companies`, `PUT /admin/shipping-companies/{id}`, `PATCH /admin/shipping-companies/{id}/status`, `DELETE /admin/shipping-companies/{id}` |
| Đơn hàng | `GET /orders/manage`, `GET /orders/{id}` | `PUT /orders/{id}/cancel` |

Các danh sách admin nhận `search`, `status`, `page`, `size`; user nhận thêm `role`. `/orders/manage` nhận `status`, `page`, `size`.

- Status User/Shop: `ACTIVE`, `INACTIVE`, `BLOCKED`; role: `CUSTOMER`, `SELLER`, `SHIPPER`, `ADMIN`.
- Status danh mục/ĐVVC: `ACTIVE`, `INACTIVE`.
- Danh mục tạo/sửa: `{name, slug, parentId, displayOrder}`. `parentId` là ID cha hoặc `null` cho danh mục gốc. File ảnh dùng field multipart `image`.
- ĐVVC tạo/sửa: `{name, code, phone, email, website}`. File logo dùng field multipart `logo`.
- Có ảnh thì dùng multipart; không có ảnh dùng JSON. Đổi trạng thái gửi `{status}`, đổi role gửi `{role}`, hủy đơn gửi `{reason}`.

Các thao tác ghi không tự retry. Khi request lỗi, giao diện giữ dữ liệu nhập và hiển thị thông báo backend. Những ràng buộc như danh mục còn sản phẩm, quyền đổi role, quyền hủy đơn và hoàn tiền do backend kiểm tra.

## Kiểm tra

Chạy kiểm tra thông thường:

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Test thật chỉ bật khi có đủ hai biến môi trường. Nhập tài khoản admin kiểm thử vào phiên shell; không lưu mật khẩu hoặc JWT vào mã nguồn.

```powershell
$env:SHOPPY_ADMIN_EMAIL = '<email admin kiểm thử>'
$env:SHOPPY_ADMIN_PASSWORD = '<mật khẩu>'
try {
  flutter test --no-pub test/admin_live_smoke_test.dart --reporter expanded
} finally {
  Remove-Item Env:SHOPPY_ADMIN_EMAIL, Env:SHOPPY_ADMIN_PASSWORD
}
```

Smoke test đăng nhập, xác minh role `ADMIN`, đọc trang đầu của cả năm phân hệ và đọc chi tiết bản ghi mẫu khi có dữ liệu. Test chỉ in cấu trúc field, không in giá trị hồ sơ hoặc token. Ngoài `POST /auth/login`, test chỉ gọi GET; không khóa tài khoản/shop, đổi role, tạo/xóa thực thể, hủy đơn hay vô hiệu hóa token thật. Test không chứng minh các thao tác ghi trên backend thật đã thành công; các thao tác này cần test hợp đồng bằng API giả lập hoặc môi trường kiểm thử riêng.

Đã chạy thành công smoke test đọc dữ liệu thật ngày 08/11/2026. Response chi tiết shop dùng `totalProductsCount`, `totalOrdersCount` và `owner`; user Seller có `shop`, user Shipper có `shippingCompany`. Mẫu user Shipper kiểm tra chưa trả thông tin xe. Mẫu chi tiết ĐVVC chỉ có `id`, `name`, `code`, `logoUrl`, `baseFee`, `status`, chưa trả các field liên hệ có trong đặc tả. Giao diện cần hiển thị thiếu dữ liệu theo response, không tự suy đoán các giá trị này.
