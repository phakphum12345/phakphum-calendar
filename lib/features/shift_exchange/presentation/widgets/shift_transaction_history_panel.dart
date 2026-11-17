import 'package:flutter/material.dart';

import '../../infrastructure/shift_transaction_api_client.dart';

class ShiftTransactionHistoryPanel extends StatefulWidget {
  const ShiftTransactionHistoryPanel({
    required this.apiClient,
    super.key,
  });

  final ShiftTransactionApiClient apiClient;

  @override
  State<ShiftTransactionHistoryPanel> createState() =>
      _ShiftTransactionHistoryPanelState();
}

class _ShiftTransactionHistoryPanelState
    extends State<ShiftTransactionHistoryPanel> {
  late Future<List<ShiftTransactionSnapshot>> _history;

  @override
  void initState() {
    super.initState();
    _history = _load();
  }

  Future<List<ShiftTransactionSnapshot>> _load() =>
      widget.apiClient.listTransactions();

  void _reload() => setState(() => _history = _load());

  @override
  Widget build(BuildContext context) {
    if (!widget.apiClient.isConfigured) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.cloud_off_outlined),
          title: Text('Transaction history is not configured'),
          subtitle: Text('Set ORGANIZATION_API_BASE_URL to enable server history.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Server transaction history',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh history',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<ShiftTransactionSnapshot>>(
              future: _history,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final message = error is ShiftTransactionApiException
                      ? error.message
                      : 'Unable to load transaction history.';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.error_outline),
                    title: Text(message),
                    trailing: TextButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  );
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.history),
                    title: Text('No server transactions yet'),
                  );
                }
                return Column(
                  children: [
                    for (final item in items)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        leading: const Icon(Icons.swap_horiz),
                        title: Text('${_typeLabel(item.type)} · ${item.status}'),
                        subtitle: Text(
                          '${item.createdAt.toLocal()} · ${item.mode} · v${item.version}',
                        ),
                        children: [
                          for (final transfer in item.transfers)
                            ListTile(
                              dense: true,
                              title: Text(
                                '${transfer['shift_code'] ?? 'Shift'} · '
                                '${transfer['from_employee_id'] ?? '?'} → '
                                '${transfer['to_employee_id'] ?? '?'}',
                              ),
                              subtitle: Text(
                                '${transfer['starts_at'] ?? ''} – '
                                '${transfer['ends_at'] ?? ''}',
                              ),
                            ),
                          const Divider(),
                          for (final event in item.timeline)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.history, size: 18),
                              title: Text(event['event_type']?.toString() ?? 'Event'),
                              subtitle: Text(
                                '${event['actor_name'] ?? 'System'} · '
                                '${event['occurred_at'] ?? ''}',
                              ),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
    'give_up' => 'Give up',
    'exchange' => 'Exchange',
    'exchange_and_return' => 'Exchange + return',
    _ => type,
  };
}
