import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';

Map<String, dynamic> _notificationMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return {};
}

List<Map<String, dynamic>> _notificationList(dynamic value) => value is List
    ? value.whereType<Map>().map(_notificationMap).toList()
    : <Map<String, dynamic>>[];

String _notificationDate(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  return date == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(date);
}

class CustomerNotificationsPage extends StatefulWidget {
  const CustomerNotificationsPage({required this.state, super.key});

  final AppState state;

  @override
  State<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState extends State<CustomerNotificationsPage> {
  List<Map<String, dynamic>> _vouchers = [];
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
      final response = _notificationMap(
        await widget.state.api.get('Notification/customer-vouchers'),
      );
      _vouchers = _notificationList(response['vouchers']);
    } on ApiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = 'Không thể tải thông báo voucher: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Thông báo voucher'),
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
        ? _NotificationError(message: _error!, onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.local_activity_outlined),
                    title: Text(
                      _vouchers.isEmpty
                          ? 'Hiện chưa có voucher khả dụng.'
                          : 'Có ${_vouchers.length} voucher ưu đãi dành cho bạn.',
                    ),
                    subtitle: const Text(
                      'Danh sách được cập nhật từ chương trình đang có hiệu lực.',
                    ),
                  ),
                ),
                for (final voucher in _vouchers)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.confirmation_number_outlined),
                      ),
                      title: Text('${voucher['name'] ?? 'Voucher mới'}'),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mã voucher: ${voucher['code'] ?? '—'}'),
                            if (voucher['minimumOrderValue'] != null)
                              Text(
                                'Đơn tối thiểu: ${_notificationMoney(voucher['minimumOrderValue'])}',
                              ),
                            Text(
                              'Hạn dùng: ${_notificationDate(voucher['endDate'])}',
                            ),
                            if (voucher['remainingUses'] != null)
                              Text('Còn ${voucher['remainingUses']} lượt'),
                          ],
                        ),
                      ),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ),
          ),
  );
}

class StaffNotificationsPage extends StatefulWidget {
  const StaffNotificationsPage({required this.state, super.key});

  final AppState state;

  @override
  State<StaffNotificationsPage> createState() => _StaffNotificationsPageState();
}

class _StaffNotificationsPageState extends State<StaffNotificationsPage> {
  final Set<String> _knownNotifications = {};
  List<Map<String, dynamic>> _notifications = [];
  String? _error;
  bool _loading = true;
  bool _hasLoaded = false;
  bool _requestInProgress = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _load(showNew: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _key(Map<String, dynamic> item) =>
      '${item['type']}:${item['referenceId']}:${item['createdAt']}';

  Future<void> _load({bool showNew = false}) async {
    if (_requestInProgress) return;
    _requestInProgress = true;
    if (!_hasLoaded && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = _notificationMap(
        await widget.state.api.get('Notification/staff'),
      );
      final latest = _notificationList(response['notifications']);
      final newItems = latest
          .where((item) => !_knownNotifications.contains(_key(item)))
          .toList();
      _knownNotifications.addAll(latest.map(_key));
      if (_knownNotifications.length > 200) {
        _knownNotifications
          ..clear()
          ..addAll(latest.map(_key));
      }
      if (!mounted) return;
      setState(() {
        _notifications = latest;
        _error = null;
        _loading = false;
        _hasLoaded = true;
      });
      if (showNew && newItems.isNotEmpty) {
        final item = newItems.first;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '${item['title'] ?? 'Thông báo mới'}: ${item['message'] ?? ''}',
              ),
            ),
          );
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
          _hasLoaded = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải thông báo nhân viên: $error';
          _loading = false;
          _hasLoaded = true;
        });
      }
    } finally {
      _requestInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Thông báo hệ thống'),
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: _requestInProgress ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _notifications.isEmpty
        ? _NotificationError(message: _error!, onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Biến động cửa hàng trong 7 ngày gần đây'),
                    subtitle: Text(
                      'Tự cập nhật mỗi 10 giây. API hiện chỉ cung cấp thông báo hệ thống, chưa hỗ trợ gửi thông báo thủ công.',
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Không thể làm mới: $_error',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (_notifications.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.notifications_none),
                      title: Text('Chưa có biến động trong 7 ngày gần đây.'),
                    ),
                  )
                else
                  for (final item in _notifications)
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.notifications_active_outlined),
                        ),
                        title: Text('${item['title'] ?? 'Thông báo'}'),
                        subtitle: Text(
                          '${item['message'] ?? ''}\n${_notificationDate(item['createdAt'])}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
              ],
            ),
          ),
  );
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}

String _notificationMoney(dynamic value) {
  final amount = value is num ? value : num.tryParse('$value') ?? 0;
  return NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(amount);
}
