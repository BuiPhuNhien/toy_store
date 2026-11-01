import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';

const _adminRose = Color(0xFFE11D48);
const _adminMuted = Color(0xFF777681);

int _numberId(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _numberAmount(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

Map<String, dynamic> _object(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return {};
}

List<Map<String, dynamic>> _objects(dynamic value) {
  if (value is! List) return [];
  return value.whereType<Map>().map(_object).toList();
}

String _price(dynamic value) {
  final amount = _numberAmount(value).round();
  final digits = amount.toString();
  final formatted = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '$formatted ₫';
}

String _date(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '—';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _statusText(dynamic value, {required String kind}) {
  final status = _numberId(value);
  return switch (kind) {
    'product' => switch (status) {
      1 => 'Đang bán',
      2 => 'Thanh lý',
      3 => 'Ngừng bán',
      _ => 'Bản nháp',
    },
    'import' => switch (status) {
      1 => 'Chờ nhập kho',
      2 => 'Đang nhận',
      3 => 'Đã nhập kho',
      4 => 'Đã hủy',
      _ => 'Chưa xác định',
    },
    'return' => switch (status) {
      0 => 'Chờ duyệt',
      1 => 'Đã duyệt · Chờ nhận hàng',
      2 => 'Đã từ chối',
      3 => 'Đã nhận hàng',
      4 => 'Đã hủy',
      _ => 'Chưa xác định',
    },
    _ => 'Chưa xác định',
  };
}

Widget _statusPill(String text, int status) {
  final color = switch (status) {
    1 || 2 => const Color(0xFF2563EB),
    3 => const Color(0xFF15803D),
    4 => const Color(0xFF737373),
    _ => const Color(0xFFB45309),
  };
  return DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Xác nhận',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ==
    true;

class _WorkflowError extends StatelessWidget {
  const _WorkflowError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42, color: _adminMuted),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
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

class _WorkflowEmpty extends StatelessWidget {
  const _WorkflowEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: _adminMuted),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center),
      ],
    ),
  );
}

class ProductManagerPage extends StatefulWidget {
  const ProductManagerPage({required this.state, super.key});

  final AppState state;

  @override
  State<ProductManagerPage> createState() => _ProductManagerPageState();
}

class _ProductManagerPageState extends State<ProductManagerPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _suppliers = [];
  int? _categoryFilter;
  int? _statusFilter;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.state.api.get('Product'),
        widget.state.api.get('Category'),
        widget.state.api.get('Brand'),
        widget.state.api.get('Supplier'),
      ]);
      _products = _objects(results[0]);
      _categories = _objects(results[1]);
      _brands = _objects(results[2]);
      _suppliers = _objects(
        results[3],
      ).where((item) => item['isActive'] != false).toList();
    } on ApiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = 'Không thể tải dữ liệu sản phẩm: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? product]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(
          state: widget.state,
          categories: _categories,
          brands: _brands,
          suppliers: _suppliers,
          product: product,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> product) async {
    if (!await _confirm(
      context,
      title: 'Ngừng sử dụng sản phẩm?',
      message:
          'Thao tác này sẽ gửi yêu cầu xóa đến máy chủ. Sản phẩm đã phát sinh đơn có thể không xóa được.',
      confirmLabel: 'Tiếp tục',
    )) {
      return;
    }
    try {
      await widget.state.api.delete(
        'Product/${_numberId(product['productId'])}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật sản phẩm trên máy chủ.')),
        );
      }
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = _products.where((product) {
      final matchesText =
          query.isEmpty ||
          '${product['name']} ${product['brandName']} ${product['categoryName']}'
              .toLowerCase()
              .contains(query);
      final matchesCategory =
          _categoryFilter == null ||
          _numberId(product['categoryId']) == _categoryFilter;
      final matchesStatus =
          _statusFilter == null ||
          _numberId(product['status']) == _statusFilter;
      return matchesText && matchesCategory && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sản phẩm'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm sản phẩm'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _WorkflowError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Tìm theo tên, danh mục hoặc thương hiệu',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _filterChip(
                        label: 'Mọi danh mục',
                        selected: _categoryFilter == null,
                        onTap: () => setState(() => _categoryFilter = null),
                      ),
                      for (final category in _categories)
                        _filterChip(
                          label: '${category['name'] ?? ''}',
                          selected:
                              _categoryFilter == _numberId(category['id']),
                          onTap: () => setState(
                            () => _categoryFilter = _numberId(category['id']),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Lọc trạng thái',
                    ),
                    items: const [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tất cả trạng thái'),
                      ),
                      DropdownMenuItem<int?>(value: 1, child: Text('Đang bán')),
                      DropdownMenuItem<int?>(value: 0, child: Text('Bản nháp')),
                      DropdownMenuItem<int?>(value: 2, child: Text('Thanh lý')),
                      DropdownMenuItem<int?>(
                        value: 3,
                        child: Text('Ngừng bán'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _statusFilter = value),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Hiển thị ${filtered.length} / ${_products.length} sản phẩm',
                      style: const TextStyle(color: _adminMuted, fontSize: 12),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const _WorkflowEmpty(
                      icon: Icons.toys_outlined,
                      title: 'Không tìm thấy sản phẩm',
                      subtitle: 'Thử đổi từ khóa hoặc bộ lọc.',
                    )
                  else
                    for (final product in filtered)
                      _ProductSummaryCard(
                        product: product,
                        onEdit: () => _openForm(product),
                        onDelete: () => _delete(product),
                      ),
                ],
              ),
            ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
  );
}

enum ReferenceCreateKind { category, supplier, brand }

class ReferenceManagerPage extends StatefulWidget {
  const ReferenceManagerPage({
    required this.state,
    required this.kind,
    super.key,
  });

  final AppState state;
  final ReferenceCreateKind kind;

  @override
  State<ReferenceManagerPage> createState() => _ReferenceManagerPageState();
}

class _ReferenceManagerPageState extends State<ReferenceManagerPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _records = [];
  String? _error;
  bool _loading = true;

  String get _endpoint => switch (widget.kind) {
    ReferenceCreateKind.category => 'Category',
    ReferenceCreateKind.supplier => 'Supplier',
    ReferenceCreateKind.brand => 'Brand',
  };

  String get _singular => switch (widget.kind) {
    ReferenceCreateKind.category => 'danh mục',
    ReferenceCreateKind.supplier => 'nhà cung cấp',
    ReferenceCreateKind.brand => 'thương hiệu',
  };

  String get _plural => switch (widget.kind) {
    ReferenceCreateKind.category => 'Danh mục',
    ReferenceCreateKind.supplier => 'Nhà cung cấp',
    ReferenceCreateKind.brand => 'Thương hiệu',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _recordId(Map<String, dynamic> record) => _numberId(
    record['id'] ??
        record['categoryId'] ??
        record['brandId'] ??
        record['supplierId'],
  );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _records = _objects(await widget.state.api.get(_endpoint));
    } on ApiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = 'Không thể tải $_singular: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? record]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReferenceCreatePage(
          state: widget.state,
          kind: widget.kind,
          record: record,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final isSupplier = widget.kind == ReferenceCreateKind.supplier;
    final confirmed = await _confirm(
      context,
      title: isSupplier ? 'Vô hiệu hóa nhà cung cấp?' : 'Xóa $_singular?',
      message: isSupplier
          ? 'Nhà cung cấp sẽ được vô hiệu hóa và không còn dùng để lập phiếu nhập.'
          : 'Thao tác sẽ gửi yêu cầu xóa lên máy chủ. Nếu dữ liệu đang được sử dụng, máy chủ có thể từ chối.',
      confirmLabel: isSupplier ? 'Vô hiệu hóa' : 'Xóa',
    );
    if (!confirmed) return;
    try {
      await widget.state.api.delete('$_endpoint/${_recordId(record)}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSupplier ? 'Đã vô hiệu hóa nhà cung cấp.' : 'Đã xóa $_singular.',
          ),
        ),
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xóa $_singular: $error')),
        );
      }
    }
  }

  Future<void> _showLinkedProducts(Map<String, dynamic> record) async {
    final id = _recordId(record);
    try {
      final result = widget.kind == ReferenceCreateKind.supplier
          ? await widget.state.api.get('Supplier/$id/products')
          : await widget.state.api.get(
              'Product',
              queryParameters: {
                widget.kind == ReferenceCreateKind.category
                        ? 'categoryId'
                        : 'brandId':
                    '$id',
              },
            );
      if (!mounted) return;
      final products = _objects(result);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Sản phẩm liên kết · ${record['name'] ?? ''}'),
          content: SizedBox(
            width: 440,
            child: products.isEmpty
                ? const Text('Chưa có sản phẩm liên kết.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${product['productName'] ?? product['name'] ?? 'Sản phẩm'}',
                        ),
                        subtitle: Text(
                          [
                            if (product['sku'] != null) 'SKU ${product['sku']}',
                            if (product['variantName'] != null)
                              '${product['variantName']}',
                            if (product['quantity'] != null)
                              'Số lượng ${product['quantity']}',
                            if (product['basePrice'] != null)
                              _price(product['basePrice']),
                          ].join(' · '),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải sản phẩm liên kết: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final records = _records.where((record) {
      final searchable =
          '${record['name']} ${record['email']} ${record['phone']} ${record['taxCode']}'
              .toLowerCase();
      return query.isEmpty || searchable.contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý $_plural'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _edit(),
        icon: const Icon(Icons.add),
        label: Text('Thêm $_singular'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _WorkflowError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Tìm $_singular',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '${records.length} / ${_records.length} mục',
                      style: const TextStyle(color: _adminMuted, fontSize: 12),
                    ),
                  ),
                  if (records.isEmpty)
                    _WorkflowEmpty(
                      icon: Icons.search_off,
                      title: 'Chưa có $_singular',
                      subtitle: 'Thêm $_singular để bắt đầu quản lý.',
                    )
                  else
                    for (final record in records)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${record['name'] ?? 'Chưa có tên'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            widget.kind == ReferenceCreateKind.supplier
                                ? '${record['phone'] ?? '—'} · ${record['email'] ?? '—'}\n${record['isActive'] == false ? 'Đã vô hiệu hóa' : 'Đang hoạt động'}'
                                : '${record['description'] ?? 'Không có mô tả'} · ${record['isActive'] == false ? 'Đã vô hiệu hóa' : 'Đang hoạt động'}${widget.kind == ReferenceCreateKind.category && record['productCount'] != null ? ' · ${record['productCount']} sản phẩm' : ''}',
                          ),
                          isThreeLine:
                              widget.kind == ReferenceCreateKind.supplier,
                          leading: CircleAvatar(
                            child: Icon(switch (widget.kind) {
                              ReferenceCreateKind.category =>
                                Icons.category_outlined,
                              ReferenceCreateKind.supplier =>
                                Icons.business_outlined,
                              ReferenceCreateKind.brand => Icons.sell_outlined,
                            }),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'products') {
                                _showLinkedProducts(record);
                              } else if (action == 'edit') {
                                _edit(record);
                              } else if (action == 'delete') {
                                _delete(record);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'products',
                                child: Text('Xem sản phẩm liên kết'),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Sửa thông tin / trạng thái'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  widget.kind == ReferenceCreateKind.supplier
                                      ? 'Vô hiệu hóa'
                                      : 'Xóa',
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _showLinkedProducts(record),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

class ReferenceCreatePage extends StatefulWidget {
  const ReferenceCreatePage({
    required this.state,
    required this.kind,
    this.record,
    super.key,
  });

  final AppState state;
  final ReferenceCreateKind kind;
  final Map<String, dynamic>? record;

  @override
  State<ReferenceCreatePage> createState() => _ReferenceCreatePageState();
}

class _ReferenceCreatePageState extends State<ReferenceCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _taxCode = TextEditingController();
  bool _saving = false;
  bool _isActive = true;

  bool get _isSupplier => widget.kind == ReferenceCreateKind.supplier;
  bool get _isEditing => widget.record != null;
  String get _endpoint => switch (widget.kind) {
    ReferenceCreateKind.category => 'Category',
    ReferenceCreateKind.supplier => 'Supplier',
    ReferenceCreateKind.brand => 'Brand',
  };
  String get _label => switch (widget.kind) {
    ReferenceCreateKind.category => 'danh mục',
    ReferenceCreateKind.supplier => 'nhà cung cấp',
    ReferenceCreateKind.brand => 'thương hiệu',
  };

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    if (record != null) {
      _name.text = '${record['name'] ?? ''}';
      _description.text = '${record['description'] ?? ''}';
      _phone.text = '${record['phone'] ?? ''}';
      _email.text = '${record['email'] ?? ''}';
      _address.text = '${record['address'] ?? ''}';
      _taxCode.text = '${record['taxCode'] ?? ''}';
      _isActive = record['isActive'] != false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _taxCode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'description': _description.text.trim(),
      };
      if (_isSupplier) {
        payload.addAll({
          'phone': _phone.text.trim(),
          'email': _email.text.trim(),
          'address': _address.text.trim(),
          'taxCode': _taxCode.text.trim(),
          'isActive': _isActive,
        });
      } else if (_isEditing) {
        payload['isActive'] = _isActive;
      }
      if (_isEditing) {
        final record = widget.record!;
        final id = _numberId(
          record['id'] ??
              record['categoryId'] ??
              record['brandId'] ??
              record['supplierId'],
        );
        await widget.state.api.put('$_endpoint/$id', payload);
      } else {
        await widget.state.api.post(_endpoint, payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Đã cập nhật $_label.' : 'Đã thêm $_label.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể ${_isEditing ? 'cập nhật' : 'tạo'} $_label: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${_isEditing ? 'Sửa' : 'Thêm'} $_label')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            maxLength: _isSupplier ? 200 : 100,
            decoration: InputDecoration(labelText: 'Tên $_label *'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Vui lòng nhập tên.'
                : null,
          ),
          if (_isSupplier) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập số điện thoại.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email *'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập email.';
                }
                if (!RegExp(
                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                ).hasMatch(value.trim())) {
                  return 'Email chưa đúng định dạng.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Địa chỉ *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập địa chỉ.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _taxCode,
              decoration: const InputDecoration(labelText: 'Mã số thuế *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập mã số thuế.'
                  : null,
            ),
          ] else ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mô tả (không bắt buộc)',
              ),
            ),
          ],
          if (_isEditing || _isSupplier) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Đang hoạt động'),
              subtitle: const Text(
                'Tắt để ngừng sử dụng mà không xóa dữ liệu liên quan.',
              ),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _saving
                  ? 'Đang lưu...'
                  : (_isEditing ? 'Lưu thay đổi' : 'Tạo mới'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProductSummaryCard extends StatelessWidget {
  const _ProductSummaryCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = _numberId(product['status']);
    final variants = _objects(product['productVariants']);
    final available = variants
        .map((variant) => variant['availableQuantity'])
        .whereType<num>()
        .fold<int>(0, (total, value) => total + value.toInt());
    final tracked = variants.any(
      (variant) => variant['availableQuantity'] is num,
    );
    final image = '${product['imageUrl'] ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 66,
                  height: 66,
                  child: image.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFFFEFF1),
                          child: Icon(Icons.toys_outlined, color: _adminRose),
                        )
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFFFEFF1),
                            child: Icon(Icons.toys_outlined, color: _adminRose),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${product['name'] ?? 'Sản phẩm'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [product['categoryName'], product['brandName']]
                          .where(
                            (value) => value != null && '$value'.isNotEmpty,
                          )
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _adminMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _price(
                        product['basePrice'] ??
                            (variants.isEmpty ? 0 : variants.first['price']),
                      ),
                      style: const TextStyle(
                        color: _adminRose,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      tracked
                          ? 'Còn $available sản phẩm'
                          : 'Tồn kho chưa cập nhật',
                      style: const TextStyle(color: _adminMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusPill(_statusText(status, kind: 'product'), status),
                  PopupMenuButton<String>(
                    tooltip: 'Tùy chọn sản phẩm',
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Xóa / ngừng bán'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantDraft {
  _VariantDraft({
    required this.sku,
    required this.price,
    required this.cost,
    required this.weight,
    required this.image,
    this.id,
    this.status = 1,
    this.attributes = const [],
  });

  final int? id;
  final TextEditingController sku;
  int status;
  final List<Map<String, dynamic>> attributes;
  final TextEditingController price;
  final TextEditingController cost;
  final TextEditingController weight;
  final TextEditingController image;

  factory _VariantDraft.fromApi(Map<String, dynamic> variant) => _VariantDraft(
    id: _numberId(variant['variantId']),
    sku: TextEditingController(text: '${variant['sku'] ?? ''}'),
    price: TextEditingController(text: '${variant['price'] ?? ''}'),
    cost: TextEditingController(text: '${variant['costPrice'] ?? ''}'),
    weight: TextEditingController(text: '${variant['weight'] ?? ''}'),
    image: TextEditingController(text: '${variant['imageUrl'] ?? ''}'),
    status: _numberId(variant['status']) == 0 ? 0 : 1,
    attributes: _objects(variant['attributes']),
  );

  factory _VariantDraft.create() => _VariantDraft(
    sku: TextEditingController(
      text:
          'TOY-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1000)}',
    ),
    price: TextEditingController(),
    cost: TextEditingController(),
    weight: TextEditingController(),
    image: TextEditingController(),
    attributes: <Map<String, dynamic>>[],
  );

  void dispose() {
    sku.dispose();
    price.dispose();
    cost.dispose();
    weight.dispose();
    image.dispose();
  }
}

class _SupplierProductDraft {
  _SupplierProductDraft({
    required this.supplierId,
    String referenceCost = '',
    String supplierSku = '',
    this.isDefault = false,
  }) : referenceCost = TextEditingController(text: referenceCost),
       supplierSku = TextEditingController(text: supplierSku);

  final int supplierId;
  final TextEditingController referenceCost;
  final TextEditingController supplierSku;
  bool isDefault;

  void dispose() {
    referenceCost.dispose();
    supplierSku.dispose();
  }
}

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({
    required this.state,
    required this.categories,
    required this.brands,
    required this.suppliers,
    this.product,
    super.key,
  });

  final AppState state;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> brands;
  final List<Map<String, dynamic>> suppliers;
  final Map<String, dynamic>? product;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class ImportReceiptsPage extends StatefulWidget {
  const ImportReceiptsPage({required this.state, super.key});

  final AppState state;

  @override
  State<ImportReceiptsPage> createState() => _ImportReceiptsPageState();
}

class _ImportReceiptsPageState extends State<ImportReceiptsPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _receipts = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<_ImportVariant> _variants = [];
  int? _statusFilter;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.state.api.get('ImportReceipt'),
        widget.state.api.get('Supplier'),
        widget.state.api.get('Product'),
      ]);
      _receipts = _objects(results[0]);
      _suppliers = _objects(
        results[1],
      ).where((supplier) => supplier['isActive'] != false).toList();
      _variants = [
        for (final product in _objects(results[2]))
          for (final variant in _objects(product['productVariants']))
            _ImportVariant.fromProduct(product, variant),
      ];
    } on ApiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = 'Không thể tải dữ liệu nhập kho: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newReceipt([Map<String, dynamic>? receipt]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ImportReceiptFormPage(
          state: widget.state,
          suppliers: _suppliers,
          variants: _variants,
          receipt: receipt,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _approve(Map<String, dynamic> receipt) async {
    final details = _objects(receipt['importReceiptDetails']);
    if (details.any((detail) => _numberAmount(detail['newPrice']) <= 0)) {
      _show(
        'Vui lòng chỉnh sửa phiếu và nhập giá bán mới trước khi nhận hàng.',
      );
      return;
    }
    if (!await _confirm(
      context,
      title: 'Xác nhận đã nhận hàng?',
      message:
          'Chỉ tiếp tục khi kho đã thực sự nhận và kiểm đếm đủ số lượng. Tồn kho sẽ được cập nhật.',
      confirmLabel: 'Đã nhận hàng',
    )) {
      return;
    }
    try {
      final id = _numberId(receipt['importReceiptId']);
      await widget.state.api.post('ImportReceipt/$id/approve', {
        'details': details
            .map(
              (detail) => {
                'importReceiptDetailId': _numberId(
                  detail['importReceiptDetailId'],
                ),
                'quantity': _numberId(detail['quantity']),
                'newPrice': detail['newPrice'],
              },
            )
            .toList(),
      });
      _show('Đã xác nhận nhập kho và cập nhật tồn kho.');
      await _load();
    } on ApiException catch (error) {
      _show(error.message);
    }
  }

  Future<void> _cancel(Map<String, dynamic> receipt) async {
    if (!await _confirm(
      context,
      title: 'Hủy phiếu nhập?',
      message: 'Chỉ phiếu nháp/chờ duyệt mới có thể hủy.',
      confirmLabel: 'Hủy phiếu',
    )) {
      return;
    }
    try {
      await widget.state.api.post(
        'ImportReceipt/${_numberId(receipt['importReceiptId'])}/cancel',
      );
      await _load();
    } on ApiException catch (error) {
      _show(error.message);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final rows =
        _receipts.where((receipt) {
          final status = _numberId(receipt['status']);
          final matchesStatus =
              _statusFilter == null || status == _statusFilter;
          final matchesQuery =
              query.isEmpty ||
              '${receipt['supplierName']} ${receipt['note']}'
                  .toLowerCase()
                  .contains(query);
          return matchesStatus && matchesQuery;
        }).toList()..sort(
          (left, right) =>
              '${right['importDate']}'.compareTo('${left['importDate']}'),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập kho'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _newReceipt(),
        icon: const Icon(Icons.add),
        label: const Text('Tạo phiếu nhập'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _WorkflowError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Tìm theo nhà cung cấp hoặc ghi chú',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Trạng thái phiếu',
                    ),
                    items: const [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tất cả phiếu'),
                      ),
                      DropdownMenuItem<int?>(
                        value: 1,
                        child: Text('Chờ nhập kho'),
                      ),
                      DropdownMenuItem<int?>(
                        value: 3,
                        child: Text('Đã nhập kho'),
                      ),
                      DropdownMenuItem<int?>(value: 4, child: Text('Đã hủy')),
                    ],
                    onChanged: (value) => setState(() => _statusFilter = value),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '${rows.length} phiếu nhập',
                      style: const TextStyle(color: _adminMuted, fontSize: 12),
                    ),
                  ),
                  if (rows.isEmpty)
                    const _WorkflowEmpty(
                      icon: Icons.inventory_2_outlined,
                      title: 'Chưa có phiếu nhập',
                      subtitle: 'Tạo phiếu để ghi nhận hàng từ nhà cung cấp.',
                    )
                  else
                    for (final receipt in rows)
                      _ImportReceiptCard(
                        receipt: receipt,
                        onEdit: _numberId(receipt['status']) == 1
                            ? () => _newReceipt(receipt)
                            : null,
                        onApprove: _numberId(receipt['status']) == 1
                            ? () => _approve(receipt)
                            : null,
                        onCancel: _numberId(receipt['status']) == 1
                            ? () => _cancel(receipt)
                            : null,
                      ),
                ],
              ),
            ),
    );
  }
}

class _ImportVariant {
  const _ImportVariant({
    required this.id,
    required this.productName,
    required this.price,
    required this.cost,
    required this.label,
  });

  final int id;
  final String productName;
  final double price;
  final double cost;
  final String label;

  factory _ImportVariant.fromProduct(
    Map<String, dynamic> product,
    Map<String, dynamic> variant,
  ) {
    final attributes = _objects(variant['attributes'])
        .map((item) => '${item['attributeValue'] ?? ''}')
        .where((value) => value.isNotEmpty)
        .join(' · ');
    final name = '${product['name'] ?? 'Sản phẩm'}';
    return _ImportVariant(
      id: _numberId(variant['variantId']),
      productName: name,
      price: _numberAmount(variant['price']),
      cost: _numberAmount(variant['costPrice']),
      label: attributes.isEmpty ? name : '$name · $attributes',
    );
  }
}

class _ImportLineDraft {
  _ImportLineDraft({
    this.detailId,
    this.variantId,
    String quantity = '1',
    String unitCost = '',
    String newPrice = '',
  }) : quantity = TextEditingController(text: quantity),
       unitCost = TextEditingController(text: unitCost),
       newPrice = TextEditingController(text: newPrice);

  final int? detailId;
  int? variantId;
  final TextEditingController quantity;
  final TextEditingController unitCost;
  final TextEditingController newPrice;

  void dispose() {
    quantity.dispose();
    unitCost.dispose();
    newPrice.dispose();
  }
}

class _ImportReceiptCard extends StatelessWidget {
  const _ImportReceiptCard({
    required this.receipt,
    required this.onEdit,
    required this.onApprove,
    required this.onCancel,
  });

  final Map<String, dynamic> receipt;
  final VoidCallback? onEdit;
  final VoidCallback? onApprove;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final status = _numberId(receipt['status']);
    final details = _objects(receipt['importReceiptDetails']);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFEFF1),
          child: Icon(Icons.inventory_2_outlined, color: _adminRose),
        ),
        title: Text(
          '${receipt['supplierName'] ?? 'Nhà cung cấp'}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${_date(receipt['importDate'])} · ${_price(receipt['totalAmount'])} · ${details.length} mặt hàng',
        ),
        trailing: _statusPill(_statusText(status, kind: 'import'), status),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final detail in details)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${detail['productName'] ?? 'Sản phẩm'}'),
              subtitle: Text(
                'Số lượng: ${detail['quantity'] ?? 0} · Đã nhận: ${detail['receivedQuantity'] ?? 0}',
              ),
              trailing: Text(_price(detail['totalAmount'])),
            ),
          if ('${receipt['note'] ?? ''}'.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ghi chú: ${receipt['note']}',
                style: const TextStyle(color: _adminMuted),
              ),
            ),
          if (onEdit != null || onApprove != null || onCancel != null)
            Wrap(
              spacing: 8,
              children: [
                if (onEdit != null)
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Sửa phiếu'),
                  ),
                if (onApprove != null)
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.inventory),
                    label: const Text('Đã nhận hàng'),
                  ),
                if (onCancel != null)
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Hủy phiếu'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ImportReceiptFormPage extends StatefulWidget {
  const _ImportReceiptFormPage({
    required this.state,
    required this.suppliers,
    required this.variants,
    this.receipt,
  });

  final AppState state;
  final List<Map<String, dynamic>> suppliers;
  final List<_ImportVariant> variants;
  final Map<String, dynamic>? receipt;

  @override
  State<_ImportReceiptFormPage> createState() => _ImportReceiptFormPageState();
}

class _ImportReceiptFormPageState extends State<_ImportReceiptFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  final List<_ImportLineDraft> _lines = [];
  int? _supplierId;
  DateTime _importDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final receipt = widget.receipt;
    _supplierId = receipt == null ? null : _numberId(receipt['supplierId']);
    _note.text = '${receipt?['note'] ?? ''}';
    if (receipt != null) {
      _importDate =
          DateTime.tryParse('${receipt['importDate']}') ?? DateTime.now();
      for (final detail in _objects(receipt['importReceiptDetails'])) {
        _lines.add(
          _ImportLineDraft(
            detailId: _numberId(detail['importReceiptDetailId']),
            variantId: _numberId(detail['variantId']),
            quantity: '${detail['quantity'] ?? 1}',
            unitCost: '${detail['unitCost'] ?? ''}',
            newPrice: '${detail['newPrice'] ?? detail['currentPrice'] ?? ''}',
          ),
        );
      }
    }
    if (_lines.isEmpty) _lines.add(_ImportLineDraft());
  }

  @override
  void dispose() {
    _note.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_supplierId == null) {
      _show('Vui lòng chọn nhà cung cấp.');
      return;
    }
    if (_lines.any((line) => line.variantId == null)) {
      _show('Chọn sản phẩm cho từng dòng.');
      return;
    }
    final variants = _lines.map((line) => line.variantId).toList();
    if (variants.toSet().length != variants.length) {
      _show('Mỗi sản phẩm chỉ được thêm một lần vào cùng phiếu.');
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'supplierId': _supplierId,
        'receiptCode':
            widget.receipt?['receiptCode'] ??
            'PN-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        'importDate': _importDate.toUtc().toIso8601String(),
        'status': 1,
        'note': _note.text.trim(),
        'details': _lines
            .map(
              (line) => {
                'variantId': line.variantId,
                'quantity': _intField(line.quantity.text),
                'unitCost': _amount(line.unitCost.text),
                'newPrice': line.newPrice.text.trim().isEmpty
                    ? null
                    : _amount(line.newPrice.text),
              },
            )
            .toList(),
      };
      final existingId = _numberId(widget.receipt?['importReceiptId']);
      if (existingId > 0) {
        await widget.state.api.put('ImportReceipt/$existingId', payload);
      } else {
        await widget.state.api.post('ImportReceipt', payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) _show(error.message);
    } catch (error) {
      if (mounted) _show('Không thể lưu phiếu nhập: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _importDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _importDate = date);
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.receipt == null ? 'Tạo phiếu nhập' : 'Sửa phiếu nhập'),
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang lưu...' : 'Lưu nháp'),
        ),
      ],
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _InfoNotice(
            text:
                'Tạo phiếu nháp trước. Khi hàng đã về kho, mở phiếu và chọn “Đã nhận hàng” để cập nhật tồn kho.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _supplierId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nhà cung cấp *'),
            items: [
              for (final supplier in widget.suppliers)
                DropdownMenuItem(
                  value: _numberId(supplier['supplierId']),
                  child: Text('${supplier['name'] ?? 'Nhà cung cấp'}'),
                ),
            ],
            validator: (value) => value == null ? 'Chọn nhà cung cấp.' : null,
            onChanged: (value) => setState(() => _supplierId = value),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              'Ngày nhập dự kiến: ${_date(_importDate.toIso8601String())}',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Ghi chú (không bắt buộc)',
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sản phẩm trong phiếu',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _lines.add(_ImportLineDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Thêm dòng'),
              ),
            ],
          ),
          for (var index = 0; index < _lines.length; index++)
            _importLine(index, _lines[index]),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Đang lưu...' : 'Lưu phiếu nháp'),
          ),
        ],
      ),
    ),
  );

  Widget _importLine(int index, _ImportLineDraft line) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue:
                      widget.variants.any(
                        (variant) => variant.id == line.variantId,
                      )
                      ? line.variantId
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Sản phẩm ${index + 1} *',
                  ),
                  items: [
                    for (final variant in widget.variants)
                      DropdownMenuItem(
                        value: variant.id,
                        child: Text(
                          variant.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  validator: (value) => value == null ? 'Chọn sản phẩm.' : null,
                  onChanged: (value) {
                    final variant = widget.variants.where(
                      (item) => item.id == value,
                    );
                    setState(() {
                      line.variantId = value;
                      if (line.unitCost.text.isEmpty && variant.isNotEmpty) {
                        line.unitCost.text = '${variant.first.cost}';
                      }
                      if (line.newPrice.text.isEmpty && variant.isNotEmpty) {
                        line.newPrice.text = '${variant.first.price}';
                      }
                    });
                  },
                ),
              ),
              IconButton(
                tooltip: 'Xóa dòng',
                onPressed: _lines.length <= 1
                    ? null
                    : () => setState(() {
                        _lines.removeAt(index);
                        line.dispose();
                      }),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  line.quantity,
                  'Số lượng *',
                  allowZero: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _numberField(line.unitCost, 'Giá nhập / sản phẩm'),
              ),
              const SizedBox(width: 8),
              Expanded(child: _numberField(line.newPrice, 'Giá bán mới *')),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _numberField(
  TextEditingController controller,
  String label, {
  bool allowZero = true,
}) => TextFormField(
  controller: controller,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  decoration: InputDecoration(labelText: label),
  validator: (value) {
    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0 || (!allowZero && parsed <= 0)) {
      return allowZero ? 'Nhập số hợp lệ.' : 'Phải lớn hơn 0.';
    }
    return null;
  },
);

int _intField(String value) => int.tryParse(value.trim()) ?? 0;

double _amount(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

class ReturnRequestsPage extends StatefulWidget {
  const ReturnRequestsPage({
    required this.state,
    required this.customerMode,
    super.key,
  });

  final AppState state;
  final bool customerMode;

  @override
  State<ReturnRequestsPage> createState() => _ReturnRequestsPageState();
}

class _ReturnRequestsPageState extends State<ReturnRequestsPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _requests = [];
  int? _statusFilter;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = widget.customerMode ? 'ReturnRequest/mine' : 'ReturnRequest';
      _requests = _objects(await widget.state.api.get(path));
    } on ApiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = 'Không thể tải yêu cầu đổi trả: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createRequest() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReturnRequestFormPage(state: widget.state),
      ),
    );
    if (created == true) _load();
  }

  Future<void> _review(Map<String, dynamic> request, int status) async {
    final result = await showDialog<_ReturnReview>(
      context: context,
      builder: (_) =>
          _ReturnReviewDialog(request: request, approved: status == 1),
    );
    if (result == null) return;
    try {
      await widget.state.api
          .put('ReturnRequest/${_numberId(request['returnRequestId'])}', {
            'status': status,
            'refundAmount': result.refundAmount,
            'staffNote': result.note,
          });
      _show(status == 1 ? 'Đã duyệt yêu cầu.' : 'Đã từ chối yêu cầu.');
      await _load();
    } on ApiException catch (error) {
      _show(error.message);
    }
  }

  Future<void> _receive(Map<String, dynamic> request) async {
    if (!await _confirm(
      context,
      title: 'Xác nhận đã nhận hàng hoàn?',
      message:
          'Chỉ xác nhận sau khi kho đã thực sự nhận và kiểm tra hàng. Tồn kho sẽ tăng theo số lượng trả.',
      confirmLabel: 'Kho đã nhận hàng',
    )) {
      return;
    }
    try {
      await widget.state.api.post(
        'ReturnRequest/${_numberId(request['returnRequestId'])}/receive',
      );
      _show('Đã xác nhận nhận hàng hoàn và cập nhật tồn kho.');
      await _load();
    } on ApiException catch (error) {
      _show(error.message);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final rows =
        _requests.where((request) {
          final status = _numberId(request['status']);
          final matchStatus = _statusFilter == null || status == _statusFilter;
          final details = _objects(request['details']);
          final searchable = [
            request['customerName'],
            request['description'],
            request['orderCode'],
            ...details.map((detail) => detail['productName']),
          ].join(' ').toLowerCase();
          return matchStatus && (query.isEmpty || searchable.contains(query));
        }).toList()..sort(
          (left, right) =>
              '${right['requestedAt']}'.compareTo('${left['requestedAt']}'),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerMode ? 'Yêu cầu đổi trả' : 'Duyệt đổi trả'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: widget.customerMode
          ? FloatingActionButton.extended(
              onPressed: _loading ? null : _createRequest,
              icon: const Icon(Icons.assignment_return_outlined),
              label: const Text('Tạo yêu cầu'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _WorkflowError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                children: [
                  if (!widget.customerMode) ...[
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Tìm theo khách hàng hoặc sản phẩm',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      initialValue: _statusFilter,
                      decoration: const InputDecoration(
                        labelText: 'Lọc trạng thái',
                      ),
                      items: const [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Tất cả yêu cầu'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 0,
                          child: Text('Chờ duyệt'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 1,
                          child: Text('Chờ nhận hàng'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 2,
                          child: Text('Đã từ chối'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 3,
                          child: Text('Đã nhận hàng'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _statusFilter = value),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (rows.isEmpty)
                    _WorkflowEmpty(
                      icon: Icons.assignment_return_outlined,
                      title: widget.customerMode
                          ? 'Chưa có yêu cầu đổi trả'
                          : 'Không có yêu cầu phù hợp',
                      subtitle: widget.customerMode
                          ? 'Đơn đã hoàn tất có thể yêu cầu trả trong 7 ngày.'
                          : 'Các yêu cầu mới sẽ xuất hiện tại đây.',
                    )
                  else
                    for (final request in rows)
                      _ReturnRequestCard(
                        request: request,
                        customerMode: widget.customerMode,
                        onApprove:
                            !widget.customerMode &&
                                _numberId(request['status']) == 0
                            ? () => _review(request, 1)
                            : null,
                        onReject:
                            !widget.customerMode &&
                                _numberId(request['status']) == 0
                            ? () => _review(request, 2)
                            : null,
                        onReceive:
                            !widget.customerMode &&
                                _numberId(request['status']) == 1
                            ? () => _receive(request)
                            : null,
                      ),
                ],
              ),
            ),
    );
  }
}

class _ReturnRequestCard extends StatelessWidget {
  const _ReturnRequestCard({
    required this.request,
    required this.customerMode,
    required this.onApprove,
    required this.onReject,
    required this.onReceive,
  });

  final Map<String, dynamic> request;
  final bool customerMode;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onReceive;

  @override
  Widget build(BuildContext context) {
    final status = _numberId(request['status']);
    final details = _objects(request['details']);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFEFF1),
          child: Icon(Icons.assignment_return_outlined, color: _adminRose),
        ),
        title: Text(
          customerMode
              ? '${details.isEmpty ? 'Yêu cầu trả hàng' : details.first['productName']}'
              : '${request['customerName'] ?? 'Khách hàng'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${_date(request['requestedAt'])} · Hoàn ${_price(request['refundAmount'])}',
        ),
        trailing: _statusPill(_statusText(status, kind: 'return'), status),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _ReturnInfoRow(
            label: 'Lý do',
            value: _returnReason(request['reason']),
          ),
          if ('${request['description'] ?? ''}'.isNotEmpty)
            _ReturnInfoRow(label: 'Mô tả', value: request['description']),
          for (final detail in details)
            _ReturnInfoRow(
              label: '${detail['productName'] ?? 'Sản phẩm'}',
              value:
                  'Số lượng ${detail['quantity'] ?? 0} · Hoàn ${_price(detail['refundAmount'])}',
            ),
          if ('${request['staffNote'] ?? ''}'.isNotEmpty)
            _ReturnInfoRow(
              label: 'Ghi chú cửa hàng',
              value: request['staffNote'],
            ),
          if ('${request['evidenceImageUrl'] ?? ''}'.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    _showEvidence(context, '${request['evidenceImageUrl']}'),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Xem ảnh minh chứng'),
              ),
            ),
          if (onApprove != null || onReject != null || onReceive != null)
            Wrap(
              spacing: 8,
              children: [
                if (onApprove != null)
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('Duyệt yêu cầu'),
                  ),
                if (onReject != null)
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Từ chối'),
                  ),
                if (onReceive != null)
                  FilledButton.icon(
                    onPressed: onReceive,
                    icon: const Icon(Icons.inventory),
                    label: const Text('Kho đã nhận hàng'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _showEvidence(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Text('Không thể tải ảnh minh chứng.'),
          ),
        ),
      ),
    );
  }
}

String _returnReason(dynamic value) {
  final reason = _numberId(value);
  return switch (reason) {
    0 => 'Sản phẩm lỗi / hư hỏng',
    1 => 'Giao sai sản phẩm',
    2 => 'Không còn nhu cầu',
    3 => 'Lý do khác',
    _ => 'Chưa xác định',
  };
}

class _ReturnInfoRow extends StatelessWidget {
  const _ReturnInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(color: _adminMuted, fontSize: 12),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _ReturnReview {
  const _ReturnReview(this.refundAmount, this.note);

  final double refundAmount;
  final String note;
}

class _ReturnReviewDialog extends StatefulWidget {
  const _ReturnReviewDialog({required this.request, required this.approved});

  final Map<String, dynamic> request;
  final bool approved;

  @override
  State<_ReturnReviewDialog> createState() => _ReturnReviewDialogState();
}

class _ReturnReviewDialogState extends State<_ReturnReviewDialog> {
  late final _refund = TextEditingController(
    text: '${_numberAmount(widget.request['refundAmount'])}',
  );
  late final _note = TextEditingController(
    text: widget.approved
        ? 'Đã duyệt yêu cầu trả hàng.'
        : 'Yêu cầu trả hàng không được chấp nhận.',
  );

  @override
  void dispose() {
    _refund.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.approved ? 'Duyệt yêu cầu đổi trả' : 'Từ chối yêu cầu'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.approved) _numberField(_refund, 'Số tiền hoàn (₫)'),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Ghi chú cho khách'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          final refund = _amount(_refund.text);
          if (widget.approved &&
              (refund < 0 ||
                  refund > _numberAmount(widget.request['refundAmount']))) {
            return;
          }
          Navigator.pop(
            context,
            _ReturnReview(
              refund,
              _note.text.trim().isEmpty
                  ? 'Đã xử lý yêu cầu.'
                  : _note.text.trim(),
            ),
          );
        },
        child: Text(widget.approved ? 'Duyệt' : 'Từ chối'),
      ),
    ],
  );
}

class ReturnRequestFormPage extends StatefulWidget {
  const ReturnRequestFormPage({required this.state, super.key});

  final AppState state;

  @override
  State<ReturnRequestFormPage> createState() => _ReturnRequestFormPageState();
}

class _ReturnRequestFormPageState extends State<ReturnRequestFormPage> {
  final _description = TextEditingController();
  final _evidence = TextEditingController();
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _priorRequests = [];
  Map<String, dynamic>? _selectedOrder;
  final Map<int, int> _quantities = {};
  int _reason = 0;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _description.dispose();
    _evidence.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      final results = await Future.wait([
        widget.state.api.get('Order/mine'),
        widget.state.api.get('ReturnRequest/mine'),
      ]);
      final existingReturns = _objects(results[1]);
      final today = DateTime.now();
      _orders = _objects(results[0]).where((order) {
        if (_numberId(order['status']) != 4) return false;
        final shipping = _object(order['shipping']);
        final completedAt = DateTime.tryParse(
          '${shipping['deliveredAt'] ?? order['orderDate'] ?? order['createdAt']}',
        );
        return completedAt != null &&
            today.difference(completedAt).inDays <= 7 &&
            today.isAfter(completedAt.subtract(const Duration(minutes: 1)));
      }).toList();
      _priorRequests = existingReturns;
      if (mounted) setState(() {});
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<int, int> _previouslyReturned(int orderId) {
    final totals = <int, int>{};
    for (final request in _priorRequests) {
      if (_numberId(request['orderId']) != orderId ||
          ![0, 1, 3].contains(_numberId(request['status']))) {
        continue;
      }
      for (final detail in _objects(request['details'])) {
        final variantId = _numberId(detail['variantId']);
        totals[variantId] =
            (totals[variantId] ?? 0) + _numberId(detail['quantity']);
      }
    }
    return totals;
  }

  List<Map<String, dynamic>> _returnableLines() {
    final order = _selectedOrder;
    if (order == null) return [];
    final previouslyReturned = _previouslyReturned(_numberId(order['orderId']));
    final totals = <int, Map<String, dynamic>>{};
    for (final detail in _objects(order['orderDetails'])) {
      final variantId = _numberId(detail['variantId']);
      final current = totals.putIfAbsent(variantId, () => {...detail});
      current['quantity'] =
          _numberId(current['quantity']) + _numberId(detail['quantity']);
    }
    return totals.entries
        .where(
          (entry) =>
              _numberId(entry.value['quantity']) -
                  (previouslyReturned[entry.key] ?? 0) >
              0,
        )
        .map((entry) {
          final line = entry.value;
          line['remainingQuantity'] =
              _numberId(line['quantity']) -
              (previouslyReturned[entry.key] ?? 0);
          return line;
        })
        .toList();
  }

  Future<void> _submit() async {
    final order = _selectedOrder;
    if (order == null) {
      _show('Chọn đơn hàng cần đổi trả.');
      return;
    }
    if (_description.text.trim().isEmpty) {
      _show('Mô tả tình trạng sản phẩm trước khi gửi.');
      return;
    }
    final selected = _returnableLines()
        .where((line) => (_quantities[_numberId(line['variantId'])] ?? 0) > 0)
        .map((line) {
          final variantId = _numberId(line['variantId']);
          final quantity = _quantities[variantId]!;
          return {
            'variantId': variantId,
            'quantity': quantity,
            'unitPrice': 0,
            'refundAmount': 0,
            'reason': _description.text.trim(),
          };
        })
        .toList();
    if (selected.isEmpty) {
      _show('Chọn ít nhất một sản phẩm và số lượng muốn trả.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.state.api.post('ReturnRequest', {
        'orderId': _numberId(order['orderId']),
        'customerId': _numberId(widget.state.profile['customerId']),
        'returnType': 0,
        'reason': _reason,
        'description': _description.text.trim(),
        'evidenceImageUrl': _evidence.text.trim(),
        'details': selected,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) _show(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo yêu cầu đổi trả')),
      body: _error != null
          ? _WorkflowError(message: _error!, onRetry: _loadOrders)
          : Form(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _InfoNotice(
                    text:
                        'Chỉ đơn đã hoàn tất trong 7 ngày được yêu cầu đổi trả. Cửa hàng sẽ kiểm tra và xác nhận số tiền hoàn.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedOrder,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Đơn hàng đã hoàn tất *',
                    ),
                    items: [
                      for (final order in _orders)
                        DropdownMenuItem(
                          value: order,
                          child: Text(
                            '${_date(order['orderDate'] ?? order['createdAt'])} · ${_price(order['totalAmount'])}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedOrder = value;
                      _quantities.clear();
                    }),
                  ),
                  const SizedBox(height: 10),
                  if (_selectedOrder != null)
                    for (final line in _returnableLines()) _returnLine(line),
                  if (_selectedOrder != null && _returnableLines().isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Các sản phẩm trong đơn này đã được yêu cầu trả hết.',
                      ),
                    ),
                  DropdownButtonFormField<int>(
                    initialValue: _reason,
                    decoration: const InputDecoration(
                      labelText: 'Lý do đổi trả',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 0,
                        child: Text('Sản phẩm lỗi / hư hỏng'),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text('Giao sai sản phẩm'),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text('Không còn nhu cầu'),
                      ),
                      DropdownMenuItem(value: 3, child: Text('Lý do khác')),
                    ],
                    onChanged: (value) => setState(() => _reason = value ?? 0),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    maxLength: 2000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả tình trạng *',
                      hintText: 'Cho cửa hàng biết sản phẩm gặp vấn đề gì.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _evidence,
                    decoration: const InputDecoration(
                      labelText: 'Đường dẫn ảnh minh chứng (không bắt buộc)',
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(_saving ? 'Đang gửi...' : 'Gửi yêu cầu'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _returnLine(Map<String, dynamic> line) {
    final variantId = _numberId(line['variantId']);
    final maxQuantity = _numberId(line['remainingQuantity']);
    final quantity = _quantities[variantId] ?? 0;
    final title = '${line['productName'] ?? 'Sản phẩm'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Còn được trả: $maxQuantity',
                    style: const TextStyle(color: _adminMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: quantity <= 0
                  ? null
                  : () => setState(() {
                      if (quantity == 1) {
                        _quantities.remove(variantId);
                      } else {
                        _quantities[variantId] = quantity - 1;
                      }
                    }),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(quantity == 0 ? 'Không' : '$quantity'),
            IconButton(
              tooltip: quantity == 0 ? 'Chọn sản phẩm trả' : 'Tăng số lượng',
              onPressed: quantity >= maxQuantity
                  ? null
                  : () => setState(() => _quantities[variantId] = quantity + 1),
              icon: Icon(
                quantity == 0 ? Icons.add_circle : Icons.add_circle_outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoNotice extends StatelessWidget {
  const _InfoNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class SupportChatInboxPage extends StatefulWidget {
  const SupportChatInboxPage({required this.state, super.key});

  final AppState state;

  @override
  State<SupportChatInboxPage> createState() => _SupportChatInboxPageState();
}

class _SupportChatInboxPageState extends State<SupportChatInboxPage> {
  final _message = TextEditingController();
  Timer? _timer;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _messages = [];
  int? _selectedId;
  String? _error;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadConversations(quiet: true);
      _loadMessages(quiet: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadConversations({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await widget.state.api.get('SupportChat');
      _conversations = _objects(result);
      if (_selectedId == null && _conversations.isNotEmpty) {
        _selectedId = _numberId(_conversations.first['conversationId']);
        await _loadMessages();
      }
    } on ApiException catch (error) {
      if (!quiet) _error = error.message;
    } finally {
      if (!quiet && mounted) setState(() => _loading = false);
      if (quiet && mounted) setState(() {});
    }
  }

  Future<void> _select(Map<String, dynamic> conversation) async {
    setState(() {
      _selectedId = _numberId(conversation['conversationId']);
      _messages = [];
    });
    await _loadMessages();
  }

  Future<void> _loadMessages({bool quiet = false}) async {
    final id = _selectedId;
    if (id == null) return;
    try {
      final result = await widget.state.api.get('SupportChat/$id/messages');
      if (mounted) setState(() => _messages = _objects(result));
      await widget.state.api.post('SupportChat/$id/read');
    } on ApiException catch (error) {
      if (!quiet && mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _accept() async {
    final id = _selectedId;
    if (id == null) return;
    try {
      await widget.state.api.post('SupportChat/$id/accept');
      await _loadConversations();
      await _loadMessages();
    } on ApiException catch (error) {
      _show(error.message);
    }
  }

  Future<void> _send() async {
    final id = _selectedId;
    if (id == null || _message.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.state.api.post('SupportChat/$id/messages', {
        'content': _message.text.trim(),
      });
      _message.clear();
      await _loadMessages();
      await _loadConversations(quiet: true);
    } on ApiException catch (error) {
      _show(error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _show(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _conversations.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hỗ trợ khách hàng')),
        body: _WorkflowError(message: _error!, onRetry: _loadConversations),
      );
    }
    final selected = _conversations.where(
      (item) => _numberId(item['conversationId']) == _selectedId,
    );
    final current = selected.isEmpty ? null : selected.first;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hỗ trợ khách hàng'),
        actions: [
          IconButton(
            onPressed: _loadConversations,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showListOnly =
              _selectedId == null || constraints.maxWidth < 520;
          if (showListOnly) {
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final conversation in _conversations)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(
                        '${conversation['customerName'] ?? 'Khách hàng'}',
                      ),
                      subtitle: Text(_chatStatus(conversation['status'])),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        await _select(conversation);
                        if (!mounted) return;
                        await navigator.push(
                          MaterialPageRoute(
                            builder: (_) => _StaffConversationPage(
                              state: widget.state,
                              conversation: conversation,
                            ),
                          ),
                        );
                        if (mounted) _loadConversations();
                      },
                    ),
                  ),
                if (_conversations.isEmpty)
                  const _WorkflowEmpty(
                    icon: Icons.chat_bubble_outline,
                    title: 'Chưa có hội thoại',
                    subtitle: 'Yêu cầu chat của khách sẽ hiện tại đây.',
                  ),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(
                width: math.min(300, constraints.maxWidth * 0.4),
                child: ListView(
                  children: [
                    for (final conversation in _conversations)
                      ListTile(
                        selected:
                            _numberId(conversation['conversationId']) ==
                            _selectedId,
                        title: Text(
                          '${conversation['customerName'] ?? 'Khách hàng'}',
                        ),
                        subtitle: Text(_chatStatus(conversation['status'])),
                        onTap: () => _select(conversation),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _ConversationPanel(
                  conversation: current,
                  messages: _messages,
                  controller: _message,
                  sending: _sending,
                  onSend: _send,
                  onAccept: _accept,
                  onRefresh: _loadMessages,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _chatStatus(dynamic status) {
  switch (_numberId(status)) {
    case 0:
      return 'Chờ nhân viên tiếp nhận';
    case 1:
      return 'Đang trao đổi';
    case 2:
      return 'Đã đóng';
    default:
      return 'Hội thoại';
  }
}

class _StaffConversationPage extends StatefulWidget {
  const _StaffConversationPage({
    required this.state,
    required this.conversation,
  });

  final AppState state;
  final Map<String, dynamic> conversation;

  @override
  State<_StaffConversationPage> createState() => _StaffConversationPageState();
}

class _StaffConversationPageState extends State<_StaffConversationPage> {
  final _controller = TextEditingController();
  Timer? _timer;
  List<Map<String, dynamic>> _messages = [];
  bool _sending = false;
  String? _error;

  int get _id => _numberId(widget.conversation['conversationId']);

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await widget.state.api.get('SupportChat/$_id/messages');
      if (mounted) setState(() => _messages = _objects(result));
      await widget.state.api.post('SupportChat/$_id/read');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _accept() async {
    try {
      await widget.state.api.post('SupportChat/$_id/accept');
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.state.api.post('SupportChat/$_id/messages', {
        'content': _controller.text.trim(),
      });
      _controller.clear();
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.conversation['customerName'] ?? 'Hội thoại'}'),
    ),
    body: _ConversationPanel(
      conversation: widget.conversation,
      messages: _messages,
      controller: _controller,
      sending: _sending,
      onSend: _send,
      onAccept: _accept,
      onRefresh: _load,
      error: _error,
    ),
  );
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
    required this.conversation,
    required this.messages,
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAccept,
    required this.onRefresh,
    this.error,
  });

  final Map<String, dynamic>? conversation;
  final List<Map<String, dynamic>> messages;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAccept;
  final VoidCallback onRefresh;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (conversation == null) {
      return const _WorkflowEmpty(
        icon: Icons.chat_bubble_outline,
        title: 'Chọn một hội thoại',
        subtitle: 'Tin nhắn sẽ được hiển thị tại đây.',
      );
    }
    return Column(
      children: [
        if (error != null)
          MaterialBanner(
            content: Text(error!),
            actions: [
              TextButton(onPressed: onRefresh, child: const Text('Thử lại')),
            ],
          ),
        if (_numberId(conversation!['status']) == 0)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onAccept,
                child: const Text('Tiếp nhận hội thoại'),
              ),
            ),
          ),
        Expanded(
          child: messages.isEmpty
              ? const _WorkflowEmpty(
                  icon: Icons.mark_chat_unread_outlined,
                  title: 'Chưa có tin nhắn',
                  subtitle: 'Tin nhắn mới sẽ tự tải lại sau vài giây.',
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final message in messages)
                      Align(
                        alignment: message['senderRole'] == 'Customer'
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 350),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: message['senderRole'] == 'Customer'
                                ? const Color(0xFFF3F4F6)
                                : const Color(0xFFFFE4E9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${message['senderName'] ?? (message['senderRole'] == 'Customer' ? 'Khách hàng' : 'Nhân viên')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _adminMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('${message['content'] ?? ''}'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Trả lời khách hàng...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sending ? null : onSend,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: '${widget.product?['name'] ?? ''}',
  );
  late final _description = TextEditingController(
    text: '${widget.product?['description'] ?? ''}',
  );
  late final _basePrice = TextEditingController(
    text: '${widget.product?['basePrice'] ?? ''}',
  );
  late final _ageFrom = TextEditingController(
    text: '${widget.product?['ageFrom'] ?? ''}',
  );
  late final _ageTo = TextEditingController(
    text: '${widget.product?['ageTo'] ?? ''}',
  );
  late final _imageUrl = TextEditingController(
    text: '${widget.product?['imageUrl'] ?? ''}',
  );
  late int? _categoryId = _numberId(widget.product?['categoryId']) == 0
      ? null
      : _numberId(widget.product?['categoryId']);
  late int? _brandId = _numberId(widget.product?['brandId']) == 0
      ? null
      : _numberId(widget.product?['brandId']);
  late int? _supplierId = _numberId(widget.product?['supplierId']) == 0
      ? null
      : _numberId(widget.product?['supplierId']);
  final List<_SupplierProductDraft> _supplierLinks = [];
  late int _status = widget.product == null
      ? 1
      : _numberId(widget.product?['status']);
  late bool _featured = widget.product?['isFeatured'] == true;
  late bool _isNew = widget.product?['isNew'] != false;
  final List<_VariantDraft> _variants = [];
  bool _saving = false;
  bool _uploading = false;

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final source = _objects(widget.product?['productVariants']);
    if (source.isNotEmpty) {
      _variants.addAll(source.map(_VariantDraft.fromApi));
    } else {
      _variants.add(_VariantDraft.create());
    }
    for (final supplier in _objects(widget.product?['suppliers'])) {
      final supplierId = _numberId(supplier['supplierId']);
      if (supplierId > 0) {
        _supplierLinks.add(
          _SupplierProductDraft(
            supplierId: supplierId,
            referenceCost: '${supplier['giaNhapThamKhao'] ?? ''}',
            supplierSku: '${supplier['maHangNCC'] ?? ''}',
            isDefault: supplier['isDefault'] == true,
          ),
        );
      }
    }
    if (_supplierLinks.isEmpty && _supplierId != null) {
      _supplierLinks.add(
        _SupplierProductDraft(supplierId: _supplierId!, isDefault: true),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _basePrice.dispose();
    _ageFrom.dispose();
    _ageTo.dispose();
    _imageUrl.dispose();
    for (final variant in _variants) {
      variant.dispose();
    }
    for (final supplier in _supplierLinks) {
      supplier.dispose();
    }
    super.dispose();
  }

  Future<void> _uploadImage() async {
    setState(() => _uploading = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const ApiException('Không đọc được ảnh đã chọn.');
      }
      final response = _object(
        await widget.state.api.uploadImage(
          bytes,
          file.name,
          folder: 'products',
        ),
      );
      final url = response['url']?.toString();
      if (url == null || url.isEmpty) {
        throw const ApiException('Máy chủ chưa trả về đường dẫn ảnh.');
      }
      _imageUrl.text = widget.state.api.absoluteAssetUrl(url);
    } on ApiException catch (error) {
      if (mounted) _show(error.message);
    } catch (error) {
      if (mounted) _show('Không thể tải ảnh: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadVariantImage(_VariantDraft variant) async {
    setState(() => _uploading = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const ApiException('Không đọc được ảnh đã chọn.');
      }
      final response = _object(
        await widget.state.api.uploadImage(
          bytes,
          file.name,
          folder: 'products',
        ),
      );
      final url = response['url']?.toString();
      if (url == null || url.isEmpty) {
        throw const ApiException('Máy chủ chưa trả về đường dẫn ảnh.');
      }
      variant.image.text = widget.state.api.absoluteAssetUrl(url);
    } on ApiException catch (error) {
      if (mounted) _show(error.message);
    } catch (error) {
      if (mounted) _show('Không thể tải ảnh phiên bản: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _generateVariantMatrix() async {
    final names = List.generate(2, (_) => TextEditingController());
    final values = List.generate(2, (_) => TextEditingController());
    final result = await showDialog<List<List<Map<String, dynamic>>>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo tổ hợp phiên bản'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < names.length; index++) ...[
                TextField(
                  controller: names[index],
                  decoration: InputDecoration(
                    labelText: 'Thuộc tính ${index + 1} (ví dụ: Màu sắc)',
                  ),
                ),
                TextField(
                  controller: values[index],
                  decoration: const InputDecoration(
                    labelText: 'Giá trị phân tách bằng dấu phẩy',
                    hintText: 'Đỏ, Xanh, Vàng',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const Text(
                'Ví dụ: màu Đỏ/Xanh và size S/M sẽ tạo 4 phiên bản. Bỏ trống thuộc tính thứ hai nếu không cần.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final groups = <(String, List<String>)>[];
              for (var index = 0; index < names.length; index++) {
                final name = names[index].text.trim();
                final items = values[index].text
                    .split(',')
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .toList();
                if (name.isNotEmpty && items.isNotEmpty) {
                  groups.add((name, items));
                }
              }
              if (groups.isEmpty) return;
              var combinationCount = 1;
              final maximum = 100 - _variants.length;
              for (final group in groups) {
                if (group.$2.length > maximum ~/ combinationCount) {
                  _show(
                    'Ma trận vượt giới hạn $maximum phiên bản. Hãy giảm số giá trị thuộc tính.',
                  );
                  return;
                }
                combinationCount *= group.$2.length;
              }
              var combinations = <List<Map<String, dynamic>>>[[]];
              for (final group in groups) {
                combinations = [
                  for (final combination in combinations)
                    for (var index = 0; index < group.$2.length; index++)
                      [
                        ...combination,
                        {
                          'attributeName': group.$1,
                          'attributeValue': group.$2[index],
                          'displayOrder': index,
                        },
                      ],
                ];
              }
              Navigator.pop(context, combinations);
            },
            child: const Text('Tạo phiên bản'),
          ),
        ],
      ),
    );
    for (final controller in [...names, ...values]) {
      controller.dispose();
    }
    if (result == null || result.isEmpty) return;
    setState(() {
      for (final attributes in result) {
        final variant = _VariantDraft.create();
        variant.attributes.addAll(attributes);
        _variants.add(variant);
      }
    });
  }

  void _addSupplierLink() {
    final selected = _supplierLinks.map((item) => item.supplierId).toSet();
    final available = widget.suppliers
        .where(
          (supplier) => !selected.contains(_numberId(supplier['supplierId'])),
        )
        .toList();
    if (available.isEmpty) {
      _show('Không còn nhà cung cấp nào để thêm.');
      return;
    }
    int? supplierId;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm nhà cung cấp'),
          content: DropdownButtonFormField<int>(
            initialValue: supplierId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nhà cung cấp'),
            items: [
              for (final supplier in available)
                DropdownMenuItem(
                  value: _numberId(supplier['supplierId']),
                  child: Text('${supplier['name'] ?? 'Nhà cung cấp'}'),
                ),
            ],
            onChanged: (value) => setDialogState(() => supplierId = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: supplierId == null
                  ? null
                  : () {
                      setState(() {
                        _supplierLinks.add(
                          _SupplierProductDraft(
                            supplierId: supplierId!,
                            isDefault: _supplierLinks.isEmpty,
                          ),
                        );
                        if (_supplierLinks.length == 1) {
                          _supplierId = supplierId;
                        }
                      });
                      Navigator.pop(context);
                    },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null || _brandId == null) {
      _show('Vui lòng chọn danh mục và thương hiệu.');
      return;
    }
    if (_supplierLinks.isNotEmpty) {
      final defaultLinks = _supplierLinks
          .where((link) => link.isDefault)
          .toList();
      final selectedDefault = defaultLinks.isEmpty
          ? _supplierLinks.first
          : defaultLinks.first;
      for (final supplier in _supplierLinks) {
        supplier.isDefault = identical(supplier, selectedDefault);
      }
      _supplierId = selectedDefault.supplierId;
    } else {
      _supplierId = null;
    }
    if (_variants.isEmpty) {
      _show('Sản phẩm cần ít nhất một phiên bản.');
      return;
    }
    if (_variants.any(
      (variant) =>
          _amount(variant.price.text) <= 0 ||
          (variant.cost.text.trim().isNotEmpty &&
              _amount(variant.cost.text) < 0) ||
          (variant.weight.text.trim().isNotEmpty &&
              _amount(variant.weight.text) < 0),
    )) {
      _show('Giá bán phải lớn hơn 0; giá nhập và trọng lượng không được âm.');
      return;
    }
    if ((_ageFrom.text.trim().isNotEmpty &&
            (_numberId(_ageFrom.text) < 0 ||
                int.tryParse(_ageFrom.text) == null)) ||
        (_ageTo.text.trim().isNotEmpty &&
            (_numberId(_ageTo.text) < 0 ||
                int.tryParse(_ageTo.text) == null))) {
      _show('Độ tuổi phải là số tháng nguyên không âm.');
      return;
    }
    if (_ageFrom.text.trim().isNotEmpty &&
        _ageTo.text.trim().isNotEmpty &&
        _numberId(_ageTo.text) < _numberId(_ageFrom.text)) {
      _show('Độ tuổi kết thúc phải lớn hơn hoặc bằng độ tuổi bắt đầu.');
      return;
    }

    setState(() => _saving = true);
    try {
      final variantPayload = _variants.map((variant) {
        final payload = <String, dynamic>{
          'sku': variant.sku.text.trim(),
          'price': _amount(variant.price.text),
          'costPrice': variant.cost.text.trim().isEmpty
              ? null
              : _amount(variant.cost.text),
          'weight': variant.weight.text.trim().isEmpty
              ? null
              : _amount(variant.weight.text),
          'imageUrl': variant.image.text.trim().isNotEmpty
              ? variant.image.text.trim()
              : _imageUrl.text.trim().isEmpty
              ? null
              : _imageUrl.text.trim(),
          'status': variant.status,
          'attributes': variant.attributes,
        };
        return (variant: variant, payload: payload);
      }).toList();

      final productPayload = <String, dynamic>{
        'categoryId': _categoryId,
        'brandId': _brandId,
        'supplierId': _supplierId,
        'supplierIds': _supplierLinks.isEmpty
            ? <int>[]
            : _supplierLinks.map((item) => item.supplierId).toList(),
        'suppliers': _supplierLinks
            .map(
              (item) => {
                'supplierId': item.supplierId,
                'giaNhapThamKhao': item.referenceCost.text.trim().isEmpty
                    ? null
                    : _amount(item.referenceCost.text),
                'maHangNCC': item.supplierSku.text.trim().isEmpty
                    ? null
                    : item.supplierSku.text.trim(),
                'isDefault': item.isDefault,
              },
            )
            .toList(),
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'ageFrom': _ageFrom.text.trim().isEmpty
            ? null
            : _numberId(_ageFrom.text),
        'ageTo': _ageTo.text.trim().isEmpty ? null : _numberId(_ageTo.text),
        'gender': 3,
        'status': _status,
        'isFeatured': _featured,
        'basePrice': _basePrice.text.trim().isEmpty
            ? _amount(_variants.first.price.text)
            : _amount(_basePrice.text),
        'isNew': _isNew,
        'imageUrl': _imageUrl.text.trim().isEmpty
            ? null
            : _imageUrl.text.trim(),
      };

      if (!_editing) {
        productPayload['variants'] = variantPayload
            .map((entry) => entry.payload)
            .toList();
        await widget.state.api.post('Product', productPayload);
      } else {
        final productId = _numberId(widget.product!['productId']);
        await widget.state.api.put('Product/$productId', productPayload);
        for (final entry in variantPayload) {
          if (entry.variant.id == null || entry.variant.id == 0) {
            await widget.state.api.post(
              'Product/$productId/variants',
              entry.payload,
            );
          } else {
            await widget.state.api.put(
              'Product/variants/${entry.variant.id}',
              entry.payload,
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editing ? 'Đã lưu thông tin sản phẩm.' : 'Đã tạo sản phẩm mới.',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (error) {
      if (mounted) _show(error.message);
    } catch (error) {
      if (mounted) _show('Không thể lưu sản phẩm: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeVariant(_VariantDraft variant) async {
    if (variant.id != null &&
        !await _confirm(
          context,
          title: 'Xóa phiên bản?',
          message:
              'Tồn kho và đơn hàng cũ có thể khiến máy chủ từ chối thao tác này.',
          confirmLabel: 'Xóa phiên bản',
        )) {
      return;
    }
    try {
      if (variant.id != null) {
        await widget.state.api.delete('Product/variants/${variant.id}');
      }
      setState(() {
        _variants.remove(variant);
        variant.dispose();
      });
    } on ApiException catch (error) {
      if (mounted) _show(error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_editing ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm'),
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
        ),
      ],
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _FormSection(
            title: 'Thông tin sản phẩm',
            subtitle: 'Các trường có dấu * cần được điền.',
            children: [
              _input(
                _name,
                'Tên sản phẩm *',
                requiredField: true,
                maxLength: 200,
              ),
              const SizedBox(height: 12),
              _dropdown(
                label: 'Danh mục *',
                value: _categoryId,
                options: widget.categories,
                idKey: 'id',
                nameKey: 'name',
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 12),
              _dropdown(
                label: 'Thương hiệu *',
                value: _brandId,
                options: widget.brands,
                idKey: 'id',
                nameKey: 'name',
                onChanged: (value) => setState(() => _brandId = value),
              ),
              const SizedBox(height: 12),
              if (_supplierLinks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_supplierLinks.length} nhà cung cấp được liên kết',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final supplierLink in _supplierLinks)
                  _supplierLinkEditor(supplierLink),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addSupplierLink,
                  icon: const Icon(Icons.add_business_outlined),
                  label: const Text('Thêm nhà cung cấp'),
                ),
              ),
              const SizedBox(height: 12),
              _input(_description, 'Mô tả *', requiredField: true, maxLines: 3),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _input(
                      _ageFrom,
                      'Độ tuổi từ (tháng)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _input(
                      _ageTo,
                      'Đến (tháng)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _input(
                _basePrice,
                'Giá bán chung (để trống để dùng giá phiên bản)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              _dropdown(
                label: 'Trạng thái sản phẩm',
                value: _status,
                options: const [
                  {'id': 1, 'name': 'Đang bán'},
                  {'id': 0, 'name': 'Bản nháp'},
                  {'id': 2, 'name': 'Thanh lý'},
                  {'id': 3, 'name': 'Ngừng bán'},
                ],
                idKey: 'id',
                nameKey: 'name',
                onChanged: (value) => setState(() => _status = value ?? 1),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sản phẩm nổi bật'),
                value: _featured,
                onChanged: (value) => setState(() => _featured = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sản phẩm mới'),
                value: _isNew,
                onChanged: (value) => setState(() => _isNew = value),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FormSection(
            title: 'Ảnh sản phẩm',
            subtitle: 'Tải ảnh từ thiết bị hoặc dán đường dẫn ảnh.',
            children: [
              TextField(
                controller: _imageUrl,
                decoration: const InputDecoration(
                  labelText: 'Đường dẫn ảnh',
                  hintText: 'https://... hoặc đường dẫn ảnh đã tải lên',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _uploadImage,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _uploading ? 'Đang tải ảnh...' : 'Chọn ảnh từ thiết bị',
                ),
              ),
              if (_imageUrl.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _imageUrl.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _adminMuted, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _FormSection(
            title: 'Phiên bản và giá bán',
            subtitle:
                'Tạo tổ hợp màu/kích cỡ tự động hoặc sửa từng phiên bản. Mỗi phiên bản có giá, cân nặng, mã và ảnh riêng.',
            children: [
              for (var index = 0; index < _variants.length; index++)
                _variantEditor(index, _variants[index]),
              OutlinedButton.icon(
                onPressed: _generateVariantMatrix,
                icon: const Icon(Icons.grid_view_outlined),
                label: const Text('Tạo ma trận thuộc tính'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _variants.add(_VariantDraft.create())),
                icon: const Icon(Icons.add),
                label: const Text('Thêm phiên bản'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving || _uploading ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Đang lưu sản phẩm...' : 'Lưu sản phẩm'),
          ),
        ],
      ),
    ),
  );

  Widget _supplierLinkEditor(_SupplierProductDraft link) {
    final supplier = widget.suppliers.firstWhere(
      (item) => _numberId(item['supplierId']) == link.supplierId,
      orElse: () => {'name': 'Nhà cung cấp'},
    );
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${supplier['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Checkbox(
                  value: link.isDefault,
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      for (final item in _supplierLinks) {
                        item.isDefault = false;
                      }
                      link.isDefault = true;
                      _supplierId = link.supplierId;
                    }
                  }),
                ),
                const Text('Mặc định'),
                IconButton(
                  tooltip: 'Gỡ nhà cung cấp',
                  onPressed: () => setState(() {
                    _supplierLinks.remove(link);
                    link.dispose();
                    if (_supplierLinks.isEmpty) {
                      _supplierId = null;
                    } else if (link.isDefault) {
                      _supplierLinks.first.isDefault = true;
                      _supplierId = _supplierLinks.first.supplierId;
                    }
                  }),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _input(
                    link.referenceCost,
                    'Giá nhập tham khảo',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _input(link.supplierSku, 'Mã hàng của NCC')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _variantEditor(int index, _VariantDraft variant) => Card(
    color: const Color(0xFFFFFBFA),
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Phiên bản ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Xóa phiên bản',
                onPressed: _variants.length <= 1
                    ? null
                    : () => _removeVariant(variant),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: variant.sku,
                  decoration: const InputDecoration(labelText: 'Mã SKU'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nhập mã SKU'
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: variant.status == 0 ? 0 : 1,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Đang bán')),
                    DropdownMenuItem(value: 0, child: Text('Ngừng bán')),
                  ],
                  onChanged: (value) =>
                      setState(() => variant.status = value ?? 1),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _input(
                  variant.price,
                  'Giá bán *',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  requiredField: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _input(
                  variant.cost,
                  'Giá vốn (tùy chọn)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          _input(
            variant.weight,
            'Trọng lượng (gram)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: variant.image,
            decoration: const InputDecoration(
              labelText: 'Ảnh riêng cho phiên bản (tùy chọn)',
            ),
          ),
          TextButton.icon(
            onPressed: _uploading ? null : () => _uploadVariantImage(variant),
            icon: const Icon(Icons.image_outlined),
            label: const Text('Tải ảnh phiên bản'),
          ),
          if (variant.attributes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                variant.attributes
                    .map(
                      (attribute) =>
                          '${attribute['attributeName']}: ${attribute['attributeValue']}',
                    )
                    .join(' · '),
                style: const TextStyle(color: _adminMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _input(
    TextEditingController controller,
    String label, {
    bool requiredField = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    maxLength: maxLength,
    decoration: InputDecoration(labelText: label),
    validator: requiredField
        ? (value) => value == null || value.trim().isEmpty
              ? 'Vui lòng nhập thông tin này.'
              : null
        : null,
  );

  Widget _dropdown({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> options,
    required String idKey,
    required String nameKey,
    required ValueChanged<int?> onChanged,
    bool nullable = false,
  }) {
    final validIds = options.map((option) => _numberId(option[idKey])).toSet();
    final selected = value != null && validIds.contains(value) ? value : null;
    return DropdownButtonFormField<int?>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (nullable)
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('Không chọn nhà cung cấp'),
          ),
        for (final option in options)
          DropdownMenuItem<int?>(
            value: _numberId(option[idKey]),
            child: Text(
              '${option[nameKey] ?? 'Chưa đặt tên'}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      validator: !nullable && label.endsWith('*')
          ? (value) => value == null ? 'Vui lòng chọn $label' : null
          : null,
      onChanged: onChanged,
    );
  }

  double _amount(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: _adminMuted)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}
