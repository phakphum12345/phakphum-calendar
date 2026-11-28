import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/core/result/result.dart';
import 'package:phakphum_calendar/domain/entities/department.dart';
import 'package:phakphum_calendar/domain/entities/employee.dart';
import 'package:phakphum_calendar/domain/entities/schedule.dart';
import 'package:phakphum_calendar/domain/entities/schedule_month.dart';
import 'package:phakphum_calendar/domain/entities/shift_type.dart';
import 'package:phakphum_calendar/domain/repositories/conditional_schedule_writer.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_repository.dart';
import 'package:phakphum_calendar/domain/repositories/schedule_revision_source.dart';
import 'package:phakphum_calendar/features/schedule_generation/application/schedule_generation_review_workflow.dart';
import 'package:phakphum_calendar/features/schedule_generation/domain/coverage_requirement.dart';
import 'package:phakphum_calendar/features/schedule_generation/domain/generation_request.dart';

class _MemoryScheduleRepository
    implements
        ScheduleRepository,
        ScheduleRevisionSource,
        ConditionalScheduleWriter {
  Schedule? value;
  int generation = 0;

  @override
  String? currentRevisionFor(String scheduleId) =>
      value?.id == scheduleId ? 'revision-$generation' : 'absent:$scheduleId';

  @override
  String? revisionForSnapshot(Schedule schedule) =>
      identical(value, schedule) ? 'revision-$generation' : null;

  @override
  String? revisionForAbsentSchedule(String scheduleId) =>
      value == null ? 'absent:$scheduleId' : null;

  @override
  Future<Result<Schedule?>> findById(String id) async =>
      Success(value?.id == id ? value : null);

  @override
  Future<Result<ScheduleMonth?>> loadMonth(
    String scheduleId,
    DateTime month,
  ) async =>
      Success(value?.id == scheduleId ? value?.month(month) : null);

  @override
  Future<Result<Schedule>> save(Schedule schedule) async {
    value = schedule;
    generation++;
    return Success(schedule);
  }

  @override
  Future<Result<Schedule>> saveIfRevision(
    Schedule schedule,
    String expectedRevision,
  ) async {
    if (currentRevisionFor(schedule.id) != expectedRevision) {
      return const ValidationFailure('Schedule revision conflict.');
    }
    value = schedule;
    generation++;
    return Success(schedule);
  }

  @override
  Future<Result<void>> delete(String id) async {
    if (value?.id == id) value = null;
    generation++;
    return const Success(null);
  }
}

void main() {
  const scheduleId = 'generation-review-schedule';
  final generatedAt = DateTime.utc(2026, 11, 27, 10);
  final approvedAt = DateTime.utc(2026, 11, 27, 10, 5);
  final committedAt = DateTime.utc(2026, 11, 27, 10, 6);

  late _MemoryScheduleRepository repository;
  late ScheduleGenerationReviewWorkflow workflow;
  late Schedule source;
  late Employee employee;
  late ShiftType shift;

  setUp(() {
    source = Schedule(id: scheduleId, name: 'November roster');
    repository = _MemoryScheduleRepository()
      ..value = source
      ..generation = 1;
    workflow = ScheduleGenerationReviewWorkflow(
      scheduleRepository: repository,
      revisionSource: repository,
      conditionalWriter: repository,
    );
    final department = Department(
      id: 'department-1',
      code: 'OPD',
      name: 'Outpatient',
    );
    employee = Employee(
      id: 'employee-1',
      employeeCode: 'E001',
      firstName: 'Test',
      lastName: 'Employee',
      nickname: '',
      department: department,
      position: 'Nurse',
    );
    shift = const ShiftType(
      id: 'shift-1',
      code: 'AM',
      name: 'Morning',
      color: 0xff336699,
      startTime: Duration(hours: 8),
      endTime: Duration(hours: 16),
      workingHours: 8,
    );
  });

  GenerationRequest request({List<Employee>? employees}) => GenerationRequest(
    schedule: source,
    month: DateTime(2026, 11),
    employees: employees ?? [employee],
    shiftTypes: [shift],
    coverageRequirements: [
      CoverageRequirement(
        id: 'coverage-1',
        date: DateTime(2026, 11, 27),
        departmentId: employee.department.id,
        shiftTypeId: shift.id,
        requiredEmployees: 1,
      ),
    ],
  );

  Future<ScheduleGenerationPreview> createPreview({
    GenerationRequest? generationRequest,
  }) async {
    final result = await workflow.preview(
      request: generationRequest ?? request(),
      runId: 'generation-run-1',
      employeeDirectoryRevision: 'employees-v1',
      shiftCatalogRevision: 'shifts-v1',
      policyVersion: 'policy-v1',
      generatedAtUtc: generatedAt,
    );
    expect(result, isA<Success<ScheduleGenerationPreview>>());
    return (result as Success<ScheduleGenerationPreview>).value;
  }

  ScheduleGenerationApproval approve(ScheduleGenerationPreview preview) {
    final result = workflow.approve(
      preview: preview,
      approverId: 'owner-1',
      approvedAtUtc: approvedAt,
    );
    expect(result, isA<Success<ScheduleGenerationApproval>>());
    return (result as Success<ScheduleGenerationApproval>).value;
  }

  test('preview is immutable and does not write the canonical Schedule', () async {
    final preview = await createPreview();

    expect(preview.completed, isTrue);
    expect(preview.assignmentsCreated, 1);
    expect(preview.operations, hasLength(1));
    expect(preview.operations.single.employeeId, employee.id);
    expect(preview.operations.single.shiftTypeId, shift.id);
    expect(preview.sourceRevision, 'revision-1');
    expect(repository.value, same(source));
    expect(workflow.scheduleFingerprint(repository.value!), preview.sourceScheduleFingerprint);
    expect(workflow.scheduleFingerprint(preview.candidateSchedule), preview.candidateFingerprint);
  });

  test('commit requires exact approval and performs conditional write plus read-back', () async {
    final preview = await createPreview();
    final approval = approve(preview);

    final result = await workflow.commit(
      preview: preview,
      approval: approval,
      currentRequest: request(),
      currentEmployeeDirectoryRevision: 'employees-v1',
      currentShiftCatalogRevision: 'shifts-v1',
      currentPolicyVersion: 'policy-v1',
      committedAtUtc: committedAt,
    );

    expect(result, isA<Success<ScheduleGenerationCommitReceipt>>());
    final receipt = (result as Success<ScheduleGenerationCommitReceipt>).value;
    expect(receipt.runId, preview.runId);
    expect(receipt.assignmentsCreated, 1);
    expect(receipt.sourceRevision, 'revision-1');
    expect(receipt.resultingRevision, 'revision-2');
    expect(
      workflow.scheduleFingerprint(receipt.schedule),
      preview.candidateFingerprint,
    );
    expect(repository.value?.month(DateTime(2026, 11))?.day(DateTime(2026, 11, 27))?.assignments, hasLength(1));
  });

  test('stale Schedule revision is rejected without overwriting newer data', () async {
    final preview = await createPreview();
    final approval = approve(preview);
    final newer = source.copyWith(name: 'Newer roster revision');
    await repository.save(newer);

    final result = await workflow.commit(
      preview: preview,
      approval: approval,
      currentRequest: request(),
      currentEmployeeDirectoryRevision: 'employees-v1',
      currentShiftCatalogRevision: 'shifts-v1',
      currentPolicyVersion: 'policy-v1',
      committedAtUtc: committedAt,
    );

    expect(result, isA<ValidationFailure<ScheduleGenerationCommitReceipt>>());
    expect(repository.value?.name, 'Newer roster revision');
    expect(repository.value?.months, isEmpty);
  });

  test('directory, catalog or policy changes invalidate approval', () async {
    final preview = await createPreview();
    final approval = approve(preview);

    final result = await workflow.commit(
      preview: preview,
      approval: approval,
      currentRequest: request(),
      currentEmployeeDirectoryRevision: 'employees-v2',
      currentShiftCatalogRevision: 'shifts-v1',
      currentPolicyVersion: 'policy-v1',
      committedAtUtc: committedAt,
    );

    expect(result, isA<ValidationFailure<ScheduleGenerationCommitReceipt>>());
    expect(repository.value, same(source));
  });

  test('incomplete generation cannot be approved or committed', () async {
    final preview = await createPreview(
      generationRequest: request(employees: const []),
    );

    expect(preview.completed, isFalse);
    final approval = workflow.approve(
      preview: preview,
      approverId: 'owner-1',
      approvedAtUtc: approvedAt,
    );
    expect(approval, isA<ValidationFailure<ScheduleGenerationApproval>>());
    expect(repository.value, same(source));
  });

  test('approval from another candidate cannot authorize this preview', () async {
    final preview = await createPreview();
    final approval = approve(preview);
    final mismatched = ScheduleGenerationApproval(
      runId: approval.runId,
      scheduleId: approval.scheduleId,
      sourceRevision: approval.sourceRevision,
      sourceScheduleFingerprint: approval.sourceScheduleFingerprint,
      inputFingerprint: approval.inputFingerprint,
      candidateFingerprint: 'different-candidate',
      employeeDirectoryRevision: approval.employeeDirectoryRevision,
      shiftCatalogRevision: approval.shiftCatalogRevision,
      policyVersion: approval.policyVersion,
      approverId: approval.approverId,
      approvedAtUtc: approval.approvedAtUtc,
    );

    final result = await workflow.commit(
      preview: preview,
      approval: mismatched,
      currentRequest: request(),
      currentEmployeeDirectoryRevision: 'employees-v1',
      currentShiftCatalogRevision: 'shifts-v1',
      currentPolicyVersion: 'policy-v1',
      committedAtUtc: committedAt,
    );

    expect(result, isA<ValidationFailure<ScheduleGenerationCommitReceipt>>());
    expect(repository.value, same(source));
  });
}
