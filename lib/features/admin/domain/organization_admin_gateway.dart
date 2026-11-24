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

@immutable
class OrganizationMembershipAuditEvent {
  const OrganizationMembershipAuditEvent({
    required this.id,
    required this.action,
    required this.actorUserId,
    required this.actorName,
    required this.subjectUserId,
    required this.subjectName,
    required this.createdAt,
    this.before,
    this.after,
  });

  final int id;
  final String action;
  final String actorUserId;
  final String actorName;
  final String subjectUserId;
  final String subjectName;
  final DateTime createdAt;
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;
}

@immutable
class OrganizationMembershipAuditPage {
  const OrganizationMembershipAuditPage({
    required this.events,
    this.nextBeforeId,
  });

  final List<OrganizationMembershipAuditEvent> events;
  final int? nextBeforeId;
}

abstract interface class OrganizationAdminGateway {
  Future<List<OrganizationMembership>> organizations();

  Future<List<OrganizationMember>> members(String organizationId);

  Future<OrganizationMembershipAuditPage> membershipAudit(
    String organizationId, {
    int limit = 50,
    int? beforeId,
  });

  Future<void> updateMemberRole({
    required String organizationId,
    required String userId,
    required String role,
  });

  Future<void> removeMember({
    required String organizationId,
    required String userId,
  });

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
