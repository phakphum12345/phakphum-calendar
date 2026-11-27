import '../../../domain/entities/employee.dart';

enum EmployeeIdentityMatchKind {
  employeeCode,
  fullName,
  alias,
  displayName,
  nickname,
  containsText,
}

enum EmployeeIdentityResolutionStatus {
  sourceNameMissing,
  exactUniqueCandidate,
  ambiguousExactCandidates,
  suggestionsOnly,
  noMatch,
}

/// A candidate is evidence for human review, never an automatic identity link.
class EmployeeIdentityCandidate {
  const EmployeeIdentityCandidate({
    required this.employee,
    required this.matchKind,
  });

  final Employee employee;
  final EmployeeIdentityMatchKind matchKind;
}

class EmployeeIdentityResolution {
  EmployeeIdentityResolution({
    required this.sourceName,
    required this.status,
    required List<EmployeeIdentityCandidate> candidates,
  }) : candidates = List.unmodifiable(candidates);

  final String sourceName;
  final EmployeeIdentityResolutionStatus status;
  final List<EmployeeIdentityCandidate> candidates;

  bool get requiresHumanConfirmation => true;

  /// Resolution is deliberately proposal-only; a reviewer must select an ID.
  String? get selectedEmployeeId => null;

  /// Candidate discovery never authorizes persistence.
  bool get canCommit => false;
}

/// Finds active employee candidates for a source worker label.
///
/// Exact matches are ranked above substring suggestions. Even a unique exact
/// match remains unselected until a reviewer explicitly confirms the employee.
class GridRosterEmployeeIdentityResolver {
  const GridRosterEmployeeIdentityResolver();

  EmployeeIdentityResolution resolve({
    required String sourceName,
    required Iterable<Employee> employees,
  }) {
    final normalizedSource = _normalize(sourceName);
    if (normalizedSource.isEmpty) {
      return EmployeeIdentityResolution(
        sourceName: sourceName,
        status: EmployeeIdentityResolutionStatus.sourceNameMissing,
        candidates: const [],
      );
    }

    final active = employees.where((employee) => employee.active).toList();
    final exact = <String, EmployeeIdentityCandidate>{};
    final suggestions = <String, EmployeeIdentityCandidate>{};

    for (final employee in active) {
      final fields = <(String, EmployeeIdentityMatchKind)>[
        (employee.employeeCode, EmployeeIdentityMatchKind.employeeCode),
        (employee.fullName, EmployeeIdentityMatchKind.fullName),
        for (final alias in employee.aliases)
          (alias, EmployeeIdentityMatchKind.alias),
        (employee.displayName, EmployeeIdentityMatchKind.displayName),
        (employee.nickname, EmployeeIdentityMatchKind.nickname),
      ];

      for (final field in fields) {
        final normalizedValue = _normalize(field.$1);
        if (normalizedValue.isEmpty) continue;
        if (normalizedValue == normalizedSource) {
          _keepBest(
            exact,
            EmployeeIdentityCandidate(
              employee: employee,
              matchKind: field.$2,
            ),
          );
        } else if (normalizedValue.contains(normalizedSource) ||
            normalizedSource.contains(normalizedValue)) {
          _keepBest(
            suggestions,
            EmployeeIdentityCandidate(
              employee: employee,
              matchKind: EmployeeIdentityMatchKind.containsText,
            ),
          );
        }
      }
    }

    if (exact.isNotEmpty) {
      // Keep every exact identity candidate, even when evidence kinds differ.
      // Ranking orders the review list; it must not hide an alias collision
      // behind a canonical-name or employee-code match.
      final ranked = exact.values.toList()..sort(_compareCandidates);
      return EmployeeIdentityResolution(
        sourceName: sourceName,
        status: ranked.length == 1
            ? EmployeeIdentityResolutionStatus.exactUniqueCandidate
            : EmployeeIdentityResolutionStatus.ambiguousExactCandidates,
        candidates: ranked,
      );
    }

    final candidates = suggestions.values.toList()..sort(_compareCandidates);
    return EmployeeIdentityResolution(
      sourceName: sourceName,
      status: candidates.isEmpty
          ? EmployeeIdentityResolutionStatus.noMatch
          : EmployeeIdentityResolutionStatus.suggestionsOnly,
      candidates: candidates,
    );
  }

  void _keepBest(
    Map<String, EmployeeIdentityCandidate> target,
    EmployeeIdentityCandidate candidate,
  ) {
    final existing = target[candidate.employee.id];
    if (existing == null ||
        _rank(candidate.matchKind) < _rank(existing.matchKind)) {
      target[candidate.employee.id] = candidate;
    }
  }

  int _compareCandidates(
    EmployeeIdentityCandidate left,
    EmployeeIdentityCandidate right,
  ) {
    final kind = _rank(left.matchKind).compareTo(_rank(right.matchKind));
    if (kind != 0) return kind;
    final code = left.employee.employeeCode.compareTo(
      right.employee.employeeCode,
    );
    return code != 0 ? code : left.employee.id.compareTo(right.employee.id);
  }

  int _rank(EmployeeIdentityMatchKind kind) => switch (kind) {
    EmployeeIdentityMatchKind.employeeCode => 0,
    EmployeeIdentityMatchKind.fullName => 1,
    EmployeeIdentityMatchKind.alias => 2,
    EmployeeIdentityMatchKind.displayName => 3,
    EmployeeIdentityMatchKind.nickname => 4,
    EmployeeIdentityMatchKind.containsText => 5,
  };

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
}
