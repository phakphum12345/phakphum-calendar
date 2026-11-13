import 'package:flutter/foundation.dart';

@immutable
class OrganizationMembership {
  const OrganizationMembership({
    required this.id,
    required this.name,
    required this.slug,
    required this.employeeId,
    required this.role,
  });

  final String id;
  final String name;
  final String slug;
  final String employeeId;
  final String role;

  bool get canReviewRequests => role == 'owner' || role == 'admin';
}

@immutable
class OrganizationMember {
  const OrganizationMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.employeeId,
    required this.role,
    required this.status,
  });

  final String userId;
  final String name;
  final String email;
  final String employeeId;
  final String role;
  final String status;
}

@immutable
class OrganizationJoinRequest {
  const OrganizationJoinRequest({
    required this.id,
    required this.employeeId,
    required this.status,
    this.name,
    this.email,
    this.organizationId,
    this.organizationName,
    this.organizationSlug,
    this.approvedRole,
    this.createdAt,
  });

  final int id;
  final String employeeId;
  final String status;
  final String? name;
  final String? email;
  final String? organizationId;
  final String? organizationName;
  final String? organizationSlug;
  final String? approvedRole;
  final DateTime? createdAt;
}

abstract interface class OrganizationAdminGateway {
  Future<List<OrganizationMembership>> organizations();

  Future<List<OrganizationMember>> members(String organizationId);

  Future<List<OrganizationJoinRequest>> pendingRequests(
    String organizationId,
  );

  Future<List<OrganizationJoinRequest>> myRequests();

  Future<OrganizationJoinRequest> requestMembership({
    required String organizationSlug,
    required String employeeId,
  });

  Future<void> approveRequest({
    required String organizationId,
    required int requestId,
    required String role,
  });

  Future<void> rejectRequest({
    required String organizationId,
    required int requestId,
  });

  void close();
}

class OrganizationAdminApiException implements Exception {
  const OrganizationAdminApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}
