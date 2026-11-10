# ToyStore Mobile

Ứng dụng Flutter đa nền tảng cho hệ thống quản lý cửa hàng đồ chơi trẻ em. Ứng dụng giao tiếp với ASP.NET Core Web API qua HTTP/JSON; không kết nối trực tiếp, không đọc và không ghi vào cơ sở dữ liệu.

## Tính năng

- Đăng nhập, đăng ký, khôi phục mật khẩu và đổi mật khẩu qua API.
- Giao diện theo vai trò được trả về từ máy chủ: `Customer`, `Admin`, `Manager`, `Staff`, `Shipper`.
- Khách hàng: xem/tìm sản phẩm, lọc danh mục, giỏ hàng, đặt đơn COD/chuyển khoản/ZaloPay, theo dõi đơn và thanh toán ZaloPay đang chờ, điểm thưởng/voucher, cập nhật hồ sơ, sổ địa chỉ, yêu cầu đổi trả và chat CSKH.
- Admin/Quản lý: CRUD sản phẩm và biến thể, tải ảnh sản phẩm lên API, lập phiếu nhập và xác nhận hàng đã nhận, duyệt/từ chối đổi trả và xác nhận kho nhận hàng hoàn.
- Admin/Quản lý: CRUD danh mục, nhà cung cấp, thương hiệu; tra cứu sản phẩm liên kết, vô hiệu hóa hoặc xóa theo API.
- Khách hàng: xem điểm và lịch sử, đổi điểm lấy voucher, chọn voucher áp dụng tại bước đặt hàng.
- Admin/Quản lý: quản lý khuyến mãi/voucher, điều kiện/sản phẩm áp dụng, điều chỉnh tồn và lập/xác nhận/hủy phiếu thanh lý.
- Admin/Quản lý: tìm kiếm, lọc và cập nhật hồ sơ/trạng thái khách hàng; Admin quản lý người dùng, vai trò và trạng thái tài khoản.
- Admin/Quản lý/Nhân viên: điều phối giao hàng theo gợi ý hoặc chọn đơn, gán/đổi shipper, xuất giao cả lô, tách đơn chờ xuất và giao lại đơn thất bại.
- Admin/Quản lý: quản lý hồ sơ shipper và theo dõi số đơn/COD; Shipper xử lý từng bước giao hàng, báo nộp COD; nhân viên xác nhận COD và xem báo cáo thu tiền/doanh thu theo ngày.
- Khách hàng xem thông báo voucher đang khả dụng; nhân viên xem biến động hệ thống gần đây và nhận cập nhật khi màn hình thông báo đang mở. Gửi thông báo tùy chỉnh chưa khả dụng do backend chưa có API.
- Khách hàng: xem chi tiết mặt hàng/biến thể, nhật ký vận chuyển, hủy đơn khi còn điều kiện và xác nhận đã nhận hàng.
- Nhân viên/Quản lý/Admin: xử lý đơn theo từng bước hợp lệ hoặc hủy đơn trước khi kết thúc.
- Nhân viên/Quản lý/Admin: dashboard, đơn hàng có tìm kiếm/lọc trạng thái, hộp thư chat hỗ trợ; danh sách tra cứu có tìm kiếm, lọc trạng thái và ẩn mã kỹ thuật.
- Shipper: xem đơn được phân công, cập nhật từng bước giao hàng, báo giao thất bại và xem đối soát COD.
- Giao diện tiếng Việt, ưu tiên thao tác ngắn, thẻ tóm tắt và mở rộng chi tiết khi cần; có trạng thái tải, lỗi API, danh sách rỗng và làm mới dữ liệu.

Mô tả chi tiết chức năng và luồng nghiệp vụ: [FEATURES.md](./FEATURES.md).
Đối chiếu các chức năng web chưa được mobile hỗ trợ đầy đủ: [COMPARE.md](./COMPARE.md).

## Công nghệ và cấu trúc

- Flutter / Dart, Material 3.
- `http` cho REST API; `flutter_secure_storage` lưu phiên; `intl` định dạng tiền; `file_picker` chọn ảnh; `url_launcher` mở cổng thanh toán ZaloPay.
- Mã nguồn chia theo lớp:

```text
lib/
  core/
    api_client.dart      # HTTP, JWT Bearer, phân tích lỗi API
    app_state.dart       # Phiên đăng nhập, catalog, giỏ hàng, đơn hàng
  ui/
    app_screens.dart     # Giao diện khách hàng, đơn hàng và tra cứu
    admin_workflows.dart # Form sản phẩm, nhập kho, đổi trả, chat
    admin_management.dart # Khuyến mãi, tồn kho, thanh lý, khách hàng, người dùng
    delivery_management.dart # Điều phối giao hàng, shipper, COD, báo cáo thu tiền
    notifications.dart  # Thông báo voucher khách hàng và biến động hệ thống
  main.dart              # Khởi tạo ứng dụng, theme và phiên
test/
  widget_test.dart
```

## Yêu cầu

- Flutter SDK có Dart `3.10.7` trở lên.
- Backend ToyStore API đang chạy và truy cập được từ thiết bị chạy Flutter.
- Với Android emulator, cho phép emulator truy cập máy phát triển qua `10.0.2.2`.

## Cài đặt và chạy

Tại thư mục project web KhoaLuanCuNhan_QuanLyCuaHangDoChoiTreEm:
- Khởi chạy project (hoặc khởi chạy riêng server)

Tại thư mục project này:

```powershell
flutter pub get
flutter run
```

Mặc định API base URL được chọn theo nền tảng:

| Nền tảng | API mặc định |
|---|---|
| Android emulator | `http://10.0.2.2:5225/api` |
| Windows, iOS simulator, Linux, macOS, Web | `http://localhost:5225/api` |

Có thể ghi đè bằng compile-time define `API_BASE_URL`. Có thể truyền URL gốc của server hoặc URL kết thúc bằng `/api`:
Trên Android emulator, `localhost`, `127.0.0.1` và `::1` trong cấu hình sẽ được chuyển thành `10.0.2.2` để truy cập máy phát triển.

```powershell
# Windows desktop
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5225/api

# Android emulator
flutter run -d <device-id> --dart-define=API_BASE_URL=http://10.0.2.2:5225/api

# Thiết bị thật: thay địa chỉ bằng IP LAN của máy chạy backend
flutter run -d <device-id> --dart-define=API_BASE_URL=http://192.168.1.10:5225/api

# Web
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5225/api
```

Nếu dùng Flutter Web, cấu hình CORS của backend phải cho phép origin của ứng dụng web. Với thiết bị thật, backend và thiết bị cần cùng mạng, đồng thời firewall phải cho phép cổng API.

### Cấu hình môi trường triển khai

- Không đưa URL môi trường triển khai, khóa bí mật hoặc tài khoản thật vào mã nguồn.
- Truyền `API_BASE_URL` riêng cho từng môi trường build.
- Android manifest hiện bật cleartext để hỗ trợ server HTTP local trong quá trình phát triển. Bản phát hành nên dùng HTTPS và tắt cleartext traffic.
- JWT được lưu bằng `flutter_secure_storage`; quyền truy cập API vẫn được backend kiểm tra, không dựa vào việc ẩn/hiện nút trong giao diện.

## Kiểm tra chất lượng

```powershell
dart format lib test
flutter analyze
flutter test
```

Widget test hiện kiểm tra chuyển đổi giữa màn hình đăng nhập và đăng ký. Các API cần backend đang hoạt động để kiểm tra thủ công luồng nghiệp vụ.

## Nguyên tắc tích hợp API

- REST API được gọi tại `lib/core/api_client.dart`; token được gửi bằng header `Authorization: Bearer`.
- Các API thao tác dữ liệu đều đi qua máy chủ. Ứng dụng không dùng Entity Framework, SQL Server, connection string hay truy cập database.
- Mã lỗi HTTP và thông báo do API trả về được hiển thị rõ trong ứng dụng.
- Danh sách sản phẩm/danh mục công khai được tải từ `Product` và `Category`; thông tin đơn hàng, profile, voucher, báo cáo và giao hàng lấy theo API dành cho vai trò hiện tại.
- Đơn hàng chỉ gửi mã biến thể, số lượng, thông tin giao hàng, phương thức thanh toán và mã voucher; máy chủ là nơi xác thực quyền, giá, giảm giá và trạng thái đơn.
- Phương thức thanh toán: `0` COD, `1` chuyển khoản, `2` ZaloPay. API hiện chưa cung cấp thông tin tài khoản/mã QR hoặc xác minh chuyển khoản nên app chỉ ghi nhận đơn chờ thanh toán và hướng dẫn liên hệ cửa hàng. ZaloPay sử dụng API tạo giao dịch/truy vấn trạng thái; xác nhận mô phỏng chỉ khả dụng khi backend chạy Sandbox.
- Tạo yêu cầu đổi trả chỉ áp dụng đơn đã hoàn tất trong 7 ngày; duyệt và xác nhận kho nhận hàng gọi API riêng, không cập nhật tồn kho trực tiếp từ app.

## Tham khảo

Backend và giao diện web tham khảo nằm ngoài project Flutter tại `C:\Nam4\KLCN\KhoaLuanCuNhan_QuanLyCuaHangDoChoiTreEm`. Không có file nào trong project tham khảo bị thay đổi.
