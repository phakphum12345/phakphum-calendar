import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/schedule.dart';
import '../entities/schedule_day.dart';
import '../entities/shift_assignment.dart';
import 'shift_pay_calculator.dart';
import 'shift_pay_profile.dart';

enum ShiftPayStatementLineStatus {
  notConfirmed,
  employmentTypeRequired,
  duplicateAssignment,
  sourceSelectionRequired,
  ambiguousRule,
  noMatchingRule,
  includedInSalary,
  compensatoryTime,
  payable,
  invalidRule,
}

typedef ShiftAssignmentConfirmation = bool Function(
  ScheduleDay day,
  ShiftAssignment assignment,
);

typedef ShiftEmploymentTypeResolver = EmploymentType? Function(
  ShiftAssignment assignment,
);

typedef ShiftPaySourceResolver = ShiftPayRuleSource? Function(
  ScheduleDay day,
  ShiftAssignment assignment,
);

/// Immutable, reproducible payroll-period calculation snapshot.
///
/// Only assignments accepted by [isConfirmed] are payable candidates. The
/// caller must supply the exact Schedule revision and employee employment-type
/// resolver; the builder never guesses either value from a display name.
class ShiftPayStatementBuilder {
  const ShiftPayStatementBuilder({
    this.calculator = const ShiftPayCalculator(),
  });

  final ShiftPayCalculator calculator;

  ShiftPayStatement build({
    required String statementId,
    required Schedule schedule,
    required String scheduleRevision,
    required ShiftPayProfile profile,
    required DateTime periodStart,
    required DateTime periodEnd,
    required DateTime generatedAtUtc,
    required ShiftAssignmentConfirmation isConfirmed,
    required ShiftEmploymentTypeResolver employmentTypeFor,
    Map<String, WorkDayCategory> dateOverrides = const {},
    ShiftPaySourceResolver? selectedSourceFor,
  }) {
    if (statementId.trim().isEmpty) {
      throw ArgumentError.value(statementId, 'statementId');
    }
    if (scheduleRevision.trim().isEmpty) {
      throw ArgumentError.value(scheduleRevision, 'scheduleRevision');
    }
    final start = _calendarDate(periodStart);
    final end = _calendarDate(periodEnd);
    if (_dateOrdinal(start) > _dateOrdinal(end)) {
      throw ArgumentError('periodStart must not be after periodEnd.');
    }
    if (!generatedAtUtc.isUtc) {
      throw ArgumentError.value(
        generatedAtUtc,
        'generatedAtUtc',
        'must be UTC',
      );
    }

    final profileFingerprint = _fingerprintProfile(profile);
    final seenAssignments = <String>{};
    final lines = <ShiftPayStatementLine>[];
    for (final month in schedule.months) {
      for (final day in month.days) {
        final date = _calendarDate(day.date);
        final ordinal = _dateOrdinal(date);
        if (ordinal < _dateOrdinal(start) || ordinal > _dateOrdinal(end)) {
          continue;
        }
        for (final assignment in day.assignments) {
          final key = _assignmentKey(schedule.id, date, assignment);
          if (!isConfirmed(day, assignment)) {
            lines.add(
              ShiftPayStatementLine(
                assignmentKey: key,
                date: date,
                employeeId: assignment.employee.id,
                employeeName: assignment.employee.displayName,
                departmentId: assignment.employee.department.id,
                shiftTypeId: assignment.shift.id,
                shiftCode: assignment.shift.code,
                location: assignment.location,
                hours: assignment.shift.workingHours,
                status: ShiftPayStatementLineStatus.notConfirmed,
                amount: null,
                source: null,
                ruleId: null,
                conflictingRuleIds: const [],
              ),
            );
            continue;
          }
          if (!seenAssignments.add(key)) {
            lines.add(
              ShiftPayStatementLine(
                assignmentKey: key,
                date: date,
                employeeId: assignment.employee.id,
                employeeName: assignment.employee.displayName,
                departmentId: assignment.employee.department.id,
                shiftTypeId: assignment.shift.id,
                shiftCode: assignment.shift.code,
                location: assignment.location,
                hours: assignment.shift.workingHours,
                status: ShiftPayStatementLineStatus.duplicateAssignment,
                amount: null,
                source: null,
                ruleId: null,
                conflictingRuleIds: const [],
              ),
            );
            continue;
          }

          final employmentType = employmentTypeFor(assignment);
          if (employmentType == null) {
            lines.add(
              ShiftPayStatementLine(
                assignmentKey: key,
                date: date,
                employeeId: assignment.employee.id,
                employeeName: assignment.employee.displayName,
                departmentId: assignment.employee.department.id,
                shiftTypeId: assignment.shift.id,
                shiftCode: assignment.shift.code,
                location: assignment.location,
                hours: assignment.shift.workingHours,
                status: ShiftPayStatementLineStatus.employmentTypeRequired,
                amount: null,
                source: null,
                ruleId: null,
                conflictingRuleIds: const [],
              ),
            );
            continue;
          }

          final resolved = profile.resolve(
            calculator: calculator,
            input: ShiftPayInput(
              date: date,
              employmentType: employmentType,
              shiftTypeId: assignment.shift.id,
              hours: assignment.shift.workingHours,
              department: assignment.employee.department.id,
              location: assignment.location,
            ),
            dateOverrides: dateOverrides,
            selectedSource: selectedSourceFor?.call(day, assignment),
          );
          final calculation = resolved.calculation;
          final status = _statusFor(resolved);
          lines.add(
            ShiftPayStatementLine(
              assignmentKey: key,
              date: date,
              employeeId: assignment.employee.id,
              employeeName: assignment.employee.displayName,
              departmentId: assignment.employee.department.id,
              shiftTypeId: assignment.shift.id,
              shiftCode: assignment.shift.code,
              location: assignment.location,
              hours: assignment.shift.workingHours,
              status: status,
              amount: calculation.amount,
              source: resolved.source,
              ruleId: calculation.rule?.id,
              conflictingRuleIds: calculation.conflictingRuleIds,
              dayCategory: calculation.dayCategory,
              isCoveredBySalary: calculation.isCoveredBySalary,
              isCompensatoryTime: calculation.isCompensatoryTime,
              compensatesShiftTypeId: calculation.compensatesShiftTypeId,
            ),
          );
        }
      }
    }

    lines.sort((left, right) {
      final dateOrder = _dateOrdinal(left.date).compareTo(
        _dateOrdinal(right.date),
      );
      if (dateOrder != 0) return dateOrder;
      final employeeOrder = left.employeeId.compareTo(right.employeeId);
      if (employeeOrder != 0) return employeeOrder;
      return left.assignmentKey.compareTo(right.assignmentKey);
    });

    final scale = _decimalScale(profile.decimalPlaces);
    var totalMinorUnits = 0;
    for (final line in lines) {
      if (line.status == ShiftPayStatementLineStatus.payable &&
          line.amount != null) {
        totalMinorUnits += (line.amount! * scale).round();
      }
    }

    return ShiftPayStatement(
      statementId: statementId,
      scheduleId: schedule.id,
      scheduleRevision: scheduleRevision,
      profileId: profile.id,
      profileFingerprint: profileFingerprint,
      periodStart: start,
      periodEnd: end,
      generatedAtUtc: generatedAtUtc,
      currencyCode: profile.currencyCode,
      decimalPlaces: profile.decimalPlaces,
      totalMinorUnits: totalMinorUnits,
      lines: List.unmodifiable(lines),
    );
  }

  ShiftPayStatementLineStatus _statusFor(
    ShiftPayResolvedCalculation resolved,
  ) {
    if (resolved.sourceSelectionRequired) {
      return ShiftPayStatementLineStatus.sourceSelectionRequired;
    }
    final calculation = resolved.calculation;
    if (calculation.hasRuleConflict) {
      return ShiftPayStatementLineStatus.ambiguousRule;
    }
    if (!calculation.hasRule) {
      return ShiftPayStatementLineStatus.noMatchingRule;
    }
    if (calculation.isCoveredBySalary) {
      return ShiftPayStatementLineStatus.includedInSalary;
    }
    if (calculation.isCompensatoryTime) {
      return ShiftPayStatementLineStatus.compensatoryTime;
    }
    if (calculation.amount == null) {
      return ShiftPayStatementLineStatus.invalidRule;
    }
    return ShiftPayStatementLineStatus.payable;
  }

  String _assignmentKey(
    String scheduleId,
    DateTime date,
    ShiftAssignment assignment,
  ) {
    final source = [
      scheduleId,
      _dateKey(date),
      assignment.employee.id,
      assignment.shift.id,
      assignment.location ?? '',
    ].join('|');
    return sha256.convert(utf8.encode(source)).toString();
  }

  String _fingerprintProfile(ShiftPayProfile profile) {
    final entries = profile.rules.map((entry) {
      final rule = entry.rule;
      return <String, Object?>{
        'source': entry.source.name,
        'organizationId': entry.organizationId,
        'id': rule.id,
        'employmentType': rule.employmentType.name,
        'dayCategory': rule.dayCategory.name,
        'shiftTypeId': rule.shiftTypeId,
        'department': rule.department,
        'location': rule.location,
        'workPoint': rule.workPoint,
        'assignmentPurpose': rule.assignmentPurpose.name,
        'payComponent': rule.payComponent.name,
        'salaryIncluded': rule.salaryIncluded,
        'treatment': rule.treatment.name,
        'compensatesShiftTypeId': rule.compensatesShiftTypeId,
        'compensatoryWeekdays': rule.compensatoryWeekdays.toList()..sort(),
        'fixedAmount': rule.fixedAmount,
        'hourlyRate': rule.hourlyRate,
        'multiplier': rule.multiplier,
        'active': rule.active,
      };
    }).toList()
      ..sort((left, right) {
        final leftKey = [
          left['source'],
          left['organizationId'] ?? '',
          left['id'],
        ].join('|');
        final rightKey = [
          right['source'],
          right['organizationId'] ?? '',
          right['id'],
        ].join('|');
        return leftKey.compareTo(rightKey);
      });
    final canonical = <String, Object?>{
      'id': profile.id,
      'mode': profile.mode.name,
      'organizationId': profile.organizationId,
      'hybridPriority': profile.hybridPriority.name,
      'currencyCode': profile.currencyCode,
      'decimalPlaces': profile.decimalPlaces,
      'organizationDecimalPlaces': profile.organizationDecimalPlaces,
      'rules': entries,
    };
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  DateTime _calendarDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  int _dateOrdinal(DateTime value) =>
      value.year * 10000 + value.month * 100 + value.day;

  String _dateKey(DateTime value) =>
      value.year.toString().padLeft(4, '0') +
      '-' +
      value.month.toString().padLeft(2, '0') +
      '-' +
      value.day.toString().padLeft(2, '0');

  int _decimalScale(int places) => switch (places) {
    0 => 1,
    1 => 10,
    2 => 100,
    3 => 1000,
    4 => 10000,
    _ => throw ArgumentError.value(places, 'decimalPlaces'),
  };
}

class ShiftPayStatementLine {
  const ShiftPayStatementLine({
    required this.assignmentKey,
    required this.date,
    required this.employeeId,
    required this.employeeName,
    required this.departmentId,
    required this.shiftTypeId,
    required this.shiftCode,
    required this.location,
    required this.hours,
    required this.status,
    required this.amount,
    required this.source,
    required this.ruleId,
    required this.conflictingRuleIds,
    this.dayCategory,
    this.isCoveredBySalary = false,
    this.isCompensatoryTime = false,
    this.compensatesShiftTypeId,
  });

  final String assignmentKey;
  final DateTime date;
  final String employeeId;
  final String employeeName;
  final String departmentId;
  final String shiftTypeId;
  final String shiftCode;
  final String? location;
  final double hours;
  final ShiftPayStatementLineStatus status;
  final double? amount;
  final ShiftPayRuleSource? source;
  final String? ruleId;
  final List<String> conflictingRuleIds;
  final WorkDayCategory? dayCategory;
  final bool isCoveredBySalary;
  final bool isCompensatoryTime;
  final String? compensatesShiftTypeId;
}

class ShiftPayStatement {
  ShiftPayStatement({
    required this.statementId,
    required this.scheduleId,
    required this.scheduleRevision,
    required this.profileId,
    required this.profileFingerprint,
    required this.periodStart,
    required this.periodEnd,
    required this.generatedAtUtc,
    required this.currencyCode,
    required this.decimalPlaces,
    required this.totalMinorUnits,
    required Iterable<ShiftPayStatementLine> lines,
  }) : lines = List.unmodifiable(lines);

  final String statementId;
  final String scheduleId;
  final String scheduleRevision;
  final String profileId;
  final String profileFingerprint;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime generatedAtUtc;
  final String currencyCode;
  final int decimalPlaces;
  final int totalMinorUnits;
  final List<ShiftPayStatementLine> lines;

  int get payableCount => lines
      .where((line) => line.status == ShiftPayStatementLineStatus.payable)
      .length;

  int get unresolvedCount => lines
      .where((line) => {
            ShiftPayStatementLineStatus.employmentTypeRequired,
            ShiftPayStatementLineStatus.sourceSelectionRequired,
            ShiftPayStatementLineStatus.ambiguousRule,
            ShiftPayStatementLineStatus.noMatchingRule,
            ShiftPayStatementLineStatus.invalidRule,
            ShiftPayStatementLineStatus.duplicateAssignment,
          }.contains(line.status))
      .length;

  double get totalAmount => totalMinorUnits / switch (decimalPlaces) {
    0 => 1,
    1 => 10,
    2 => 100,
    3 => 1000,
    4 => 10000,
    _ => throw ArgumentError.value(decimalPlaces, 'decimalPlaces'),
  };
}
