import 'package:googleapis_auth/googleapis_auth.dart' as auth;

import '../../calendar_engine/application/calendar_sync_plan_builder.dart';
import '../../calendar_engine/application/resilient_calendar_sync_executor.dart';
import '../../calendar_engine/infrastructure/google_calendar_sync_gateway.dart';
import '../../history/domain/sync_history_repository.dart';
import '../../history/infrastructure/in_memory_sync_history_repository.dart';
import '../../rules/application/schedule_validation_service.dart';
import 'calendar_sync_coordinator.dart';
import 'shift_calendar_workflow_controller.dart';
import 'workflow_preview_builder.dart';

/// ประกอบ dependency ของระบบ Shift Calendar Workflow
///
/// รับ [auth.AuthClient] ที่ได้รับสิทธิ์ Google Calendar แล้ว
/// และคืน controller ที่พร้อมทำ Preview และ Synchronize
class CalendarWorkflowFactory {
  const CalendarWorkflowFactory._();

  static ShiftCalendarWorkflowController create({
    required auth.AuthClient client,
    SyncHistoryRepository? historyRepository,
    int maxAttempts = 2,
    String? Function(String key)? messageProvider,
  }) {
    final repository = historyRepository ?? InMemorySyncHistoryRepository();

    final gateway = GoogleCalendarSyncGateway(client);

    final executor = ResilientCalendarSyncExecutor(
      gateway: gateway,
      historyRepository: repository,
      maxAttempts: maxAttempts,
    );

    final coordinator = CalendarSyncCoordinator(
      gateway: gateway,
      planBuilder: const CalendarSyncPlanBuilder(),
      executor: executor,
    );

    return ShiftCalendarWorkflowController(
      previewBuilder: const WorkflowPreviewBuilder(),
      syncCoordinator: coordinator,
      validationService: ScheduleValidationService(),
      messageProvider: messageProvider,
    );
  }
}
