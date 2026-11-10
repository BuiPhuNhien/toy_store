import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import 'admin_management.dart';
import 'admin_workflows.dart';
import 'delivery_management.dart';
import 'notifications.dart';

const _rose = Color(0xFFE11D48);
const _ink = Color(0xFF20212A);
const _muted = Color(0xFF777681);
final _money = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

String money(dynamic value) {
  final amount = value is num ? value : num.tryParse('$value') ?? 0;
  return _money.format(amount);
}

String displayValue(dynamic value) {
  if (value == null || value.toString().isEmpty) return '—';
  if (value is num && value == value.toInt()) return '$value';
  return value.toString();
}

void showNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.state, super.key});

  final AppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      if (_register) {
        await widget.state.register(
          fullName: _name.text,
          email: _email.text,
          phone: _phone.text,
          password: _password.text,
        );
      } else {
        await widget.state.login(_email.text, _password.text);
      }
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    } catch (error) {
      if (mounted) showNotice(context, 'Đăng nhập thất bại: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: AnimatedBuilder(
                    animation: widget.state,
                    builder: (context, _) => Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CircleAvatar(
                            radius: 32,
                            backgroundColor: Color(0xFFFFE4E9),
                            child: Icon(
                              Icons.toys_rounded,
                              color: _rose,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _register
                                ? 'Tạo tài khoản mới'
                                : 'Chào mừng đến ToyStore',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _register
                                ? 'Đăng ký để mua sắm và theo dõi đơn hàng.'
                                : 'Đăng nhập để tiếp tục mua sắm hoặc quản lý cửa hàng.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _muted),
                          ),
                          const SizedBox(height: 26),
                          if (_register) ...[
                            _textField(
                              _name,
                              'Họ và tên',
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 12),
                            _textField(
                              _phone,
                              'Số điện thoại',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _textField(
                            _email,
                            'Email',
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) =>
                                value == null || !value.contains('@')
                                ? 'Nhập email hợp lệ'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                (value == null || value.length < 6)
                                ? 'Mật khẩu cần ít nhất 6 ký tự'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: widget.state.busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: _rose,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: widget.state.busy
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_register ? 'Đăng ký' : 'Đăng nhập'),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _register = !_register),
                            child: Text(
                              _register
                                  ? 'Đã có tài khoản? Đăng nhập'
                                  : 'Chưa có tài khoản? Đăng ký ngay',
                            ),
                          ),
                          if (!_register)
                            TextButton(
                              onPressed: _recoverPassword,
                              child: const Text('Quên mật khẩu?'),
                            ),
                          const Divider(height: 24),
                          TextButton.icon(
                            onPressed: _configServerUrl,
                            icon: const Icon(Icons.settings_ethernet, size: 18),
                            label: Text(
                              'Cấu hình Server (${widget.state.api.baseUrl})',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _configServerUrl() async {
    final controller = TextEditingController(text: widget.state.api.baseUrl);
    String? pingResult;
    bool pinging = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cấu hình Server API'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Chọn hoặc nhập địa chỉ API máy chủ ToyStore:',
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'API Base URL',
                    hintText: 'http://192.168.1.x:5225/api',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Localhost (Windows)'),
                      onPressed: () => setDialogState(
                        () => controller.text = 'http://localhost:5225/api',
                      ),
                    ),
                    ActionChip(
                      label: const Text('Android Emulator (10.0.2.2)'),
                      onPressed: () => setDialogState(
                        () => controller.text = 'http://10.0.2.2:5225/api',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: pinging
                      ? null
                      : () async {
                          setDialogState(() {
                            pinging = true;
                            pingResult = null;
                          });
                          final prevUrl = widget.state.api.baseUrl;
                          await widget.state.updateApiBaseUrl(controller.text);
                          final ok = await widget.state.api.checkHealth();
                          setDialogState(() {
                            pinging = false;
                            pingResult = ok
                                ? 'Kết nối thành công tới Server ToyStore!'
                                : 'Không thể kết nối tới server. Vui lòng kiểm tra lại IP/Port.';
                          });
                          if (!ok) {
                            await widget.state.updateApiBaseUrl(prevUrl);
                          }
                        },
                  icon: pinging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_find, size: 18),
                  label: const Text('Kiểm tra kết nối (Ping)'),
                ),
                if (pingResult != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    pingResult!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: pingResult!.startsWith('Kết nối')
                          ? Colors.green
                          : _rose,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogCtx);
                final messenger = ScaffoldMessenger.of(context);
                final newUrl = controller.text;
                await widget.state.updateApiBaseUrl(newUrl);
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Đã lưu cấu hình API: $newUrl')),
                );
              },
              child: const Text('Lưu cấu hình'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator:
          validator ??
          (value) => value == null || value.trim().isEmpty
              ? 'Vui lòng nhập $label'
              : null,
    );
  }

  Future<void> _recoverPassword() async {
    final emailController = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi phục mật khẩu'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email tài khoản'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, emailController.text),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    emailController.dispose();
    if (email == null || email.trim().isEmpty || !mounted) return;

    try {
      final result = await widget.state.requestPasswordReset(email);
      if (!mounted) return;
      final token = result['resetToken']?.toString() ?? '';
      if (token.isEmpty) {
        showNotice(
          context,
          result['message']?.toString() ?? 'Không nhận được mã đặt lại.',
        );
        return;
      }

      final tokenController = TextEditingController(text: token);
      final passwordController = TextEditingController();
      final didReset = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đặt mật khẩu mới'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tokenController,
                decoration: const InputDecoration(labelText: 'Mã xác nhận'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đặt lại'),
            ),
          ],
        ),
      );
      if (didReset == true) {
        await widget.state.resetPassword(
          email: email,
          token: tokenController.text,
          password: passwordController.text,
        );
        if (mounted) {
          showNotice(context, 'Đã đặt lại mật khẩu. Bạn có thể đăng nhập.');
        }
      }
      tokenController.dispose();
      passwordController.dispose();
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    }
  }
}

class AppShell extends StatefulWidget {
  const AppShell({required this.state, super.key});

  final AppState state;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  List<_Destination> get _destinations {
    if (widget.state.isShipper) {
      return const [
        _Destination('Giao hàng', Icons.local_shipping_outlined),
        _Destination('Tài khoản', Icons.person_outline),
      ];
    }
    if (widget.state.isStaff) {
      return const [
        _Destination('Tổng quan', Icons.space_dashboard_outlined),
        _Destination('Đơn hàng', Icons.receipt_long_outlined),
        _Destination('Quản lý', Icons.inventory_2_outlined),
        _Destination('Tài khoản', Icons.person_outline),
      ];
    }
    return const [
      _Destination('Cửa hàng', Icons.storefront_outlined),
      _Destination('Đơn hàng', Icons.receipt_long_outlined),
      _Destination('Ưu đãi', Icons.card_giftcard_outlined),
      _Destination('Tài khoản', Icons.person_outline),
    ];
  }

  List<Widget> get _pages {
    if (widget.state.isShipper) {
      return [
        ShipperPage(state: widget.state),
        ProfilePage(state: widget.state),
      ];
    }
    if (widget.state.isStaff) {
      return [
        DashboardPage(state: widget.state),
        OrdersPage(state: widget.state),
        OperationsPage(state: widget.state),
        ProfilePage(state: widget.state),
      ];
    }
    return [
      StorePage(state: widget.state),
      OrdersPage(state: widget.state),
      RewardsPage(state: widget.state),
      ProfilePage(state: widget.state),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    if (_index >= destinations.length) _index = 0;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.toys_rounded, color: _rose),
            const SizedBox(width: 8),
            Text(
              destinations[_index].label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          if (widget.state.isCustomer)
            IconButton(
              tooltip: 'Thông báo voucher',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CustomerNotificationsPage(state: widget.state),
                ),
              ),
              icon: const Icon(Icons.notifications_outlined),
            ),
          if (widget.state.isStaff)
            IconButton(
              tooltip: 'Thông báo hệ thống',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StaffNotificationsPage(state: widget.state),
                ),
              ),
              icon: const Icon(Icons.notifications_outlined),
            ),
          if (widget.state.isCustomer)
            AnimatedBuilder(
              animation: widget.state,
              builder: (context, _) => IconButton(
                tooltip: 'Giỏ hàng',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CartPage(state: widget.state),
                  ),
                ),
                icon: Badge(
                  label: Text('${widget.state.cartCount}'),
                  isLabelVisible: widget.state.cartCount > 0,
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
              ),
            ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon);

  final String label;
  final IconData icon;
}

class StorePage extends StatefulWidget {
  const StorePage({required this.state, super.key});

  final AppState state;

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final _search = TextEditingController();
  int? _categoryId;
  int? _brandId;
  int _priceFilter = 0; // 0: all, 1: <200k, 2: 200k-500k, 3: 500k-1M, 4: >1M
  String _sortBy = 'default'; // default, price_asc, price_desc, name_asc
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      await widget.state.loadCatalog();
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    } catch (error) {
      if (mounted) showNotice(context, 'Không thể tải cửa hàng: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFilterDialog() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bộ lọc & Sắp xếp',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Khoảng giá',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _priceFilter == 0,
                    onSelected: (_) {
                      setModalState(() => _priceFilter = 0);
                      setState(() {});
                    },
                  ),
                  ChoiceChip(
                    label: const Text('< 200.000₫'),
                    selected: _priceFilter == 1,
                    onSelected: (_) {
                      setModalState(() => _priceFilter = 1);
                      setState(() {});
                    },
                  ),
                  ChoiceChip(
                    label: const Text('200k - 500k'),
                    selected: _priceFilter == 2,
                    onSelected: (_) {
                      setModalState(() => _priceFilter = 2);
                      setState(() {});
                    },
                  ),
                  ChoiceChip(
                    label: const Text('500k - 1 triệu'),
                    selected: _priceFilter == 3,
                    onSelected: (_) {
                      setModalState(() => _priceFilter = 3);
                      setState(() {});
                    },
                  ),
                  ChoiceChip(
                    label: const Text('> 1 triệu'),
                    selected: _priceFilter == 4,
                    onSelected: (_) {
                      setModalState(() => _priceFilter = 4);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Sắp xếp theo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Mặc định'),
                    selected: _sortBy == 'default',
                    onSelected: (_) {
                      setModalState(() => _sortBy = 'default');
                      setState(() {});
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Giá tăng dần'),
                    selected: _sortBy == 'price_asc',
                    onSelected: (_) {
                      setModalState(() => _sortBy = 'price_asc');
                      setState(() {});
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Giá giảm dần'),
                    selected: _sortBy == 'price_desc',
                    onSelected: (_) {
                      setModalState(() => _sortBy = 'price_desc');
                      setState(() {});
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Tên A - Z'),
                    selected: _sortBy == 'name_asc',
                    onSelected: (_) {
                      setModalState(() => _sortBy = 'name_asc');
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Áp dụng bộ lọc'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final search = _search.text.toLowerCase().trim();
        var products = widget.state.products.where((product) {
          final matchesCategory =
              _categoryId == null || product['categoryId'] == _categoryId;
          final matchesBrand =
              _brandId == null || product['brandId'] == _brandId;
          final matchesSearch =
              search.isEmpty ||
              '${product['name']} ${product['brandName']} ${product['categoryName']}'
                  .toLowerCase()
                  .contains(search);
          final price = productDisplayPrice(product);
          final matchesPrice = switch (_priceFilter) {
            1 => price < 200000,
            2 => price >= 200000 && price <= 500000,
            3 => price > 500000 && price <= 1000000,
            4 => price > 1000000,
            _ => true,
          };
          return matchesCategory &&
              matchesBrand &&
              matchesSearch &&
              matchesPrice;
        }).toList();

        if (_sortBy == 'price_asc') {
          products.sort(
            (a, b) => productDisplayPrice(a).compareTo(productDisplayPrice(b)),
          );
        } else if (_sortBy == 'price_desc') {
          products.sort(
            (a, b) => productDisplayPrice(b).compareTo(productDisplayPrice(a)),
          );
        } else if (_sortBy == 'name_asc') {
          products.sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFEFF1),
                          Color(0xFFFFF8E8),
                          Color(0xFFEEF5FF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MÓN QUÀ NHỎ, NIỀM VUI LỚN',
                          style: TextStyle(
                            color: _rose,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Khám phá thế giới\nđồ chơi cho bé!',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: _ink,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Text('An toàn · Sáng tạo · Tràn đầy niềm vui'),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Tìm đồ chơi, thương hiệu...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _search.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _search.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.clear, size: 18),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _openFilterDialog,
                        icon: Badge(
                          isLabelVisible:
                              _priceFilter != 0 || _sortBy != 'default',
                          child: const Icon(Icons.tune),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Category chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 54,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _CategoryChip(
                        label: 'Tất cả danh mục',
                        selected: _categoryId == null,
                        onTap: () => setState(() => _categoryId = null),
                      ),
                      for (final category in widget.state.categories)
                        _CategoryChip(
                          label: '${category['name'] ?? ''}',
                          selected: _categoryId == category['id'],
                          onTap: () => setState(
                            () => _categoryId = category['id'] as int?,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Brand chips if available
              if (widget.state.brands.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CategoryChip(
                          label: 'Tất cả thương hiệu',
                          selected: _brandId == null,
                          onTap: () => setState(() => _brandId = null),
                        ),
                        for (final brand in widget.state.brands)
                          _CategoryChip(
                            label: '${brand['name'] ?? ''}',
                            selected: _brandId == brand['id'],
                            onTap: () =>
                                setState(() => _brandId = brand['id'] as int?),
                          ),
                      ],
                    ),
                  ),
                ),
              if (_loading && products.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (products.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.toys_outlined,
                    title: 'Chưa có sản phẩm phù hợp',
                    subtitle:
                        'Kéo xuống để tải lại hoặc thay đổi tiêu chí lọc.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ProductCard(
                        state: widget.state,
                        product: products[index],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailPage(
                              state: widget.state,
                              product: products[index],
                            ),
                          ),
                        ),
                      ),
                      childCount: products.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.63,
                        ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      selectedColor: const Color(0xFFFFE4E9),
      onSelected: (_) => onTap(),
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.state,
    required this.product,
    required this.onTap,
  });

  final AppState state;
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = product['imageUrl']?.toString() ?? '';
    final fullImageUrl = state.api.absoluteAssetUrl(image);
    // stock == -1 nghĩa là null/chưa nhập, stock == 0 là hết hàng thực sự
    final rawStock = productAvailableStock(product);
    final stockKnown = rawStock != null; // Backend đã cập nhật tồn kho chưa
    final stock = stockKnown ? _asInt(rawStock) : -1;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFFFF4F3),
                    child: image.isEmpty
                        ? const Icon(
                            Icons.toys_outlined,
                            size: 52,
                            color: Color(0xFFE6A5B0),
                          )
                        : Image.network(
                            fullImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.toys_outlined,
                              size: 52,
                              color: Color(0xFFE6A5B0),
                            ),
                          ),
                  ),
                  if (stock == 0) // hết hàng thực sự
                    Positioned.fill(
                      child: Container(
                        color: Colors.black45,
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'HẾT HÀNG',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!stockKnown) // chưa về hàng lần nào — banner vàng nhẹ
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        color: const Color(0xFFCA8A04).withValues(alpha: 0.85),
                        alignment: Alignment.center,
                        child: const Text(
                          'SẮP VỀ HÀNG',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${product['name'] ?? 'Sản phẩm'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Chỉ hiển thị giá khi tồn kho đã được cập nhật
                      if (stockKnown)
                        Text(
                          money(productDisplayPrice(product)),
                          style: const TextStyle(
                            color: _rose,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else
                        const Text(
                          'Liên hệ để đặt hàng',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      if (product['brandName'] != null)
                        Text(
                          '${product['brandName']}',
                          style: const TextStyle(fontSize: 10, color: _muted),
                        ),
                    ],
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

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    required this.state,
    required this.product,
    super.key,
  });

  final AppState state;
  final Map<String, dynamic> product;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Map<String, dynamic> _product;
  List<Map<String, dynamic>> _variants = [];
  List<Map<String, dynamic>> _images = [];
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _selectedVariant;
  int _quantity = 1;
  int _currentImageIndex = 0;
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final id = _asInt(widget.product['productId'] ?? widget.product['id']);
    if (id <= 0) {
      setState(() => _loading = false);
      return;
    }

    try {
      final results = await Future.wait([
        widget.state.api.get('Product/$id'),
        widget.state.api
            .get('ProductReview/by-product/$id')
            .catchError((_) => []),
      ]);
      if (mounted) {
        setState(() {
          _product = _map(results[0]);
          _variants = _asMapList(
            _product['productVariants'] ?? _product['variants'],
          );
          _images = _asMapList(_product['productImages'] ?? _product['images']);
          if (_images.isEmpty &&
              (_product['imageUrl'] ?? '').toString().isNotEmpty) {
            _images = [
              {'imageUrl': _product['imageUrl']},
            ];
          }
          if (_variants.isNotEmpty) {
            _selectedVariant = _variants.first;
          }
          _reviews = _asMapList(results[1]);
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải chi tiết sản phẩm: $e';
          _loading = false;
        });
      }
    }
  }

  double get _currentPrice {
    if (_selectedVariant != null) {
      final price = variantPrice(_selectedVariant!);
      if (price > 0) return price;
    }
    return productDisplayPrice(_product);
  }

  int get _currentStock {
    if (_selectedVariant != null) {
      final stock = variantAvailableStock(_selectedVariant!);
      if (stock != null) return stock;
    }
    return productAvailableStock(_product) ?? 99;
  }

  String get _currentSku {
    if (_selectedVariant != null) {
      return (_selectedVariant!['sku'] ?? _selectedVariant!['barcode'] ?? '')
          .toString();
    }
    return (_product['sku'] ?? '').toString();
  }

  String? get _variantLabel {
    if (_selectedVariant != null) {
      final color = _selectedVariant!['color']?.toString() ?? '';
      final size = _selectedVariant!['size']?.toString() ?? '';
      final name = _selectedVariant!['variantName']?.toString() ?? '';
      final parts = [
        if (color.isNotEmpty) color,
        if (size.isNotEmpty) size,
        if (name.isNotEmpty && color.isEmpty && size.isEmpty) name,
      ];
      return parts.isEmpty ? null : parts.join(' - ');
    }
    return null;
  }

  Future<void> _handleAddToCart({bool buyNow = false}) async {
    final stock = _currentStock;
    if (stock <= 0) {
      showNotice(context, 'Sản phẩm hoặc biến thể này hiện đã hết hàng.');
      return;
    }

    final variantId = _selectedVariant != null
        ? _asInt(_selectedVariant!['variantId'] ?? _selectedVariant!['id'])
        : null;

    setState(() => _submitting = true);
    try {
      await widget.state.addToCart(
        _product,
        variantId: variantId,
        quantity: _quantity,
        variantName: _variantLabel,
        sku: _currentSku,
      );
      if (!mounted) return;

      if (buyNow) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CheckoutPage(state: widget.state)),
        );
      } else {
        showNotice(context, 'Đã thêm $_quantity sản phẩm vào giỏ hàng.');
      }
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    } catch (e) {
      if (mounted) showNotice(context, 'Lỗi thêm vào giỏ: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
        body: _ErrorPanel(message: _error!, onRetry: _loadDetails),
      );
    }

    final stock = _currentStock;
    final price = _currentPrice;
    final basePrice = productDisplayPrice(_product);
    final hasSale = basePrice > price && price > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_product['name'] ?? 'Chi tiết sản phẩm'}'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CartPage(state: widget.state)),
            ),
            icon: Badge(
              label: Text('${widget.state.cartCount}'),
              isLabelVisible: widget.state.cartCount > 0,
              backgroundColor: _rose,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: stock <= 0 || _submitting
                      ? null
                      : () => _handleAddToCart(buyNow: false),
                  icon: const Icon(Icons.add_shopping_cart, size: 20),
                  label: const Text('Thêm vào giỏ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _rose,
                    side: const BorderSide(color: _rose),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: stock <= 0 || _submitting
                      ? null
                      : () => _handleAddToCart(buyNow: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _rose,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Mua ngay'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        children: [
          // Image Gallery
          if (_images.isNotEmpty)
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: _images.length,
                    onPageChanged: (i) =>
                        setState(() => _currentImageIndex = i),
                    itemBuilder: (context, i) {
                      final imgUrl = (_images[i]['imageUrl'] ?? '').toString();
                      final fullUrl = widget.state.api.absoluteAssetUrl(imgUrl);
                      return Container(
                        color: const Color(0xFFFFF4F3),
                        child: imgUrl.isEmpty
                            ? const Icon(
                                Icons.toys_outlined,
                                size: 80,
                                color: Color(0xFFE6A5B0),
                              )
                            : Image.network(
                                fullUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image, size: 60),
                              ),
                      );
                    },
                  ),
                  if (_images.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < _images.length; i++)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentImageIndex == i
                                    ? _rose
                                    : Colors.grey[300],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category & Brand
                Row(
                  children: [
                    if (_product['categoryName'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEFF1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_product['categoryName']}',
                          style: const TextStyle(
                            color: _rose,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (_product['brandName'] != null)
                      Text(
                        'Thương hiệu: ${_product['brandName']}',
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Product Name
                Text(
                  '${_product['name'] ?? 'Sản phẩm'}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),

                // Price & Sale
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      money(price),
                      style: const TextStyle(
                        color: _rose,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (hasSale) ...[
                      const SizedBox(width: 10),
                      Text(
                        money(basePrice),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: stock > 0
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: stock > 0
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Text(
                        stock > 0 ? 'Còn hàng ($stock)' : 'Tạm hết hàng',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: stock > 0
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),

                // Variants Selection
                if (_variants.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chọn phân loại hàng (Biến thể):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (_currentSku.isNotEmpty)
                        Text(
                          'SKU: $_currentSku',
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final variant in _variants)
                        ChoiceChip(
                          label: Text(
                            [
                                  if ((variant['color'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    '${variant['color']}',
                                  if ((variant['size'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    '${variant['size']}',
                                  if ((variant['variantName'] ?? '')
                                          .toString()
                                          .isNotEmpty &&
                                      (variant['color'] ?? '')
                                          .toString()
                                          .isEmpty &&
                                      (variant['size'] ?? '')
                                          .toString()
                                          .isEmpty)
                                    '${variant['variantName']}',
                                ]
                                .join(' - ')
                                .ifEmptyThen('${variant['sku'] ?? 'Mặc định'}'),
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected:
                              _selectedVariant?['variantId'] ==
                                  variant['variantId'] ||
                              _selectedVariant?['id'] == variant['id'],
                          selectedColor: const Color(0xFFFFE4E9),
                          onSelected: (_) {
                            setState(() {
                              _selectedVariant = variant;
                              _quantity = 1;
                            });
                          },
                        ),
                    ],
                  ),
                  const Divider(height: 28),
                ],

                // Quantity selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Số lượng mua:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton.outlined(
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(Icons.remove, size: 16),
                          visualDensity: VisualDensity.compact,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton.outlined(
                          onPressed: stock > _quantity
                              ? () => setState(() => _quantity++)
                              : null,
                          icon: const Icon(Icons.add, size: 16),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 28),

                // Product Description & Specs
                const Text(
                  'Mô tả sản phẩm',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  (_product['description'] ??
                          'Chưa có mô tả chi tiết cho sản phẩm này.')
                      .toString(),
                  style: const TextStyle(height: 1.5, color: _ink),
                ),
                const SizedBox(height: 16),

                // Attributes table
                Card(
                  color: const Color(0xFFF9FAFB),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        if (_product['ageRange'] != null ||
                            _product['targetAge'] != null)
                          _specRow(
                            'Độ tuổi phù hợp',
                            '${_product['ageRange'] ?? _product['targetAge']}',
                          ),
                        if (_product['origin'] != null)
                          _specRow('Xuất xứ', '${_product['origin']}'),
                        if (_product['material'] != null)
                          _specRow('Chất liệu', '${_product['material']}'),
                        _specRow(
                          'Mã sản phẩm',
                          '${_product['productId'] ?? _product['id'] ?? '—'}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Customer Reviews
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đánh giá từ khách hàng (${_reviews.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_reviews.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Chưa có đánh giá nào cho sản phẩm này.',
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final review in _reviews)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: const Color(0xFFF9FAFB),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 12,
                                      child: Icon(Icons.person, size: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${review['customerName'] ?? 'Khách hàng'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        for (int i = 1; i <= 5; i++)
                                          Icon(
                                            Icons.star,
                                            size: 14,
                                            color: i <= _asInt(review['rating'])
                                                ? Colors.amber
                                                : Colors.grey.shade300,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                if ((review['comment'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '${review['comment']}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String ifEmptyThen(String fallback) => isEmpty ? fallback : this;
}

class CartPage extends StatelessWidget {
  const CartPage({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Giỏ hàng'),
      actions: [
        if (state.cart.isNotEmpty)
          IconButton(
            tooltip: 'Xóa toàn bộ',
            onPressed: () {
              state.clearCart();
              showNotice(context, 'Đã xóa toàn bộ giỏ hàng.');
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
      ],
    ),
    body: AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        if (state.cart.isEmpty) {
          return const _EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'Giỏ hàng đang trống',
            subtitle: 'Hãy chọn món đồ chơi yêu thích cho bé.',
          );
        }

        const freeshipTarget = 500000.0;
        final cartTotal = state.cartTotal;
        final isFreeship = cartTotal >= freeshipTarget;
        final progress = (cartTotal / freeshipTarget).clamp(0.0, 1.0);

        return Column(
          children: [
            // Freeship progress banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFreeship
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFreeship
                      ? Colors.green.shade300
                      : Colors.amber.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isFreeship
                            ? Icons.local_shipping
                            : Icons.local_shipping_outlined,
                        color: isFreeship
                            ? Colors.green.shade800
                            : Colors.amber.shade900,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isFreeship
                              ? '🎉 Đơn hàng đã đạt điều kiện MIỄN PHÍ VẬN CHUYỂN!'
                              : 'Mua thêm ${money(freeshipTarget - cartTotal)} để được MIỄN PHÍ VẬN CHUYỂN!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isFreeship
                                ? Colors.green.shade900
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      color: isFreeship ? Colors.green : _rose,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.cart.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final line = state.cart[index];
                  final imageUrl = (line.product['imageUrl'] ?? '').toString();
                  final fullImgUrl = state.api.absoluteAssetUrl(imageUrl);
                  final variantDesc = line.variantName ?? line.sku;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 54,
                              height: 54,
                              color: const Color(0xFFFFEFF1),
                              child: imageUrl.isEmpty
                                  ? const Icon(Icons.toys, color: _rose)
                                  : Image.network(
                                      fullImgUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Icon(Icons.toys, color: _rose),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${line.product['name'] ?? ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (variantDesc != null &&
                                    variantDesc.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Phân loại: $variantDesc',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _muted,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  money(line.price),
                                  style: const TextStyle(
                                    color: _rose,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => state.updateCartQuantity(line, -1),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '${line.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () {
                              try {
                                state.updateCartQuantity(line, 1);
                              } on ApiException catch (e) {
                                showNotice(context, e.message);
                              }
                            },
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: _rose,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Tạm tính',
                      value: money(state.cartTotal),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CheckoutPage(state: state),
                          ),
                        ),
                        child: const Text('Tiến hành đặt hàng'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({required this.state, super.key});

  final AppState state;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _voucher = TextEditingController();
  final _note = TextEditingController();
  int _paymentMethod = 0;
  bool _loading = false;
  List<Map<String, dynamic>> _availableVouchers = [];
  List<Map<String, dynamic>> _savedAddresses = [];
  Map<String, dynamic>? _selectedVoucher;

  @override
  void initState() {
    super.initState();
    _loadProfileAndAddresses();
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    try {
      final result = await widget.state.api.get('Voucher/available');
      _availableVouchers = result is List
          ? result.whereType<Map>().map(_map).toList()
          : [];
      if (mounted) setState(() {});
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    }
  }

  Future<void> _loadProfileAndAddresses() async {
    try {
      final results = await Future.wait([
        widget.state.api.get('Customer/profile'),
        widget.state.api
            .get('Customer/profile/addresses')
            .catchError((_) => []),
      ]);
      final profile = _map(results[0]);
      widget.state.profile = profile;

      _savedAddresses = _asMapList(results[1]);

      if (_savedAddresses.isNotEmpty) {
        final defaultAddr = _savedAddresses.firstWhere(
          (a) => a['isDefault'] == true,
          orElse: () => _savedAddresses.first,
        );
        _name.text =
            '${defaultAddr['receiverName'] ?? profile['fullName'] ?? widget.state.fullName}';
        _phone.text =
            '${defaultAddr['receiverPhone'] ?? profile['phone'] ?? ''}';
        _address.text =
            '${defaultAddr['fullAddress'] ?? defaultAddr['addressDetail'] ?? profile['address'] ?? ''}';
      } else {
        _name.text = '${profile['fullName'] ?? widget.state.fullName}';
        _phone.text = '${profile['phone'] ?? ''}';
        _address.text = '${profile['address'] ?? ''}';
      }

      if (mounted) setState(() {});
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    }
  }

  void _chooseAddress() {
    if (_savedAddresses.isEmpty) {
      showNotice(
        context,
        'Chưa có địa chỉ lưu sẵn. Bạn có thể nhập trực tiếp bên dưới.',
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn địa chỉ giao hàng',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _savedAddresses.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final addr = _savedAddresses[i];
                  final isDef = addr['isDefault'] == true;
                  return ListTile(
                    leading: Icon(
                      isDef ? Icons.home : Icons.location_on_outlined,
                      color: isDef ? _rose : _muted,
                    ),
                    title: Text(
                      '${addr['receiverName']} · ${addr['receiverPhone']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${addr['fullAddress'] ?? addr['addressDetail']}',
                    ),
                    trailing: isDef
                        ? const Chip(
                            label: Text(
                              'Mặc định',
                              style: TextStyle(fontSize: 10),
                            ),
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _name.text = '${addr['receiverName']}';
                        _phone.text = '${addr['receiverPhone']}';
                        _address.text =
                            '${addr['fullAddress'] ?? addr['addressDetail']}';
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _voucherDiscount {
    if (_selectedVoucher == null) return 0.0;
    final type = _asInt(_selectedVoucher!['discountType']);
    final val = _asNum(_selectedVoucher!['discountValue']);
    final minOrder = _asNum(_selectedVoucher!['minimumOrderValue']);

    if (widget.state.cartTotal < minOrder) return 0.0;
    if (type == 1) {
      // Percentage
      return (widget.state.cartTotal * val / 100.0);
    }
    // Fixed amount
    return val;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _voucher.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await widget.state.checkout(
        receiverName: _name.text,
        receiverPhone: _phone.text,
        address: _address.text,
        paymentMethod: _paymentMethod,
        voucherCode: _voucher.text.isEmpty ? null : _voucher.text,
        note: _note.text,
      );
      if (!mounted) return;
      final orderId = _asInt(result['orderId']);
      final orderCode = '${result['orderCode'] ?? ''}';
      if (_paymentMethod == 2) {
        widget.state.clearCart();
        if (orderId <= 0) {
          await _showPaymentPending(
            'Đơn ${orderCode.isEmpty ? '' : '$orderCode '}đã được tạo nhưng máy chủ không trả mã đơn để khởi tạo ZaloPay. Liên hệ cửa hàng để được hỗ trợ.',
          );
          return;
        }
        try {
          final payment = await widget.state.createZaloPayPayment(orderId);
          if (!mounted) return;
          final paid = await showDialog<bool>(
            context: context,
            builder: (_) => ZaloPayDialog(
              state: widget.state,
              orderId: orderId,
              orderCode: orderCode,
              orderUrl: '${payment['orderUrl'] ?? ''}',
              alreadyPaid: payment['isPaid'] == true,
            ),
          );
          if (!mounted) return;
          if (paid == true) {
            await _showOrderCreated(orderCode);
          } else {
            await _showPaymentPending(
              'Đơn hàng đã được tạo và đang chờ thanh toán. Bạn có thể tiếp tục thanh toán từ danh sách đơn hàng.',
            );
          }
        } on ApiException catch (error) {
          if (mounted) {
            await _showPaymentPending(
              'Đơn ${orderCode.isEmpty ? '' : '$orderCode '}đã được tạo nhưng chưa khởi tạo được ZaloPay: ${error.message}',
            );
          }
        }
        return;
      }

      widget.state.clearCart();
      if (_paymentMethod == 1) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.account_balance_outlined,
              color: _rose,
              size: 42,
            ),
            title: const Text('Đã ghi nhận đơn hàng'),
            content: const Text(
              'Đơn đang chờ thanh toán chuyển khoản. Máy chủ hiện chưa cung cấp thông tin tài khoản ngân hàng, mã QR hoặc API xác nhận giao dịch; vui lòng liên hệ cửa hàng để nhận hướng dẫn chuyển khoản.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Hoàn tất'),
              ),
            ],
          ),
        );
      } else {
        await _showOrderCreated(orderCode);
      }
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    } catch (error) {
      if (mounted) showNotice(context, 'Không thể đặt hàng: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showOrderCreated(String orderCode) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 44),
        title: const Text('Đặt hàng thành công'),
        content: Text(
          orderCode.isEmpty ? 'Đơn hàng đã được tạo.' : 'Mã đơn: $orderCode',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Hoàn tất'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentPending(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.hourglass_top_rounded,
          color: Color(0xFFB45309),
          size: 42,
        ),
        title: const Text('Đơn đang chờ thanh toán'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng thông báo'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final discount = _voucherDiscount;
    final total = (widget.state.cartTotal - discount).clamp(
      0.0,
      double.infinity,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đơn hàng')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thông tin giao hàng',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_savedAddresses.isNotEmpty)
                  TextButton.icon(
                    onPressed: _chooseAddress,
                    icon: const Icon(Icons.bookmark_border, size: 18),
                    label: const Text('Sổ địa chỉ'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _checkoutField(_name, 'Người nhận'),
            const SizedBox(height: 12),
            _checkoutField(
              _phone,
              'Số điện thoại',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _checkoutField(_address, 'Địa chỉ giao hàng', maxLines: 2),
            const SizedBox(height: 18),
            Text('Thanh toán', style: Theme.of(context).textTheme.titleLarge),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Thanh toán khi nhận hàng (COD)'),
                  selected: _paymentMethod == 0,
                  onSelected: (_) => setState(() => _paymentMethod = 0),
                ),
                ChoiceChip(
                  label: const Text('Chuyển khoản'),
                  selected: _paymentMethod == 1,
                  onSelected: (_) => setState(() => _paymentMethod = 1),
                ),
                ChoiceChip(
                  label: const Text('ZaloPay'),
                  selected: _paymentMethod == 2,
                  onSelected: (_) => setState(() => _paymentMethod = 2),
                ),
              ],
            ),
            if (_paymentMethod == 1)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: _CheckoutNotice(
                  text:
                      'Đơn sẽ ghi nhận chờ thanh toán. Cửa hàng cần cung cấp thông tin chuyển khoản vì API hiện chưa có QR ngân hàng.',
                ),
              ),
            if (_paymentMethod == 2)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: _CheckoutNotice(
                  text:
                      'ZaloPay mở cổng thanh toán do máy chủ cấu hình. Bạn có thể mở ứng dụng thanh toán hoặc xác nhận sandbox.',
                ),
              ),
            const SizedBox(height: 12),
            if (_availableVouchers.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue:
                    _availableVouchers.any(
                      (voucher) => voucher['code'] == _voucher.text,
                    )
                    ? _voucher.text
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Chọn voucher khả dụng',
                ),
                items: [
                  for (final voucher in _availableVouchers)
                    DropdownMenuItem(
                      value: '${voucher['code'] ?? ''}',
                      child: Text(
                        '${voucher['name'] ?? voucher['code']} · ${voucher['discountType'] == 1 ? '${voucher['discountValue']}%' : money(voucher['discountValue'])}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _voucher.text = value ?? '';
                    final match = _availableVouchers.where(
                      (v) => v['code'] == value,
                    );
                    _selectedVoucher = match.isNotEmpty ? match.first : null;
                  });
                },
              ),
            _checkoutField(
              _voucher,
              'Mã ưu đãi (có thể nhập thủ công)',
              requiredField: false,
            ),
            const SizedBox(height: 12),
            _checkoutField(_note, 'Ghi chú cho cửa hàng', requiredField: false),
            const SizedBox(height: 18),
            _SummaryRow(
              label: 'Tạm tính',
              value: money(widget.state.cartTotal),
            ),
            if (discount > 0) ...[
              const SizedBox(height: 6),
              _SummaryRow(
                label: 'Giảm giá voucher',
                value: '- ${money(discount)}',
              ),
            ],
            const SizedBox(height: 6),
            _SummaryRow(
              label: 'Phí giao hàng',
              value: widget.state.cartTotal >= 500000
                  ? 'Miễn phí'
                  : 'Máy chủ xác nhận',
            ),
            const Divider(height: 24),
            _SummaryRow(label: 'Tổng thanh toán', value: money(total)),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loading ? null : _placeOrder,
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Đặt hàng'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkoutField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          requiredField && (value == null || value.trim().isEmpty)
          ? 'Vui lòng nhập $label'
          : null,
    );
  }
}

class _CheckoutNotice extends StatelessWidget {
  const _CheckoutNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class ZaloPayDialog extends StatefulWidget {
  const ZaloPayDialog({
    required this.state,
    required this.orderId,
    required this.orderCode,
    required this.orderUrl,
    this.alreadyPaid = false,
    super.key,
  });

  final AppState state;
  final int orderId;
  final String orderCode;
  final String orderUrl;
  final bool alreadyPaid;

  @override
  State<ZaloPayDialog> createState() => _ZaloPayDialogState();
}

class _ZaloPayDialogState extends State<ZaloPayDialog> {
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.alreadyPaid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    }
  }

  Future<void> _openPayment() async {
    final uri = Uri.tryParse(widget.orderUrl);
    if (uri == null || !uri.hasScheme) {
      setState(() => _error = 'Đường dẫn thanh toán ZaloPay không hợp lệ.');
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        setState(() => _error = 'Thiết bị chưa thể mở liên kết thanh toán.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Không thể mở ZaloPay: $error');
    }
  }

  Future<void> _checkPayment() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final status = await widget.state.getZaloPayPaymentStatus(widget.orderId);
      if (status['isPaid'] == true && mounted) {
        Navigator.pop(context, true);
        return;
      }
      if (mounted) {
        setState(
          () => _error =
              status['message']?.toString() ??
              'Máy chủ chưa xác nhận thanh toán. Vui lòng kiểm tra lại sau.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _confirmSandbox() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result = await widget.state.confirmSandboxPayment(widget.orderId);
      if (result['isPaid'] == true && mounted) {
        Navigator.pop(context, true);
        return;
      }
      if (mounted) {
        setState(() => _error = 'Máy chủ chưa xác nhận thanh toán thử nghiệm.');
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(
      Icons.account_balance_wallet_outlined,
      color: _rose,
      size: 42,
    ),
    title: const Text('Thanh toán ZaloPay'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.orderCode.isNotEmpty) Text('Đơn hàng ${widget.orderCode}'),
        const SizedBox(height: 8),
        const Text(
          'Mở trang thanh toán do máy chủ cung cấp. Sau khi hoàn tất, quay lại đây và kiểm tra trạng thái.',
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 12),
        const _CheckoutNotice(
          text:
              'Xác nhận mô phỏng chỉ dùng được khi backend đang chạy ZaloPay Sandbox.',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Để thanh toán sau'),
      ),
      if (widget.orderUrl.isNotEmpty)
        OutlinedButton.icon(
          onPressed: _checking ? null : _openPayment,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Mở ZaloPay'),
        ),
      TextButton(
        onPressed: _checking ? null : _confirmSandbox,
        child: const Text('Xác nhận Sandbox'),
      ),
      FilledButton(
        onPressed: _checking ? null : _checkPayment,
        child: Text(_checking ? 'Đang kiểm tra...' : 'Kiểm tra đã thanh toán'),
      ),
    ],
  );
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({required this.state, super.key});

  final AppState state;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _search = TextEditingController();
  int? _statusFilter;
  bool _loading = false;
  bool _updatingOrder = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      await widget.state.loadOrders();
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    } catch (error) {
      if (mounted) showNotice(context, 'Không thể tải đơn hàng: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) {
      final query = _search.text.trim().toLowerCase();
      final orders = widget.state.orders.where((order) {
        final status = _asInt(order['status']);
        final matchesStatus =
            _statusFilter == null ||
            switch (_statusFilter) {
              0 => status == 0,
              1 => status >= 1 && status <= 3,
              4 => status == 4,
              5 => status == 5,
              _ => true,
            };
        final searchable =
            '${order['customerName']} ${order['phoneNumber']} ${order['orderCode']}'
                .toLowerCase();
        return matchesStatus && (query.isEmpty || searchable.contains(query));
      }).toList();
      if (_loading && widget.state.orders.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (widget.state.orders.isEmpty) {
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            children: const [
              SizedBox(height: 140),
              _EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Chưa có đơn hàng',
                subtitle: 'Các đơn hàng sẽ được hiển thị tại đây.',
              ),
            ],
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.state.isStaff)
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm theo khách hàng hoặc số điện thoại',
                ),
              ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final option in const [
                    (label: 'Tất cả', value: -1),
                    (label: 'Chờ xác nhận', value: 0),
                    (label: 'Đang xử lý', value: 1),
                    (label: 'Hoàn tất', value: 4),
                    (label: 'Đã hủy', value: 5),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(option.label),
                        selected: (_statusFilter ?? -1) == option.value,
                        onSelected: (_) => setState(
                          () => _statusFilter = option.value == -1
                              ? null
                              : option.value,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${orders.length} đơn hàng',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
            if (orders.isEmpty)
              const _EmptyState(
                icon: Icons.search_off,
                title: 'Không tìm thấy đơn hàng',
                subtitle: 'Thử đổi từ khóa hoặc trạng thái.',
              )
            else
              for (final order in orders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Card(
                    child: ExpansionTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFEFF1),
                        child: Icon(Icons.local_mall_outlined, color: _rose),
                      ),
                      title: Text(
                        widget.state.isCustomer
                            ? 'Đơn hàng của bạn'
                            : '${order['customerName'] ?? 'Khách hàng'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${_orderStatus(order['status'])} · ${money(order['totalAmount'])} · ${_formatApiDate(order['orderDate'] ?? order['createdAt'])}',
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        if (widget.state.isStaff)
                          _DataLine(
                            label: 'Số điện thoại',
                            value: order['phoneNumber'],
                          ),
                        _DataLine(
                          label: 'Thanh toán',
                          value: _paymentLabel(order['payment']),
                        ),
                        _DataLine(
                          label: 'Địa chỉ',
                          value: _shippingAddress(order),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OrderDetailPage(
                                  state: widget.state,
                                  orderId: _asInt(order['orderId']),
                                  onChanged: _reload,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('Chi tiết và theo dõi'),
                          ),
                        ),
                        if (widget.state.isStaff && _asInt(order['status']) < 4)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _updatingOrder
                                  ? null
                                  : () => _chooseOrderStatus(order),
                              icon: const Icon(Icons.sync_alt),
                              label: const Text('Cập nhật trạng thái đơn'),
                            ),
                          ),
                        if (_canPayWithZalo(order))
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () => _payZalo(order),
                              icon: const Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
                              label: const Text('Tiếp tục thanh toán ZaloPay'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
    },
  );

  Future<void> _chooseOrderStatus(Map<String, dynamic> order) async {
    final currentStatus = _asInt(order['status']);
    if (currentStatus < 0 || currentStatus >= 4) return;
    final shipping = _map(order['shipping']);
    final canComplete = currentStatus == 3 && _asInt(shipping['status']) == 4;
    final nextStatus = currentStatus < 3
        ? currentStatus + 1
        : canComplete
        ? 4
        : null;
    final selectedStatus = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xử lý đơn hàng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trạng thái hiện tại: ${_orderStatus(currentStatus)}.'),
            const SizedBox(height: 8),
            if (nextStatus != null)
              Text('Bước tiếp theo: ${_orderStatus(nextStatus)}.')
            else
              const Text(
                'Chỉ có thể hoàn tất đơn sau khi Shipper xác nhận giao hàng thành công.',
              ),
            const SizedBox(height: 8),
            const Text(
              'Không thể bỏ qua bước. Máy chủ sẽ kiểm tra và xác nhận thay đổi.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau'),
          ),
          if (currentStatus < 4)
            TextButton(
              onPressed: () => Navigator.pop(context, 5),
              child: const Text('Hủy đơn hàng'),
            ),
          if (nextStatus != null)
            FilledButton(
              onPressed: () => Navigator.pop(context, nextStatus),
              child: Text('Chuyển sang ${_orderStatus(nextStatus)}'),
            ),
        ],
      ),
    );
    if (selectedStatus == null || !mounted) return;

    final targetLabel = selectedStatus == 5
        ? 'hủy đơn hàng'
        : 'chuyển đơn sang "${_orderStatus(selectedStatus)}"';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thay đổi'),
        content: Text('Bạn có chắc muốn $targetLabel không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final orderId = _asInt(order['orderId']);
    if (orderId <= 0) {
      showNotice(context, 'Đơn hàng thiếu thông tin cần thiết để cập nhật.');
      return;
    }
    setState(() => _updatingOrder = true);
    try {
      await widget.state.api.put('Order/$orderId', {'status': selectedStatus});
      if (!mounted) return;
      showNotice(
        context,
        selectedStatus == 5
            ? 'Đã hủy đơn hàng.'
            : 'Đã cập nhật đơn sang "${_orderStatus(selectedStatus)}".',
      );
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    } catch (error) {
      if (mounted) showNotice(context, 'Không thể cập nhật đơn hàng: $error');
    } finally {
      if (mounted) setState(() => _updatingOrder = false);
    }
  }

  bool _canPayWithZalo(Map<String, dynamic> order) {
    if (!widget.state.isCustomer) return false;
    final payment = _map(order['payment']);
    return _asInt(payment['paymentMethod']) == 2 &&
        _asInt(payment['status']) != 1 &&
        _asInt(order['orderId']) > 0;
  }

  Future<void> _payZalo(Map<String, dynamic> order) async {
    final orderId = _asInt(order['orderId']);
    try {
      final payment = await widget.state.createZaloPayPayment(orderId);
      if (!mounted) return;
      final paid = await showDialog<bool>(
        context: context,
        builder: (_) => ZaloPayDialog(
          state: widget.state,
          orderId: orderId,
          orderCode: '${order['orderCode'] ?? ''}',
          orderUrl: '${payment['orderUrl'] ?? ''}',
          alreadyPaid: payment['isPaid'] == true,
        ),
      );
      if (paid == true) {
        await _reload();
      }
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    }
  }
}

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    required this.state,
    required this.orderId,
    required this.onChanged,
    super.key,
  });

  final AppState state;
  final int orderId;
  final Future<void> Function() onChanged;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Map<String, dynamic> _order = {};
  List<Map<String, dynamic>> _trackingLogs = [];
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  List<Map<String, dynamic>> get _items {
    final value = _order['orderDetails'] ?? _order['items'];
    if (value is! List) return [];
    return value.whereType<Map>().map(_map).toList();
  }

  Map<String, dynamic> get _shipping => _map(_order['shipping']);

  bool get _canCancel {
    final status = _asInt(_order['status']);
    return widget.state.isCustomer &&
        status >= 0 &&
        status < 4 &&
        _firstText(_shipping, ['shippedAt']).isEmpty &&
        _asInt(_shipping['status']) < 2;
  }

  bool get _canConfirmReceived =>
      widget.state.isCustomer && _asInt(_order['status']) == 3;

  bool get _isCompleted => _asInt(_order['status']) == 4;

  bool get _isWaitingZaloPay {
    final payment = _map(_order['payment']);
    return widget.state.isCustomer &&
        _asInt(_order['status']) == 0 &&
        _asInt(payment['paymentMethod']) == 2 &&
        _asInt(payment['status']) == 0;
  }

  Future<void> _payWithZaloPay() async {
    final orderId = widget.orderId;
    final orderCode = '${_order['orderCode'] ?? ''}';
    try {
      final payment = await widget.state.createZaloPayPayment(orderId);
      if (!mounted) return;
      final paid = await showDialog<bool>(
        context: context,
        builder: (_) => ZaloPayDialog(
          state: widget.state,
          orderId: orderId,
          orderCode: orderCode,
          orderUrl: '${payment['orderUrl'] ?? ''}',
          alreadyPaid: payment['isPaid'] == true,
        ),
      );
      if (!mounted) return;
      if (paid == true) {
        showNotice(context, 'Thanh toán ZaloPay thành công!');
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait([
        widget.state.api.get('Order/${widget.orderId}'),
        widget.state.api.get('Order/${widget.orderId}/tracking-logs'),
      ]);
      _order = _map(result[0]);
      _trackingLogs = result[1] is List
          ? (result[1] as List).whereType<Map>().map(_map).toList()
          : [];
    } on ApiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = 'Không thể tải chi tiết đơn hàng: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy đơn hàng?'),
        content: const Text(
          'Bạn chỉ có thể hủy trước khi shipper lấy hàng. Nếu đã thanh toán trước, vui lòng liên hệ cửa hàng để đối soát hoàn tiền.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _submitCustomerAction(
      path: 'Order/${widget.orderId}/cancel',
      successMessage: 'Đã gửi yêu cầu hủy đơn.',
    );
  }

  Future<void> _confirmReceived() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đã nhận hàng'),
        content: const Text(
          'Chỉ xác nhận nếu bạn đã thực sự nhận đủ hàng. Đơn sẽ được hoàn tất.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Chưa nhận'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đã nhận hàng'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _submitCustomerAction(
      path: 'Order/${widget.orderId}/complete-delivery',
      successMessage: 'Đã xác nhận nhận hàng.',
    );
  }

  Future<void> _submitCustomerAction({
    required String path,
    required String successMessage,
  }) async {
    setState(() => _submitting = true);
    try {
      final result = await widget.state.api.post(path);
      if (!mounted) return;
      final message = _map(result)['message'];
      showNotice(context, message is String ? message : successMessage);
      await Future.wait([_load(), widget.onChanged()]);
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    } catch (error) {
      if (mounted) showNotice(context, 'Không thể cập nhật đơn hàng: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderCode = '${_order['orderCode'] ?? 'Đơn hàng'}';
    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết $orderCode'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorPanel(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _orderStatus(_order['status']),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          _DataLine(
                            label: 'Ngày đặt',
                            value: _formatApiDate(
                              _order['orderDate'] ?? _order['createdAt'],
                            ),
                          ),
                          _DataLine(
                            label: 'Người nhận',
                            value:
                                _shipping['receiverName'] ??
                                _order['customerName'],
                          ),
                          _DataLine(
                            label: 'Số điện thoại',
                            value:
                                _shipping['receiverPhone'] ??
                                _order['phoneNumber'],
                          ),
                          _DataLine(
                            label: 'Địa chỉ giao hàng',
                            value: _shipping['address'],
                          ),
                          _DataLine(
                            label: 'Mã vận đơn',
                            value: _shipping['trackingCode'],
                          ),
                          _DataLine(
                            label: 'Shipper',
                            value:
                                _map(_shipping['shipper'])['fullName'] ??
                                _shipping['shipperName'],
                          ),
                          _DataLine(
                            label: 'Tình trạng giao',
                            value: _shippingStatus(_shipping['status']),
                          ),
                          if (_shipping['failReason'] != null)
                            _DataLine(
                              label: 'Lý do giao thất bại',
                              value: _shipping['failReason'],
                            ),
                          if (_canCancel ||
                              _canConfirmReceived ||
                              _isWaitingZaloPay ||
                              (_isCompleted && widget.state.isCustomer)) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_isWaitingZaloPay)
                                  FilledButton.icon(
                                    onPressed: _submitting
                                        ? null
                                        : _payWithZaloPay,
                                    icon: const Icon(
                                      Icons.account_balance_wallet,
                                    ),
                                    label: const Text('Thanh toán ZaloPay'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF0068FF),
                                    ),
                                  ),
                                if (_canCancel)
                                  OutlinedButton.icon(
                                    onPressed: _submitting
                                        ? null
                                        : _cancelOrder,
                                    icon: const Icon(Icons.cancel_outlined),
                                    label: const Text('Hủy đơn'),
                                  ),
                                if (_canConfirmReceived)
                                  FilledButton.icon(
                                    onPressed: _submitting
                                        ? null
                                        : _confirmReceived,
                                    icon: const Icon(
                                      Icons.inventory_2_outlined,
                                    ),
                                    label: const Text('Tôi đã nhận hàng'),
                                  ),
                                if (_isCompleted &&
                                    widget.state.isCustomer) ...[
                                  FilledButton.icon(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => OrderReviewPage(
                                          state: widget.state,
                                          order: _order,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.star_outline,
                                      size: 18,
                                    ),
                                    label: const Text('Đánh giá sản phẩm'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.amber.shade800,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ReturnRequestFormPage(
                                          state: widget.state,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.assignment_return_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Yêu cầu đổi trả'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sản phẩm trong đơn',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_items.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'API chưa trả chi tiết mặt hàng cho đơn này.',
                        ),
                      ),
                    )
                  else
                    for (final item in _items)
                      Card(
                        child: ListTile(
                          leading: _orderItemImage(
                            widget.state,
                            item['imageUrl'] ?? item['productImageUrl'],
                          ),
                          title: Text(
                            '${item['productName'] ?? item['name'] ?? 'Sản phẩm'}',
                          ),
                          subtitle: Text(
                            [
                              if (item['variantAttributes'] != null)
                                '${item['variantAttributes']}',
                              if (item['sku'] != null) 'SKU ${item['sku']}',
                              'SL ${item['quantity'] ?? 1}',
                              '${money(item['unitPrice'])} / sản phẩm',
                            ].join(' · '),
                          ),
                          trailing: Text(
                            money(
                              item['totalAmount'] ??
                                  item['totalPrice'] ??
                                  ((_asInt(item['quantity']) *
                                      (_asInt(item['unitPrice'])))),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _DataLine(
                            label: 'Tạm tính',
                            value: money(_order['subtotal']),
                          ),
                          _DataLine(
                            label: 'Giảm giá',
                            value: money(_order['discountAmount']),
                          ),
                          _DataLine(
                            label: 'Phí giao hàng',
                            value: money(_order['shippingFee']),
                          ),
                          _DataLine(
                            label: 'Tổng thanh toán',
                            value: money(_order['totalAmount']),
                          ),
                          _DataLine(
                            label: 'Thanh toán',
                            value: _paymentLabel(_order['payment']),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hành trình và nhật ký giao hàng',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Card(
                    child: _trackingLogs.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Chưa có nhật ký vận chuyển.'),
                          )
                        : Column(
                            children: [
                              for (final log in _trackingLogs)
                                ListTile(
                                  leading: const Icon(
                                    Icons.radio_button_checked,
                                    color: _rose,
                                  ),
                                  title: Text(
                                    '${log['action'] ?? log['newStatus'] ?? 'Cập nhật vận chuyển'}',
                                  ),
                                  subtitle: Text(
                                    [
                                      if (log['previousStatus'] != null &&
                                          log['previousStatus'] !=
                                              log['newStatus'])
                                        '${log['previousStatus']} → ${log['newStatus']}',
                                      if (log['note'] != null) '${log['note']}',
                                      '${log['performedByName'] ?? 'Hệ thống'}${log['performedByRole'] == null ? '' : ' · ${log['performedByRole']}'}',
                                      _formatApiDate(log['createdAt']),
                                    ].join('\n'),
                                  ),
                                  isThreeLine: true,
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

String _shippingStatus(dynamic value) => switch (_asInt(value)) {
  1 => 'Đang giao',
  2 => 'Giao thành công',
  3 => 'Giao thất bại',
  4 => 'Đang giao lại',
  5 => 'Đã hoàn kho',
  _ => 'Chờ xuất kho',
};

Widget _orderItemImage(AppState state, dynamic imageUrl) {
  final path = imageUrl?.toString().trim() ?? '';
  if (path.isEmpty) {
    return const CircleAvatar(child: Icon(Icons.toys_outlined));
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.network(
      state.api.absoluteAssetUrl(path),
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const CircleAvatar(child: Icon(Icons.toys_outlined)),
    ),
  );
}

String _shippingAddress(Map<String, dynamic> order) {
  final shipping = order['shipping'];
  return shipping is Map ? displayValue(shipping['address']) : '—';
}

String _paymentLabel(dynamic value) {
  final payment = _map(value);
  final method = _asInt(payment['paymentMethod']);
  final status = _asInt(payment['status']);
  final methodText = switch (method) {
    0 => 'COD',
    1 => 'Chuyển khoản ngân hàng',
    2 => 'ZaloPay',
    _ => 'Chưa có thông tin',
  };
  final statusText = status == 1 ? 'Đã thanh toán' : 'Chờ thanh toán';
  return '$methodText · $statusText';
}

String _orderStatus(dynamic value) {
  final v = _asInt(value);
  switch (v) {
    case 0:
      return 'Chờ xác nhận';
    case 1:
      return 'Đã xác nhận';
    case 2:
      return 'Đang xử lý';
    case 3:
      return 'Đang giao';
    case 4:
      return 'Hoàn tất';
    case 5:
      return 'Đã hủy';
    default:
      return 'Trạng thái ${displayValue(value)}';
  }
}

class OrderReviewPage extends StatefulWidget {
  const OrderReviewPage({required this.state, required this.order, super.key});

  final AppState state;
  final Map<String, dynamic> order;

  @override
  State<OrderReviewPage> createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<OrderReviewPage> {
  final Map<int, int> _ratings = {};
  final Map<int, TextEditingController> _comments = {};
  bool _submitting = false;

  List<Map<String, dynamic>> get _items {
    final list = widget.order['orderDetails'] ?? widget.order['items'];
    if (list is! List) return [];
    return list.whereType<Map>().map(_map).toList();
  }

  @override
  void initState() {
    super.initState();
    for (final item in _items) {
      final pid = _asInt(item['productId'] ?? item['id']);
      _ratings[pid] = 5;
      _comments[pid] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _comments.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submitReviews() async {
    final orderId = _asInt(widget.order['orderId'] ?? widget.order['id']);
    if (orderId <= 0) {
      showNotice(context, 'Mã đơn hàng không hợp lệ.');
      return;
    }

    setState(() => _submitting = true);
    try {
      for (final item in _items) {
        final pid = _asInt(item['productId'] ?? item['id']);
        if (pid <= 0) continue;
        final rating = _ratings[pid] ?? 5;
        final comment = _comments[pid]?.text.trim() ?? '';

        await widget.state.api.post('ProductReview', {
          'orderId': orderId,
          'productId': pid,
          'rating': rating,
          'comment': comment.isEmpty ? 'Sản phẩm rất tốt!' : comment,
        });
      }

      if (mounted) {
        showNotice(context, 'Cảm ơn bạn đã gửi đánh giá sản phẩm!');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) showNotice(context, e.message);
    } catch (e) {
      if (mounted) showNotice(context, 'Không thể gửi đánh giá: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Đánh giá đơn #${widget.order['orderCode'] ?? widget.order['orderId']}',
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _submitting ? null : _submitReviews,
            style: FilledButton.styleFrom(
              backgroundColor: _rose,
              minimumSize: const Size.fromHeight(50),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Gửi đánh giá',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Hãy chia sẻ cảm nhận của bạn về sản phẩm đã mua:',
            style: TextStyle(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 16),
          if (_items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Không tìm thấy danh sách sản phẩm trong đơn.'),
              ),
            )
          else
            for (final item in _items) ...[
              Builder(
                builder: (context) {
                  final pid = _asInt(item['productId'] ?? item['id']);
                  final currentRating = _ratings[pid] ?? 5;
                  final commentCtrl = _comments[pid] ?? TextEditingController();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _orderItemImage(
                                widget.state,
                                item['imageUrl'] ?? item['productImageUrl'],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${item['productName'] ?? item['name'] ?? 'Sản phẩm'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Chất lượng sản phẩm:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              for (int i = 1; i <= 5; i++)
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _ratings[pid] = i),
                                  icon: Icon(
                                    Icons.star,
                                    size: 32,
                                    color: i <= currentRating
                                        ? Colors.amber
                                        : Colors.grey.shade300,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                switch (currentRating) {
                                  5 => 'Tuyệt vời',
                                  4 => 'Tốt',
                                  3 => 'Bình thường',
                                  2 => 'Không hài lòng',
                                  _ => 'Rất tệ',
                                },
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _rose,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: commentCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText:
                                  'Hãy chia sẻ cảm nhận về đồ chơi cho bé nhé...',
                              labelText: 'Nhận xét chi tiết',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
        ],
      ),
    );
  }
}

class RewardsPage extends StatefulWidget {
  const RewardsPage({required this.state, super.key});

  final AppState state;

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  dynamic _summary;
  List<dynamic> _vouchers = [];
  String? _error;
  bool _loading = true;
  int? _redeemingVoucherId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.state.api.get('LoyaltyTransaction/summary'),
        widget.state.api.get('Voucher/available'),
      ]);
      _summary = results[0];
      _vouchers = results[1] is List ? results[1] as List : [];
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redeem(Map voucher) async {
    final voucherId = _asInt(voucher['voucherId']);
    if (voucherId <= 0) {
      showNotice(context, 'Voucher chưa có mã nhận diện hợp lệ.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi điểm lấy voucher?'),
        content: Text(
          'Dùng ${voucher['requiredPoints'] ?? 0} điểm để đổi "${voucher['name'] ?? 'voucher'}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đổi voucher'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _redeemingVoucherId = voucherId);
    try {
      final result = _map(
        await widget.state.api.post('LoyaltyTransaction/redeem/$voucherId'),
      );
      if (mounted) {
        showNotice(
          context,
          '${result['message'] ?? 'Đổi voucher thành công.'}',
        );
        await _load();
      }
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _redeemingVoucherId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorPanel(message: _error!, onRetry: _load);
    }

    final summary = _map(_summary);
    final redeemable = summary['redeemableVouchers'] is List
        ? (summary['redeemableVouchers'] as List)
              .whereType<Map>()
              .map(_map)
              .toList()
        : <Map<String, dynamic>>[];
    final transactions = summary['transactions'] is List
        ? (summary['transactions'] as List).whereType<Map>().map(_map).toList()
        : <Map<String, dynamic>>[];
    final points = _asInt(summary['loyaltyPoint']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE11D48), Color(0xFFF97384)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ĐIỂM THƯỞNG CỦA BẠN',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  '$points điểm',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Đổi điểm lấy voucher',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (redeemable.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Hiện chưa có voucher để đổi điểm.'),
              ),
            )
          else
            for (final voucher in redeemable)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.card_giftcard_outlined,
                    color: _rose,
                  ),
                  title: Text('${voucher['name'] ?? 'Voucher'}'),
                  subtitle: Text(
                    '${voucher['discountType'] == 1 ? '${voucher['discountValue']}%' : money(voucher['discountValue'])} · Cần ${voucher['requiredPoints'] ?? 0} điểm · Hạn ${_formatApiDate(voucher['endDate'])}',
                  ),
                  trailing: voucher['isRedeemed'] == true
                      ? const Chip(label: Text('Đã đổi'))
                      : FilledButton(
                          onPressed:
                              _redeemingVoucherId == null &&
                                  points >= _asInt(voucher['requiredPoints'])
                              ? () => _redeem(voucher)
                              : null,
                          child: Text(
                            _redeemingVoucherId == _asInt(voucher['voucherId'])
                                ? 'Đang đổi...'
                                : 'Đổi',
                          ),
                        ),
                ),
              ),
          const SizedBox(height: 18),
          Text(
            'Voucher đang có thể dùng khi đặt hàng',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (_vouchers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Hiện chưa có voucher khả dụng.'),
              ),
            )
          else
            for (final voucher in _vouchers.whereType<Map>())
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.confirmation_num_outlined,
                    color: _rose,
                  ),
                  title: Text(
                    '${voucher['name'] ?? voucher['code'] ?? 'Voucher'}',
                  ),
                  subtitle: Text('Mã: ${voucher['code'] ?? '—'}'),
                  trailing: IconButton(
                    tooltip: 'Hướng dẫn áp dụng',
                    onPressed: () => showNotice(
                      context,
                      'Chọn mã voucher này tại bước xác nhận đơn hàng. Máy chủ sẽ kiểm tra điều kiện và tính lại số tiền.',
                    ),
                    icon: const Icon(Icons.info_outline),
                  ),
                ),
              ),
          const SizedBox(height: 18),
          Text(
            'Lịch sử điểm và đổi voucher',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chưa có giao dịch điểm thưởng.'),
              ),
            )
          else
            for (final transaction in transactions)
              Card(
                child: ListTile(
                  leading: Icon(
                    _asInt(transaction['points']) < 0
                        ? Icons.remove_circle_outline
                        : Icons.add_circle_outline,
                    color: _asInt(transaction['points']) < 0
                        ? Colors.deepOrange
                        : Colors.green,
                  ),
                  title: Text(
                    '${transaction['description'] ?? 'Giao dịch điểm'}',
                  ),
                  subtitle: Text(_formatApiDate(transaction['createdAt'])),
                  trailing: Text(
                    '${_asInt(transaction['points']) > 0 ? '+' : ''}${transaction['points'] ?? 0}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({required this.state, super.key});

  final AppState state;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.state.isCustomer) {
      setState(() => _loading = false);
      return;
    }
    try {
      await widget.state.loadProfile();
      _name.text =
          '${widget.state.profile['fullName'] ?? widget.state.fullName}';
      _phone.text = '${widget.state.profile['phone'] ?? ''}';
      _address.text = '${widget.state.profile['address'] ?? ''}';
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.state.saveProfile(fullName: _name.text, phone: _phone.text);
      if (mounted) showNotice(context, 'Đã lưu hồ sơ khách hàng.');
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final session = widget.state.session ?? {};
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFFFE4E9),
                  child: Icon(Icons.person, color: _rose),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${session['fullName'] ?? 'Tài khoản'}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${session['email'] ?? ''}',
                        style: const TextStyle(color: _muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vai trò: ${session['role'] ?? '—'}',
                        style: const TextStyle(
                          color: _rose,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.state.isCustomer) ...[
          const SizedBox(height: 20),
          Text(
            'Hồ sơ khách hàng',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Số điện thoại'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ mặc định',
              helperText:
                  'Địa chỉ giao hàng được quản lý trong sổ địa chỉ của máy chủ.',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Đang lưu...' : 'Lưu hồ sơ'),
          ),
          const SizedBox(height: 18),
          _ProfileLink(
            state: widget.state,
            title: 'Sổ địa chỉ giao hàng',
            icon: Icons.location_on_outlined,
            path: 'Customer/profile/addresses',
          ),
          _ProfileLink(
            state: widget.state,
            title: 'Yêu cầu đổi trả',
            icon: Icons.assignment_return_outlined,
            path: 'ReturnRequest/mine',
          ),
          _ProfileLink(
            state: widget.state,
            title: 'Hỗ trợ khách hàng',
            icon: Icons.support_agent,
            path: 'SupportChat/mine',
          ),
        ],
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: () => _changePassword(context),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Đổi mật khẩu'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              await widget.state.logout();
            } on ApiException catch (error) {
              if (context.mounted) showNotice(context, error.message);
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
        ),
      ],
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đổi mật khẩu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      );
      if (result == true) {
        await widget.state.changePassword(
          currentPassword: current.text,
          newPassword: next.text,
        );
        if (context.mounted) showNotice(context, 'Đã đổi mật khẩu.');
      }
    } on ApiException catch (error) {
      if (context.mounted) showNotice(context, error.message);
    } finally {
      current.dispose();
      next.dispose();
    }
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.state,
    required this.title,
    required this.icon,
    required this.path,
  });

  final AppState state;
  final String title;
  final IconData icon;
  final String path;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: _rose),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        final page = switch (path) {
          'Customer/profile/addresses' => AddressBookPage(state: state),
          'SupportChat/mine' => SupportChatPage(state: state),
          'ReturnRequest/mine' => ReturnRequestsPage(
            state: state,
            customerMode: true,
          ),
          _ => ApiModulePage(state: state, title: title, path: path),
        };
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
      },
    ),
  );
}

class AddressBookPage extends StatefulWidget {
  const AddressBookPage({required this.state, super.key});

  final AppState state;

  @override
  State<AddressBookPage> createState() => _AddressBookPageState();
}

class _AddressBookPageState extends State<AddressBookPage> {
  List<Map<String, dynamic>> _addresses = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.state.api.get('Customer/profile/addresses');
      _addresses = result is List
          ? result.whereType<Map>().map(_map).toList()
          : [];
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? address]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddressEditor(address: address),
    );
    if (result == null) return;
    final id = _asInt(address?['customerAddressId'] ?? address?['id']);
    try {
      if (id > 0) {
        await widget.state.api.put('Customer/profile/addresses/$id', result);
      } else {
        await widget.state.api.post('Customer/profile/addresses', result);
      }
      await _load();
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    }
  }

  Future<void> _delete(Map<String, dynamic> address) async {
    final id = _asInt(address['customerAddressId'] ?? address['id']);
    if (id <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa địa chỉ?'),
        content: const Text('Địa chỉ này sẽ bị xóa khỏi sổ địa chỉ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.state.api.delete('Customer/profile/addresses/$id');
      await _load();
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sổ địa chỉ'),
      actions: [
        IconButton(
          tooltip: 'Thêm địa chỉ',
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _ErrorPanel(message: _error!, onRetry: _load)
        : _addresses.isEmpty
        ? const _EmptyState(
            icon: Icons.location_on_outlined,
            title: 'Chưa lưu địa chỉ',
            subtitle: 'Thêm địa chỉ để đặt hàng nhanh hơn.',
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final address in _addresses)
                Card(
                  child: ListTile(
                    title: Text('${address['receiverName'] ?? 'Người nhận'}'),
                    subtitle: Text(
                      '${address['addressDetail'] ?? ''}, ${address['wardName'] ?? ''}, ${address['provinceName'] ?? ''}',
                    ),
                    leading: Icon(
                      address['isDefault'] == true
                          ? Icons.location_on
                          : Icons.location_on_outlined,
                      color: _rose,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _edit(address);
                        if (value == 'delete') _delete(address);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                        PopupMenuItem(value: 'delete', child: Text('Xóa')),
                      ],
                    ),
                  ),
                ),
            ],
          ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _edit(),
      child: const Icon(Icons.add),
    ),
  );
}

class _AddressEditor extends StatefulWidget {
  const _AddressEditor({this.address});

  final Map<String, dynamic>? address;

  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  late final _name = TextEditingController(
    text: '${widget.address?['receiverName'] ?? ''}',
  );
  late final _phone = TextEditingController(
    text: '${widget.address?['receiverPhone'] ?? ''}',
  );
  late final _detail = TextEditingController(
    text: '${widget.address?['addressDetail'] ?? ''}',
  );
  late final _province = TextEditingController(
    text: '${widget.address?['provinceName'] ?? ''}',
  );
  late final _provinceCode = TextEditingController(
    text: '${widget.address?['provinceCode'] ?? ''}',
  );
  late final _ward = TextEditingController(
    text: '${widget.address?['wardName'] ?? ''}',
  );
  late final _wardCode = TextEditingController(
    text: '${widget.address?['wardCode'] ?? ''}',
  );
  late bool _isDefault = widget.address?['isDefault'] == true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _detail.dispose();
    _province.dispose();
    _provinceCode.dispose();
    _ward.dispose();
    _wardCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.address == null ? 'Thêm địa chỉ' : 'Sửa địa chỉ'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_name, 'Tên người nhận'),
            _field(_phone, 'Số điện thoại', keyboardType: TextInputType.phone),
            _field(_detail, 'Địa chỉ chi tiết'),
            _field(_province, 'Tỉnh / thành phố'),
            _field(_provinceCode, 'Mã tỉnh / thành phố'),
            _field(_ward, 'Phường / xã'),
            _field(_wardCode, 'Mã phường / xã'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              onChanged: (value) => setState(() => _isDefault = value ?? false),
              title: const Text('Đặt làm địa chỉ mặc định'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          final fields = [
            _name,
            _phone,
            _detail,
            _province,
            _provinceCode,
            _ward,
            _wardCode,
          ];
          if (fields.any((field) => field.text.trim().isEmpty)) return;
          Navigator.pop(context, {
            'receiverName': _name.text.trim(),
            'receiverPhone': _phone.text.trim(),
            'addressDetail': _detail.text.trim(),
            'provinceName': _province.text.trim(),
            'provinceCode': _provinceCode.text.trim(),
            'wardName': _ward.text.trim(),
            'wardCode': _wardCode.text.trim(),
            'isDefault': _isDefault,
          });
        },
        child: const Text('Lưu'),
      ),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({required this.state, super.key});

  final AppState state;

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final _message = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  int? _conversationId;
  List<Map<String, dynamic>> _messages = [];
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _openConversation();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _message.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openConversation() async {
    try {
      final conversation = await widget.state.api.post('SupportChat/mine');
      final map = _map(conversation);
      _conversationId = _asInt(map['conversationId']);
      if (_conversationId == null || _conversationId == 0) {
        throw const ApiException('Máy chủ chưa trả về mã cuộc trò chuyện.');
      }
      await _loadMessages();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _loadMessages(),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _loadMessages() async {
    final id = _conversationId;
    if (id == null) return;
    try {
      final result = await widget.state.api.get('SupportChat/$id/messages');
      if (mounted) {
        setState(() {
          _messages = result is List
              ? result.whereType<Map>().map(_map).toList()
              : [];
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _send() async {
    final id = _conversationId;
    if (id == null || _message.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.state.api.post('SupportChat/$id/messages', {
        'content': _message.text.trim(),
      });
      _message.clear();
      await _loadMessages();
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Hỗ trợ khách hàng'),
      actions: [
        IconButton(onPressed: _loadMessages, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: _error != null && _conversationId == null
        ? _ErrorPanel(message: _error!, onRetry: _openConversation)
        : Column(
            children: [
              if (_error != null)
                MaterialBanner(
                  content: Text(_error!),
                  actions: [
                    TextButton(
                      onPressed: _loadMessages,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              Expanded(
                child: _messages.isEmpty
                    ? const _EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'Bắt đầu trò chuyện',
                        subtitle: 'Nhân viên cửa hàng sẽ phản hồi tại đây.',
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return Align(
                            alignment: message['senderRole'] == 'Customer'
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: message['senderRole'] == 'Customer'
                                    ? const Color(0xFFFFE4E9)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text('${message['content'] ?? ''}'),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _message,
                          decoration: const InputDecoration(
                            hintText: 'Nhập tin nhắn...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.state, super.key});

  final AppState state;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _inventory = {};
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.state.api.get('Dashboard/summary'),
        widget.state.api.get('Dashboard/inventory'),
      ]);
      _summary = _map(results[0]);
      _inventory = _map(results[1]);
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorPanel(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Xin chào, ${widget.state.fullName}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tổng quan hoạt động cửa hàng',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                label: 'Doanh thu',
                value: money(
                  _first(_summary, ['totalRevenue', 'revenue', 'totalSales']),
                ),
                icon: Icons.trending_up,
              ),
              _MetricCard(
                label: 'Đơn hàng',
                value: displayValue(
                  _first(_summary, ['totalOrders', 'orderCount', 'orders']),
                ),
                icon: Icons.receipt_long,
              ),
              _MetricCard(
                label: 'Sắp hết hàng',
                value: displayValue(
                  _first(_inventory, [
                    'lowStockCount',
                    'lowStock',
                    'warningCount',
                  ]),
                ),
                icon: Icons.warning_amber_rounded,
              ),
              _MetricCard(
                label: 'Tồn kho',
                value: displayValue(
                  _first(_inventory, [
                    'totalProducts',
                    'totalVariants',
                    'totalStock',
                  ]),
                ),
                icon: Icons.inventory_2_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Truy cập nhanh', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _QuickLink(
            icon: Icons.bar_chart,
            title: 'Báo cáo doanh thu',
            subtitle: 'Doanh thu, đơn hàng, sản phẩm bán chạy',
            onTap: () => _openModule(
              context,
              widget.state,
              'Báo cáo doanh thu',
              'Dashboard/financial-report',
            ),
          ),
          _QuickLink(
            icon: Icons.local_shipping_outlined,
            title: 'Điều phối giao hàng',
            subtitle: 'Gộp lô, phân công shipper và đối soát COD',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DeliveryManagementPage(state: widget.state),
              ),
            ),
          ),
          _QuickLink(
            icon: Icons.support_agent,
            title: 'Chăm sóc khách hàng',
            subtitle: 'Phản hồi và xử lý yêu cầu hỗ trợ',
            onTap: () => _openModule(
              context,
              widget.state,
              'Chăm sóc khách hàng',
              'SupportChat',
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 42) / 2,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _rose),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFFEFF1),
        child: Icon(icon, color: _rose),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class OperationsPage extends StatefulWidget {
  const OperationsPage({required this.state, super.key});

  final AppState state;

  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage> {
  final _search = TextEditingController();

  static const _groups = <_ApiGroup>[
    _ApiGroup('Sản phẩm và bán hàng', Icons.toys_outlined, [
      ApiAction('Sản phẩm', 'GET', 'Product'),
      ApiAction('Danh mục', 'GET', 'Category'),
      ApiAction('Thương hiệu', 'GET', 'Brand'),
      ApiAction('Nhà cung cấp', 'GET', 'Supplier'),
      ApiAction('Khuyến mãi', 'GET', 'Promotion'),
      ApiAction('Voucher', 'GET', 'Voucher'),
    ]),
    _ApiGroup('Kho hàng', Icons.inventory_2_outlined, [
      ApiAction('Tồn kho', 'GET', 'Inventory'),
      ApiAction('Lịch sử kho', 'GET', 'InventoryTransaction'),
      ApiAction('Thanh lý', 'GET', 'Liquidation'),
      ApiAction('Báo cáo tồn kho', 'GET', 'ManagementReport/inventory'),
    ]),
    _ApiGroup('Khách hàng', Icons.people_outline, [
      ApiAction('Khách hàng', 'GET', 'Customer'),
      ApiAction('Đánh giá và phản hồi', 'GET', 'CustomerFeedback'),
      ApiAction('Giao dịch điểm thưởng', 'GET', 'LoyaltyTransaction'),
    ]),
    _ApiGroup('Thanh toán và báo cáo', Icons.analytics_outlined, [
      ApiAction('Báo cáo tài chính', 'GET', 'Dashboard/financial-report'),
      ApiAction('Thống kê đơn hàng', 'GET', 'Dashboard/orders'),
      ApiAction('Sản phẩm bán chạy', 'GET', 'Dashboard/best-selling'),
      ApiAction('Thanh toán', 'GET', 'Payment'),
    ]),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Nghiệp vụ cửa hàng',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          'Các thao tác thường dùng được đặt ở đầu danh sách.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Tìm chức năng quản lý',
          ),
        ),
        if (widget.state.canManageInventory) ...[
          const SizedBox(height: 16),
          Text(
            'Thao tác nhanh',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          _OperationTile(
            icon: Icons.toys_outlined,
            title: 'Quản lý sản phẩm',
            subtitle: 'Tạo, sửa, tìm kiếm và lọc sản phẩm',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductManagerPage(state: widget.state),
              ),
            ),
          ),
          _OperationTile(
            icon: Icons.inventory_2_outlined,
            title: 'Nhập hàng vào kho',
            subtitle: 'Tạo phiếu nhập và xác nhận hàng đã nhận',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ImportReceiptsPage(state: widget.state),
              ),
            ),
          ),
          _OperationTile(
            icon: Icons.category_outlined,
            title: 'Quản lý danh mục',
            subtitle: 'Tạo, sửa, vô hiệu hóa và xem sản phẩm liên kết',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReferenceManagerPage(
                  state: widget.state,
                  kind: ReferenceCreateKind.category,
                ),
              ),
            ),
          ),
          _OperationTile(
            icon: Icons.business_outlined,
            title: 'Quản lý nhà cung cấp',
            subtitle:
                'Cập nhật thông tin, vô hiệu hóa và xem sản phẩm cung ứng',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReferenceManagerPage(
                  state: widget.state,
                  kind: ReferenceCreateKind.supplier,
                ),
              ),
            ),
          ),
          _OperationTile(
            icon: Icons.sell_outlined,
            title: 'Quản lý thương hiệu',
            subtitle: 'Tạo, sửa, vô hiệu hóa và xem sản phẩm liên kết',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReferenceManagerPage(
                  state: widget.state,
                  kind: ReferenceCreateKind.brand,
                ),
              ),
            ),
          ),
          _OperationTile(
            icon: Icons.local_offer_outlined,
            title: 'Khuyến mãi và voucher',
            subtitle: 'Quản lý mức giảm, điều kiện, thời hạn và lượt dùng',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MarketingManagementPage(state: widget.state),
              ),
            ),
          ),
          _OperationTile(
            icon: Icons.warehouse_outlined,
            title: 'Tồn kho và thanh lý',
            subtitle: 'Điều chỉnh tồn và lập/xác nhận phiếu thanh lý',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InventoryLiquidationPage(state: widget.state),
              ),
            ),
          ),
          _OperationTile(
            icon: Icons.people_outline,
            title: 'Khách hàng',
            subtitle: 'Cập nhật hồ sơ và trạng thái khách hàng',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerManagementPage(state: widget.state),
              ),
            ),
          ),
          if (widget.state.isAdmin)
            _OperationTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Người dùng và phân quyền',
              subtitle: 'Gán vai trò và kích hoạt/tạm khóa tài khoản',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserManagementPage(state: widget.state),
                ),
              ),
            ),
        ],
        const SizedBox(height: 4),
        _OperationTile(
          icon: Icons.notifications_active_outlined,
          title: 'Thông báo hệ thống',
          subtitle: 'Theo dõi đơn hàng, kho, sản phẩm và nộp COD gần đây',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StaffNotificationsPage(state: widget.state),
            ),
          ),
        ),
        _OperationTile(
          icon: Icons.assignment_return_outlined,
          title: 'Duyệt đổi trả',
          subtitle: 'Xem yêu cầu, duyệt/từ chối và xác nhận hàng hoàn',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ReturnRequestsPage(state: widget.state, customerMode: false),
            ),
          ),
        ),
        _OperationTile(
          icon: Icons.support_agent,
          title: 'Chat hỗ trợ',
          subtitle: 'Tiếp nhận và trả lời tin nhắn khách hàng',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SupportChatInboxPage(state: widget.state),
            ),
          ),
        ),
        _OperationTile(
          icon: Icons.local_shipping_outlined,
          title: 'Điều phối giao hàng và thu tiền',
          subtitle:
              'Gộp lô, phân công shipper, giao lại và đối soát COD/doanh thu',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DeliveryManagementPage(state: widget.state),
            ),
          ),
        ),
        for (final group in _groups) ...[
          if (query.isEmpty ||
              group.title.toLowerCase().contains(query) ||
              group.actions.any(
                (action) => action.label.toLowerCase().contains(query),
              )) ...[
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                leading: Icon(group.icon, color: _rose),
                title: Text(group.title),
                children: [
                  for (final action in group.actions.where(
                    (item) =>
                        query.isEmpty ||
                        item.label.toLowerCase().contains(query) ||
                        group.title.toLowerCase().contains(query),
                  ))
                    ListTile(
                      dense: true,
                      title: Text(action.label),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _openModule(
                        context,
                        widget.state,
                        action.label,
                        action.path,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFFEFF1),
        child: Icon(icon, color: _rose),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _ApiGroup {
  const _ApiGroup(this.title, this.icon, this.actions);

  final String title;
  final IconData icon;
  final List<ApiAction> actions;
}

class ShipperPage extends StatefulWidget {
  const ShipperPage({required this.state, super.key});

  final AppState state;

  @override
  State<ShipperPage> createState() => _ShipperPageState();
}

class _ShipperPageState extends State<ShipperPage> {
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic> _profile = {};
  String? _error;
  bool _loading = true;
  int _tabIndex = 0; // 0: Tất cả, 1: Cần giao, 2: Hoàn tất, 3: Thất bại

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.state.api.get('Shipper/my-orders'),
        widget.state.api.get('Shipper/me').catchError((_) => {}),
      ]);
      _orders = results[0] is List
          ? (results[0] as List).whereType<Map>().map(_map).toList()
          : [];
      _profile = _map(results[1]);
    } on ApiException catch (error) {
      _error = error.message;
    } catch (e) {
      _error = 'Lỗi tải đơn giao: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(int orderId, String action) async {
    Object? body;
    if (action == 'fail-delivery') {
      body = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => const _FailDeliveryDialog(),
      );
      if (body == null) return;
    } else if (action == 'submit-cod') {
      if (!await _deliveryActionConfirmation(
        context,
        'Báo đã nộp tiền COD?',
        'Cửa hàng sẽ kiểm đếm số tiền hàng (không gồm phí giao) trước khi ghi nhận vào quỹ.',
      )) {
        return;
      }
      body = {'note': 'Shipper đã báo nộp tiền COD về cửa hàng'};
    }
    try {
      await widget.state.api.post('Shipper/orders/$orderId/$action', body);
      if (mounted) {
        showNotice(context, 'Đã gửi cập nhật giao hàng.');
        await _load();
      }
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((o) {
      final shipping = _map(o['shipping']);
      final status = _asInt(shipping['status']);
      switch (_tabIndex) {
        case 1: // Cần giao
          return status != 4 && status != 5 && status != 6;
        case 2: // Hoàn tất
          return status == 4;
        case 3: // Thất bại
          return status == 5;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorPanel(message: _error!, onRetry: _load);

    final displayOrders = _filteredOrders;
    final codHolding = _profile['currentCodHolding'] != null
        ? _asNum(_profile['currentCodHolding'])
        : 0.0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Đơn được phân công',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Đối soát COD',
                onPressed: () => _openModule(
                  context,
                  widget.state,
                  'Đối soát COD',
                  'Shipper/cod-reconciliation',
                ),
                icon: const Icon(Icons.account_balance_wallet_outlined),
              ),
            ],
          ),
          if (codHolding > 0)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Color(0xFFB45309),
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tiền thu hộ COD đang giữ:',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                        Text(
                          money(codHolding),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _openModule(
                      context,
                      widget.state,
                      'Đối soát COD',
                      'Shipper/cod-reconciliation',
                    ),
                    child: const Text('Xem ví COD'),
                  ),
                ],
              ),
            ),
          _ShipperPerformanceSummary(orders: _orders),
          const SizedBox(height: 12),
          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('Tất cả (${_orders.length})'),
                  selected: _tabIndex == 0,
                  onSelected: (_) => setState(() => _tabIndex = 0),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'Cần giao (${_orders.where((o) => _asInt(_map(o['shipping'])['status']) != 4 && _asInt(_map(o['shipping'])['status']) != 5).length})',
                  ),
                  selected: _tabIndex == 1,
                  onSelected: (_) => setState(() => _tabIndex = 1),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'Đã giao (${_orders.where((o) => _asInt(_map(o['shipping'])['status']) == 4).length})',
                  ),
                  selected: _tabIndex == 2,
                  onSelected: (_) => setState(() => _tabIndex = 2),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'Thất bại (${_orders.where((o) => _asInt(_map(o['shipping'])['status']) == 5).length})',
                  ),
                  selected: _tabIndex == 3,
                  onSelected: (_) => setState(() => _tabIndex = 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (displayOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 50),
              child: _EmptyState(
                icon: Icons.local_shipping_outlined,
                title: 'Không có đơn trong mục này',
                subtitle: 'Đơn hàng được phân công sẽ xuất hiện tại đây.',
              ),
            )
          else
            for (final order in displayOrders)
              _ShipperOrderCard(order: order, onAction: _run),
        ],
      ),
    );
  }
}

class _ShipperOrderCard extends StatelessWidget {
  const _ShipperOrderCard({required this.order, required this.onAction});

  final Map<String, dynamic> order;
  final Future<void> Function(int orderId, String action) onAction;

  @override
  Widget build(BuildContext context) {
    final orderId = _asInt(order['orderId']);
    final shipping = _map(order['shipping']);
    final shippingStatus = _asInt(shipping['status']);
    final payment = _map(order['payment']);
    final isCod = _asInt(payment['paymentMethod']) == 0;
    final phone = (order['phoneNumber'] ?? shipping['receiverPhone'] ?? '')
        .toString()
        .trim();
    final address = (shipping['address'] ?? '').toString().trim();

    final actions = switch (shippingStatus) {
      0 => const [('Nhận đơn', 'accept-order')],
      1 => const [('Đã lấy hàng', 'pickup')],
      2 => const [('Bắt đầu giao', 'start-delivery')],
      3 => const [
        ('Giao thành công', 'complete-delivery'),
        ('Giao thất bại', 'fail-delivery'),
      ],
      4 when isCod && _asInt(payment['codStatus']) == 1 => const [
        ('Báo đã nộp COD', 'submit-cod'),
      ],
      5 => const [('Giao lại đơn này', 'retry-delivery')],
      _ => const <(String, String)>[],
    };

    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Đơn #${order['orderCode'] ?? orderId}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: switch (shippingStatus) {
                      4 => Colors.green.shade50,
                      5 => Colors.red.shade50,
                      3 => Colors.blue.shade50,
                      _ => Colors.orange.shade50,
                    },
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    switch (shippingStatus) {
                      0 => 'Chờ nhận',
                      1 => 'Đã nhận đơn',
                      2 => 'Đã lấy hàng',
                      3 => 'Đang giao',
                      4 => 'Thành công',
                      5 => 'Giao thất bại',
                      6 => 'Hoàn kho',
                      _ => 'Chưa rõ',
                    },
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: switch (shippingStatus) {
                        4 => Colors.green.shade800,
                        5 => Colors.red.shade800,
                        3 => Colors.blue.shade800,
                        _ => Colors.orange.shade800,
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _DataLine(
              label: 'Người nhận',
              value: order['customerName'] ?? shipping['receiverName'],
            ),
            _DataLine(
              label: 'Số điện thoại',
              value: phone.isEmpty ? '—' : phone,
            ),
            _DataLine(label: 'Địa chỉ', value: address.isEmpty ? '—' : address),
            _DataLine(
              label: 'Tổng thu hộ',
              value: money(payment['amount'] ?? order['totalAmount']),
            ),
            if (isCod)
              _DataLine(
                label: 'Đối soát COD',
                value: switch (_asInt(payment['codStatus'])) {
                  1 => 'Shipper đang giữ tiền',
                  2 => 'Đã báo nộp · chờ cửa hàng',
                  3 => 'Đã xác nhận vào quỹ',
                  _ => 'Chưa thu tiền',
                },
              ),
            if (shipping['failReason'] != null)
              _DataLine(label: 'Lý do thất bại', value: shipping['failReason']),
            const SizedBox(height: 10),

            // Call & Map Quick Action buttons
            Row(
              children: [
                if (phone.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                    icon: const Icon(Icons.call, size: 16, color: Colors.green),
                    label: const Text('Gọi khách'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (phone.isNotEmpty && address.isNotEmpty)
                  const SizedBox(width: 8),
                if (address.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(
                      Icons.directions,
                      size: 16,
                      color: Colors.blue,
                    ),
                    label: const Text('Chỉ đường'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Operational Action buttons
            if (actions.isNotEmpty)
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final action in actions)
                    FilledButton.tonal(
                      onPressed: orderId <= 0
                          ? null
                          : () => onAction(orderId, action.$2),
                      child: Text(action.$1),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _deliveryActionConfirmation(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ==
    true;

class _ShipperPerformanceSummary extends StatelessWidget {
  const _ShipperPerformanceSummary({required this.orders});

  final List<Map<String, dynamic>> orders;

  @override
  Widget build(BuildContext context) {
    final active = orders.where((order) {
      final status = _asInt(_map(order['shipping'])['status']);
      return status >= 0 && status <= 3;
    }).length;
    final delivered = orders
        .where((order) => _asInt(_map(order['shipping'])['status']) == 4)
        .length;
    final codHolding = orders.fold<double>(0, (total, order) {
      final payment = _map(order['payment']);
      if (_asInt(payment['paymentMethod']) != 0 ||
          _asInt(payment['codStatus']) != 1) {
        return total;
      }
      final shipping = _map(order['shipping']);
      return total +
          (_asNum(payment['amount']) - _asNum(shipping['shippingFee'])).clamp(
            0,
            double.infinity,
          );
    });
    return Card(
      color: const Color(0xFFFFEFF1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          runSpacing: 8,
          children: [
            _ShipperMetric(label: 'Đang xử lý', value: '$active'),
            _ShipperMetric(label: 'Đã giao', value: '$delivered'),
            _ShipperMetric(label: 'COD đang giữ', value: money(codHolding)),
          ],
        ),
      ),
    );
  }
}

class _ShipperMetric extends StatelessWidget {
  const _ShipperMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}

class _FailDeliveryDialog extends StatefulWidget {
  const _FailDeliveryDialog();

  @override
  State<_FailDeliveryDialog> createState() => _FailDeliveryDialogState();
}

class _FailDeliveryDialogState extends State<_FailDeliveryDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ghi nhận giao hàng thất bại'),
    content: TextField(
      controller: _reason,
      autofocus: true,
      maxLines: 3,
      decoration: const InputDecoration(labelText: 'Lý do giao thất bại'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (_reason.text.trim().isEmpty) return;
          Navigator.pop(context, {'failReason': _reason.text.trim()});
        },
        child: const Text('Gửi'),
      ),
    ],
  );
}

class ApiAction {
  const ApiAction(this.label, this.method, this.path, {this.body});

  final String label;
  final String method;
  final String path;
  final Object? body;
}

class ApiModulePage extends StatefulWidget {
  const ApiModulePage({
    required this.state,
    required this.title,
    required this.path,
    this.actions = const [],
    super.key,
  });

  final AppState state;
  final String title;
  final String path;
  final List<ApiAction> actions;

  @override
  State<ApiModulePage> createState() => _ApiModulePageState();
}

class _ApiModulePageState extends State<ApiModulePage> {
  dynamic _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load(widget.path);
  }

  Future<void> _load(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _data = await widget.state.loadApiData(path);
    } on ApiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = 'Không thể tải dữ liệu: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runAction(ApiAction action) async {
    try {
      final result = await widget.state.performApiAction(
        action.method,
        action.path,
        body: action.body,
      );
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ApiResultPage(title: action.label, data: result),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) showNotice(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _ErrorPanel(message: _error!, onRetry: () => _load(widget.path))
        : RefreshIndicator(
            onRefresh: () => _load(widget.path),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.actions.isNotEmpty) ...[
                  for (final action in widget.actions)
                    Card(
                      child: ListTile(
                        title: Text(action.label),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _runAction(action),
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
                _ApiData(data: _data),
              ],
            ),
          ),
  );
}

void _openModule(
  BuildContext context,
  AppState state,
  String title,
  String path,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ApiModulePage(state: state, title: title, path: path),
    ),
  );
}

class _ApiResultPage extends StatelessWidget {
  const _ApiResultPage({required this.title, required this.data});

  final String title;
  final dynamic data;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [_ApiData(data: data)],
    ),
  );
}

class _ApiData extends StatelessWidget {
  const _ApiData({required this.data});

  final dynamic data;

  @override
  Widget build(BuildContext context) {
    if (data == null) return const Text('Máy chủ không trả về dữ liệu.');
    if (data is List) {
      if (data.isEmpty) {
        return const _EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Chưa có dữ liệu',
          subtitle: 'Danh sách từ máy chủ hiện đang trống.',
        );
      }
      return _ApiList(records: data);
    }
    if (data is Map) {
      final values = data.entries
          .where(
            (entry) =>
                !_isNested(entry.value) && !_hideInternalField(entry.key),
          )
          .toList();
      final nested = data.entries
          .where((entry) => _isNested(entry.value))
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in values)
            _DataLine(label: _humanize(entry.key), value: entry.value),
          for (final entry in nested)
            ExpansionTile(
              title: Text(_humanize(entry.key)),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _ApiData(data: entry.value),
                ),
              ],
            ),
        ],
      );
    }
    return Text(data.toString());
  }

  bool _isNested(dynamic value) => value is Map || value is List;
}

String _humanize(String text) {
  final spaced = text.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match[1]} ${match[2]}',
  );
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

bool _hideInternalField(String rawKey) {
  final key = rawKey.toLowerCase();
  return key.endsWith('id') ||
      key.contains('code') ||
      key == 'sku' ||
      key.contains('token') ||
      key.contains('transactioncode');
}

class _ApiList extends StatefulWidget {
  const _ApiList({required this.records});

  final List<dynamic> records;

  @override
  State<_ApiList> createState() => _ApiListState();
}

class _ApiListState extends State<_ApiList> {
  final _search = TextEditingController();
  int? _status;
  int _visibleCount = 40;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final records = widget.records.where((record) {
      if (record is! Map) {
        return query.isEmpty || '$record'.toLowerCase().contains(query);
      }
      final matchesQuery =
          query.isEmpty ||
          record.entries.any(
            (entry) => '${entry.value}'.toLowerCase().contains(query),
          );
      final status = record['status'];
      final matchesStatus = _status == null || _asInt(status) == _status;
      return matchesQuery && matchesStatus;
    }).toList();
    final visible = records.take(_visibleCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() => _visibleCount = 40),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Tìm trong danh sách',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          initialValue: _status,
          decoration: const InputDecoration(
            labelText: 'Mã trạng thái',
            isDense: true,
          ),
          items: const [
            DropdownMenuItem<int?>(value: null, child: Text('Mọi trạng thái')),
            DropdownMenuItem<int?>(value: 0, child: Text('Mã trạng thái 0')),
            DropdownMenuItem<int?>(value: 1, child: Text('Mã trạng thái 1')),
            DropdownMenuItem<int?>(value: 2, child: Text('Mã trạng thái 2')),
            DropdownMenuItem<int?>(value: 3, child: Text('Mã trạng thái 3')),
            DropdownMenuItem<int?>(value: 4, child: Text('Mã trạng thái 4')),
          ],
          onChanged: (value) => setState(() {
            _status = value;
            _visibleCount = 40;
          }),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            '${records.length} mục${records.length > 40 ? ' · đang hiển thị ${visible.length}' : ''}',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
        if (records.isEmpty)
          const _EmptyState(
            icon: Icons.search_off,
            title: 'Không tìm thấy dữ liệu',
            subtitle: 'Thử từ khóa hoặc trạng thái khác.',
          )
        else
          for (final record in visible) _ApiRecordCard(data: record),
        if (visible.length < records.length)
          OutlinedButton(
            onPressed: () => setState(() => _visibleCount += 40),
            child: const Text('Xem thêm'),
          ),
      ],
    );
  }
}

class _ApiRecordCard extends StatelessWidget {
  const _ApiRecordCard({required this.data});

  final dynamic data;

  @override
  Widget build(BuildContext context) {
    if (data is! Map) {
      return Card(
        child: Padding(padding: const EdgeInsets.all(12), child: Text('$data')),
      );
    }

    final record = _map(data);
    final title = _firstText(record, const [
      'name',
      'productName',
      'customerName',
      'supplierName',
      'categoryName',
      'brandName',
      'fullName',
      'subject',
      'title',
    ]);
    final status = record['status'];
    final amount = _firstValue(record, const [
      'totalAmount',
      'amount',
      'revenue',
      'refundAmount',
      'price',
    ]);
    final date = _firstValue(record, const [
      'createdAt',
      'requestedAt',
      'importDate',
      'orderDate',
      'startDate',
    ]);
    final details = record.entries
        .where(
          (entry) =>
              !_hideInternalField(entry.key) &&
              (entry.value is Map || entry.value is List),
        )
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          title.isEmpty ? 'Thông tin' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (status != null) _statusTextForModule(record, status),
            if (date != null) _formatApiDate(date),
            if (amount != null) money(amount),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: status is num ? _StatusDot(status: status.toInt()) : null,
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          for (final entry in record.entries)
            if (!_hideInternalField(entry.key) &&
                entry.value != null &&
                entry.value is! Map &&
                entry.value is! List)
              _DataLine(label: _humanize(entry.key), value: entry.value),
          for (final entry in details)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(_humanize(entry.key)),
              children: [_ApiData(data: entry.value)],
            ),
        ],
      ),
    );
  }
}

String _firstText(Map<String, dynamic> record, List<String> keys) {
  for (final key in keys) {
    final value = record[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

dynamic _firstValue(Map<String, dynamic> record, List<String> keys) {
  for (final key in keys) {
    final value = record[key];
    if (value != null && value.toString().isNotEmpty) return value;
  }
  return null;
}

String _formatApiDate(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '$value';
  return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
}

String _statusTextForModule(Map<String, dynamic> record, dynamic value) {
  final status = _asInt(value);
  final keys = record.keys.map((key) => key.toLowerCase()).toSet();
  if (keys.contains('productvariants') || keys.contains('baseprice')) {
    return switch (status) {
      0 => 'Bản nháp',
      1 => 'Đang bán',
      2 => 'Thanh lý',
      3 => 'Ngừng bán',
      _ => 'Trạng thái $status',
    };
  }
  if (keys.contains('importreceiptdetails')) {
    return switch (status) {
      1 => 'Chờ nhập kho',
      2 => 'Đang nhận',
      3 => 'Đã nhập kho',
      4 => 'Đã hủy',
      _ => 'Trạng thái $status',
    };
  }
  if (keys.contains('returnrequestid')) {
    return switch (status) {
      0 => 'Chờ duyệt',
      1 => 'Đã duyệt · Chờ nhận hàng',
      2 => 'Đã từ chối',
      3 => 'Đã nhận hàng',
      4 => 'Đã hủy',
      _ => 'Trạng thái $status',
    };
  }
  if (keys.contains('orderdetails') || keys.contains('ordercode')) {
    return _orderStatus(status);
  }
  if (keys.contains('paymentmethod')) {
    return status == 1 ? 'Đã thanh toán' : 'Chưa thanh toán';
  }
  return 'Trạng thái $status';
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final int status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      0 => const Color(0xFFB45309),
      1 => const Color(0xFF2563EB),
      2 || 3 => const Color(0xFF15803D),
      _ => const Color(0xFF737373),
    };
    return Icon(Icons.circle, size: 10, color: color);
  }
}

class _DataLine extends StatelessWidget {
  const _DataLine({required this.label, required this.value});

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            _formatApiField(label, value),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

String _formatApiField(String label, dynamic value) {
  final key = label.toLowerCase();
  if (value is bool) return value ? 'Có' : 'Không';
  if (value is num &&
      (key.contains('amount') ||
          key.contains('price') ||
          key.contains('revenue') ||
          key.contains('refund'))) {
    return money(value);
  }
  if (value is String && DateTime.tryParse(value) != null) {
    return _formatApiDate(value);
  }
  return displayValue(value);
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: _muted)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFFD8B8BD)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
        ],
      ),
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 44, color: _rose),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}

dynamic _first(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    if (source[key] != null) return source[key];
  }
  return null;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return {};
}

int _asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double _asNum(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return [];
  return value.whereType<Map>().map(_map).toList();
}
