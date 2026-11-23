/// A local audit record. Optional fields keep records from older app versions
/// readable while allowing newer actions to preserve actor and state details.
class AuditEntry {
  const AuditEntry({
    required this.timestamp,
    required this.action,
    required this.message,
    required this.success,
    this.actorId,
    this.entityType,
    this.entityId,
    this.previousState,
    this.newState,
  });

  final DateTime timestamp;
  final String action;
  final String message;
  final bool success;

  /// Stable authenticated account/staff identifier, not a display name.
  /// Null means the actor was not verified when the record was created.
  final String? actorId;
  final String? entityType;
  final String? entityId;
  final String? previousState;
  final String? newState;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'action': action,
    'message': message,
    'success': success,
    if (actorId != null) 'actorId': actorId,
    if (entityType != null) 'entityType': entityType,
    if (entityId != null) 'entityId': entityId,
    if (previousState != null) 'previousState': previousState,
    if (newState != null) 'newState': newState,
  };

  factory AuditEntry.fromJson(Map<String, Object?> json) => AuditEntry(
    timestamp:
        DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    action: json['action']?.toString() ?? '-',
    message: json['message']?.toString() ?? '-',
    success: json['success'] == true,
    actorId: _nonEmptyString(json['actorId']),
    entityType: _nonEmptyString(json['entityType']),
    entityId: _nonEmptyString(json['entityId']),
    previousState: _nonEmptyString(json['previousState']),
    newState: _nonEmptyString(json['newState']),
  );

  static String? _nonEmptyString(Object? value) {
    final result = value?.toString().trim();
    return result == null || result.isEmpty ? null : result;
  }
}
