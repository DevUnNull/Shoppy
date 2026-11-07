# Đơn hàng Shipper

## Chạy thử

1. Điền JWT của tài khoản SHIPPER vào `ApiConfig.shipperJwtToken` trong `lib/config/api_config.dart`, không thêm `Bearer`.
2. JWT Seller vẫn dùng `ApiConfig.jwtToken`.
3. Khởi động lại app sau khi cài plugin mở link.
4. `main.dart` hiện mở trực tiếp màn Shipper. Nếu mở màn **Đơn hàng Shop**, có thể bấm **Tài xế** ở góc trên bên phải.

Màn Shipper có ba tab: **Chờ nhận**, **Đang giao** và **Đã giao**.

## Các API

- `GET /shipper/orders/available`: `data` là mảng, không tự thêm phân trang.
- `GET /shipper/orders/{id}`: lấy tên người nhận, địa chỉ, sản phẩm, ghi chú và hành trình.
- `PUT /shipper/orders/{id}/assign`: nhận đơn; không tự gửi lại khi lỗi.
- `GET /shipper/orders/my-deliveries?status=SHIPPING`: đơn đang giao của tài xế. Mảng rỗng được hỗ trợ; với mỗi bản ghi, chỉ cần ID rồi đọc API chi tiết.
- `GET /shipper/orders/my-deliveries?status=DELIVERED`: lịch sử đã giao của tài xế.
- `PUT /shipper/orders/{id}/delivered`: xác nhận giao thành công, không gửi body và không tự lặp khi timeout.

Danh sách được tải thêm chi tiết vì response available chưa có tên người nhận và shipperId. Tối đa 4 yêu cầu chi tiết chạy cùng lúc.

## Vị trí lấy hàng

`shopAddress` có thể là link Google Maps rút gọn. Nút **Mở vị trí lấy hàng** mở nguyên link API trả về bằng `url_launcher`. Đây là mở link bản đồ bên ngoài, không nhúng bản đồ trong app. Có nút sao chép nếu không mở được link.

Không tự suy đoán tên shop, địa chỉ dạng chữ, tọa độ hoặc khoảng cách từ link rút gọn. Chi tiết không có shopId vẫn đọc được.

## Trạng thái và lỗi

- Nhận đơn chỉ khi còn sẵn sàng lấy hàng và đã xác minh shipperId là null.
- `READY_TO_SHIP` và `READY_FOR_PICKUP` hiển thị cùng ý nghĩa chờ lấy hàng.
- Một khóa cho mỗi đơn được dùng chung ở danh sách và chi tiết.
- Sau PUT, đọc lại chi tiết và làm mới cả hai danh sách.
- Sau timeout, kiểm tra lại chi tiết. Nếu đang SHIPPING, dùng my-deliveries để phân biệt đơn của mình với đơn tài xế khác đã nhận.
- Nếu chưa kiểm tra lại được, chặn gửi tiếp và hiện nút kiểm tra trạng thái.
- Backend phải kiểm tra hãng vận chuyển, trạng thái và cập nhật nguyên tử khi nhiều tài xế cùng nhận. Kiểm thử giả lập không chứng minh các kiểm tra này đã hoạt động trên backend thật.

Nếu chạy Flutter Web, backend cần cho phép CORS đối với GET, PUT, OPTIONS và header Authorization từ origin của app.

## Xác nhận giao thành công

- Nút chỉ hiện ở đơn SHIPPING có shipperId, đồng thời xuất hiện trong danh sách đang giao của token hiện tại. Controller kiểm tra lại quyền và trạng thái trước khi gửi PUT.
- COD hiển thị grandTotal và bắt buộc tích xác nhận đã thu đủ tiền. WALLET nhắc không thu tiền.
- Khóa nút và chặn quay về trong khi xử lý. Bấm Quay lại trong hộp thoại không gọi API.
- Sau thành công, đọc lại chi tiết/hành trình, cập nhật danh sách đang giao và lịch sử đã giao.
- Sau timeout, kiểm tra trạng thái. Nếu đã DELIVERED, xác minh trong lịch sử của token trước khi báo thành công. Nếu không kiểm tra được, chỉ cho tải lại trạng thái trước khi thử tiếp.
- Không ghi số dư hay giao dịch COD từ FE. Chỉ invalidate các provider dữ liệu sau thao tác COD.

## Kết nối màn COD sau này

Màn COD riêng chưa được tạo trong phần này. Khi triển khai, watch `shipperCodBalanceProvider` và `shipperCodTransactionsProvider` trong `providers/shipper_cod_provider.dart`. Chúng đọc đúng hai endpoint balance/transactions và trả nguyên data; chưa suy đoán model giao dịch.

Các provider autoDispose tải mới khi mở màn; xác nhận giao COD sẽ invalidate cả hai để làm mới cả khi màn đã được mở. Backend chịu trách nhiệm ghi nhận tiền đúng một lần, chỉ đối với COD. Kiểm thử hiện dùng BE giả lập, chưa gửi delivered lên backend thật.
