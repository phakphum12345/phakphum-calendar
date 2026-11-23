import 'dart:convert';

enum SwapRequestStatus { pending, approved, rejected }

class SwapRequest {
  SwapRequest({
    required this.id,
    required this.requester,
    required this.target,
    required this.shiftRef,
    required this.reason,
    required this.createdAt,
    this.status = SwapRequestStatus.pending,
  });

  final String id;
  final String requester;
  final String target;
  final String shiftRef;
  final String reason;
  final DateTime createdAt;
  SwapRequestStatus status;

  Map<String, Object?> toJson() => {
        'id': id,
        'requester': requester,
        'target': target,
        'shiftRef': shiftRef,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
      };

  factory SwapRequest.fromJson(Map<String, Object?> json) {
    return SwapRequest(
      id: json['id'] as String,
      requester: json['requester'] as String,
      target: json['target'] as String,
      shiftRef: json['shiftRef'] as String,
      reason: json['reason'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: SwapRequestStatus.values.byName(json['status'] as String),
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
