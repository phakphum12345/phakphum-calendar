import 'package:flutter/material.dart';

import '../../infrastructure/shift_transaction_api_client.dart';

class ShiftTransactionHistoryPanel extends StatefulWidget {
  const ShiftTransactionHistoryPanel({
    required this.apiClient,
    this.approvableOrganizationIds = const {},
    this.onChanged,
    super.key,
  });

  final ShiftTransactionApiClient apiClient;
  final Set<String> approvableOrganizationIds;
  final VoidCallback? onChanged;

  @override
  State<ShiftTransactionHistoryPanel> createState() =>
      _ShiftTransactionHistoryPanelState();
}

class _ShiftTransactionHistoryPanelState
    extends State<ShiftTransactionHistoryPanel> {
  late Future<List<ShiftTransactionSnapshot>> _history;
  String? _actingOn;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _history = widget.apiClient.isConfigured
        ? _load()
        : Future<List<ShiftTransactionSnapshot>>.value(const []);
  }

  Future<List<ShiftTransactionSnapshot>> _load() =>
      widget.apiClient.listTransactions();

  void _reload() {
    if (!widget.apiClient.isConfigured) return;
    setState(() {
      _actionError = null;
      _history = _load();
    });
  }

  Future<void> _act(
    ShiftTransactionSnapshot transaction,
    String action,
  ) async {
    setState(() {
      _actingOn = transaction.id;
      _actionError = null;
    });
    try {
      switch (action) {
        case 'confirm':
          await widget.apiClient.confirmTransaction(transaction.id);
        case 'reject':
          await widget.apiClient.rejectTransaction(transaction.id);
        case 'approve':
          await widget.apiClient.approveTransaction(transaction.id);
        case 'reject_by_approver':
          await widget.apiClient.rejectByApprover(transaction.id);
      }
      if (!mounted) return;
      setState(() {
        _actingOn = null;
        _history = _load();
      });
      widget.onChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actingOn = null;
        _actionError = error is ShiftTransactionApiException
            ? error.message
            : 'Unable to update this transaction. Refresh and try again.';
      });
    }
  }

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
            if (_actionError != null) ...[
              const SizedBox(height: 8),
              MaterialBanner(
                content: Text(_actionError!),
                actions: [
                  TextButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ],
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
                          for (final participant in item.participants)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                participant['confirmed_at'] == null
                                    ? Icons.pending_outlined
                                    : Icons.check_circle_outline,
                              ),
                              title: Text(
                                '${participant['name'] ?? participant['employee_id'] ?? 'Participant'}'
                                ' · ${participant['role'] ?? ''}',
                              ),
                              subtitle: Text(
                                participant['confirmed_at'] == null
                                    ? 'Waiting for confirmation'
                                    : 'Confirmed ${participant['confirmed_at']}',
                              ),
                            ),
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
                          if (_canAct(item))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _actionButtons(item),
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

  bool _canAct(ShiftTransactionSnapshot item) {
    if (_actingOn == item.id) return false;
    if (['pending_response', 'partially_accepted'].contains(item.status)) {
      return item.participants.any(
        (participant) =>
            participant['is_current_user'] == true &&
            participant['confirmed_at'] == null,
      );
    }
    return item.status == 'pending_approval' &&
        item.organizationId != null &&
        widget.approvableOrganizationIds.contains(item.organizationId);
  }

  List<Widget> _actionButtons(ShiftTransactionSnapshot item) {
    if (['pending_response', 'partially_accepted'].contains(item.status)) {
      return [
        FilledButton.icon(
          onPressed: () => _act(item, 'confirm'),
          icon: const Icon(Icons.check),
          label: const Text('Confirm'),
        ),
        OutlinedButton.icon(
          onPressed: () => _act(item, 'reject'),
          icon: const Icon(Icons.close),
          label: const Text('Reject'),
        ),
      ];
    }
    return [
      FilledButton.icon(
        onPressed: () => _act(item, 'approve'),
        icon: const Icon(Icons.verified_outlined),
        label: const Text('Approve'),
      ),
      OutlinedButton.icon(
        onPressed: () => _act(item, 'reject_by_approver'),
        icon: const Icon(Icons.block_outlined),
        label: const Text('Reject'),
      ),
    ];
  }

  String _typeLabel(String type) => switch (type) {
    'give_up' => 'Give up',
    'exchange' => 'Exchange',
    'exchange_and_return' => 'Exchange + return',
    _ => type,
  };
}
