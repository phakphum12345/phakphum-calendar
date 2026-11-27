import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/result/result.dart';
import '../../../domain/entities/schedule.dart';
import '../../../domain/entities/shift_assignment.dart';
import '../../../domain/repositories/conditional_schedule_writer.dart';
import '../../../domain/repositories/schedule_repository.dart';
import '../../../domain/repositories/schedule_revision_source.dart';
import '../../schedule/data/schedule_json_codec.dart';
import '../domain/coverage_requirement.dart';
import '../domain/generation_request.dart';
import '../domain/schedule_conflict.dart';
import '../domain/generation_result.dart';
import 'schedule_generator.dart';

/// One immutable proposed assignment added by a generation run.
class GeneratedAssignmentOperation {
  const GeneratedAssignmentOperation({
    required this.date,
    required this.employeeId,
    required this.shiftTypeId,
    this.location,
    this.remark,
  });

  final DateTime date;
  final String employeeId;
  final String shiftTypeId;
  final String? location;
  final String? remark;
}

/// Read-only output of a generation run, bound to its source revision and
/// every input version that influenced candidate selection.
class ScheduleGenerationPreview {
  ScheduleGenerationPreview({
    required this.runId,
    required this.scheduleId,
    required this.sourceRevision,
    required this.sourceScheduleFingerprint,
    required this.inputFingerprint,
    required this.candidateFingerprint,
    required this.employeeDirectoryRevision,
    required this.shiftCatalogRevision,
    required this.policyVersion,
    required this.generatedAtUtc,
    required this.candidateSchedule,
    required this.assignmentsCreated,
    required List<GeneratedAssignmentOperation> operations,
    required List<ScheduleConflict> conflicts,
    required List<CoverageRequirement> uncoveredRequirements,
  }) : operations = List.unmodifiable(operations),
       conflicts = List.unmodifiable(conflicts),
       uncoveredRequirements = List.unmodifiable(uncoveredRequirements);

  final String runId;
  final String scheduleId;
  final String sourceRevision;
  final String sourceScheduleFingerprint;
  final String inputFingerprint;
  final String candidateFingerprint;
  final String employeeDirectoryRevision;
  final String shiftCatalogRevision;
  final String policyVersion;
  final DateTime generatedAtUtc;
  final Schedule candidateSchedule;
  final int assignmentsCreated;
  final List<GeneratedAssignmentOperation> operations;
  final List<ScheduleConflict> conflicts;
  final List<CoverageRequirement> uncoveredRequirements;

  bool get completed =>
      uncoveredRequirements.isEmpty &&
      !conflicts.any(
        (conflict) => conflict.severity == ScheduleConflictSeverity.error,
      );
}

/// Explicit approval for exactly one immutable generation preview.
class ScheduleGenerationApproval {
  const ScheduleGenerationApproval({
    required this.runId,
    required this.scheduleId,
    required this.sourceRevision,
    required this.sourceScheduleFingerprint,
    required this.inputFingerprint,
    required this.candidateFingerprint,
    required this.employeeDirectoryRevision,
    required this.shiftCatalogRevision,
    required this.policyVersion,
    required this.approverId,
    required this.approvedAtUtc,
  });

  final String runId;
  final String scheduleId;
  final String sourceRevision;
  final String sourceScheduleFingerprint;
  final String inputFingerprint;
  final String candidateFingerprint;
  final String employeeDirectoryRevision;
  final String shiftCatalogRevision;
  final String policyVersion;
  final String approverId;
  final DateTime approvedAtUtc;
}

class ScheduleGenerationCommitReceipt {
  const ScheduleGenerationCommitReceipt({
    required this.runId,
    required this.schedule,
    required this.sourceRevision,
    required this.resultingRevision,
    required this.candidateFingerprint,
    required this.assignmentsCreated,
    required this.committedAtUtc,
  });

  final String runId;
  final Schedule schedule;
  final String sourceRevision;
  final String? resultingRevision;
  final String candidateFingerprint;
  final int assignmentsCreated;
  final DateTime committedAtUtc;
}

/// Review, approval and conditional commit boundary for automatic generation.
///
/// Preview never writes. Commit requires an approval for the exact preview,
/// unchanged directory/catalog/policy versions, a fresh source revision, a
/// deterministic re-run that produces the same candidate, atomic CAS, and a
/// read-back fingerprint check.
class ScheduleGenerationReviewWorkflow {
  const ScheduleGenerationReviewWorkflow({
    required this.scheduleRepository,
    required this.revisionSource,
    required this.conditionalWriter,
    this.generator = const ScheduleGenerator(),
    this.scheduleCodec = const ScheduleJsonCodec(),
  });

  final ScheduleRepository scheduleRepository;
  final ScheduleRevisionSource revisionSource;
  final ConditionalScheduleWriter conditionalWriter;
  final ScheduleGenerator generator;
  final ScheduleJsonCodec scheduleCodec;

  Future<Result<ScheduleGenerationPreview>> preview({
    required GenerationRequest request,
    required String runId,
    required String employeeDirectoryRevision,
    required String shiftCatalogRevision,
    required String policyVersion,
    required DateTime generatedAtUtc,
  }) async {
    if (runId.trim().isEmpty ||
        employeeDirectoryRevision.trim().isEmpty ||
        shiftCatalogRevision.trim().isEmpty ||
        policyVersion.trim().isEmpty ||
        !generatedAtUtc.isUtc) {
      return const ValidationFailure(
        'Generation run ID, input revisions, policy version and UTC timestamp are required.',
      );
    }
    if (request.schedule.id.trim().isEmpty) {
      return const ValidationFailure('A target Schedule ID is required.');
    }

    final loaded = await scheduleRepository.findById(request.schedule.id);
    if (loaded case Failure<Schedule?>()) {
      return _copyFailure<Schedule?, ScheduleGenerationPreview>(loaded);
    }
    final current = (loaded as Success<Schedule?>).value;
    final sourceRevision = current == null
        ? revisionSource.revisionForAbsentSchedule(request.schedule.id)
        : revisionSource.revisionForSnapshot(current);
    if (sourceRevision == null || sourceRevision.isEmpty) {
      return const ValidationFailure(
        'The Schedule repository did not provide a revision bound to the loaded snapshot.',
      );
    }

    final sourceSchedule = current ?? request.schedule;
    final sourceFingerprint = scheduleFingerprint(sourceSchedule);
    if (scheduleFingerprint(request.schedule) != sourceFingerprint) {
      return const ValidationFailure(
        'Generation request is based on a stale Schedule snapshot.',
      );
    }

    try {
      final result = generator.autoAssign(request);
      final candidateFingerprint = scheduleFingerprint(result.schedule);
      final inputFingerprint = _inputFingerprint(
        request: request,
        sourceScheduleFingerprint: sourceFingerprint,
        employeeDirectoryRevision: employeeDirectoryRevision,
        shiftCatalogRevision: shiftCatalogRevision,
        policyVersion: policyVersion,
      );
      return Success(
        ScheduleGenerationPreview(
          runId: runId,
          scheduleId: request.schedule.id,
          sourceRevision: sourceRevision,
          sourceScheduleFingerprint: sourceFingerprint,
          inputFingerprint: inputFingerprint,
          candidateFingerprint: candidateFingerprint,
          employeeDirectoryRevision: employeeDirectoryRevision,
          shiftCatalogRevision: shiftCatalogRevision,
          policyVersion: policyVersion,
          generatedAtUtc: generatedAtUtc,
          candidateSchedule: result.schedule,
          assignmentsCreated: result.assignmentsCreated,
          operations: _operations(sourceSchedule, result.schedule),
          conflicts: result.conflicts,
          uncoveredRequirements: result.uncoveredRequirements,
        ),
      );
    } on Object catch (error, stackTrace) {
      return ValidationFailure(
        'Could not generate a Schedule preview.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Result<ScheduleGenerationApproval> approve({
    required ScheduleGenerationPreview preview,
    required String approverId,
    required DateTime approvedAtUtc,
  }) {
    if (approverId.trim().isEmpty || !approvedAtUtc.isUtc) {
      return const ValidationFailure(
        'An approver identity and UTC approval timestamp are required.',
      );
    }
    if (!preview.completed) {
      return const ValidationFailure(
        'Generation cannot be approved while conflicts or uncovered requirements remain.',
      );
    }
    if (preview.operations.isEmpty || preview.assignmentsCreated == 0) {
      return const ValidationFailure(
        'Generation preview contains no new assignments to commit.',
      );
    }
    return Success(
      ScheduleGenerationApproval(
        runId: preview.runId,
        scheduleId: preview.scheduleId,
        sourceRevision: preview.sourceRevision,
        sourceScheduleFingerprint: preview.sourceScheduleFingerprint,
        inputFingerprint: preview.inputFingerprint,
        candidateFingerprint: preview.candidateFingerprint,
        employeeDirectoryRevision: preview.employeeDirectoryRevision,
        shiftCatalogRevision: preview.shiftCatalogRevision,
        policyVersion: preview.policyVersion,
        approverId: approverId,
        approvedAtUtc: approvedAtUtc,
      ),
    );
  }

  Future<Result<ScheduleGenerationCommitReceipt>> commit({
    required ScheduleGenerationPreview preview,
    required ScheduleGenerationApproval approval,
    required GenerationRequest currentRequest,
    required String currentEmployeeDirectoryRevision,
    required String currentShiftCatalogRevision,
    required String currentPolicyVersion,
    required DateTime committedAtUtc,
  }) async {
    if (!committedAtUtc.isUtc) {
      return const ValidationFailure(
        'Generation commit timestamp must be UTC.',
      );
    }
    if (!_approvalMatches(preview, approval)) {
      return const ValidationFailure(
        'Approval does not match this exact generation preview.',
      );
    }
    if (!preview.completed || preview.operations.isEmpty) {
      return const ValidationFailure(
        'Only a complete preview with proposed assignments can be committed.',
      );
    }
    if (currentEmployeeDirectoryRevision !=
            preview.employeeDirectoryRevision ||
        currentShiftCatalogRevision != preview.shiftCatalogRevision ||
        currentPolicyVersion != preview.policyVersion) {
      return const ValidationFailure(
        'Employee directory, shift catalog or policy changed after preview. Generate and review a new preview.',
      );
    }
    if (currentRequest.schedule.id != preview.scheduleId ||
        scheduleFingerprint(currentRequest.schedule) !=
            preview.sourceScheduleFingerprint) {
      return const ValidationFailure(
        'Current generation request no longer matches the approved source Schedule.',
      );
    }

    final inputFingerprint = _inputFingerprint(
      request: currentRequest,
      sourceScheduleFingerprint: preview.sourceScheduleFingerprint,
      employeeDirectoryRevision: currentEmployeeDirectoryRevision,
      shiftCatalogRevision: currentShiftCatalogRevision,
      policyVersion: currentPolicyVersion,
    );
    if (inputFingerprint != preview.inputFingerprint) {
      return const ValidationFailure(
        'Generation inputs changed after approval. Review a new preview.',
      );
    }

    final loaded = await scheduleRepository.findById(preview.scheduleId);
    if (loaded case Failure<Schedule?>()) {
      return _copyFailure<Schedule?, ScheduleGenerationCommitReceipt>(loaded);
    }
    final current = (loaded as Success<Schedule?>).value;
    final liveRevision = current == null
        ? revisionSource.revisionForAbsentSchedule(preview.scheduleId)
        : revisionSource.revisionForSnapshot(current);
    if (liveRevision != preview.sourceRevision) {
      return const ValidationFailure(
        'Schedule revision changed after preview. No generated assignments were written.',
      );
    }
    if (current != null &&
        scheduleFingerprint(current) != preview.sourceScheduleFingerprint) {
      return const ValidationFailure(
        'Canonical Schedule content changed after preview.',
      );
    }

    try {
      final regenerated = generator.autoAssign(currentRequest);
      final regeneratedFingerprint = scheduleFingerprint(regenerated.schedule);
      if (!regenerated.completed ||
          regeneratedFingerprint != preview.candidateFingerprint) {
        return const ValidationFailure(
          'Revalidated generation candidate differs from the approved preview.',
        );
      }

      final saved = await conditionalWriter.saveIfRevision(
        regenerated.schedule,
        preview.sourceRevision,
      );
      if (saved case Failure<Schedule>()) {
        return _copyFailure<Schedule, ScheduleGenerationCommitReceipt>(saved);
      }

      final readBack = await scheduleRepository.findById(preview.scheduleId);
      if (readBack case Failure<Schedule?>()) {
        return _copyFailure<Schedule?, ScheduleGenerationCommitReceipt>(
          readBack,
        );
      }
      final persisted = (readBack as Success<Schedule?>).value;
      if (persisted == null ||
          scheduleFingerprint(persisted) != preview.candidateFingerprint) {
        return const ValidationFailure(
          'Generation write could not be verified by read-back.',
        );
      }

      return Success(
        ScheduleGenerationCommitReceipt(
          runId: preview.runId,
          schedule: persisted,
          sourceRevision: preview.sourceRevision,
          resultingRevision: revisionSource.revisionForSnapshot(persisted),
          candidateFingerprint: preview.candidateFingerprint,
          assignmentsCreated: preview.assignmentsCreated,
          committedAtUtc: committedAtUtc,
        ),
      );
    } on Object catch (error, stackTrace) {
      return ValidationFailure(
        'Could not commit the approved Schedule generation.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  String scheduleFingerprint(Schedule schedule) =>
      sha256.convert(utf8.encode(scheduleCodec.encode(schedule))).toString();

  bool _approvalMatches(
    ScheduleGenerationPreview preview,
    ScheduleGenerationApproval approval,
  ) =>
      approval.runId == preview.runId &&
      approval.scheduleId == preview.scheduleId &&
      approval.sourceRevision == preview.sourceRevision &&
      approval.sourceScheduleFingerprint == preview.sourceScheduleFingerprint &&
      approval.inputFingerprint == preview.inputFingerprint &&
      approval.candidateFingerprint == preview.candidateFingerprint &&
      approval.employeeDirectoryRevision ==
          preview.employeeDirectoryRevision &&
      approval.shiftCatalogRevision == preview.shiftCatalogRevision &&
      approval.policyVersion == preview.policyVersion;

  String _inputFingerprint({
    required GenerationRequest request,
    required String sourceScheduleFingerprint,
    required String employeeDirectoryRevision,
    required String shiftCatalogRevision,
    required String policyVersion,
  }) {
    final payload = <String, Object?>{
      'schedule_id': request.schedule.id,
      'source_schedule_fingerprint': sourceScheduleFingerprint,
      'month': _dateKey(request.month),
      'employee_directory_revision': employeeDirectoryRevision,
      'shift_catalog_revision': shiftCatalogRevision,
      'policy_version': policyVersion,
      'employees': [
        for (final employee in request.employees)
          <String, Object?>{
            'id': employee.id,
            'employee_code': employee.employeeCode,
            'first_name': employee.firstName,
            'last_name': employee.lastName,
            'nickname': employee.nickname,
            'department_id': employee.department.id,
            'department_code': employee.department.code,
            'department_name': employee.department.name,
            'position': employee.position,
            'active': employee.active,
          },
      ],
      'shift_types': [
        for (final shift in request.shiftTypes)
          <String, Object?>{
            'id': shift.id,
            'code': shift.code,
            'name': shift.name,
            'start_minutes': shift.startTime.inMinutes,
            'end_minutes': shift.endTime.inMinutes,
            'working_hours': shift.workingHours,
          },
      ],
      'coverage_requirements': [
        for (final item in request.coverageRequirements)
          <String, Object?>{
            'id': item.id,
            'date': _dateKey(item.date),
            'department_id': item.departmentId,
            'shift_type_id': item.shiftTypeId,
            'required_employees': item.requiredEmployees,
            'location': item.location,
          },
      ],
      'availability': [
        for (final item in request.availability)
          <String, Object?>{
            'employee_id': item.employeeId,
            'date': _dateKey(item.date),
            'available': item.available,
            'shift_type_ids': item.shiftTypeIds.toList()..sort(),
          },
      ],
      'department_capacities': [
        for (final item in request.departmentCapacities)
          <String, Object?>{
            'department_id': item.departmentId,
            'date': _dateKey(item.date),
            'maximum_assignments': item.maximumAssignments,
          },
      ],
      'locked_duty_points': Map.fromEntries(
        request.lockedDutyPointsByEmployeeId.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key)),
      ),
    };
    return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
  }

  List<GeneratedAssignmentOperation> _operations(
    Schedule source,
    Schedule candidate,
  ) {
    final operations = <GeneratedAssignmentOperation>[];
    for (final month in candidate.months) {
      for (final day in month.days) {
        final unmatched = List<ShiftAssignment>.from(
          source.month(day.date)?.day(day.date)?.assignments ??
              const <ShiftAssignment>[],
        );
        for (final assignment in day.assignments) {
          final existingIndex = unmatched.indexOf(assignment);
          if (existingIndex >= 0) {
            unmatched.removeAt(existingIndex);
            continue;
          }
          operations.add(
            GeneratedAssignmentOperation(
              date: day.date,
              employeeId: assignment.employee.id,
              shiftTypeId: assignment.shift.id,
              location: assignment.location,
              remark: assignment.remark,
            ),
          );
        }
      }
    }
    return List.unmodifiable(operations);
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

Result<TTarget> _copyFailure<TSource, TTarget>(
  Result<TSource> result,
) {
  final failure = result as Failure<TSource>;
  return switch (failure) {
    ValidationFailure<TSource>() => ValidationFailure(
      failure.message,
      fieldErrors: failure.fieldErrors,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
    NetworkFailure<TSource>() => NetworkFailure(
      failure.message,
      statusCode: failure.statusCode,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
    ImportFailure<TSource>() => ImportFailure(
      failure.message,
      rowNumber: failure.rowNumber,
      column: failure.column,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
    PersistenceFailure<TSource>() => PersistenceFailure(
      failure.message,
      cause: failure.cause,
      stackTrace: failure.stackTrace,
    ),
  };
}
