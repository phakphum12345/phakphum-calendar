import 'department.dart';

class Employee {
  const Employee({
    required this.id,
    required this.employeeCode,
    required this.firstName,
    required this.lastName,
    required this.nickname,
    required this.department,
    required this.position,
    this.alternateNames = '',
    this.active = true,
  });

  final String id;
  final String employeeCode;
  final String firstName;
  final String lastName;
  final String nickname;
  final Department department;
  final String position;

  /// Additional names used by roster imports, separated by commas or lines.
  /// Kept as text so the immutable entity remains const-constructible.
  final String alternateNames;
  final bool active;

  List<String> get aliases => List.unmodifiable(
    alternateNames
        .split(RegExp(r'[,;\r\n]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty),
  );

  /// Creates an updated immutable employee record.
  Employee copyWith({
    String? id,
    String? employeeCode,
    String? firstName,
    String? lastName,
    String? nickname,
    Department? department,
    String? position,
    String? alternateNames,
    bool? active,
  }) {
    return Employee(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nickname: nickname ?? this.nickname,
      department: department ?? this.department,
      position: position ?? this.position,
      alternateNames: alternateNames ?? this.alternateNames,
      active: active ?? this.active,
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  String get displayName =>
      nickname.trim().isEmpty ? fullName : '$fullName ($nickname)';

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    return normalized.isEmpty ||
        employeeCode.toLowerCase().contains(normalized) ||
        firstName.toLowerCase().contains(normalized) ||
        lastName.toLowerCase().contains(normalized) ||
        nickname.toLowerCase().contains(normalized) ||
        position.toLowerCase().contains(normalized) ||
        aliases.any((alias) => alias.toLowerCase().contains(normalized));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Employee && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
