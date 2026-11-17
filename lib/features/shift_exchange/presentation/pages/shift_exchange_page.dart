import 'package:flutter/material.dart';

import '../../../../domain/entities/schedule.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/shift_exchange_request.dart';
import '../controllers/shift_exchange_controller.dart';
import '../../infrastructure/shift_transaction_api_client.dart';
import '../widgets/shift_transaction_history_panel.dart';

/// Top-level exchange workspace for SCE navigation.
///
/// Phase 1 exposes request inspection and status filtering. Mutation remains
/// behind the existing exchange service so the UI cannot bypass approval.
class ShiftExchangePage extends StatefulWidget {
  const ShiftExchangePage({
    required this.schedule,
    this.controller,
    this.controllerFactory,
    this.historyApiClient,
    super.key,
  });

  final Schedule schedule;
  final ShiftExchangeController? controller;
  final ShiftExchangeController Function()? controllerFactory;
  final ShiftTransactionApiClient? historyApiClient;

  @override
  State<ShiftExchangePage> createState() => _ShiftExchangePageState();
}

class _ShiftExchangePageState extends State<ShiftExchangePage> {
  late final ShiftExchangeController controller =
      widget.controller ??
      widget.controllerFactory?.call() ??
      ShiftExchangeController();
  late final bool ownsController = widget.controller == null;

  @override
  void dispose() {
    if (ownsController) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          context.l10n.shiftExchange,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(context.l10n.shiftExchangeDescription),
        const SizedBox(height: 16),
        if (widget.historyApiClient != null) ...[
          ShiftTransactionHistoryPanel(apiClient: widget.historyApiClient!),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              selected: controller.status == null,
              onSelected: (_) => controller.updateStatus(null),
              label: Text(context.l10n.all),
            ),
            for (final status in ShiftExchangeStatus.values)
              ChoiceChip(
                selected: controller.status == status,
                onSelected: (_) => controller.updateStatus(status),
                label: Text(_statusLabel(context, status)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (controller.requests.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.swap_horiz_outlined, size: 52),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.noExchangeRequests,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.exchangeApprovalBoundary,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final request in controller.requests)
                  ListTile(
                    leading: const Icon(Icons.swap_calls_outlined),
                    title: Text(
                      '${request.requesterId} → ${request.targetStaffId}',
                    ),
                    subtitle: Text(request.note ?? request.id),
                    trailing: Chip(
                      label: Text(_statusLabel(context, request.status)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );

  String _statusLabel(BuildContext context, ShiftExchangeStatus status) =>
      switch (status) {
        ShiftExchangeStatus.pending => context.l10n.pending,
        ShiftExchangeStatus.approved => context.l10n.approved,
        ShiftExchangeStatus.rejected => context.l10n.rejected,
        ShiftExchangeStatus.cancelled => context.l10n.cancelled,
      };
}
