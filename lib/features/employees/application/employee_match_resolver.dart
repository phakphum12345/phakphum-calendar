import '../../../domain/entities/employee.dart';

enum EmployeeMatchStatus { matched, ambiguous, unmatched }

/// A conservative employee lookup result for roster-import review.
///
/// Only one exact identity match is safe to resolve automatically. Partial
/// matches are suggestions, never an implicit assignment.
class EmployeeMatchResult {
  EmployeeMatchResult({
    required this.status,
    required List<Employee> candidates,
    this.employee,
    this.reason,
  }) : candidates = List.unmodifiable(candidates);

  final EmployeeMatchStatus status;
  final List<Employee> candidates;
  final Employee? employee;
  final String? reason;

  bool get requiresReview => status != EmployeeMatchStatus.matched;
}

/// Resolves imported roster names against the user's employee directory.
///
/// Matching is deliberately exact-first and conservative: duplicate names
/// remain ambiguous, department can narrow exact-name matches, and partial
/// matches are returned as review suggestions without selecting an employee.
class EmployeeMatchResolver {
  const EmployeeMatchResolver();

  EmployeeMatchResult resolve({
    required String importedName,
    required Iterable<Employee> employees,
    String? department,
  }) {
    final query = _normalize(importedName);
    if (query.isEmpty) {
      return EmployeeMatchResult(
        status: EmployeeMatchStatus.unmatched,
        candidates: const [],
        reason: 'Employee name is empty',
      );
    }

    final directory = employees.toList(growable: false);
    final codeMatches = directory
        .where((employee) => _normalize(employee.employeeCode) == query)
        .toList(growable: false);
    if (codeMatches.length == 1) {
      return EmployeeMatchResult(
        status: EmployeeMatchStatus.matched,
        candidates: codeMatches,
        employee: codeMatches.single,
        reason: 'Exact employee code',
      );
    }
    if (codeMatches.length > 1) {
      return EmployeeMatchResult(
        status: EmployeeMatchStatus.ambiguous,
        candidates: codeMatches,
        reason: 'Employee code is not unique',
      );
    }

    final exactNameMatches = directory.where((employee) {
      return _aliases(employee).contains(query);
    }).toList(growable: false);

    if (exactNameMatches.isNotEmpty) {
      final departmentQuery = _normalize(department ?? '');
      final departmentMatches = departmentQuery.isEmpty
          ? <Employee>[]
          : exactNameMatches
                .where(
                  (employee) =>
                      _normalize(employee.department.name) == departmentQuery ||
                      _normalize(employee.department.code) == departmentQuery ||
                      _normalize(employee.department.id) == departmentQuery,
                )
                .toList(growable: false);
      final narrowed = departmentMatches.isNotEmpty
          ? departmentMatches
          : exactNameMatches;

      if (narrowed.length == 1) {
        return EmployeeMatchResult(
          status: EmployeeMatchStatus.matched,
          candidates: narrowed,
          employee: narrowed.single,
          reason: departmentMatches.isNotEmpty
              ? 'Exact name and department'
              : 'Exact name',
        );
      }
      return EmployeeMatchResult(
        status: EmployeeMatchStatus.ambiguous,
        candidates: narrowed,
        reason: 'More than one employee has this name',
      );
    }

    final suggestions = directory.where((employee) {
      return _aliases(employee).any(
        (alias) => alias.contains(query) || query.contains(alias),
      );
    }).toList(growable: false);

    if (suggestions.isNotEmpty) {
      return EmployeeMatchResult(
        status: EmployeeMatchStatus.ambiguous,
        candidates: suggestions,
        reason: 'Name is similar but not an exact match',
      );
    }

    return EmployeeMatchResult(
      status: EmployeeMatchStatus.unmatched,
      candidates: const [],
      reason: 'No employee matches this name',
    );
  }

  Set<String> _aliases(Employee employee) {
    return {
      _normalize(employee.fullName),
      _normalize(employee.displayName),
      _normalize(employee.nickname),
    }..remove('');
  }

  String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
