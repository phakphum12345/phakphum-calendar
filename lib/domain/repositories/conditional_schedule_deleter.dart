import '../../core/result/result.dart';

/// Atomic delete capability bound to the exact revision observed by the caller.
/// Implementations retain a tombstone so stale clients cannot recreate data.
abstract interface class ConditionalScheduleDeleter {
  Future<Result<void>> deleteIfRevision(
    String scheduleId,
    String expectedRevision,
  );
}
