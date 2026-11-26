class ManagedCalendarEvent {
  const ManagedCalendarEvent({
    required this.eventId,
    required this.syncId,
    required this.title,
    required this.start,
    required this.end,
    this.description,
    this.colorId,
    this.etag,
  });

  final String eventId;
  final String syncId;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? description;
  final String? colorId;
  /// Google Calendar provider version used for conditional mutations.
  final String? etag;
}
