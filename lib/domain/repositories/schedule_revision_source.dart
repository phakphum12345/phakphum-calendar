import '../entities/schedule.dart';

/// Exposes the authoritative revision loaded by a revision-aware Schedule repository.
///
/// A revision may include a monotonic generation as well as a content hash. It
/// must not be recomputed from the Schedule payload when the backing store has
/// a stronger revision token, because that would reintroduce ABA acceptance.

abstract interface class ScheduleRevisionSource {
  String? currentRevisionFor(String scheduleId);

  /// Returns the revision bound to this exact loaded Schedule snapshot.
  String? revisionForSnapshot(Schedule schedule);

  /// Returns the exact absent-state revision captured by the last read.
  /// Implementations must not substitute a later shared revision.
  String? revisionForAbsentSchedule(String scheduleId);
}
