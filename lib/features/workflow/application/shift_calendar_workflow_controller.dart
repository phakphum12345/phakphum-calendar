import 'package:flutter/foundation.dart';

import '../../../core/state/controller_state.dart';
import '../../../domain/entities/schedule.dart';
import '../../calendar_engine/application/resilient_calendar_sync_executor.dart';
import '../../calendar_engine/application/resume_sync_service.dart';
import '../../diff_engine/domain/calendar_event_candidate.dart';
import '../../relationship_engine/domain/user_shift_change.dart';
import '../../rules/application/schedule_validation_service.dart';
import '../../rules/domain/rule_result.dart';
import '../domain/workflow_preview.dart';
import 'calendar_sync_coordinator.dart';
import 'workflow_preview_builder.dart';

class ShiftCalendarWorkflowController extends ChangeNotifier
    implements ControllerState {
  ShiftCalendarWorkflowController({
    required this._previewBuilder,
    required this._syncCoordinator,
    required this.validationService,
    this.resumeSyncService,
    this.onDispose,
    String? Function(String key)? messageProvider,
  }) : _messageProvider = messageProvider ?? _defaultMessageProvider;

  final WorkflowPreviewBuilder _previewBuilder;
  final CalendarSyncCoordinator _syncCoordinator;
  final ScheduleValidationService validationService;
  final ResumeSyncService? resumeSyncService;
  final VoidCallback? onDispose;
  final String? Function(String key) _messageProvider;

  static String? _defaultMessageProvider(String key) => const {
    'workflowScheduleFailedValidation':
        'ตารางเวรไม่ผ่านการตรวจสอบ จึงยังไม่สามารถซิงก์ได้',
    'workflowReadyToConfirm': 'พร้อมยืนยันการซิงก์',
    'workflowWarningsBeforeConfirm':
        'พบคำเตือน กรุณาตรวจสอบก่อนยืนยันการซิงก์',
    'workflowCalendarCheckFailed': 'ตรวจสอบ Google Calendar ไม่สำเร็จ',
    'workflowNoValidatedPlan': 'ยังไม่มีแผนที่ผ่านการตรวจสอบสำหรับซิงก์',
    'workflowNoValidationResult': 'ยังไม่มีผลการตรวจสอบสำหรับซิงก์',
    'workflowItemsStillBlocked':
        'ยังมีรายการที่ถูกบล็อก กรุณาตรวจสอบก่อนซิงก์',
    'workflowSyncPartialSuccess': 'ซิงก์สำเร็จบางส่วน กรุณาตรวจสอบประวัติ',
    'workflowSyncSuccessful': 'ซิงก์ Google Calendar สำเร็จ',
    'workflowSyncFailed':
        'ซิงก์ไม่สำเร็จ กรุณาตรวจสอบอินเทอร์เน็ตและสิทธิ์ Google',
  }[key];

  WorkflowPreview? _preview;
  bool _isBusy = false;
  String? _message;
  ResilientCalendarSyncResult? _lastResult;
  RuleResult? _validationResult;
  CalendarSyncPreparation? _schedulePreparation;
  Schedule? _schedule;

  WorkflowPreview? get preview => _preview;
  bool get isBusy => _isBusy;
  @override
  String? get message => _message;
  ResilientCalendarSyncResult? get lastResult => _lastResult;
  RuleResult? get validationResult => _validationResult;
  CalendarSyncPreparation? get schedulePreparation => _schedulePreparation;
  Schedule? get schedule => _schedule;
  bool get hasBlockingFailures =>
      _validationResult != null && _validationResult!.errors.isNotEmpty;
  bool get requiresConfirmation =>
      _schedulePreparation != null && !hasBlockingFailures;

  @override
  bool get loading => _isBusy;

  @override
  Object? get error =>
      _message != null && (_lastResult == null || _lastResult!.hasFailures)
      ? _message
      : null;

  @override
  bool get success => _lastResult != null && !_lastResult!.hasFailures;

  void preparePreview({
    required List<UserShiftChange> changes,
    required List<CalendarEventCandidate> existing,
  }) {
    _preview = _previewBuilder.build(changes: changes, existing: existing);
    _message = null;
    notifyListeners();
  }

  /// Prepares a compatibility preview from pre-mapped event candidates.
  Future<void> prepareCandidatePreview({
    required List<CalendarEventCandidate> desired,
    String calendarId = 'primary',
  }) async {
    _isBusy = true;
    _message = null;
    notifyListeners();
    try {
      final existing = await _syncCoordinator.listExistingCandidates(
        desired,
        calendarId: calendarId,
      );
      _preview = _previewBuilder.buildCandidates(
        desired: desired,
        existing: existing,
      );
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Validates and compares one canonical schedule before confirmation.
  Future<void> prepareSchedule(
    Schedule schedule, {
    String calendarId = 'primary',
  }) async {
    _isBusy = true;
    _message = null;
    _lastResult = null;
    _schedule = schedule;
    _schedulePreparation = null;
    notifyListeners();
    try {
      _validationResult = validationService.validateSchedule(schedule);
      if (hasBlockingFailures) {
        _message = _messageProvider('workflowScheduleFailedValidation');
        return;
      }
      _schedulePreparation = await _syncCoordinator.prepareSchedule(
        schedule,
        calendarId: calendarId,
      );
      _message = _validationResult!.warnings.isEmpty
          ? _messageProvider('workflowReadyToConfirm')
          : _messageProvider('workflowWarningsBeforeConfirm');
    } catch (_) {
      _message = _messageProvider('workflowCalendarCheckFailed');
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> synchronize({String calendarId = 'primary'}) async {
    final schedulePreparation = _schedulePreparation;
    if (_schedule != null) {
      if (hasBlockingFailures || schedulePreparation == null) {
        _message = _messageProvider('workflowNoValidatedPlan');
        notifyListeners();
        return;
      }
      await _executeSchedulePreparation(schedulePreparation);
      return;
    }
    final current = _preview;
    if (current == null) {
      _message = _messageProvider('workflowNoValidationResult');
      notifyListeners();
      return;
    }
    if (!current.simulation.summary.canSynchronize) {
      _message = _messageProvider('workflowItemsStillBlocked');
      notifyListeners();
      return;
    }

    _isBusy = true;
    _message = null;
    notifyListeners();

    try {
      _lastResult = await _syncCoordinator.synchronize(
        diff: current.diff,
        timeMin: current.timeMin,
        timeMax: current.timeMax,
        calendarId: calendarId,
      );
      _message = _lastResult!.hasFailures
          ? _messageProvider('workflowSyncPartialSuccess')
          : _messageProvider('workflowSyncSuccessful');
    } catch (_) {
      _message = _messageProvider('workflowSyncFailed');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _executeSchedulePreparation(
    CalendarSyncPreparation preparation,
  ) async {
    _isBusy = true;
    _message = null;
    notifyListeners();
    try {
      _lastResult = await _syncCoordinator.execute(preparation);
      _message = _lastResult!.hasFailures
          ? _messageProvider('workflowSyncPartialSuccess')
          : _messageProvider('workflowSyncSuccessful');
    } catch (_) {
      _message = _messageProvider('workflowSyncFailed');
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Resumes failed operations recorded by the resilient executor.
  Future<ResumeSyncResult> resume(String historyId) {
    final service = resumeSyncService;
    if (service == null) {
      throw StateError('Resume synchronization is not configured.');
    }
    return service.resume(historyId);
  }

  @override
  void dispose() {
    onDispose?.call();
    super.dispose();
  }
}
