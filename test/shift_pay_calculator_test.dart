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
            shiftPeriod: ShiftPeriod.morning,
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
            shiftPeriod: ShiftPeriod.night,
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
            shiftPeriod: ShiftPeriod.afternoon,
            fixedAmount: 500,
          ),
          ShiftPayRule(
            id: 'emergency-specific',
            employmentType: EmploymentType.dailyPaid,
            dayCategory: WorkDayCategory.regularWeekday,
            shiftPeriod: ShiftPeriod.afternoon,
            department: 'Emergency',
            fixedAmount: 800,
          ),
        ],
      );

      expect(result.rule?.id, 'emergency-specific');
      expect(result.amount, 800);
    });

    test('missing rule is reported as unconfigured, not unpaid', () {
      final result = calculator.calculate(
        input: ShiftPayInput(
          date: DateTime(2026, 10, 26),
          employmentType: EmploymentType.salaried,
          shiftPeriod: ShiftPeriod.night,
          hours: 8,
        ),
        rules: const [],
      );

      expect(result.hasRule, isFalse);
      expect(result.amount, isNull);
    });
  });
}
