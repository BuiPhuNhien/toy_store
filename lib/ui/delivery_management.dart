import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';

int _deliveryId(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _deliveryAmount(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

Map<String, dynamic> _deliveryMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return {};
}

List<Map<String, dynamic>> _deliveryList(dynamic value) => value is List
    ? value.whereType<Map>().map(_deliveryMap).toList()
    : <Map<String, dynamic>>[];

String _deliveryMoney(dynamic value) =>
    '${_deliveryAmount(value).toStringAsFixed(0)} ₫';

String _deliveryDate(dynamic value, {bool withTime = false}) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '—';
  final day =
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  return withTime
      ? '$day ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
      : day;
}

void _deliveryNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> _deliveryConfirm(
  BuildContext context, {
  required String title,
  required String message,
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

class DeliveryManagementPage extends StatelessWidget {
  const DeliveryManagementPage({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Điều phối và thu tiền'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Điều phối'),
            Tab(text: 'Shipper'),
            Tab(text: 'COD'),
            Tab(text: 'Thu tiền'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _DispatchTab(state: state),
          _ShipperRosterTab(state: state),
          _CodReconciliationTab(state: state),
          _CollectionsTab(state: state),
        ],
      ),
    ),
  );
}

class _DispatchTab extends StatefulWidget {
  const _DispatchTab({required this.state});

  final AppState state;

  @override
  State<_DispatchTab> createState() => _DispatchTabState();
}

class _DispatchTabState extends State<_DispatchTab> {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _shippers = [];
  final Set<int> _selectedOrders = {};
  String? _error;
  bool _loading = true;
  bool _busy = false;
  double _maxDistanceKm = 3;

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
      final values = await Future.wait([
        widget.state.api.get('Order'),
        widget.state.api.get(
          'Shipping/batch-suggestions',
          queryParameters: {'maxDistanceKm': '$_maxDistanceKm'},
        ),
        widget.state.api.get('Shipper'),
      ]);
      _orders = _deliveryList(values[0]);
      _suggestions = _deliveryList(values[1]);
      _shippers = _deliveryList(values[2]);
      _selectedOrders.removeWhere(
        (id) => !_orders.any((order) => _deliveryId(order['orderId']) == id),
      );
    } on ApiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = 'Không thể tải dữ liệu điều phối: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _shipping(Map<String, dynamic> order) =>
      _deliveryMap(order['shipping']);

  List<Map<String, dynamic>> get _pendingOrders => _orders.where((order) {
    final shipping = _shipping(order);
    return _deliveryId(shipping['status']) == 0 &&
        _deliveryId(order['status']) != 4 &&
        _deliveryId(order['status']) != 5;
  }).toList();

  Map<String, List<Map<String, dynamic>>> get _batches {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final order in _orders) {
      final code = '${_shipping(order)['deliveryBatchCode'] ?? ''}'.trim();
      if (code.isNotEmpty) (result[code] ??= []).add(order);
    }
    return result;
  }

  Future<int?> _chooseShipper() async {
    final active = _shippers
        .where((shipper) => shipper['isActive'] == true)
        .toList();
    if (active.isEmpty) {
      _deliveryNotice(context, 'Chưa có shipper đang hoạt động.');
      return null;
    }
    int? selectedId = _deliveryId(active.first['shipperId']);
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chọn shipper'),
          content: DropdownButtonFormField<int>(
            initialValue: selectedId,
            isExpanded: true,
            items: [
              for (final shipper in active)
                DropdownMenuItem(
                  value: _deliveryId(shipper['shipperId']),
                  child: Text(
                    '${shipper['fullName']} · ${shipper['phoneNumber'] ?? 'Không có SĐT'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setDialogState(() => selectedId = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: selectedId == null
                  ? null
                  : () => Navigator.pop(context, selectedId),
              child: const Text('Chọn shipper'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assign({
    int? orderId,
    String? batchCode,
    int? knownShipperId,
  }) async {
    final shipperId = knownShipperId ?? await _chooseShipper();
    if (shipperId == null) return;
    setState(() => _busy = true);
    try {
      await widget.state.api.post('Shipper/assign-order', {
        'shipperId': shipperId,
        'orderId': batchCode == null ? orderId : null,
        'deliveryBatchCode': batchCode,
      });
      if (mounted) _deliveryNotice(context, 'Đã phân công shipper.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) _deliveryNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _newBatchCode() =>
      'MOB-${DateTime.now().millisecondsSinceEpoch.toString()}';

  Future<void> _mergeOrders(
    List<int> orderIds, {
    String? batchCode,
    bool dispatch = false,
  }) async {
    if (orderIds.length < 2) {
      _deliveryNotice(context, 'Chọn ít nhất 2 đơn để gộp thành lô.');
      return;
    }
    final code = batchCode ?? _newBatchCode();
    int? shipperId;
    if (dispatch) {
      shipperId = await _chooseShipper();
      if (!mounted || shipperId == null) return;
    }
    if (!await _deliveryConfirm(
      context,
      title: dispatch ? 'Gộp và xuất giao lô?' : 'Gộp đơn thành lô?',
      message: dispatch
          ? 'Gộp ${orderIds.length} đơn vào lô $code, phân công shipper và chuyển cả lô sang giao. Chỉ xác nhận khi đã sẵn sàng xuất kho.'
          : 'Gộp ${orderIds.length} đơn vào lô $code.',
      confirm: dispatch ? 'Gộp và xuất giao' : 'Gộp đơn',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.state.api.post('Shipping/merge-batch', {
        'orderIds': orderIds,
        'batchCode': code,
      });
      if (dispatch) {
        await widget.state.api.post('Shipper/assign-order', {
          'shipperId': shipperId,
          'deliveryBatchCode': code,
        });
        await widget.state.api.post(
          'Shipping/dispatch-batch/${Uri.encodeComponent(code)}',
        );
      }
      _selectedOrders.clear();
      if (mounted) {
        _deliveryNotice(
          context,
          dispatch
              ? 'Đã gộp, phân công và xuất giao lô $code.'
              : 'Đã gộp đơn vào lô $code.',
        );
      }
      await _load();
    } on ApiException catch (error) {
      if (mounted) _deliveryNotice(context, error.message);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mergeSuggestion(
    Map<String, dynamic> suggestion, {
    required bool dispatch,
  }) async {
    final ids = (suggestion['orderIds'] as List? ?? [])
        .map(_deliveryId)
        .where((id) => id > 0)
        .toList();
    final code = '${suggestion['targetBatchCode'] ?? _newBatchCode()}';
    await _mergeOrders(ids, batchCode: code, dispatch: dispatch);
  }

  Future<void> _dispatchBatch(String code) async {
    final batchOrders = _batches[code] ?? [];
    if (!await _deliveryConfirm(
      context,
      title: 'Xuất giao cả lô?',
      message:
          'Lô $code có ${batchOrders.length} đơn. Thao tác sẽ chuyển tất cả đơn trong lô sang trạng thái đang giao.',
      confirm: 'Xuất giao',
    )) {
      return;
    }
    await _runRequest(
      () => widget.state.api.post(
        'Shipping/dispatch-batch/${Uri.encodeComponent(code)}',
      ),
      'Đã xuất giao lô $code.',
    );
  }

  Future<void> _unbatch(Map<String, dynamic> order) async {
    final id = _deliveryId(order['orderId']);
    if (!await _deliveryConfirm(
      context,
      title: 'Tách đơn khỏi lô?',
      message:
          'Đơn ${order['orderCode'] ?? '#$id'} sẽ không còn thuộc lô hiện tại.',
      confirm: 'Tách đơn',
    )) {
      return;
    }
    await _runRequest(
      () => widget.state.api.post('Shipping/unbatch-order/$id'),
      'Đã tách đơn khỏi lô.',
    );
  }

  Future<void> _retryDelivery(Map<String, dynamic> order) async {
    final id = _deliveryId(order['orderId']);
    final shipperId = await _chooseShipper();
    if (!mounted || shipperId == null) return;
    if (!await _deliveryConfirm(
      context,
      title: 'Xuất giao lại?',
      message:
          'Đơn ${order['orderCode'] ?? '#$id'} sẽ chuyển sang đang giao và được giao cho shipper đã chọn.',
      confirm: 'Giao lại',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.state.api.post(
        'Shipper/orders/$id/retry-delivery?shipperId=$shipperId',
      );
      if (mounted) _deliveryNotice(context, 'Đã chuyển đơn sang giao lại.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) _deliveryNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runRequest(
    Future<dynamic> Function() request,
    String success,
  ) async {
    setState(() => _busy = true);
    try {
      await request();
      if (mounted) _deliveryNotice(context, success);
      await _load();
    } on ApiException catch (error) {
      if (mounted) _deliveryNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _DeliveryLoadError(message: _error!, onRetry: _load);
    }
    final batches = _batches;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Đơn chờ xuất kho: ${_pendingOrders.length}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Tải lại',
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Gợi ý lô trong bán kính'),
              const SizedBox(width: 8),
              DropdownButton<double>(
                value: _maxDistanceKm,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 km')),
                  DropdownMenuItem(value: 3, child: Text('3 km')),
                  DropdownMenuItem(value: 5, child: Text('5 km')),
                  DropdownMenuItem(value: 10, child: Text('10 km')),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _maxDistanceKm = value);
                        _load();
                      },
              ),
            ],
          ),
          if (_suggestions.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.route_outlined),
                title: Text('Chưa có nhóm đơn phù hợp để gộp.'),
                subtitle: Text(
                  'Gợi ý dựa trên số điện thoại người nhận hoặc địa chỉ lân cận.',
                ),
              ),
            )
          else
            for (final suggestion in _suggestions)
              _BatchSuggestionCard(
                suggestion: suggestion,
                busy: _busy,
                onMerge: () => _mergeSuggestion(suggestion, dispatch: false),
                onDispatch: () => _mergeSuggestion(suggestion, dispatch: true),
              ),
          if (_selectedOrders.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                title: Text(
                  'Đã chọn ${_selectedOrders.length} đơn chưa xuất kho',
                ),
                subtitle: const Text(
                  'Gộp thủ công thành lô; máy chủ sẽ kiểm tra tính hợp lệ.',
                ),
                trailing: FilledButton(
                  onPressed: _busy || _selectedOrders.length < 2
                      ? null
                      : () => _mergeOrders(_selectedOrders.toList()),
                  child: const Text('Gộp lô'),
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(
              'Các lô hiện có',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          if (batches.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Chưa có lô giao hàng.'),
                subtitle: Text(
                  'Tạo lô từ gợi ý hoặc chọn các đơn chờ xuất kho.',
                ),
              ),
            )
          else
            for (final entry in batches.entries)
              _DeliveryBatchCard(
                code: entry.key,
                orders: entry.value,
                busy: _busy,
                canManage: widget.state.isStaff,
                onAssign: () => _assign(batchCode: entry.key),
                onDispatch: () => _dispatchBatch(entry.key),
                onUnbatch: _unbatch,
                onRetry: _retryDelivery,
              ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(
              'Đơn hàng chưa xuất kho',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          if (_pendingOrders.isEmpty)
            const Card(
              child: ListTile(title: Text('Không có đơn chờ xuất kho.')),
            )
          else
            for (final order in _pendingOrders)
              _PendingDeliveryOrder(
                order: order,
                selected: _selectedOrders.contains(
                  _deliveryId(order['orderId']),
                ),
                busy: _busy,
                canManage: widget.state.isStaff,
                onSelected: (value) => setState(() {
                  final id = _deliveryId(order['orderId']);
                  if (value) {
                    _selectedOrders.add(id);
                  } else {
                    _selectedOrders.remove(id);
                  }
                }),
                onAssign: () => _assign(orderId: _deliveryId(order['orderId'])),
                onUnbatch: () => _unbatch(order),
              ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(
              'Đơn giao thất bại cần xử lý',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          for (final order in _orders.where((order) {
            final status = _deliveryId(_shipping(order)['status']);
            return status == 5 || status == 6;
          }))
            _FailedDeliveryOrder(
              order: order,
              busy: _busy,
              onRetry: () => _retryDelivery(order),
            ),
        ],
      ),
    );
  }
}

class _BatchSuggestionCard extends StatelessWidget {
  const _BatchSuggestionCard({
    required this.suggestion,
    required this.busy,
    required this.onMerge,
    required this.onDispatch,
  });

  final Map<String, dynamic> suggestion;
  final bool busy;
  final VoidCallback onMerge;
  final VoidCallback onDispatch;

  @override
  Widget build(BuildContext context) {
    final stops = _deliveryList(suggestion['deliveryStops']);
    final count = (suggestion['orderIds'] as List? ?? []).length;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.alt_route, color: Colors.indigo),
        title: Text('${suggestion['reason'] ?? 'Đề xuất gộp đơn'}'),
        subtitle: Text(
          '$count đơn · ${suggestion['commonAddressArea'] ?? 'Khu vực lân cận'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final stop in stops)
            ListTile(
              dense: true,
              leading: const Icon(Icons.location_on_outlined, size: 20),
              title: Text('${stop['receiverName'] ?? 'Người nhận'}'),
              subtitle: Text(
                '${stop['address'] ?? 'Chưa có địa chỉ'} · ${stop['receiverPhone'] ?? ''}',
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy ? null : onMerge,
                child: const Text('Gộp thành lô'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : onDispatch,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Gộp, phân công và xuất giao'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeliveryBatchCard extends StatelessWidget {
  const _DeliveryBatchCard({
    required this.code,
    required this.orders,
    required this.busy,
    required this.canManage,
    required this.onAssign,
    required this.onDispatch,
    required this.onUnbatch,
    required this.onRetry,
  });

  final String code;
  final List<Map<String, dynamic>> orders;
  final bool busy;
  final bool canManage;
  final VoidCallback onAssign;
  final VoidCallback onDispatch;
  final Future<void> Function(Map<String, dynamic>) onUnbatch;
  final Future<void> Function(Map<String, dynamic>) onRetry;

  @override
  Widget build(BuildContext context) {
    final ready = orders.any(
      (order) => _deliveryId(_deliveryMap(order['shipping'])['status']) == 0,
    );
    final shipper = _deliveryMap(orders.first['shipping']);
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.local_shipping_outlined),
        title: Text(code),
        subtitle: Text(
          '${orders.length} đơn · ${shipper['shipperName'] ?? 'Chưa phân công'} · ${ready ? 'Chờ xuất kho' : 'Đang xử lý'}',
        ),
        children: [
          for (final order in orders)
            _BatchOrderLine(
              order: order,
              busy: busy,
              onUnbatch: onUnbatch,
              onRetry: onRetry,
            ),
          if (canManage)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onAssign,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(
                    shipper['shipperName'] == null
                        ? 'Gán shipper'
                        : 'Đổi shipper',
                  ),
                ),
                if (ready)
                  FilledButton(
                    onPressed: busy ? null : onDispatch,
                    child: const Text('Xuất giao cả lô'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BatchOrderLine extends StatelessWidget {
  const _BatchOrderLine({
    required this.order,
    required this.busy,
    required this.onUnbatch,
    required this.onRetry,
  });

  final Map<String, dynamic> order;
  final bool busy;
  final Future<void> Function(Map<String, dynamic>) onUnbatch;
  final Future<void> Function(Map<String, dynamic>) onRetry;

  @override
  Widget build(BuildContext context) {
    final shipping = _deliveryMap(order['shipping']);
    final status = _deliveryId(shipping['status']);
    final canUnbatch = status == 0;
    return ListTile(
      dense: true,
      title: Text(
        '${order['orderCode'] ?? 'Đơn hàng'} · ${shipping['receiverName'] ?? order['customerName'] ?? 'Khách hàng'}',
      ),
      subtitle: Text(
        '${shipping['address'] ?? 'Chưa có địa chỉ'}\n${_shippingStatusLabel(status)}',
      ),
      isThreeLine: true,
      trailing: status == 5 || status == 6
          ? TextButton(
              onPressed: busy ? null : () => onRetry(order),
              child: const Text('Giao lại'),
            )
          : canUnbatch
          ? IconButton(
              tooltip: 'Tách khỏi lô',
              onPressed: busy ? null : () => onUnbatch(order),
              icon: const Icon(Icons.link_off),
            )
          : null,
    );
  }
}

class _PendingDeliveryOrder extends StatelessWidget {
  const _PendingDeliveryOrder({
    required this.order,
    required this.selected,
    required this.busy,
    required this.canManage,
    required this.onSelected,
    required this.onAssign,
    required this.onUnbatch,
  });

  final Map<String, dynamic> order;
  final bool selected;
  final bool busy;
  final bool canManage;
  final ValueChanged<bool> onSelected;
  final VoidCallback onAssign;
  final VoidCallback onUnbatch;

  @override
  Widget build(BuildContext context) {
    final shipping = _deliveryMap(order['shipping']);
    final batchCode = '${shipping['deliveryBatchCode'] ?? ''}';
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: selected,
          onChanged: busy ? null : (value) => onSelected(value == true),
        ),
        title: Text(
          '${order['orderCode'] ?? 'Đơn hàng'} · ${shipping['receiverName'] ?? order['customerName'] ?? 'Khách hàng'}',
        ),
        subtitle: Text(
          '${shipping['address'] ?? 'Chưa có địa chỉ'}\n${batchCode.isEmpty ? 'Chưa vào lô' : 'Lô $batchCode'} · ${shipping['shipperName'] ?? 'Chưa phân công'}',
        ),
        isThreeLine: true,
        trailing: canManage
            ? PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'assign') onAssign();
                  if (action == 'unbatch') onUnbatch();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'assign',
                    child: Text(
                      shipping['shipperName'] == null
                          ? 'Gán shipper'
                          : 'Đổi shipper',
                    ),
                  ),
                  if (batchCode.isNotEmpty)
                    const PopupMenuItem(
                      value: 'unbatch',
                      child: Text('Tách khỏi lô'),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}

class _FailedDeliveryOrder extends StatelessWidget {
  const _FailedDeliveryOrder({
    required this.order,
    required this.busy,
    required this.onRetry,
  });

  final Map<String, dynamic> order;
  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final shipping = _deliveryMap(order['shipping']);
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.replay_circle_filled,
          color: Colors.deepOrange,
        ),
        title: Text('${order['orderCode'] ?? 'Đơn hàng'}'),
        subtitle: Text(
          '${shipping['receiverName'] ?? 'Khách hàng'} · ${shipping['failReason'] ?? 'Giao không thành công'}\n${_shippingStatusLabel(_deliveryId(shipping['status']))} · ${shipping['shipperName'] ?? 'Chưa phân công'}',
        ),
        isThreeLine: true,
        trailing: FilledButton(
          onPressed: busy ? null : onRetry,
          child: const Text('Giao lại'),
        ),
      ),
    );
  }
}

String _shippingStatusLabel(int status) => switch (status) {
  0 => 'Chờ xuất kho',
  1 => 'Đã nhận đơn',
  2 => 'Đã lấy hàng',
  3 => 'Đang giao',
  4 => 'Giao thành công',
  5 => 'Giao thất bại · chờ giao lại',
  6 => 'Đã hoàn hàng về kho',
  _ => 'Trạng thái $status',
};

class _ShipperRosterTab extends StatefulWidget {
  const _ShipperRosterTab({required this.state});

  final AppState state;

  @override
  State<_ShipperRosterTab> createState() => _ShipperRosterTabState();
}

class _ShipperRosterTabState extends State<_ShipperRosterTab> {
  List<Map<String, dynamic>> _shippers = [];
  String? _error;
  bool _loading = true;

  bool get _canEdit => widget.state.canManageInventory;

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
      _shippers = _deliveryList(await widget.state.api.get('Shipper'));
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? shipper]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _ShipperFormDialog(state: widget.state, shipper: shipper),
    );
    if (saved == true) _load();
  }

  Future<void> _deactivate(Map<String, dynamic> shipper) async {
    final id = _deliveryId(shipper['shipperId']);
    if (!await _deliveryConfirm(
      context,
      title: 'Tạm ngừng shipper?',
      message:
          '${shipper['fullName'] ?? 'Nhân viên giao hàng'} sẽ không còn được gán đơn mới.',
      confirm: 'Tạm ngừng',
    )) {
      return;
    }
    try {
      await widget.state.api.delete('Shipper/$id');
      if (mounted) _deliveryNotice(context, 'Đã tạm ngừng shipper.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) _deliveryNotice(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _DeliveryLoadError(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_canEdit)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Thêm shipper'),
              ),
            )
          else
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Admin/Quản lý mới có thể sửa hồ sơ shipper.'),
              ),
            ),
          if (_shippers.isEmpty)
            const Card(child: ListTile(title: Text('Chưa có hồ sơ shipper.'))),
          for (final shipper in _shippers)
            Card(
              child: ExpansionTile(
                leading: CircleAvatar(
                  child: Text(
                    '${shipper['fullName'] ?? 'S'}'
                        .trim()
                        .characters
                        .first
                        .toUpperCase(),
                  ),
                ),
                title: Text('${shipper['fullName'] ?? 'Shipper'}'),
                subtitle: Text(
                  '${shipper['phoneNumber'] ?? 'Chưa có số điện thoại'} · ${shipper['isActive'] == true ? 'Đang hoạt động' : 'Tạm dừng'}',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  _RosterMetric(
                    label: 'Đơn đang phụ trách',
                    value: '${shipper['activeOrdersCount'] ?? 0}',
                  ),
                  _RosterMetric(
                    label: 'Đã giao thành công',
                    value: '${shipper['completedOrdersCount'] ?? 0}',
                  ),
                  _RosterMetric(
                    label: 'COD đang giữ/chờ đối soát',
                    value: _deliveryMoney(shipper['pendingCodAmount']),
                  ),
                  _RosterMetric(
                    label: 'Xe / tuyến',
                    value:
                        '${shipper['vehicleNumber'] ?? 'Chưa khai báo'} · ${shipper['assignedArea'] ?? 'Linh hoạt'}',
                  ),
                  if (_canEdit)
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _edit(shipper),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Sửa hồ sơ'),
                        ),
                        if (shipper['isActive'] == true)
                          TextButton.icon(
                            onPressed: () => _deactivate(shipper),
                            icon: const Icon(Icons.person_off_outlined),
                            label: const Text('Tạm ngừng'),
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

class _RosterMetric extends StatelessWidget {
  const _RosterMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text(label),
    trailing: Text(
      value,
      style: const TextStyle(fontWeight: FontWeight.w700),
      textAlign: TextAlign.end,
    ),
  );
}

class _ShipperFormDialog extends StatefulWidget {
  const _ShipperFormDialog({required this.state, this.shipper});

  final AppState state;
  final Map<String, dynamic>? shipper;

  @override
  State<_ShipperFormDialog> createState() => _ShipperFormDialogState();
}

class _ShipperFormDialogState extends State<_ShipperFormDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: '${widget.shipper?['fullName'] ?? ''}',
  );
  late final _phone = TextEditingController(
    text: '${widget.shipper?['phoneNumber'] ?? ''}',
  );
  late final _vehicle = TextEditingController(
    text: '${widget.shipper?['vehicleNumber'] ?? ''}',
  );
  late final _area = TextEditingController(
    text: '${widget.shipper?['assignedArea'] ?? ''}',
  );
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _active = widget.shipper?['isActive'] != false;
  bool _saving = false;

  bool get _editing => widget.shipper != null;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _vehicle,
      _area,
      _email,
      _password,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (!_editing && (email.isEmpty != password.isEmpty)) {
      _deliveryNotice(
        context,
        'Nếu tạo tài khoản đăng nhập, cần nhập cả email và mật khẩu.',
      );
      return;
    }
    setState(() => _saving = true);
    final profile = <String, dynamic>{
      'fullName': _name.text.trim(),
      'phoneNumber': _phone.text.trim(),
      'vehicleNumber': _vehicle.text.trim().isEmpty
          ? null
          : _vehicle.text.trim(),
      'assignedArea': _area.text.trim().isEmpty ? null : _area.text.trim(),
    };
    try {
      if (_editing) {
        profile['isActive'] = _active;
        await widget.state.api.put(
          'Shipper/${_deliveryId(widget.shipper!['shipperId'])}',
          profile,
        );
      } else {
        profile['email'] = email.isEmpty ? null : email;
        profile['password'] = password.isEmpty ? null : password;
        await widget.state.api.post('Shipper', profile);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) _deliveryNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_editing ? 'Cập nhật hồ sơ shipper' : 'Thêm shipper'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Họ và tên *'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Nhập họ tên' : null,
            ),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nhập số điện thoại'
                  : null,
            ),
            TextFormField(
              controller: _vehicle,
              decoration: const InputDecoration(labelText: 'Biển số xe'),
            ),
            TextFormField(
              controller: _area,
              decoration: const InputDecoration(labelText: 'Tuyến phụ trách'),
            ),
            if (!_editing) ...[
              const Divider(height: 24),
              const Text(
                'Tài khoản đăng nhập (không bắt buộc)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email tài khoản'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  return RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(value.trim())
                      ? null
                      : 'Email chưa đúng định dạng';
                },
              ),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
              ),
              const Text(
                'Bỏ trống cả hai trường nếu chỉ tạo hồ sơ. Tạo tài khoản cần email và mật khẩu.',
                style: TextStyle(fontSize: 12),
              ),
            ],
            if (_editing)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đang hoạt động'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
      ),
    ],
  );
}

class _CodReconciliationTab extends StatefulWidget {
  const _CodReconciliationTab({required this.state});

  final AppState state;

  @override
  State<_CodReconciliationTab> createState() => _CodReconciliationTabState();
}

class _CodReconciliationTabState extends State<_CodReconciliationTab> {
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _shippers = [];
  final Set<int> _selectedPayments = {};
  int? _statusFilter;
  int? _shipperFilter;
  String? _error;
  bool _loading = true;
  bool _busy = false;

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
        widget.state.api.get('Shipper/cod-reconciliation'),
        widget.state.api.get('Shipper'),
      ]);
      _records = _deliveryList(results[0]);
      _shippers = _deliveryList(results[1]);
      _selectedPayments.removeWhere(
        (id) =>
            !_records.any((record) => _deliveryId(record['paymentId']) == id),
      );
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered => _records.where((record) {
    final status = _deliveryId(record['codStatus']);
    return (_statusFilter == null || status == _statusFilter) &&
        (_shipperFilter == null ||
            _deliveryId(record['shipperId']) == _shipperFilter);
  }).toList();

  double get _selectedExpected => _records
      .where(
        (record) =>
            _selectedPayments.contains(_deliveryId(record['paymentId'])),
      )
      .fold(
        0,
        (total, record) => total + _deliveryAmount(record['storeAmount']),
      );

  Future<void> _confirmSubmission({
    required List<int> paymentIds,
    required double expectedAmount,
  }) async {
    if (paymentIds.isEmpty) return;
    final amount = TextEditingController(
      text: expectedAmount.toStringAsFixed(0),
    );
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<({double amount, String note})>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận COD vào quỹ'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Số tiền cần nộp theo hệ thống: ${_deliveryMoney(expectedAmount)}',
                ),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Số tiền thực nhận (không gồm phí giao)',
                  ),
                  validator: (value) {
                    final entered = double.tryParse(
                      (value ?? '').replaceAll(',', ''),
                    );
                    if (entered == null || entered < 0) {
                      return 'Nhập số tiền hợp lệ';
                    }
                    if (entered != expectedAmount) {
                      return 'Số tiền phải khớp ${_deliveryMoney(expectedAmount)}';
                    }
                    return null;
                  },
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (tùy chọn)',
                  ),
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
              if (!form.currentState!.validate()) return;
              Navigator.pop(context, (
                amount: double.parse(amount.text.replaceAll(',', '')),
                note: note.text.trim(),
              ));
            },
            child: const Text('Đã kiểm đếm'),
          ),
        ],
      ),
    );
    if (result == null) {
      amount.dispose();
      note.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.state.api.post('Shipper/confirm-cod-submission', {
        'paymentIds': paymentIds,
        'receivedAmount': result.amount,
        'note': result.note.isEmpty ? null : result.note,
      });
      _selectedPayments.removeAll(paymentIds);
      if (mounted) _deliveryNotice(context, 'Đã xác nhận tiền COD vào quỹ.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) _deliveryNotice(context, error.message);
    } finally {
      amount.dispose();
      note.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _DeliveryLoadError(message: _error!, onRetry: _load);
    }
    final filtered = _filtered;
    final pending = filtered.where((row) => _deliveryId(row['codStatus']) == 2);
    final holdingTotal = _records
        .where((row) => _deliveryId(row['codStatus']) == 1)
        .fold(0.0, (sum, row) => sum + _deliveryAmount(row['storeAmount']));
    final waitingTotal = _records
        .where((row) => _deliveryId(row['codStatus']) == 2)
        .fold(0.0, (sum, row) => sum + _deliveryAmount(row['storeAmount']));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _CodSummaryCard(
            holding: holdingTotal,
            pending: waitingTotal,
            count: _records.length,
          ),
          DropdownButtonFormField<int?>(
            initialValue: _statusFilter,
            decoration: const InputDecoration(labelText: 'Lọc trạng thái COD'),
            items: const [
              DropdownMenuItem<int?>(value: null, child: Text('Tất cả')),
              DropdownMenuItem<int?>(value: 1, child: Text('Shipper đang giữ')),
              DropdownMenuItem<int?>(value: 2, child: Text('Chờ xác nhận')),
              DropdownMenuItem<int?>(value: 3, child: Text('Đã vào quỹ')),
            ],
            onChanged: (value) => setState(() => _statusFilter = value),
          ),
          DropdownButtonFormField<int?>(
            initialValue: _shipperFilter,
            decoration: const InputDecoration(labelText: 'Lọc shipper'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Tất cả shipper'),
              ),
              for (final shipper in _shippers)
                DropdownMenuItem<int?>(
                  value: _deliveryId(shipper['shipperId']),
                  child: Text('${shipper['fullName'] ?? 'Shipper'}'),
                ),
            ],
            onChanged: (value) => setState(() => _shipperFilter = value),
          ),
          if (pending.isNotEmpty)
            Card(
              child: ListTile(
                title: Text(
                  'Đang chọn ${_selectedPayments.length} khoản · ${_deliveryMoney(_selectedExpected)}',
                ),
                subtitle: const Text(
                  'Chỉ chọn khoản shipper đã báo nộp. Số tiền xác nhận phải khớp khoản cần nộp.',
                ),
                trailing: FilledButton(
                  onPressed: _busy || _selectedPayments.isEmpty
                      ? null
                      : () => _confirmSubmission(
                          paymentIds: _selectedPayments.toList(),
                          expectedAmount: _selectedExpected,
                        ),
                  child: const Text('Xác nhận đã nhận'),
                ),
              ),
            ),
          if (filtered.isEmpty)
            const Card(
              child: ListTile(title: Text('Không có khoản COD phù hợp.')),
            ),
          for (final record in filtered)
            _CodRecordCard(
              record: record,
              selected: _selectedPayments.contains(
                _deliveryId(record['paymentId']),
              ),
              busy: _busy,
              onSelected: (value) => setState(() {
                final id = _deliveryId(record['paymentId']);
                if (value) {
                  _selectedPayments.add(id);
                } else {
                  _selectedPayments.remove(id);
                }
              }),
              onConfirm: () => _confirmSubmission(
                paymentIds: [_deliveryId(record['paymentId'])],
                expectedAmount: _deliveryAmount(record['storeAmount']),
              ),
            ),
        ],
      ),
    );
  }
}

class _CodSummaryCard extends StatelessWidget {
  const _CodSummaryCard({
    required this.holding,
    required this.pending,
    required this.count,
  });

  final double holding;
  final double pending;
  final int count;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        runSpacing: 12,
        children: [
          _MiniAmount(label: 'Shipper đang giữ', amount: holding),
          _MiniAmount(label: 'Chờ xác nhận', amount: pending),
          Text(
            '$count khoản COD',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _MiniAmount extends StatelessWidget {
  const _MiniAmount({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12)),
      Text(
        _deliveryMoney(amount),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _CodRecordCard extends StatelessWidget {
  const _CodRecordCard({
    required this.record,
    required this.selected,
    required this.busy,
    required this.onSelected,
    required this.onConfirm,
  });

  final Map<String, dynamic> record;
  final bool selected;
  final bool busy;
  final ValueChanged<bool> onSelected;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final status = _deliveryId(record['codStatus']);
    final products = _deliveryList(record['products']);
    final canConfirm = status == 2;
    return Card(
      child: ExpansionTile(
        leading: canConfirm
            ? Checkbox(
                value: selected,
                onChanged: busy ? null : (value) => onSelected(value == true),
              )
            : const Icon(Icons.account_balance_wallet_outlined),
        title: Text(
          '${record['orderCode'] ?? 'Đơn hàng'} · ${record['receiverName'] ?? 'Khách hàng'}',
        ),
        subtitle: Text(
          '${_codStatusLabel(status)} · ${record['shipperName'] ?? 'Chưa gán shipper'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final product in products)
            ListTile(
              dense: true,
              title: Text(
                '${product['productName'] ?? 'Sản phẩm'} × ${product['quantity'] ?? 0}',
              ),
            ),
          _RosterMetric(
            label: 'Khách trả',
            value: _deliveryMoney(record['amount']),
          ),
          _RosterMetric(
            label: 'Phí giao',
            value: _deliveryMoney(record['shippingFee']),
          ),
          _RosterMetric(
            label: 'Cần nộp cửa hàng',
            value: _deliveryMoney(record['storeAmount']),
          ),
          _RosterMetric(
            label: 'Thời điểm thu',
            value: _deliveryDate(record['codCollectedAt'], withTime: true),
          ),
          if (record['deliveryBatchCode'] != null)
            _RosterMetric(
              label: 'Lô giao',
              value: '${record['deliveryBatchCode']}',
            ),
          if (canConfirm)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: busy ? null : onConfirm,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Kiểm đếm và xác nhận'),
              ),
            ),
        ],
      ),
    );
  }
}

String _codStatusLabel(int status) => switch (status) {
  1 => 'Shipper đang giữ tiền',
  2 => 'Shipper báo nộp · chờ xác nhận',
  3 => 'Đã xác nhận vào quỹ',
  _ => 'Chưa thu COD',
};

class _CollectionsTab extends StatefulWidget {
  const _CollectionsTab({required this.state});

  final AppState state;

  @override
  State<_CollectionsTab> createState() => _CollectionsTabState();
}

class _CollectionsTabState extends State<_CollectionsTab> {
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _to = DateTime.now();
  Map<String, dynamic> _report = {};
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _dateParam(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    if (_from.isAfter(_to)) {
      setState(() => _error = 'Ngày bắt đầu không được sau ngày kết thúc.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _report = _deliveryMap(
        await widget.state.api.get(
          'ManagementReport/collections',
          queryParameters: {'from': _dateParam(_from), 'to': _dateParam(_to)},
        ),
      );
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool from) async {
    final current = from ? _from : _to;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    setState(() {
      if (from) {
        _from = selected;
      } else {
        _to = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _DeliveryLoadError(message: _error!, onRetry: _load);
    }
    final records = _deliveryList(_report['records']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ReportDateButton(
                          label: 'Từ ngày',
                          date: _from,
                          onTap: () => _pickDate(true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ReportDateButton(
                          label: 'Đến ngày',
                          date: _to,
                          onTap: () => _pickDate(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Xem báo cáo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _RevenueSummaryCard(report: _report),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${records.length} khoản thu · ${_deliveryDate(_report['from'])} – ${_deliveryDate(_report['to'])}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (records.isEmpty)
            const Card(
              child: ListTile(
                title: Text(
                  'Không có khoản tiền thực thu trong khoảng ngày này.',
                ),
              ),
            ),
          for (final record in records) _CollectionRecordCard(record: record),
        ],
      ),
    );
  }
}

class _ReportDateButton extends StatelessWidget {
  const _ReportDateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Text(_deliveryDate(date.toIso8601String())),
      ],
    ),
  );
}

class _RevenueSummaryCard extends StatelessWidget {
  const _RevenueSummaryCard({required this.report});

  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _RosterMetric(
            label: 'Thực thu vào quỹ',
            value: _deliveryMoney(report['totalFundReceived']),
          ),
          _RosterMetric(
            label: 'Thu qua online',
            value: _deliveryMoney(report['onlineReceived']),
          ),
          _RosterMetric(
            label: 'COD đã xác nhận',
            value: _deliveryMoney(report['codReceived']),
          ),
          _RosterMetric(
            label: 'Doanh thu ghi nhận',
            value: _deliveryMoney(report['totalRecognizedRevenue']),
          ),
        ],
      ),
    ),
  );
}

class _CollectionRecordCard extends StatelessWidget {
  const _CollectionRecordCard({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final method = _deliveryId(record['paymentMethod']) == 0
        ? 'COD'
        : _deliveryId(record['paymentMethod']) == 2
        ? 'ZaloPay'
        : 'Chuyển khoản';
    final delivered = record['isDelivered'] == true;
    return Card(
      child: ExpansionTile(
        leading: Icon(
          method == 'COD'
              ? Icons.payments_outlined
              : Icons.account_balance_outlined,
        ),
        title: Text('${record['orderCode'] ?? 'Đơn hàng'} · $method'),
        subtitle: Text(
          '${record['customerName'] ?? 'Khách hàng'} · thu ${_deliveryDate(record['receivedAt'], withTime: true)}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _RosterMetric(
            label: 'Khách đã trả',
            value: _deliveryMoney(record['customerPaidAmount']),
          ),
          _RosterMetric(
            label: 'Phí giao',
            value: _deliveryMoney(record['shippingFee']),
          ),
          _RosterMetric(
            label: 'Thực thu vào quỹ',
            value: _deliveryMoney(record['fundAmount']),
          ),
          _RosterMetric(
            label: 'Doanh thu ghi nhận',
            value: _deliveryMoney(record['recognizedRevenue']),
          ),
          _RosterMetric(
            label: 'Giao hàng',
            value: delivered
                ? 'Đã giao ${_deliveryDate(record['deliveredAt'], withTime: true)}'
                : 'Chưa giao thành công',
          ),
          _RosterMetric(
            label: 'Shipper',
            value: '${record['shipperName'] ?? 'Chưa phân công'}',
          ),
          _RosterMetric(
            label: 'Điện thoại nhận',
            value: '${record['receiverPhone'] ?? '—'}',
          ),
        ],
      ),
    );
  }
}

class _DeliveryLoadError extends StatelessWidget {
  const _DeliveryLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
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
