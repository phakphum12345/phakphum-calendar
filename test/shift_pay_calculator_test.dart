import 'package:flutter_test/flutter_test.dart';
import 'package:phakphum_calendar/domain/services/shift_pay_calculator.dart';

void main() {
  group('WorkDayPolicy', () {
    const policy = WorkDayPolicy(weeklyDaysOff: {6, 7});

    test('classifies weekdays and recurring days off separately', () {
      expect(
        policy.classify(DateTime(2026, 10, 26)),
        WorkDayCategory.regularWeekday,
      );
      expect(
        policy.classify(DateTime(2026, 10, 25)),
        WorkDayCategory.weeklyDayOff,
      );
    });

    test('explicit holiday or festival overrides recurring day off', () {
      expect(
        policy.classify(
          DateTime(2026, 10, 25),
          dateOverrides: {
            '2026-10-25': WorkDayCategory.festival,
          },
        ),
        WorkDayCategory.festival,
      );
    });
  });

  group('ShiftPayCalculator', () {
    const calculator = ShiftPayCalculator(
      workDayPolicy: WorkDayPolicy(weeklyDaysOff: {6, 7}),
    );

    test('salary-covered regular morning shift has zero additional pay', () {
      final result = calculator.calculate(
        input: ShiftPayInput(
          date: DateTime(2026, 10, 26),
          employmentType: EmploymentType.salaried,
          shiftTypeId: 'morning',
          hours: 8,
          department: 'Radiology',
          location: 'Building A',
        ),
        rules: const [
          ShiftPayRule(
            id: 'salary-morning',
            employmentType: EmploymentType.salaried,
            dayCategory: WorkDayCategory.regularWeekday,
            shiftTypeId: 'morning',
            salaryIncluded: true,
          ),
        ],
      );

      expect(result.hasRule, isTrue);
      expect(result.isCoveredBySalary, isTrue);
      expect(result.amount, 0);
    });

    test('daily-paid holiday night shift uses configured hourly rate', () {
      final result = calculator.calculate(
        input: ShiftPayInput(
          date: DateTime(2026, 10, 26),
          employmentType: EmploymentType.dailyPaid,
          shiftTypeId: 'night',
          hours: 10,
        ),
        rules: const [
          ShiftPayRule(
            id: 'daily-holiday-night',
            employmentType: EmploymentType.dailyPaid,
            dayCategory: WorkDayCategory.officialHoliday,
            shiftTypeId: 'night',
            hourlyRate: 120,
            multiplier: 1.5,
          ),
        ],
        dateOverrides: {
          '2026-10-26': WorkDayCategory.officialHoliday,
        },
      );

      expect(result.dayCategory, WorkDayCategory.officialHoliday);
      expect(result.amount, 1800);
    });

    test('department-specific rule overrides the general rule', () {
      final result = calculator.calculate(
        input: ShiftPayInput(
          date: DateTime(2026, 10, 26),
          employmentType: EmploymentType.dailyPaid,
          shiftTypeId: 'afternoon',
          hours: 8,
          department: 'Emergency',
        ),
        rules: const [
          ShiftPayRule(
            id: 'general',
            employmentType: EmploymentType.dailyPaid,
            dayCategory: WorkDayCategory.regularWeekday,
            shiftTypeId: 'afternoon',
            fixedAmount: 500,
          ),
          ShiftPayRule(
            id: 'emergency-specific',
            employmentType: EmploymentType.dailyPaid,
            dayCategory: WorkDayCategory.regularWeekday,
            shiftTypeId: 'afternoon',
            department: 'Emergency',
            fixedAmount: 800,
          ),
        ],
      );

      expect(result.rule?.id, 'emergency-specific');
      expect(result.amount, 800);
    });


    test('weekday night shift can compensate for morning work without extra pay', () {
      final result = calculator.calculate(
        input: ShiftPayInput(
          date: DateTime(2026, 10, 26), // Monday
          employmentType: EmploymentType.salaried,
          shiftTypeId: 'night',
          hours: 8,
          department: 'Radiology',
        ),
        rules: const [
          ShiftPayRule(
            id: 'night-replaces-morning',
            employmentType: EmploymentType.salaried,
            dayCategory: WorkDayCategory.regularWeekday,
            shiftTypeId: 'night',
            treatment: ShiftPayTreatment.compensatoryTime,
            compensatesShiftTypeId: 'morning',
            compensatoryWeekdays: {1, 2, 3, 4, 5},
          ),
        ],
      );

      expect(result.hasRule, isTrue);
      expect(result.amount, 0);
      expect(result.isCoveredBySalary, isFalse);
      expect(result.isCompensatoryTime, isTrue);
      expect(result.compensatesShiftTypeId, 'morning');
    });

    test('compensatory shift rule only applies on configured weekdays', () {
      final result = calculator.calculate(
        input: ShiftPayInput(
          date: DateTime(2026, 10, 31), // Saturday
          employmentType: EmploymentType.salaried,
          shiftTypeId: 'night',
          hours: 8,
        ),
        rules: const [
          ShiftPayRule(
            id: 'weekday-night-replacement',
            employmentType: EmploymentType.salaried,
            dayCategory: WorkDayCategory.weeklyDayOff,
            shiftTypeId: 'night',
            treatment: ShiftPayTreatment.compensatoryTime,
            compensatesShiftTypeId: 'morning',
            compensatoryWeekdays: {1, 2, 3, 4, 5},
          ),
        ],
      );

      expect(result.hasRule, isFalse);
      expect(result.amount, isNull);
    });

    test('missing rule is reported as unconfigured, not unpaid', () {
      final result = calculator.calculate(
        input: ShiftPayInput(
          date: DateTime(2026, 10, 26),
          employmentType: EmploymentType.salaried,
          shiftTypeId: 'night',
          hours: 8,
        ),
        rules: const [],
      );

      expect(result.hasRule, isFalse);
      expect(result.amount, isNull);
    });
  });
}
