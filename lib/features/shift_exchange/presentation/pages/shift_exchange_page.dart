import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../../../../domain/entities/employee.dart';
import '../../../../domain/entities/schedule.dart';
import '../../../../domain/entities/shift_assignment.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/shift_exchange_request.dart';
import '../../application/shift_transaction_schedule_projector.dart';
import '../controllers/shift_exchange_controller.dart';
import '../../infrastructure/shift_transaction_api_client.dart';
import '../widgets/shift_transaction_history_panel.dart';

/// Transaction workspace for personal and organization editions.
///
/// The server is authoritative for participant identity, consent, and
/// organization approval. This page never writes to Google Calendar.
class ShiftExchangePage extends StatefulWidget {
  const ShiftExchangePage({
    required this.schedule,
    this.organizationMode = true,
    this.controller,
    this.controllerFactory,
    this.historyApiClient,
    this.onTransactionsLoaded,
    this.accountId,
    super.key,
  });

  final Schedule schedule;
  final bool organizationMode;
  final ShiftExchangeController? controller;
  final ShiftExchangeController Function()? controllerFactory;
  final ShiftTransactionApiClient? historyApiClient;
  final ValueChanged<List<ShiftTransactionSnapshot>>? onTransactionsLoaded;
  final String? accountId;

  @override
  State<ShiftExchangePage> createState() => _ShiftExchangePageState();
}

class _ShiftExchangePageState extends State<ShiftExchangePage> {
  late final ShiftExchangeController controller =
      widget.controller ??
      widget.controllerFactory?.call() ??
      ShiftExchangeController();
  late final bool ownsController = widget.controller == null;

  bool _loadingDirectory = false;
  String? _directoryError;
  List<ShiftTransactionOrganizationSnapshot> _organizations = const [];
  List<ShiftTransactionOrganizationMemberSnapshot> _members = const [];
  List<ShiftTransactionSnapshot> _historyTransactions = const [];
  ShiftTransactionOrganizationSnapshot? _selectedOrganization;
  int _historyRevision = 0;

  void _handleTransactionsLoaded(List<ShiftTransactionSnapshot> items) {
    _historyTransactions = List.unmodifiable(items);
    _publishScopedTransactions();
  }

  void _publishScopedTransactions() {
    final scoped = widget.organizationMode
        ? _historyTransactions.where(
            (item) => item.organizationId == _selectedOrganization?.id,
          )
        : _historyTransactions.where((item) => item.organizationId == null);
    widget.onTransactionsLoaded?.call(List.unmodifiable(scoped));
  }

  Set<String> get _approvableOrganizationIds => {
    for (final organization in _organizations)
      if (organization.role == 'owner' || organization.role == 'admin')
        organization.id,
  };

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  @override
  void didUpdateWidget(covariant ShiftExchangePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.organizationMode != widget.organizationMode) {
      _organizations = const [];
      _members = const [];
      _historyTransactions = const [];
      _selectedOrganization = null;
      _directoryError = null;
      _loadingDirectory = false;
      _historyRevision++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onTransactionsLoaded?.call(const []);
        _loadDirectory();
      });
    }
  }

  @override
  void dispose() {
    if (ownsController) controller.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory() async {
    final api = widget.historyApiClient;
    if (api == null || !api.isConfigured) return;
    setState(() {
      _loadingDirectory = true;
      _directoryError = null;
    });
    try {
      if (widget.organizationMode) {
        final organizations = await api.listOrganizations();
        final selected = _selectedOrganization == null
            ? (organizations.isEmpty ? null : organizations.first)
            : _firstOrNull(organizations.where((item) => item.id == _selectedOrganization!.id));
        final members = selected == null
            ? <ShiftTransactionOrganizationMemberSnapshot>[]
            : await api.listOrganizationMembers(selected.id);
        if (!mounted) return;
        setState(() {
          _organizations = organizations;
          _selectedOrganization = selected;
          _members = members;
          _loadingDirectory = false;
        });
        _publishScopedTransactions();
      } else {
        await api.getCurrentUser();
        if (!mounted) return;
        setState(() => _loadingDirectory = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingDirectory = false;
        _directoryError = error is ShiftTransactionApiException
            ? error.message
            : 'Unable to load participant directory.';
      });
    }
  }

  Future<void> _selectOrganization(String id) async {
    final selected = _firstOrNull(_organizations.where((item) => item.id == id));
    if (selected == null) return;
    setState(() {
      _selectedOrganization = selected;
      _members = const [];
      _loadingDirectory = true;
      _directoryError = null;
    });
    _publishScopedTransactions();
    try {
      final members = await widget.historyApiClient!.listOrganizationMembers(id);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loadingDirectory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingDirectory = false;
        _directoryError = error is ShiftTransactionApiException
            ? error.message
            : 'Unable to load organization members.';
      });
    }
  }

  Future<void> _openComposer() async {
    final api = widget.historyApiClient;
    if (api == null || !api.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction API is not configured.')),
      );
      return;
    }
    if (_loadingDirectory) return;
    if (widget.organizationMode && _selectedOrganization == null) {
      await _loadDirectory();
      if (!mounted || _selectedOrganization == null) return;
    }
    final created = await showDialog<ShiftTransactionSnapshot>(
      context: context,
      builder: (_) => _ShiftTransactionComposerDialog(
        schedule: widget.schedule,
        apiClient: api,
        organizationMode: widget.organizationMode,
        organization: _selectedOrganization,
        members: _members,
      ),
    );
    if (created != null && mounted) {
      setState(() => _historyRevision++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction request saved to server history.')),
      );
    }
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
        if (widget.organizationMode && _organizations.length > 1)
          DropdownButtonFormField<String>(
            initialValue: _selectedOrganization?.id,
            decoration: const InputDecoration(
              labelText: 'Organization',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final organization in _organizations)
                DropdownMenuItem(
                  value: organization.id,
                  child: Text(organization.name),
                ),
            ],
            onChanged: (value) {
              if (value != null) _selectOrganization(value);
            },
          ),
        if (_loadingDirectory)
          const LinearProgressIndicator()
        else if (_directoryError != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(_directoryError!),
              trailing: TextButton(
                onPressed: _loadDirectory,
                child: const Text('Retry'),
              ),
            ),
          )
        else if (widget.organizationMode && _organizations.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.groups_outlined),
              title: Text('No active organization membership'),
              subtitle: Text('Join or create an organization before requesting an organization shift transaction.'),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _loadingDirectory ||
                    (widget.organizationMode && _selectedOrganization == null)
                ? null
                : _openComposer,
            icon: const Icon(Icons.add),
            label: const Text('New shift transaction'),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.historyApiClient != null)
          ShiftTransactionHistoryPanel(
            key: ValueKey('${widget.accountId}-${widget.organizationMode}-${_historyRevision}'),
            apiClient: widget.historyApiClient!,
            approvableOrganizationIds: _approvableOrganizationIds,
            mode: widget.organizationMode ? 'organization' : 'personal',
            onTransactionsLoaded: _handleTransactionsLoaded,
          ),
        const SizedBox(height: 16),
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

class _ShiftTransactionComposerDialog extends StatefulWidget {
  const _ShiftTransactionComposerDialog({
    required this.schedule,
    required this.apiClient,
    required this.organizationMode,
    required this.members,
    this.organization,
  });

  final Schedule schedule;
  final ShiftTransactionApiClient apiClient;
  final bool organizationMode;
  final ShiftTransactionOrganizationSnapshot? organization;
  final List<ShiftTransactionOrganizationMemberSnapshot> members;

  @override
  State<_ShiftTransactionComposerDialog> createState() =>
      _ShiftTransactionComposerDialogState();
}

class _ShiftTransactionComposerDialogState
    extends State<_ShiftTransactionComposerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _recipientEmail = TextEditingController();
  final _note = TextEditingController();
  String _type = 'give_up';
  String? _requesterEmployeeId;
  String? _recipientEmployeeId;
  String? _recipientUserId;
  String? _requesterShiftKey;
  String? _recipientShiftKey;
  bool _saving = false;
  String? _error;
  final String _requestNonce = DateTime.now().microsecondsSinceEpoch.toString();

  List<_RosterShiftChoice> get _allShifts {
    final result = <_RosterShiftChoice>[];
    for (final month in widget.schedule.months) {
      for (final day in month.days) {
        for (final assignment in day.assignments) {
          result.add(_RosterShiftChoice(
            date: day.date,
            employee: assignment.employee,
            assignment: assignment,
            scheduleId: widget.schedule.id,
          ));
        }
      }
    }
    result.sort((a, b) {
      final date = a.date.compareTo(b.date);
      if (date != 0) return date;
      final employee = a.employee.employeeCode.compareTo(b.employee.employeeCode);
      return employee != 0 ? employee : a.assignment.shift.code.compareTo(b.assignment.shift.code);
    });
    return result;
  }

  List<Employee> get _employees {
    final result = <String, Employee>{};
    for (final choice in _allShifts) {
      result[choice.employee.id] = choice.employee;
    }
    return result.values.toList()
      ..sort((a, b) => a.employeeCode.compareTo(b.employeeCode));
  }

  Employee? get _requesterRosterEmployee => widget.organizationMode
      ? _findRosterEmployee(widget.organization?.employeeId)
      : _firstOrNull(_employees.where((employee) => employee.id == _requesterEmployeeId));

  Employee? get _recipientRosterEmployee => widget.organizationMode
      ? _findRosterEmployee(_recipientEmployeeId)
      : _firstOrNull(_employees.where((employee) => employee.id == _recipientEmployeeId));

  String? _serverEmployeeId(Employee? employee) {
    if (employee == null) return null;
    final code = employee.employeeCode.trim();
    return code.isEmpty ? employee.id : code;
  }

  String? get _effectiveRequesterId => widget.organizationMode
      ? widget.organization?.employeeId
      : _serverEmployeeId(_requesterRosterEmployee);
  String? get _effectiveRecipientId => widget.organizationMode
      ? _recipientEmployeeId
      : _serverEmployeeId(_recipientRosterEmployee);

  Employee? _findRosterEmployee(String? membershipEmployeeId) {
    if (membershipEmployeeId == null || membershipEmployeeId.trim().isEmpty) {
      return null;
    }
    final matches = _employees
        .where((employee) => _matchesRosterId(employee, membershipEmployeeId))
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  List<_RosterShiftChoice> get _requesterShifts => _allShifts
      .where((choice) => choice.employee.id == _requesterRosterEmployee?.id)
      .toList();

  List<_RosterShiftChoice> get _recipientShifts => _allShifts
      .where((choice) => choice.employee.id == _recipientRosterEmployee?.id)
      .toList();

  @override
  void dispose() {
    _recipientEmail.dispose();
    _note.dispose();
    super.dispose();
  }

  String _choiceLabel(_RosterShiftChoice choice) =>
      '${_dateLabel(choice.date)} · ${choice.assignment.shift.code} · '
      '${choice.employee.displayName}';

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final requesterEmployee = _requesterRosterEmployee;
    final recipientEmployee = _recipientRosterEmployee;
    final requesterId = _effectiveRequesterId;
    final recipientId = _effectiveRecipientId;
    final requesterShift = _firstOrNull(_requesterShifts.where((item) => item.key == _requesterShiftKey));
    final recipientShift = _firstOrNull(_recipientShifts.where((item) => item.key == _recipientShiftKey));
    final requesterCodeMatches = requesterId == null
        ? 0
        : _employees.where((employee) => _matchesRosterId(employee, requesterId)).length;
    final recipientCodeMatches = recipientId == null
        ? 0
        : _employees.where((employee) => _matchesRosterId(employee, recipientId)).length;
    if (requesterEmployee == null || recipientEmployee == null ||
        requesterId == null || recipientId == null ||
        requesterEmployee.id == recipientEmployee.id ||
        requesterCodeMatches != 1 || recipientCodeMatches != 1 ||
        requesterShift == null ||
        (_type == 'exchange' && recipientShift == null)) {
      setState(() => _error = 'Roster employee codes must match exactly one active account or organization member, and both shifts must be valid.');
      return;
    }

    final participants = <Map<String, dynamic>>[
      {'employee_id': requesterId, 'role': 'requester'},
      {
        'employee_id': recipientId,
        'role': 'recipient',
        if (widget.organizationMode)
          'user_id': int.tryParse(_recipientUserId ?? ''),
        if (!widget.organizationMode)
          'email': _recipientEmail.text.trim().toLowerCase(),
      },
    ];
    if (widget.organizationMode && int.tryParse(_recipientUserId ?? '') == null) {
      setState(() => _error = 'The selected organization member has an invalid account ID.');
      return;
    }

    final transfers = <Map<String, dynamic>>[
      _transfer(
        requesterShift,
        fromEmployeeId: requesterId,
        toEmployeeId: recipientId,
        purpose: _type == 'give_up' ? 'give_up' : 'exchange',
      ),
      if (_type == 'exchange')
        _transfer(
          recipientShift!,
          fromEmployeeId: recipientId,
          toEmployeeId: requesterId,
          purpose: 'exchange',
        ),
    ];
    final idempotencySeed = [
      widget.schedule.id,
      _requestNonce,
      widget.organizationMode ? 'organization' : 'personal',
      widget.organization?.id ?? '',
      _type,
      requesterId,
      recipientId,
      _recipientEmail.text.trim().toLowerCase(),
      _note.text.trim(),
      ...transfers.map((item) => item['shift_id']),
    ].join('|');
    final idempotencyKey = sha256.convert(utf8.encode(idempotencySeed)).toString();

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await widget.apiClient.createTransaction(
        mode: widget.organizationMode ? 'organization' : 'personal',
        type: _type,
        participants: participants,
        transfers: transfers,
        idempotencyKey: idempotencyKey,
        organizationId: widget.organization?.id,
        metadata: {
          if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
          'schedule_id': widget.schedule.id,
        },
      );
      try {
        await widget.apiClient.confirmTransaction(created.id);
      } on ShiftTransactionApiException {
        // The request is durable; the requester can retry confirmation from history.
      }
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is ShiftTransactionApiException
            ? error.message
            : 'Unable to create the shift transaction.';
      });
    }
  }

  Map<String, dynamic> _transfer(
    _RosterShiftChoice choice, {
    required String fromEmployeeId,
    required String toEmployeeId,
    required String purpose,
  }) {
    final shift = choice.assignment.shift;
    final start = DateTime(
      choice.date.year,
      choice.date.month,
      choice.date.day,
    ).add(shift.startTime);
    var end = DateTime(
      choice.date.year,
      choice.date.month,
      choice.date.day,
    ).add(shift.endTime);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    final identity = ShiftAssignmentIdentity.create(
      scheduleId: widget.schedule.id,
      date: choice.date,
      employeeId: fromEmployeeId,
      shiftId: shift.id,
    );
    final transferKey = sha256.convert(utf8.encode('$identity|$purpose')).toString().substring(0, 32);
    return {
      'id': transferKey,
      'shift_id': identity,
      'from_employee_id': fromEmployeeId,
      'to_employee_id': toEmployeeId,
      'shift_code': shift.code,
      'starts_at': start.toUtc().toIso8601String(),
      'ends_at': end.toUtc().toIso8601String(),
      'purpose': purpose,
    };
  }

  @override
  Widget build(BuildContext context) {
    final requesterShifts = _requesterShifts;
    final recipientShifts = _recipientShifts;
    final recipientMembers = widget.members
        .where((member) => member.employeeId != widget.organization?.employeeId)
        .toList();

    return AlertDialog(
      title: Text(widget.organizationMode ? 'Organization shift request' : 'Personal shift request'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Transaction type'),
                  items: const [
                    DropdownMenuItem(value: 'give_up', child: Text('Give up a shift')),
                    DropdownMenuItem(value: 'exchange', child: Text('Exchange shifts')),
                  ],
                  onChanged: _saving ? null : (value) => setState(() {
                    _type = value ?? 'give_up';
                    _recipientShiftKey = null;
                  }),
                ),
                if (!widget.organizationMode) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _requesterEmployeeId,
                    decoration: const InputDecoration(labelText: 'Your name in this roster'),
                    items: [
                      for (final employee in _employees)
                        DropdownMenuItem(
                          value: employee.id,
                          child: Text('${employee.employeeCode} · ${employee.displayName}'),
                        ),
                    ],
                    onChanged: _saving ? null : (value) => setState(() {
                      _requesterEmployeeId = value;
                      _requesterShiftKey = null;
                    }),
                    validator: (value) => value == null ? 'Select your roster identity.' : null,
                  ),
                ] else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Requester: ${widget.organization?.employeeId ?? ''}'),
                    subtitle: Text(widget.organization?.name ?? ''),
                  ),
                const SizedBox(height: 12),
                if (widget.organizationMode)
                  DropdownButtonFormField<String>(
                    initialValue: _recipientUserId,
                    decoration: const InputDecoration(labelText: 'Recipient'),
                    items: [
                      for (final member in recipientMembers)
                        DropdownMenuItem(
                          value: member.userId,
                          child: Text('${member.employeeId} · ${member.name ?? member.email ?? member.userId}'),
                        ),
                    ],
                    onChanged: _saving ? null : (value) => setState(() {
                      _recipientUserId = value;
                      _recipientEmployeeId = _firstOrNull(recipientMembers.where((member) => member.userId == value))?.employeeId;
                      _recipientShiftKey = null;
                    }),
                    validator: (value) => value == null ? 'Select a recipient.' : null,
                  )
                else ...[
                  TextFormField(
                    controller: _recipientEmail,
                    decoration: const InputDecoration(
                      labelText: 'Recipient verified email',
                      hintText: 'colleague@example.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                        return 'Enter a valid recipient email.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _recipientEmployeeId,
                    decoration: const InputDecoration(labelText: 'Recipient roster name'),
                    items: [
                      for (final employee in _employees.where((item) => item.id != _requesterRosterEmployee?.id))
                        DropdownMenuItem(
                          value: employee.id,
                          child: Text('${employee.employeeCode} · ${employee.displayName}'),
                        ),
                    ],
                    onChanged: _saving ? null : (value) => setState(() {
                      _recipientEmployeeId = value;
                      _recipientShiftKey = null;
                    }),
                    validator: (value) => value == null ? 'Select recipient roster identity.' : null,
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _requesterShiftKey,
                  decoration: const InputDecoration(labelText: 'Your shift to transfer'),
                  items: [
                    for (final choice in requesterShifts)
                      DropdownMenuItem(
                        value: choice.key,
                        child: Text(_choiceLabel(choice)),
                      ),
                  ],
                  onChanged: _saving ? null : (value) => setState(() => _requesterShiftKey = value),
                  validator: (value) => value == null ? 'Select the shift you own.' : null,
                ),
                if (_type == 'exchange') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _recipientShiftKey,
                    decoration: const InputDecoration(labelText: 'Recipient shift to exchange'),
                    items: [
                      for (final choice in recipientShifts)
                        DropdownMenuItem(
                          value: choice.key,
                          child: Text(_choiceLabel(choice)),
                        ),
                    ],
                    onChanged: _saving ? null : (value) => setState(() => _recipientShiftKey = value),
                    validator: (value) => _type == 'exchange' && value == null
                        ? 'Select the recipient shift.'
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (requesterShifts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('No shifts found for the selected requester in the current roster.'),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create request'),
        ),
      ],
    );
  }
}

class _RosterShiftChoice {
  const _RosterShiftChoice({
    required this.date,
    required this.employee,
    required this.assignment,
    required this.scheduleId,
  });

  final DateTime date;
  final Employee employee;
  final ShiftAssignment assignment;
  final String scheduleId;

  String get key => ShiftAssignmentIdentity.create(
    scheduleId: scheduleId,
    date: date,
    employeeId: employee.id,
    shiftId: assignment.shift.id,
  );
}

bool _matchesRosterId(Employee employee, String employeeId) =>
    employee.id == employeeId ||
    employee.employeeCode == employeeId ||
    employee.displayName == employeeId;

T? _firstOrNull<T>(Iterable<T> values) {
  for (final value in values) {
    return value;
  }
  return null;
}
