# Đơn hàng Shipper

## Chạy thử

1. Đăng nhập tài khoản có vai trò SHIPPER bằng màn đăng nhập của app.
2. Mở menu tài khoản → **Kênh Shipper**. Tài khoản SELLER vào **Kênh người bán** để quản lý đơn của shop.
3. JWT được lấy từ phiên đăng nhập; `api_config.dart` chỉ giữ baseUrl, không nhập token thủ công.
4. `main.dart` mở trang chủ Customer. Phiên đã lưu được khôi phục khi mở lại app. Khi đăng xuất/đổi tài khoản, dữ liệu đơn/COD và trạng thái thao tác được tạo lại theo phiên mới; response phiên cũ không được cập nhật vào phiên mới.

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

## Quản lý và nộp tiền COD

Bấm biểu tượng ví **Tiền thu hộ COD** ở góc trên màn Shipper. Màn quản lý hiển thị tổng đã thu, tổng đã nộp và số tiền đang giữ từ API `GET /shipper/cod/balance`.

Lịch sử dùng `GET /shipper/cod/transactions`; bộ lọc Thu tiền/Nộp tiền gửi `type=COLLECTION` hoặc `type=REMITTANCE`. Tất cả không gửi type. Mỗi bộ lọc có state riêng để response cũ không ghi đè bộ lọc mới.

Nút **Nộp tiền COD** mở form số tiền và ghi chú. Nhập VND nguyên, không dùng dấu phân cách. Số tiền tối thiểu 1.000 VND, không vượt số dư mới nhất. Nếu số dư dưới mức tối thiểu, nút bị khóa và có giải thích. Hộp thoại xác nhận hiển thị đúng số tiền và ghi chú trước POST.

`POST /shipper/cod/remittance` nộp tiền COD về công ty vận chuyển, gửi JSON gồm amount dạng số và note bằng token Shipper. Công ty nhận tiền do backend xác định theo tài xế; không thêm shipCompanyId vào body.

Đã tích hợp response thành công mẫu: data là giao dịch COD, orderId có thể null. App kiểm tra type=REMITTANCE, status=COMPLETED và amount khớp số tiền gửi; sau đó hiển thị mã giao dịch, tải lại balance và transactions từ backend. Không tự sửa số dư. Response thiếu hoặc chưa xác nhận hoàn tất sẽ được kiểm tra lại qua số dư/lịch sử trước khi cho phép gửi tiếp. Lỗi 403 giữ nguyên form và dữ liệu nhập. Kiểm thử dùng response mẫu và backend giả lập; chưa thực hiện POST tiền thật từ app.

Các màn dùng model `CodBalance`, `CodTransaction` và provider `codBalanceProvider`, `codTransactionsProvider`. Xác nhận giao COD cũng invalidate các provider này. Provider data thô trước đó vẫn được giữ cho các luồng đã có.

### Khi timeout hoặc kết quả không rõ

App không tự gửi lại POST. Trước POST, app lưu ảnh chụp số dư và các ID giao dịch trong phiên. Khi không rõ kết quả, app đọc lại balance và transactions:

- Một REMITTANCE COMPLETED mới có cùng số tiền/ghi chú, cùng với tổng đã nộp tăng tương ứng: thông báo đã có giao dịch tương ứng và không gửi lại.
- Chưa xác định được: giữ nội dung form, khóa nút nộp, cho kiểm tra lại hoặc xem lịch sử. Đóng/mở form trong cùng phiên không xóa khóa.
- Từ chối rõ ràng như HTTP 400/401/403/422 hoặc status error: cho sửa/thử lại thủ công, không tự gửi lại.

Đối chiếu amount/note không phải mã idempotency của backend. Khóa hiện giữ trong phiên đăng nhập đang chạy, không bảo đảm qua việc đăng xuất/đổi tài khoản hoặc khởi động lại app. Để bảo đảm chống trùng giữa nhiều thiết bị/lần khởi động, backend cần hỗ trợ mã tham chiếu/idempotency và xử lý nguyên tử. Kiểm thử nộp tiền hiện dùng BE giả lập; không gửi tiền lên backend thật.

Nếu dùng Flutter Web, backend cần cho phép thêm POST và Content-Type trong cấu hình CORS.
