/// Exposes the authoritative revision loaded by a revision-aware Schedule repository.
///
/// A revision may include a monotonic generation as well as a content hash. It
/// must not be recomputed from the Schedule payload when the backing store has
/// a stronger revision token, because that would reintroduce ABA acceptance.
import '../entities/schedule.dart';

abstract interface class ScheduleRevisionSource {
  String? currentRevisionFor(String scheduleId);

  /// Returns the revision bound to this exact loaded Schedule snapshot.
  String? revisionForSnapshot(Schedule schedule);
}
