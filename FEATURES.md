# Chức năng và luồng hoạt động

Tài liệu mô tả ứng dụng Flutter trong project này và các API của backend được dùng làm nguồn dữ liệu. Backend tham khảo là project ASP.NET Core tại `C:\Nam4\KLCN\KhoaLuanCuNhan_QuanLyCuaHangDoChoiTreEm`; tài liệu này không yêu cầu ứng dụng truy cập database.

## 1. Kiến trúc tương tác

```text
Màn hình Flutter
    │ dữ liệu / thao tác JSON qua HTTPS hoặc HTTP local
    ▼
ApiClient (base URL, JWT Bearer, timeout, lỗi HTTP)
    │
    ▼
ToyStore ASP.NET Core API
    │ kiểm tra role, nghiệp vụ, dữ liệu và lưu trữ phía server
    ▼
Kết quả JSON trả về Flutter để hiển thị
```

- `ApiClient` tập trung tạo request, đính kèm JWT, giải mã JSON và chuyển lỗi HTTP thành thông báo dễ hiểu.
- `AppState` giữ phiên, dữ liệu cửa hàng và giỏ hàng trong bộ nhớ của ứng dụng.
- Không có kết nối SQL/EF Core ở Flutter; client không tự quyết định giá cuối, giảm giá, quyền hoặc trạng thái đơn.
- Các route quản trị trong màn hình “Quản lý” là màn hình tra cứu dữ liệu. API ghi/cập nhật chuyên biệt khác vẫn được backend bảo vệ theo quyền; chỉ các thao tác được nêu trong luồng tương ứng bên dưới mới có nút thao tác trong app.

## 2. Đăng nhập và phân quyền

1. Người dùng nhập email/mật khẩu hoặc đăng ký.
2. Ứng dụng gọi `POST /api/Auth/login` hoặc `POST /api/Auth/register`.
3. Token, thời hạn, tên người dùng và role do API trả về được giữ trong phiên; token được lưu bằng secure storage để khôi phục lần mở sau.
4. Giao diện chọn phân hệ theo role:
   - `Customer`: cửa hàng, đơn hàng, ưu đãi, tài khoản.
   - `Admin`, `Manager`, `Staff`: tổng quan, đơn hàng, quản lý.
   - `Shipper`: đơn giao, tài khoản.
5. Đăng xuất gọi `POST /api/Auth/logout` rồi xóa phiên cục bộ.
6. API vẫn là nơi thực thi RBAC. Việc phân nhánh giao diện không thay thế xác thực/ủy quyền phía server.

API liên quan:

- `POST /Auth/register`, `/Auth/login`, `/Auth/logout`
- `POST /Auth/forgot-password`, `/Auth/reset-password`, `/Auth/change-password`
- `GET /Auth/users`, `POST /Auth/assign-role`, `POST /Auth/users/{userId}/toggle-status` (Admin)

## 3. Khách hàng

### 3.1 Cửa hàng và sản phẩm

1. Màn hình cửa hàng gọi đồng thời `GET /api/Product` và `GET /api/Category`.
2. Ứng dụng ẩn trạng thái sản phẩm ngừng bán/không hiển thị, rồi cho tìm theo tên/thương hiệu và lọc theo danh mục.
3. Thẻ sản phẩm hiển thị ảnh từ `imageUrl`, tên, danh mục và giá do API trả về.
4. Khi thêm sản phẩm vào giỏ, ứng dụng lấy chi tiết nếu danh sách chưa có biến thể; nếu API không trả biến thể, dùng mã sản phẩm theo quy ước tương thích với giao diện web hiện tại.

API dùng: `GET /Product`, `GET /Product/{id}`, `GET /Category`.

### 3.2 Giỏ hàng và đặt đơn

1. Người dùng thêm/bớt số lượng trong giỏ hàng tạm thời trên client.
2. Màn hình checkout tải `GET /Customer/profile` để điền trước tên/số điện thoại; người dùng bổ sung người nhận và địa chỉ giao hàng.
3. Ứng dụng gửi `POST /Order` với `orderDetails` (variant ID, quantity), `shipping`, `paymentMethod`, `voucherCode` và `note`.
4. Client không gửi tổng tiền hoặc số tiền giảm. Máy chủ tính lại giá, phí và voucher, kiểm tra hồ sơ khách hàng, lưu đơn và trả kết quả.
5. Sau khi API tạo đơn thành công, giỏ hàng được xóa để tránh gửi lặp đơn; trạng thái thanh toán được hiển thị rõ.

Phương thức thanh toán trong app:

- `0` — COD: tạo đơn và hiển thị xác nhận.
- `1` — Chuyển khoản: tạo đơn chờ thanh toán. Backend hiện chưa có API trả thông tin tài khoản/mã QR hoặc xác minh/đối soát giao dịch; app không thể tự xác nhận đã nhận tiền, nên hướng dẫn khách liên hệ cửa hàng.
- `2` — ZaloPay: gọi `POST /ZaloPay/orders/{orderId}/create`, mở `orderUrl` do API trả về và cho phép truy vấn `GET /ZaloPay/orders/{orderId}/status`. Đơn chưa trả tiền vẫn có nút tiếp tục thanh toán trong danh sách đơn.
- Nút xác nhận mô phỏng gọi `POST /ZaloPay/orders/{orderId}/confirm-sandbox-payment`; chỉ hoạt động khi server đang cấu hình Sandbox. Đây không phải xác nhận thật khi chạy Production.

API dùng: `GET /Customer/profile`, `POST /Order`, các endpoint `ZaloPay` nêu trên.

### 3.3 Đơn hàng, điểm thưởng và hồ sơ

- Tab đơn hàng tải danh sách cá nhân bằng `GET /Order/mine`; mỗi đơn hiển thị mã, trạng thái, tổng tiền và thông tin giao hàng có trong response.
- Ưu đãi tải điểm/lịch sử bằng `GET /LoyaltyTransaction/summary`; khách có thể đổi voucher đủ điều kiện qua `POST /LoyaltyTransaction/redeem/{voucherId}`.
- Danh sách voucher khả dụng tải qua `GET /Voucher/available`; tại checkout khách chọn mã để gửi cùng đơn. Server kiểm tra điều kiện, mức giảm và giới hạn sử dụng.
- Hồ sơ tải/lưu qua `GET /Customer/profile` và `PUT /Customer/profile`.
- Sổ địa chỉ hỗ trợ xem/thêm/sửa/xóa qua `GET|POST /Customer/profile/addresses`, `PUT|DELETE /Customer/profile/addresses/{addressId}`.
- Đổi mật khẩu gọi `POST /Auth/change-password`.
- Khách hàng tra cứu yêu cầu bằng `GET /ReturnRequest/mine`. Tạo yêu cầu qua `POST /ReturnRequest`; app chỉ cho chọn đơn đã hoàn tất trong vòng 7 ngày và giới hạn số lượng theo số lượng còn được phép trả (trừ các yêu cầu đang chờ/đã duyệt/đã nhận).

### 3.4 Đổi trả

1. Khách hàng mở “Yêu cầu đổi trả”; ứng dụng tải đơn của khách và các yêu cầu trước đó.
2. Chỉ đơn có trạng thái hoàn tất, đã giao trong 7 ngày mới được chọn. Người dùng chọn mặt hàng/số lượng, lý do, mô tả và URL ảnh minh chứng nếu có.
3. API tiếp tục kiểm tra quyền, thời hạn và dữ liệu khi nhận yêu cầu. Số tiền hoàn do cửa hàng xác nhận; app không tự thanh toán tiền hoàn.
4. Khách hàng theo dõi các trạng thái: chờ duyệt, đã duyệt/chờ nhận, từ chối, kho đã nhận hoặc đã hủy.
5. Nhân viên/Admin/Quản lý duyệt hoặc từ chối bằng `PUT /ReturnRequest/{id}`. Chỉ sau khi hàng hoàn thực sự vào kho mới dùng `POST /ReturnRequest/{id}/receive`; thao tác này có thể cập nhật tồn kho.

API dùng: `GET /Order/mine`, `GET /ReturnRequest/mine`, `POST /ReturnRequest`, `PUT /ReturnRequest/{id}`, `POST /ReturnRequest/{id}/receive`.

### 3.5 Chat hỗ trợ

1. App gọi `POST /SupportChat/mine` để lấy hoặc tạo hội thoại.
2. Tin nhắn được đọc bằng `GET /SupportChat/{conversationId}/messages`.
3. Gửi tin nhắn bằng `POST /SupportChat/{conversationId}/messages`.
4. Màn hình khách hàng làm mới tin nhắn định kỳ qua REST API. Nhân viên dùng hộp thư để tiếp nhận hội thoại, đánh dấu đã đọc và trả lời; danh sách cập nhật định kỳ. Backend có SignalR Hub nhưng Flutter hiện chưa mở kết nối Hub realtime.

## 4. Nhân viên, quản lý và Admin

### 4.1 Dashboard

- Gọi `GET /Dashboard/summary` và `GET /Dashboard/inventory`.
- Dashboard hiện các chỉ số doanh thu, đơn hàng và cảnh báo/tồn kho tương ứng với các trường backend trả về.
- Liên kết nhanh tra cứu báo cáo, điều phối giao hàng và CSKH.

### 4.2 Đơn hàng

- Danh sách nhân viên lấy từ `GET /Order`; thẻ chỉ tóm tắt khách hàng, trạng thái và tổng tiền. Mở rộng để xem số điện thoại, địa chỉ và phương thức thanh toán; không đưa mã đơn kỹ thuật lên danh sách.
- Mở “Chi tiết và theo dõi” để tải `GET /Order/{id}` và xem từng sản phẩm, thuộc tính biến thể/SKU, số lượng, giá, tổng tiền, thanh toán và thông tin giao nhận. Nhật ký quy trình gọi `GET /Order/{id}/tracking-logs`, hiển thị thao tác, trạng thái trước/sau, người thực hiện, ghi chú và thời gian.
- Khách hàng có thể hủy đơn trước khi shipper lấy hàng: trạng thái đơn từ `0` đến `3`, chưa có `shippedAt`, trạng thái giao hàng nhỏ hơn `2`. App xác nhận trước khi gọi `POST /Order/{id}/cancel`; server kiểm tra lại quyền và điều kiện nghiệp vụ. Nếu đơn đã thanh toán, API hướng dẫn liên hệ cửa hàng để đối soát hoàn tiền.
- Khi đơn ở trạng thái `3` (đang giao), khách có thể xác nhận đã nhận hàng sau bước xác nhận trong app; app gọi `POST /Order/{id}/complete-delivery`, sau đó tải lại chi tiết, nhật ký và danh sách. Đây là xác nhận của khách, không thay thế bước shipper xác nhận giao thành công mà backend yêu cầu.
- Nhân viên có thể tìm theo tên/số điện thoại và lọc trạng thái. Từ chi tiết thẻ, Admin/Manager/Staff chọn bước xử lý kế tiếp hoặc hủy đơn; app không cho nhảy bước. Các trạng thái hiển thị theo backend: `0` chờ xác nhận → `1` đã xác nhận → `2` đang xử lý → `3` đang giao → `4` hoàn tất; `5` đã hủy.
- Chỉ hiện lựa chọn hoàn tất khi thông tin giao hàng có trạng thái giao thành công (`shipping.status == 4`), đúng điều kiện API. Mọi thay đổi gọi `PUT /Order/{orderId}` và chờ server xác nhận; API từ chối thì app giữ nguyên dữ liệu và hiển thị lỗi.

### 4.3 Danh mục và nhà cung cấp

- Admin/Manager quản lý danh mục bằng `GET /Category`, tạo `POST /Category`, sửa `PUT /Category/{id}` (tên, mô tả, `isActive`), xóa `DELETE /Category/{id}`. Có thể mở danh sách sản phẩm theo danh mục qua `GET /Product?categoryId={id}`.
- Admin/Manager quản lý nhà cung cấp bằng `GET /Supplier`, tạo/sửa qua `POST /Supplier` và `PUT /Supplier/{id}`. Thông tin gồm tên, điện thoại, email, địa chỉ, mã số thuế và tình trạng hoạt động. `DELETE /Supplier/{id}` được backend xử lý như vô hiệu hóa; sản phẩm liên kết xem qua `GET /Supplier/{id}/products`.
- Admin/Manager quản lý thương hiệu bằng `GET /Brand`, tạo `POST /Brand`, sửa `PUT /Brand/{id}` (tên, mô tả, `isActive`) và xóa `DELETE /Brand/{id}`. Có thể tra cứu sản phẩm theo thương hiệu qua `GET /Product?brandId={id}`.
- Các form yêu cầu xác nhận thao tác phá hủy/vô hiệu hóa, hiển thị lỗi API và tải lại dữ liệu sau khi lưu. Backend vẫn kiểm tra role và ràng buộc dữ liệu.

### 4.4 Tra cứu phân hệ

Tab “Nghiệp vụ cửa hàng” ưu tiên các thao tác thường dùng, nhóm các chức năng tra cứu bên dưới và cho tìm chức năng. Kết quả API dạng danh sách có ô tìm kiếm, lọc trạng thái, số lượng mục và nút xem thêm; mỗi thẻ chỉ tóm tắt các thông tin chính, chi tiết được thu gọn. Mã kỹ thuật như ID, mã đơn, mã phiếu, SKU và token được ẩn khỏi phần trình bày.

Các nhóm tra cứu API:

| Nhóm | API được tra cứu |
|---|---|
| Sản phẩm | `Product`, `Category`, `Brand`, `Supplier`, `Promotion`, `Voucher` |
| Kho và nhập hàng | `Inventory`, `InventoryTransaction`, `ImportReceipt`, `Liquidation`, `ManagementReport/inventory` |
| Khách hàng | `Customer`, `CustomerFeedback`, `LoyaltyTransaction`, `ReturnRequest`, `Notification` |
| Thanh toán và báo cáo | `Dashboard/financial-report`, `Dashboard/orders`, `Dashboard/best-selling`, `Payment` |
| Giao hàng và thu tiền | `Shipping`, `Shipper`, `ManagementReport/collections` |

Các màn hình này hiển thị dữ liệu API theo thẻ và phần chi tiết có thể mở rộng; lỗi 401/403 từ server không bị thay bằng dữ liệu mẫu.

### 4.5 Biểu mẫu nghiệp vụ

- **Sản phẩm** (Admin/Quản lý): tìm và lọc theo danh mục/trạng thái; tạo/sửa thông tin, trạng thái, thương hiệu, nhà cung cấp, ảnh và biến thể. Có thể tạo tổ hợp theo tối đa hai thuộc tính với giới hạn 100 biến thể, quản lý SKU/giá/trọng lượng/ảnh/trạng thái từng biến thể, cấu hình nhiều nhà cung cấp cùng giá tham khảo/mã hàng riêng và đánh dấu nhà cung cấp mặc định. Ảnh được tải qua `POST /Upload/image`; dữ liệu được gửi qua API `Product`.
- **Nhập kho** (Admin/Quản lý): tạo phiếu nháp/chờ nhập với nhà cung cấp, ngày, ghi chú, sản phẩm/biến thể, số lượng và giá; tìm/lọc phiếu; sửa hoặc hủy theo trạng thái. Trước khi xác nhận nhận hàng, người dùng kiểm tra số lượng và giá bán mới. API `POST /ImportReceipt/{id}/approve` chỉ được gọi sau xác nhận trực quan rằng kho thực nhận hàng; máy chủ cập nhật tồn kho.
- **Khuyến mãi/voucher** (Admin/Quản lý): CRUD chương trình, cấu hình kiểu/mức giảm, thời hạn, trạng thái và giới hạn voucher; chương trình khuyến mãi có thể thêm/gỡ biến thể sản phẩm và thêm/xóa điều kiện đơn tối thiểu, số lượng, danh mục hoặc thương hiệu. Voucher có thể đặt điểm đổi, đơn tối thiểu, lượt dùng tổng/mỗi khách; lịch sử sử dụng đọc từ response API.
- **Điểm thưởng** (Khách hàng): xem điểm/voucher đổi được, đổi điểm có xác nhận và xem tối đa 20 giao dịch mới nhất do API summary cung cấp. Voucher khả dụng được chọn tại checkout; backend vẫn xác thực điều kiện.
- **Tồn kho/thanh lý** (Admin/Quản lý): xem tồn thực tế/đang giữ/có thể bán; tạo hoặc điều chỉnh bản ghi tồn (không cho lượng giữ vượt tồn). Phiếu thanh lý chỉ cho chọn phiên bản còn hàng khả dụng; `POST /Liquidation` lập phiếu chờ, `POST /Liquidation/{id}/complete` xác nhận xuất và giảm tồn, `POST /Liquidation/{id}/cancel` hủy phiếu chờ.
- **Khách hàng quản trị** (Admin/Quản lý): tìm kiếm/lọc tình trạng; sửa hồ sơ gồm tên, điện thoại, email, địa chỉ, ngày sinh, giới tính và trạng thái; danh sách hiển thị tóm tắt điểm, tổng đơn và chi tiêu.
- **Người dùng và phân quyền** (Admin): tìm kiếm tài khoản, gán vai trò `Customer`, `Staff`, `Manager`, `Admin` hoặc `Shipper`; bật/tắt tài khoản sau xác nhận. Đây là API quản trị tài khoản, không có thao tác tạo user mới.
- **Duyệt đổi trả** (nhân viên/Admin/Quản lý): tìm/lọc theo khách, mặt hàng, trạng thái; xem lý do, mô tả, ảnh và số tiền; duyệt/từ chối với ghi chú và số tiền hoàn; xác nhận nhận hàng hoàn riêng.
- **Chat nhân viên**: hộp thư gọi `GET /SupportChat`, mở hội thoại lấy messages, tiếp nhận hội thoại, đánh dấu đã đọc và gửi tin nhắn qua các endpoint `SupportChat`. App làm mới dữ liệu qua REST polling, chưa dùng SignalR.
- **Điều phối giao hàng** (Admin/Quản lý/Nhân viên): xem gợi ý lô theo khoảng cách; chọn đơn để gộp hoặc dùng gợi ý; gán/đổi shipper; xuất giao cả lô sau bước xác nhận; tách đơn chưa xuất kho; và chọn shipper để giao lại đơn thất bại. Các thao tác gọi `GET /Shipping/batch-suggestions`, `POST /Shipping/merge-batch`, `POST /Shipper/assign-order`, `POST /Shipping/dispatch-batch/{batchCode}`, `POST /Shipping/unbatch-order/{orderId}` và `POST /Shipper/orders/{orderId}/retry-delivery`. Gộp, phân công và xuất giao là nhiều request nối tiếp; nếu request sau lỗi, request trước có thể đã được máy chủ ghi nhận, app tải lại để phản ánh trạng thái và không giả lập rollback.
- **Quản lý shipper** (Admin/Quản lý): tạo/sửa hồ sơ, thông tin xe/khu vực, tùy chọn thông tin tạo tài khoản, và vô hiệu hóa hồ sơ qua API `Shipper`. Danh sách thể hiện các chỉ số đang xử lý/đã giao/COD giữ. Staff có thể xem và phân công trong điều phối; backend tiếp tục thực thi quyền cho từng endpoint.
- **Đối soát COD**: Shipper báo nộp COD sau khi giao thành công. Admin/Quản lý/Nhân viên lọc khoản COD theo shipper/trạng thái, chọn các khoản đang chờ cửa hàng kiểm tra và xác nhận sau khi đếm tiền. App yêu cầu số nhận thực tế khớp tổng tiền hàng phải nộp (tiền COD trừ phí giao), gửi `POST /Shipper/confirm-cod-submission`; API chỉ chấp nhận khoản ở trạng thái chờ xác nhận và kiểm tra lại số tiền.
- **Thu tiền** (Admin/Quản lý/Nhân viên): chọn khoảng ngày, xem tổng online/COD/thực thu/doanh thu và danh sách giao dịch do `GET /ManagementReport/collections?from=...&to=...` cung cấp. Đây là báo cáo theo dữ liệu backend; ứng dụng không tự tính hoặc cập nhật sổ quỹ.
- **Thông báo khách hàng**: biểu tượng chuông trên thanh ứng dụng mở danh sách voucher đang khả dụng từ `GET /Notification/customer-vouchers`, gồm tên/mã, hạn dùng, đơn tối thiểu và lượt còn lại. Danh sách được tải lại khi mở màn hình hoặc kéo xuống làm mới.
- **Thông báo nhân viên**: Admin/Quản lý/Nhân viên mở từ biểu tượng chuông hoặc mục “Thông báo hệ thống”; app hiển thị tối đa 50 biến động trong 7 ngày qua từ `GET /Notification/staff` và tự tải lại mỗi 10 giây khi màn hình mở. Các mục mới phát hiện trong phiên hiện tại được báo qua SnackBar. API không cung cấp trạng thái đã đọc nên danh sách không giả định mục nào đã đọc.

API quản trị thực thi quyền và kiểm tra dữ liệu; giao diện giới hạn thao tác theo vai trò để giảm nhầm lẫn nhưng không thay thế RBAC phía server. Backend hiện chỉ có thêm/xóa điều kiện khuyến mãi, chưa có endpoint sửa điều kiện; app cũng không cung cấp thao tác sửa trực tiếp cho điều kiện đã tạo.

## 5. Shipper

1. Danh sách được phân công: `GET /Shipper/my-orders`.
2. Với từng mã đơn, ứng dụng gửi các thao tác theo trình tự backend hỗ trợ:
   - `POST /Shipper/orders/{orderId}/accept-order`
   - `POST /Shipper/orders/{orderId}/pickup`
   - `POST /Shipper/orders/{orderId}/start-delivery`
   - `POST /Shipper/orders/{orderId}/complete-delivery`
   - `POST /Shipper/orders/{orderId}/fail-delivery` kèm lý do giao thất bại
3. Sau thao tác thành công, danh sách được tải lại từ server. Nếu sai trình tự/trạng thái, lỗi nghiệp vụ do API trả về sẽ được hiển thị.
4. Với đơn COD đã giao thành công, shipper xác nhận đã báo nộp tiền bằng `POST /Shipper/orders/{orderId}/submit-cod`; khoản tiền được đánh dấu chờ cửa hàng kiểm đếm, chưa được xem là đã vào quỹ.
5. Màn hình tóm tắt số đơn đang xử lý/đã giao và COD đang giữ; shipper chỉ có thể thực hiện bước kế tiếp hợp lệ cho từng đơn.
6. Tra cứu đối soát COD: `GET /Shipper/cod-reconciliation`.

## 6. Điều phối giao hàng và thu tiền

- Tab Điều phối tải đơn, danh sách shipper và gợi ý lô với bán kính có thể điều chỉnh. Người dùng có thể gộp theo gợi ý hoặc chọn thủ công, phân công shipper và xuất giao cả lô; xuất giao có xác nhận vì API đổi trạng thái toàn bộ đơn trong lô.
- Đơn chưa xuất có thể được tách khỏi lô; đơn giao thất bại có thể được giao lại cho shipper được chọn. Việc này chỉ gọi API server và tải lại dữ liệu sau thao tác.
- Tab Shipper quản lý hồ sơ theo quyền Admin/Manager, gồm tạo/sửa/vô hiệu hóa; thao tác xóa được backend xử lý như vô hiệu hóa. Tài khoản đăng nhập tùy chọn phụ thuộc xử lý của API tạo hồ sơ.
- Tab COD lọc theo shipper/trạng thái, hiển thị tiền khách trả, phí giao và phần cửa hàng cần thu. Khi xác nhận một/nhiều khoản đang chờ, giá trị thực nhận phải bằng chính xác tổng phần cửa hàng cần thu; phí giao không tính vào khoản nộp.
- Tab Thu tiền dùng khoảng ngày và endpoint `ManagementReport/collections`; các số tổng và giao dịch là dữ liệu báo cáo do API trả về.

## 7. API backend tham khảo theo phân hệ

Các controller dưới đây tồn tại trong backend web; ứng dụng chỉ gọi những endpoint đã được nối vào từng màn hình.

| Controller | API/nghiệp vụ |
|---|---|
| `Auth` | Đăng ký/đăng nhập/đăng xuất, khôi phục/đổi mật khẩu, danh sách tài khoản và phân quyền |
| `Product` | Danh sách/chi tiết, lọc, CRUD sản phẩm và biến thể |
| `Category`, `Brand`, `Supplier` | Danh mục, thương hiệu, nhà cung cấp |
| `Customer` | Profile, CRUD khách hàng, sổ địa chỉ |
| `Order` | Danh sách/chi tiết/mine, tạo/hủy, thanh toán, vận chuyển, tracking |
| `Payment`, `ZaloPay` | Thanh toán và tích hợp cổng ZaloPay |
| `Dashboard`, `ManagementReport` | Tổng quan, doanh thu, đơn hàng, tồn kho, báo cáo quản lý |
| `Inventory`, `InventoryTransaction` | Tồn kho và lịch sử giao dịch kho |
| `ImportReceipt`, `Liquidation` | Phiếu nhập, nhận/duyệt/hủy và thanh lý hàng |
| `Shipping`, `Shipper` | Gợi ý/điều phối lô giao, phân công shipper, các bước giao và COD |
| `Promotion`, `Voucher`, `Notification` | Khuyến mãi, voucher, thông báo |
| `LoyaltyTransaction` | Tra cứu điểm, lịch sử và đổi voucher |
| `CustomerFeedback`, `ProductReview` | Phản hồi khách hàng và đánh giá sản phẩm |
| `ReturnRequest` | Tạo/theo dõi/duyệt yêu cầu đổi trả |
| `SupportChat` | Hội thoại, tin nhắn, đánh dấu đã đọc, tiếp nhận hội thoại |
| `Upload`, `Health` | Upload tài nguyên và kiểm tra trạng thái API |

Backend cũng cung cấp SignalR hubs `/hubs/support-chat` và `/hubs/order-tracking`; Flutter bản hiện tại dùng REST cho các luồng trên.

## 8. Trạng thái giao diện và giới hạn

- Không có dữ liệu: hiển thị empty state, không dùng dữ liệu demo.
- Lỗi mạng/API: hiển thị thông báo từ máy chủ hoặc thông báo lỗi kết nối và nút thử lại.
- Role không đủ quyền: hiển thị phản hồi 403; thao tác không được thực hiện.
- Chuyển khoản ngân hàng chưa thể xác nhận trong app vì backend chưa có API thông tin tài khoản/QR và API kiểm tra giao dịch.
- ZaloPay cần backend được cấu hình thông tin cổng hợp lệ và truy cập được; xác nhận mô phỏng chỉ dành cho Sandbox, không thay thế đối soát giao dịch Production.
- Chat tải lại theo chu kỳ khoảng 10 giây; chưa dùng SignalR client.
- Điều phối theo lô là chuỗi request REST, không có API giao dịch/rollback cho gộp → phân công → xuất giao. Nếu một bước sau thất bại, bước trước có thể vẫn thành công; cần tải lại và xử lý tiếp theo trạng thái server.
- Theo dõi GPS trực tiếp, bản đồ lộ trình và cập nhật tức thời SignalR chưa được triển khai; màn hình điều phối hiện dùng trạng thái và gợi ý lô từ REST API.
- NotificationController chỉ cung cấp hai endpoint GET voucher khách hàng và biến động hệ thống nhân viên. Không có API tạo/gửi thông báo tùy chỉnh theo đối tượng, đánh dấu đã đọc hoặc xóa; do đó mobile chỉ triển khai các luồng đọc đúng như web, không thể cung cấp form gửi thông báo cho nhân viên/khách hàng nếu backend chưa bổ sung API và phân quyền tương ứng.
- API tạo shipper có thể vẫn lưu hồ sơ dù tạo tài khoản đăng nhập tùy chọn thất bại; nếu endpoint chỉ trả kết quả thành công cho hồ sơ, mobile không có cách xác minh riêng trạng thái tài khoản. Cần backend trả kết quả tạo tài khoản tường minh để xử lý hoàn chỉnh.
- Các thao tác thay đổi dữ liệu chỉ gọi API. Không có thao tác nào của Flutter truy cập hoặc ghi trực tiếp database.
