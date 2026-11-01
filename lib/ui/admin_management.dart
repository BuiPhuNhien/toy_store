import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';

int _id(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _amount(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return {};
}

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.whereType<Map>().map(_map).toList()
    : <Map<String, dynamic>>[];

String _money(dynamic value) => '${_amount(value).toStringAsFixed(0)} ₫';
String _date(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  return date == null
      ? '—'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

void _notice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> _confirmAction(
  BuildContext context,
  String title,
  String message, {
  String confirm = 'Xác nhận',
}) async =>
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
            child: Text(confirm),
          ),
        ],
      ),
    ) ==
    true;

class MarketingManagementPage extends StatefulWidget {
  const MarketingManagementPage({required this.state, super.key});

  final AppState state;

  @override
  State<MarketingManagementPage> createState() =>
      _MarketingManagementPageState();
}

class _MarketingManagementPageState extends State<MarketingManagementPage> {
  int _tab = 0;
  int _reloadToken = 0;

  Future<bool?> _openForm([Map<String, dynamic>? record]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _MarketingFormDialog(
        state: widget.state,
        isPromotion: _tab == 0,
        record: record,
      ),
    );
    if (changed == true && mounted) setState(() => _reloadToken++);
    return changed;
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Khuyến mãi và voucher'),
        bottom: TabBar(
          onTap: (value) => setState(() => _tab = value),
          tabs: const [
            Tab(text: 'Khuyến mãi'),
            Tab(text: 'Voucher'),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _CampaignList(
            key: ValueKey('promotion-$_reloadToken'),
            state: widget.state,
            endpoint: 'Promotion',
            idKey: 'promotionId',
            title: 'Khuyến mãi',
            onEdit: _openForm,
          ),
          _CampaignList(
            key: ValueKey('voucher-$_reloadToken'),
            state: widget.state,
            endpoint: 'Voucher',
            idKey: 'voucherId',
            title: 'Voucher',
            onEdit: _openForm,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: Text(_tab == 0 ? 'Tạo khuyến mãi' : 'Tạo voucher'),
      ),
    ),
  );
}

class _CampaignList extends StatefulWidget {
  const _CampaignList({
    super.key,
    required this.state,
    required this.endpoint,
    required this.idKey,
    required this.title,
    required this.onEdit,
  });

  final AppState state;
  final String endpoint;
  final String idKey;
  final String title;
  final Future<bool?> Function(Map<String, dynamic>? record) onEdit;

  @override
  State<_CampaignList> createState() => _CampaignListState();
}

class _CampaignListState extends State<_CampaignList> {
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _products = [];
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
        widget.state.api.get(widget.endpoint),
        widget.endpoint == 'Promotion'
            ? widget.state.api.get('Product')
            : Future<dynamic>.value(const []),
      ]);
      _records = _list(results[0]);
      _products = _list(results[1]);
    } on ApiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = 'Không thể tải ${widget.title.toLowerCase()}: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    if (!await _confirmAction(
      context,
      'Xóa ${widget.title.toLowerCase()}?',
      'Thao tác sẽ gửi yêu cầu xóa lên máy chủ. Việc xóa có thể bị từ chối nếu đã phát sinh sử dụng.',
      confirm: 'Xóa',
    )) {
      return;
    }
    try {
      await widget.state.api.delete(
        '${widget.endpoint}/${_id(record[widget.idKey])}',
      );
      if (mounted) _notice(context, 'Đã xóa ${widget.title.toLowerCase()}.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) _notice(context, error.message);
    }
  }

  Future<void> _managePromotion(Map<String, dynamic> record) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _PromotionDetailsDialog(
        state: widget.state,
        promotion: record,
        products: _products,
      ),
    );
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
        children: [
          if (_records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Chưa có dữ liệu. Nhấn Tạo mới để bắt đầu.'),
            ),
          for (final record in _records)
            Card(
              child: ExpansionTile(
                title: Text(
                  '${record['name'] ?? record['code'] ?? widget.title}',
                ),
                subtitle: Text(
                  widget.endpoint == 'Promotion'
                      ? '${_date(record['startDate'])} – ${_date(record['endDate'])} · ${record['status'] == 1 ? 'Đang bật' : 'Đang tắt'}'
                      : '${record['code'] ?? ''} · ${record['usedCount'] ?? 0}/${record['usageLimit'] ?? '∞'} lượt · ${record['status'] == 1 ? 'Đang bật' : 'Đang tắt'}',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  if (widget.endpoint == 'Voucher') ...[
                    Text(
                      'Giảm ${record['discountType'] == 1 ? '${record['discountValue']}%' : _money(record['discountValue'])}; đơn tối thiểu ${_money(record['minimumOrderValue'])}; ${record['requiredPoints'] ?? 0} điểm.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lịch sử sử dụng: ${_list(record['voucherUsages']).length} lượt',
                    ),
                    for (final usage in _list(record['voucherUsages']).take(10))
                      ListTile(
                        dense: true,
                        title: Text(
                          'Đơn ${usage['orderId']} · giảm ${_money(usage['discountAmount'])}',
                        ),
                        subtitle: Text(_date(usage['usedAt'])),
                      ),
                  ] else ...[
                    Text(
                      'Giảm ${record['promotionType'] == 1 ? '${record['discountValue']}%' : _money(record['discountValue'])}; ưu tiên ${record['priority'] ?? 0}; ${record['canCombine'] == true ? 'được cộng dồn' : 'không cộng dồn'}.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_list(record['promotionProducts']).length} sản phẩm · ${_list(record['promotionConditions']).length} điều kiện',
                    ),
                  ],
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (await widget.onEdit(record) == true) _load();
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Sửa'),
                      ),
                      if (widget.endpoint == 'Promotion')
                        OutlinedButton.icon(
                          onPressed: () => _managePromotion(record),
                          icon: const Icon(Icons.tune),
                          label: const Text('Sản phẩm / điều kiện'),
                        ),
                      TextButton.icon(
                        onPressed: () => _delete(record),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Xóa'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MarketingFormDialog extends StatefulWidget {
  const _MarketingFormDialog({
    required this.state,
    required this.isPromotion,
    this.record,
  });

  final AppState state;
  final bool isPromotion;
  final Map<String, dynamic>? record;

  @override
  State<_MarketingFormDialog> createState() => _MarketingFormDialogState();
}

class _MarketingFormDialogState extends State<_MarketingFormDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: '${widget.record?['name'] ?? ''}',
  );
  late final _code = TextEditingController(
    text: '${widget.record?['code'] ?? ''}',
  );
  late final _description = TextEditingController(
    text: '${widget.record?['description'] ?? ''}',
  );
  late final _value = TextEditingController(
    text: '${widget.record?['discountValue'] ?? ''}',
  );
  late final _maximum = TextEditingController(
    text: '${widget.record?['maximumDiscount'] ?? ''}',
  );
  late final _minimum = TextEditingController(
    text: '${widget.record?['minimumOrderValue'] ?? ''}',
  );
  late final _limit = TextEditingController(
    text: '${widget.record?['usageLimit'] ?? 0}',
  );
  late final _perCustomer = TextEditingController(
    text: '${widget.record?['usageLimitPerCustomer'] ?? ''}',
  );
  late final _points = TextEditingController(
    text: '${widget.record?['requiredPoints'] ?? 0}',
  );
  late final _priority = TextEditingController(
    text: '${widget.record?['priority'] ?? 0}',
  );
  late DateTime _start =
      DateTime.tryParse('${widget.record?['startDate'] ?? ''}') ??
      DateTime.now();
  late DateTime _end =
      DateTime.tryParse('${widget.record?['endDate'] ?? ''}') ??
      DateTime.now().add(const Duration(days: 30));
  late int _discountType = _id(
    widget.record?[widget.isPromotion ? 'promotionType' : 'discountType'],
  );
  late int _status = _id(widget.record?['status']) == 1 ? 1 : 0;
  late bool _combine = widget.record?['canCombine'] == true;
  bool _saving = false;

  bool get _editing => widget.record != null;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _code,
      _description,
      _value,
      _maximum,
      _minimum,
      _limit,
      _perCustomer,
      _points,
      _priority,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final value = start ? _start : _end;
    final selected = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _start = selected;
      } else {
        _end = selected;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_discountType == 1 && _amount(_value.text) > 100) {
      _notice(context, 'Phần trăm giảm không được vượt quá 100%.');
      return;
    }
    if ((_maximum.text.trim().isNotEmpty &&
            (double.tryParse(_maximum.text) == null ||
                _amount(_maximum.text) < 0)) ||
        (_minimum.text.trim().isNotEmpty &&
            (double.tryParse(_minimum.text) == null ||
                _amount(_minimum.text) < 0)) ||
        _id(_limit.text) < 0 ||
        _id(_points.text) < 0 ||
        (_perCustomer.text.trim().isNotEmpty &&
            int.tryParse(_perCustomer.text) == null) ||
        (_perCustomer.text.trim().isNotEmpty && _id(_perCustomer.text) < 0) ||
        int.tryParse(_limit.text) == null ||
        int.tryParse(_points.text) == null ||
        (widget.isPromotion &&
            (int.tryParse(_priority.text) == null ||
                _id(_priority.text) < 0))) {
      _notice(context, 'Vui lòng nhập giá trị giới hạn hợp lệ, không âm.');
      return;
    }
    if (!_end.isAfter(_start)) {
      _notice(context, 'Ngày kết thúc phải sau ngày bắt đầu.');
      return;
    }
    setState(() => _saving = true);
    final endpoint = widget.isPromotion ? 'Promotion' : 'Voucher';
    final payload = widget.isPromotion
        ? <String, dynamic>{
            'name': _name.text.trim(),
            'description': _description.text.trim(),
            'promotionType': _discountType,
            'discountValue': _amount(_value.text),
            'maximumDiscount': _maximum.text.isEmpty
                ? null
                : _amount(_maximum.text),
            'startDate': _start.toUtc().toIso8601String(),
            'endDate': _end.toUtc().toIso8601String(),
            'priority': _id(_priority.text),
            'canCombine': _combine,
            'variantIds': _list(widget.record?['promotionProducts'])
                .map((item) => _id(item['variantId']))
                .where((id) => id > 0)
                .toList(),
            'status': _status,
          }
        : <String, dynamic>{
            'code': _code.text.trim(),
            'name': _name.text.trim(),
            'discountType': _discountType,
            'discountValue': _amount(_value.text),
            'maximumDiscount': _maximum.text.isEmpty
                ? null
                : _amount(_maximum.text),
            'minimumOrderValue': _minimum.text.isEmpty
                ? null
                : _amount(_minimum.text),
            'requiredPoints': _id(_points.text),
            'usageLimit': _id(_limit.text),
            'usageLimitPerCustomer': _perCustomer.text.isEmpty
                ? null
                : _id(_perCustomer.text),
            'startDate': _start.toUtc().toIso8601String(),
            'endDate': _end.toUtc().toIso8601String(),
            'status': _status,
          };
    try {
      if (_editing) {
        final idKey = widget.isPromotion ? 'promotionId' : 'voucherId';
        await widget.state.api.put(
          '$endpoint/${_id(widget.record![idKey])}',
          payload,
        );
      } else {
        await widget.state.api.post(endpoint, payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) _notice(context, error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${_editing ? 'Sửa' : 'Tạo'} ${widget.isPromotion ? 'khuyến mãi' : 'voucher'}',
    ),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (!widget.isPromotion)
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Mã voucher'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập mã voucher'
                    : null,
              ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Nhập tên' : null,
            ),
            if (widget.isPromotion)
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Mô tả'),
                maxLines: 2,
              ),
            DropdownButtonFormField<int>(
              initialValue: _discountType == 1 ? 1 : 0,
              decoration: const InputDecoration(labelText: 'Kiểu ưu đãi'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Giảm số tiền')),
                DropdownMenuItem(value: 1, child: Text('Giảm phần trăm')),
              ],
              onChanged: (value) => setState(() => _discountType = value ?? 0),
            ),
            TextFormField(
              controller: _value,
              decoration: InputDecoration(
                labelText: _discountType == 1
                    ? 'Phần trăm giảm'
                    : 'Số tiền giảm',
              ),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  _amount(value) <= 0 ? 'Giá trị phải lớn hơn 0' : null,
            ),
            TextFormField(
              controller: _maximum,
              decoration: const InputDecoration(
                labelText: 'Giảm tối đa (không bắt buộc)',
              ),
              keyboardType: TextInputType.number,
            ),
            if (!widget.isPromotion) ...[
              TextFormField(
                controller: _minimum,
                decoration: const InputDecoration(
                  labelText: 'Giá trị đơn tối thiểu',
                ),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _points,
                decoration: const InputDecoration(
                  labelText: 'Điểm cần đổi voucher',
                ),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _limit,
                decoration: const InputDecoration(
                  labelText: 'Tổng lượt dùng (0 = không giới hạn)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _perCustomer,
                decoration: const InputDecoration(
                  labelText: 'Lượt tối đa mỗi khách',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            if (widget.isPromotion)
              TextFormField(
                controller: _priority,
                decoration: const InputDecoration(
                  labelText: 'Độ ưu tiên (số lớn áp dụng trước)',
                ),
                keyboardType: TextInputType.number,
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bắt đầu'),
              subtitle: Text(_date(_start)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickDate(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kết thúc'),
              subtitle: Text(_date(_end)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickDate(false),
            ),
            if (widget.isPromotion)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cho phép cộng dồn'),
                value: _combine,
                onChanged: (value) => setState(() => _combine = value),
              ),
            DropdownButtonFormField<int>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Đang bật')),
                DropdownMenuItem(value: 0, child: Text('Tạm tắt')),
              ],
              onChanged: (value) => setState(() => _status = value ?? 1),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
      ),
    ],
  );
}

class _PromotionDetailsDialog extends StatefulWidget {
  const _PromotionDetailsDialog({
    required this.state,
    required this.promotion,
    required this.products,
  });

  final AppState state;
  final Map<String, dynamic> promotion;
  final List<Map<String, dynamic>> products;

  @override
  State<_PromotionDetailsDialog> createState() =>
      _PromotionDetailsDialogState();
}

class _PromotionDetailsDialogState extends State<_PromotionDetailsDialog> {
  int? _variantId;
  bool _busy = false;

  int get _promotionId => _id(widget.promotion['promotionId']);

  Future<void> _addCondition() async {
    final minimumOrder = TextEditingController();
    final minimumQuantity = TextEditingController();
    final description = TextEditingController();
    final categoriesById = <int, Map<String, dynamic>>{};
    final brandsById = <int, Map<String, dynamic>>{};
    for (final product in widget.products) {
      final categoryId = _id(product['categoryId']);
      final brandId = _id(product['brandId']);
      if (categoryId > 0) {
        categoriesById[categoryId] = {
          'id': categoryId,
          'name': product['categoryName'] ?? 'Danh mục $categoryId',
        };
      }
      if (brandId > 0) {
        brandsById[brandId] = {
          'id': brandId,
          'name': product['brandName'] ?? 'Thương hiệu $brandId',
        };
      }
    }
    int? categoryId;
    int? brandId;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm điều kiện áp dụng'),
          content: SizedBox(
            width: 440,
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                  controller: minimumOrder,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Đơn tối thiểu (tùy chọn)',
                  ),
                ),
                TextField(
                  controller: minimumQuantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số lượng tối thiểu (tùy chọn)',
                  ),
                ),
                DropdownButtonFormField<int?>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Chỉ áp dụng danh mục (tùy chọn)',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Mọi danh mục'),
                    ),
                    for (final item in categoriesById.values)
                      DropdownMenuItem<int?>(
                        value: _id(item['id']),
                        child: Text('${item['name']}'),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => categoryId = value),
                ),
                DropdownButtonFormField<int?>(
                  initialValue: brandId,
                  decoration: const InputDecoration(
                    labelText: 'Chỉ áp dụng thương hiệu (tùy chọn)',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Mọi thương hiệu'),
                    ),
                    for (final item in brandsById.values)
                      DropdownMenuItem<int?>(
                        value: _id(item['id']),
                        child: Text('${item['name']}'),
                      ),
                  ],
                  onChanged: (value) => setDialogState(() => brandId = value),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú điều kiện',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Thêm điều kiện'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      try {
        final minimumOrderText = minimumOrder.text.trim();
        final minimumQuantityText = minimumQuantity.text.trim();
        if ((minimumOrderText.isNotEmpty && _amount(minimumOrderText) <= 0) ||
            (minimumQuantityText.isNotEmpty &&
                (int.tryParse(minimumQuantityText) == null ||
                    _id(minimumQuantityText) <= 0)) ||
            (minimumOrderText.isEmpty &&
                minimumQuantityText.isEmpty &&
                categoryId == null &&
                brandId == null)) {
          throw const ApiException(
            'Nhập ít nhất một điều kiện hợp lệ; các giá trị phải lớn hơn 0.',
          );
        }
        await widget.state.api.post('Promotion/$_promotionId/conditions', {
          'promotionId': _promotionId,
          'conditionType': 0,
          'minimumOrderValue': minimumOrderText.isEmpty
              ? null
              : _amount(minimumOrderText),
          'minimumQuantity': minimumQuantityText.isEmpty
              ? null
              : _id(minimumQuantityText),
          'categoryId': categoryId,
          'brandId': brandId,
          'customerLevel': null,
          'description': description.text.trim(),
        });
        if (mounted) Navigator.pop(context, true);
      } on ApiException catch (error) {
        if (mounted) _notice(context, error.message);
      }
    }
    minimumOrder.dispose();
    minimumQuantity.dispose();
    description.dispose();
  }

  Future<void> _addVariant() async {
    final variant = _variantId;
    if (variant == null) return;
    setState(() => _busy = true);
    try {
      await widget.state.api.post('Promotion/$_promotionId/products', {
        'promotionId': _promotionId,
        'variantId': variant,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) _notice(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String path) async {
    if (!await _confirmAction(
      context,
      'Gỡ mục này?',
      'Mục sẽ bị gỡ khỏi chương trình khuyến mãi.',
      confirm: 'Gỡ',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.state.api.delete(path);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) _notice(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final variants = <Map<String, dynamic>>[];
    for (final product in widget.products) {
      for (final variant in _list(product['productVariants'])) {
        variants.add({
          ...variant,
          'displayName':
              '${product['name']} · ${variant['attributes'] is List ? _list(variant['attributes']).map((item) => item['attributeValue']).join(' / ') : variant['sku']}',
        });
      }
    }
    return AlertDialog(
      title: const Text('Sản phẩm áp dụng'),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Điều kiện áp dụng (${_list(widget.promotion['promotionConditions']).length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final condition in _list(
              widget.promotion['promotionConditions'],
            ))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${condition['description'] ?? 'Điều kiện khuyến mãi'}',
                ),
                subtitle: Text(
                  [
                    if (condition['minimumOrderValue'] != null)
                      'Đơn từ ${_money(condition['minimumOrderValue'])}',
                    if (condition['minimumQuantity'] != null)
                      'Số lượng từ ${condition['minimumQuantity']}',
                    if (condition['categoryName'] != null)
                      'Danh mục ${condition['categoryName']}',
                    if (condition['brandName'] != null)
                      'Thương hiệu ${condition['brandName']}',
                  ].join(' · '),
                ),
                trailing: IconButton(
                  tooltip: 'Xóa điều kiện',
                  onPressed: _busy
                      ? null
                      : () => _remove(
                          'Promotion/conditions/${_id(condition['promotionConditionId'])}',
                        ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _addCondition,
              icon: const Icon(Icons.add),
              label: const Text('Thêm điều kiện'),
            ),
            const Divider(height: 24),
            const Text(
              'Sản phẩm áp dụng',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            DropdownButtonFormField<int>(
              initialValue: _variantId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Chọn sản phẩm và phiên bản',
              ),
              items: [
                for (final variant in variants)
                  DropdownMenuItem(
                    value: _id(variant['variantId']),
                    child: Text(
                      '${variant['displayName']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _variantId = value),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy || _variantId == null ? null : _addVariant,
              child: const Text('Thêm phiên bản vào chương trình'),
            ),
            const Divider(height: 24),
            for (final item in _list(widget.promotion['promotionProducts']))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${item['productName'] ?? 'Sản phẩm'} · ${item['sku'] ?? ''}',
                ),
                trailing: IconButton(
                  tooltip: 'Gỡ',
                  onPressed: _busy
                      ? null
                      : () => _remove(
                          'Promotion/products/${_id(item['promotionProductId'])}',
                        ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, true),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

class InventoryLiquidationPage extends StatefulWidget {
  const InventoryLiquidationPage({required this.state, super.key});

  final AppState state;

  @override
  State<InventoryLiquidationPage> createState() =>
      _InventoryLiquidationPageState();
}

class _InventoryLiquidationPageState extends State<InventoryLiquidationPage> {
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _liquidations = [];
  List<Map<String, dynamic>> _products = [];
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
        widget.state.api.get('Inventory'),
        widget.state.api.get('Liquidation'),
        widget.state.api.get('Product'),
      ]);
      _inventory = _list(results[0]);
      _liquidations = _list(results[1]);
      _products = _list(results[2]);
    } on ApiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = 'Không thể tải dữ liệu kho: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _adjust(Map<String, dynamic> record) async {
    final quantity = TextEditingController(text: '${record['quantity'] ?? 0}');
    final reserved = TextEditingController(
      text: '${record['reservedQuantity'] ?? 0}',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Điều chỉnh ${record['productName'] ?? 'tồn kho'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tồn thực tế'),
            ),
            TextField(
              controller: reserved,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Đang giữ'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thay đổi tồn kho ảnh hưởng trực tiếp đến số lượng có thể bán.',
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
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (save == true) {
      try {
        final body = {
          'quantity': int.tryParse(quantity.text) ?? -1,
          'reservedQuantity': int.tryParse(reserved.text) ?? -1,
        };
        if (body['quantity']! < 0 ||
            body['reservedQuantity']! < 0 ||
            body['reservedQuantity']! > body['quantity']!) {
          throw const ApiException(
            'Số lượng phải là số nguyên không âm và đang giữ không được vượt tồn thực tế.',
          );
        }
        await widget.state.api.put(
          'Inventory/${_id(record['inventoryId'])}',
          body,
        );
        if (mounted) _notice(context, 'Đã cập nhật tồn kho.');
        await _load();
      } on ApiException catch (error) {
        if (mounted) _notice(context, error.message);
      }
    }
    quantity.dispose();
    reserved.dispose();
  }

  Future<void> _createInventory() async {
    final choices = <Map<String, dynamic>>[];
    final existing = _inventory.map((item) => _id(item['variantId'])).toSet();
    for (final product in _products) {
      for (final variant in _list(product['productVariants'])) {
        if (!existing.contains(_id(variant['variantId']))) {
          choices.add({...variant, 'productName': product['name']});
        }
      }
    }
    if (choices.isEmpty) {
      _notice(context, 'Tất cả phiên bản đã có bản ghi tồn kho.');
      return;
    }
    int? variantId;
    final quantity = TextEditingController(text: '0');
    final reserved = TextEditingController(text: '0');
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tạo bản ghi tồn kho'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: variantId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Phiên bản'),
                items: [
                  for (final item in choices)
                    DropdownMenuItem(
                      value: _id(item['variantId']),
                      child: Text(
                        '${item['productName']} · ${item['sku']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setDialogState(() => variantId = value),
              ),
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tồn thực tế'),
              ),
              TextField(
                controller: reserved,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Đang giữ'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: variantId == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
    if (created == true && variantId != null) {
      try {
        final total = int.tryParse(quantity.text);
        final held = int.tryParse(reserved.text);
        if (total == null ||
            held == null ||
            total < 0 ||
            held < 0 ||
            held > total) {
          throw const ApiException(
            'Số lượng phải là số nguyên không âm và đang giữ không được vượt tồn thực tế.',
          );
        }
        await widget.state.api.post('Inventory', {
          'variantId': variantId,
          'quantity': total,
          'reservedQuantity': held,
        });
        await _load();
      } on ApiException catch (error) {
        if (mounted) _notice(context, error.message);
      }
    }
    quantity.dispose();
    reserved.dispose();
  }

  Future<void> _newLiquidation() async {
    final availableByVariant = {
      for (final item in _inventory)
        _id(item['variantId']): _id(item['availableQuantity']),
    };
    final allVariants = <Map<String, dynamic>>[];
    for (final product in _products) {
      for (final variant in _list(product['productVariants'])) {
        final available = availableByVariant[_id(variant['variantId'])] ?? 0;
        if (available > 0) {
          allVariants.add({
            ...variant,
            'productName': product['name'],
            'availableQuantity': available,
          });
        }
      }
    }
    if (allVariants.isEmpty) {
      _notice(
        context,
        'Không có phiên bản nào còn tồn kho khả dụng để thanh lý.',
      );
      return;
    }
    final selected = <int, int>{};
    final note = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Lập phiếu thanh lý'),
          content: SizedBox(
            width: 480,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'Chọn hàng cần xuất. Server sẽ kiểm tra số lượng tồn khi lập và xác nhận phiếu.',
                ),
                for (final variant in allVariants)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${variant['productName']} · ${variant['sku']}',
                        ),
                      ),
                      SizedBox(
                        width: 92,
                        child: TextFormField(
                          initialValue:
                              '${selected[_id(variant['variantId'])] ?? 0}',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'SL',
                            helperText:
                                'Tối đa ${variant['availableQuantity']}',
                          ),
                          onChanged: (value) {
                            final count = int.tryParse(value) ?? 0;
                            if (count > 0) {
                              selected[_id(variant['variantId'])] = count;
                            } else {
                              selected.remove(_id(variant['variantId']));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Ghi chú'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Lập phiếu'),
            ),
          ],
        ),
      ),
    );
    if (created == true) {
      try {
        final exceedsStock = selected.entries.any(
          (entry) => entry.value > (availableByVariant[entry.key] ?? 0),
        );
        if (exceedsStock) {
          throw const ApiException(
            'Số lượng thanh lý vượt tồn kho khả dụng. Hãy tải lại dữ liệu kho.',
          );
        }
        final result = _map(
          await widget.state.api.post('Liquidation', {
            'note': note.text.trim(),
            'details': selected.entries
                .map(
                  (entry) => {'variantId': entry.key, 'quantity': entry.value},
                )
                .toList(),
          }),
        );
        if (mounted) {
          final id = _id(result['liquidationReceiptId']);
          final complete = await _confirmAction(
            context,
            'Xác nhận đã xuất hàng?',
            'Chỉ tiếp tục nếu hàng đã được xuất khỏi kho. Khi xác nhận, tồn kho sẽ giảm.',
            confirm: 'Đã xuất hàng',
          );
          if (complete && id > 0) {
            await widget.state.api.post('Liquidation/$id/complete');
          }
        }
        await _load();
      } on ApiException catch (error) {
        if (mounted) _notice(context, error.message);
      }
    }
    note.dispose();
  }

  Future<void> _liquidationAction(
    Map<String, dynamic> item,
    String action,
  ) async {
    final complete = action == 'complete';
    if (!await _confirmAction(
      context,
      complete ? 'Xác nhận đã xuất kho?' : 'Hủy phiếu thanh lý?',
      complete
          ? 'Tồn kho sẽ giảm theo số lượng ghi trên phiếu.'
          : 'Phiếu chờ sẽ bị hủy và không làm thay đổi tồn kho.',
      confirm: complete ? 'Đã xuất hàng' : 'Hủy phiếu',
    )) {
      return;
    }
    try {
      await widget.state.api.post(
        'Liquidation/${_id(item['liquidationReceiptId'])}/$action',
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) _notice(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kho và thanh lý')),
        body: Center(child: Text(_error!)),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kho và thanh lý'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tồn kho'),
              Tab(text: 'Thanh lý'),
            ],
          ),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () {
              final tab = DefaultTabController.of(context).index;
              if (tab == 0) {
                _createInventory();
              } else {
                _newLiquidation();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Tạo mới'),
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final item in _inventory)
                  Card(
                    child: ListTile(
                      title: Text('${item['productName'] ?? 'Sản phẩm'}'),
                      subtitle: Text(
                        'SKU ${item['sku'] ?? '—'} · Tồn ${item['quantity'] ?? 0} · Đang giữ ${item['reservedQuantity'] ?? 0} · Có thể bán ${item['availableQuantity'] ?? 0}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Điều chỉnh tồn kho',
                        onPressed: () => _adjust(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final item in _liquidations)
                  Card(
                    child: ExpansionTile(
                      title: Text('${item['receiptCode'] ?? 'Phiếu thanh lý'}'),
                      subtitle: Text(
                        '${_id(item['status']) == 0
                            ? 'Chờ xác nhận xuất kho'
                            : _id(item['status']) == 1
                            ? 'Đã hoàn tất'
                            : 'Đã hủy'} · ${_date(item['createdAt'])}',
                      ),
                      children: [
                        for (final detail in _list(item['details']))
                          ListTile(
                            title: Text(
                              '${detail['productName'] ?? 'Sản phẩm'}',
                            ),
                            subtitle: Text(
                              '${detail['sku'] ?? ''} · Số lượng ${detail['quantity'] ?? 0}',
                            ),
                          ),
                        if (_id(item['status']) == 0)
                          Wrap(
                            alignment: WrapAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    _liquidationAction(item, 'cancel'),
                                child: const Text('Hủy phiếu'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    _liquidationAction(item, 'complete'),
                                child: const Text('Xác nhận đã xuất'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({required this.state, super.key});

  final AppState state;

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _customers = [];
  String? _error;
  bool _loading = true;
  int? _statusFilter;

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
      _customers = _list(await widget.state.api.get('Customer'));
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> customer) async {
    final fields = <String, TextEditingController>{
      'fullName': TextEditingController(text: '${customer['fullName'] ?? ''}'),
      'phone': TextEditingController(text: '${customer['phone'] ?? ''}'),
      'email': TextEditingController(text: '${customer['email'] ?? ''}'),
      'address': TextEditingController(text: '${customer['address'] ?? ''}'),
    };
    var status = _id(customer['status']) == 0 ? 0 : 1;
    DateTime? dateOfBirth = DateTime.tryParse(
      '${customer['dateOfBirth'] ?? ''}',
    );
    int? gender = customer['gender'] == null ? null : _id(customer['gender']);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cập nhật khách hàng'),
          content: SizedBox(
            width: 440,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final entry in fields.entries)
                  TextField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: switch (entry.key) {
                        'fullName' => 'Họ và tên',
                        'phone' => 'Số điện thoại',
                        'email' => 'Email',
                        _ => 'Địa chỉ',
                      },
                    ),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ngày sinh'),
                  subtitle: Text(_date(dateOfBirth)),
                  trailing: Wrap(
                    children: [
                      if (dateOfBirth != null)
                        IconButton(
                          tooltip: 'Xóa ngày sinh',
                          onPressed: () =>
                              setDialogState(() => dateOfBirth = null),
                          icon: const Icon(Icons.clear),
                        ),
                      IconButton(
                        tooltip: 'Chọn ngày sinh',
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: dateOfBirth ?? DateTime(2000),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (selected != null) {
                            setDialogState(() => dateOfBirth = selected);
                          }
                        },
                        icon: const Icon(Icons.calendar_today_outlined),
                      ),
                    ],
                  ),
                ),
                DropdownButtonFormField<int?>(
                  initialValue: gender,
                  decoration: const InputDecoration(labelText: 'Giới tính'),
                  items: const [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Không chọn'),
                    ),
                    DropdownMenuItem<int?>(value: 0, child: Text('Nam')),
                    DropdownMenuItem<int?>(value: 1, child: Text('Nữ')),
                    DropdownMenuItem<int?>(value: 2, child: Text('Khác')),
                  ],
                  onChanged: (value) => setDialogState(() => gender = value),
                ),
                DropdownButtonFormField<int>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Tình trạng'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Đang hoạt động')),
                    DropdownMenuItem(value: 0, child: Text('Ngừng hoạt động')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? 1),
                ),
                const SizedBox(height: 10),
                Text(
                  'Điểm: ${customer['loyaltyPoint'] ?? 0} · Tổng mua: ${_money(customer['totalSpent'])}',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      try {
        await widget.state.api.put('Customer/${_id(customer['customerId'])}', {
          'fullName': fields['fullName']!.text.trim(),
          'phone': fields['phone']!.text.trim(),
          'email': fields['email']!.text.trim(),
          'address': fields['address']!.text.trim(),
          'dateOfBirth': dateOfBirth?.toIso8601String(),
          'gender': gender,
          'status': status,
        });
        await _load();
      } on ApiException catch (error) {
        if (mounted) _notice(context, error.message);
      }
    }
    for (final field in fields.values) {
      field.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final query = _search.text.trim().toLowerCase();
    final customers = _customers.where((customer) {
      final matchesText =
          query.isEmpty ||
          '${customer['fullName']} ${customer['phone']} ${customer['email']}'
              .toLowerCase()
              .contains(query);
      final matchesStatus =
          _statusFilter == null || _id(customer['status']) == _statusFilter;
      return matchesText && matchesStatus;
    }).toList();
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Khách hàng')),
        body: Center(child: Text(_error!)),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khách hàng'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm theo tên, số điện thoại hoặc email',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: _statusFilter,
              decoration: const InputDecoration(labelText: 'Lọc tình trạng'),
              items: const [
                DropdownMenuItem<int?>(value: null, child: Text('Tất cả')),
                DropdownMenuItem<int?>(value: 1, child: Text('Đang hoạt động')),
                DropdownMenuItem<int?>(
                  value: 0,
                  child: Text('Ngừng hoạt động'),
                ),
              ],
              onChanged: (value) => setState(() => _statusFilter = value),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Hiển thị ${customers.length} / ${_customers.length} khách hàng',
              ),
            ),
            for (final customer in customers)
              Card(
                child: ListTile(
                  title: Text('${customer['fullName'] ?? 'Khách hàng'}'),
                  subtitle: Text(
                    '${customer['phone'] ?? ''} · ${customer['email'] ?? ''}\n${customer['totalOrders'] ?? 0} đơn · ${_money(customer['totalSpent'])} · ${customer['status'] == 1 ? 'Đang hoạt động' : 'Ngừng hoạt động'}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Sửa thông tin',
                    onPressed: () => _edit(customer),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  onTap: () => _edit(customer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({required this.state, super.key});

  final AppState state;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  String? _error;
  bool _loading = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
      _users = _list(await widget.state.api.get('Auth/users'));
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assignRole(Map<String, dynamic> user) async {
    const roles = ['Customer', 'Staff', 'Manager', 'Admin', 'Shipper'];
    var role = roles.contains(user['role']) ? '${user['role']}' : roles.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thay đổi vai trò'),
          content: DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Vai trò'),
            items: [
              for (final item in roles)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (value) =>
                setDialogState(() => role = value ?? roles.first),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu vai trò'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.state.api.post('Auth/assign-role', {
        'userId': user['userId'],
        'role': role,
      });
      await _load();
    } on ApiException catch (error) {
      if (mounted) _notice(context, error.message);
    }
  }

  Future<void> _toggle(Map<String, dynamic> user) async {
    final enable = user['isActive'] != true;
    if (!await _confirmAction(
      context,
      enable ? 'Kích hoạt tài khoản?' : 'Tạm khóa tài khoản?',
      'Thay đổi sẽ ảnh hưởng đến khả năng đăng nhập của người dùng này.',
      confirm: enable ? 'Kích hoạt' : 'Tạm khóa',
    )) {
      return;
    }
    try {
      await widget.state.api.post(
        'Auth/users/${Uri.encodeComponent('${user['userId']}')}/toggle-status',
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) _notice(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final query = _search.text.trim().toLowerCase();
    final users = _users.where((user) {
      return query.isEmpty ||
          '${user['fullName']} ${user['email']} ${user['role']}'
              .toLowerCase()
              .contains(query);
    }).toList();
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Người dùng và phân quyền')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Người dùng và phân quyền'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Chỉ Admin có quyền thay đổi vai trò và trạng thái tài khoản.',
              ),
            ),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm theo tên, email hoặc vai trò',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Hiển thị ${users.length} / ${_users.length} tài khoản',
              ),
            ),
            for (final user in users)
              Card(
                child: ListTile(
                  title: Text(
                    '${user['fullName'] ?? user['email'] ?? 'Tài khoản'}',
                  ),
                  subtitle: Text(
                    '${user['email'] ?? ''} · ${user['role'] ?? 'Chưa có vai trò'}\n${user['isActive'] == true ? 'Đang hoạt động' : 'Đã khóa'}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'role') _assignRole(user);
                      if (action == 'status') _toggle(user);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'role',
                        child: Text('Gán vai trò'),
                      ),
                      PopupMenuItem(
                        value: 'status',
                        child: Text(
                          user['isActive'] == true
                              ? 'Tạm khóa tài khoản'
                              : 'Kích hoạt tài khoản',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
