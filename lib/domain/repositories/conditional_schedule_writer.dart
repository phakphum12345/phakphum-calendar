import '../../core/result/result.dart';
import '../entities/schedule.dart';

/// Optional repository capability for an atomic write against a caller-owned
/// revision token. The token must come from the exact snapshot being edited;
/// implementations must not substitute a newer shared cache token.
abstract interface class ConditionalScheduleWriter {
  Future<Result<Schedule>> saveIfRevision(
    Schedule schedule,
    String expectedRevision,
  );
}
