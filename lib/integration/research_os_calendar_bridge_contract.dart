/// Canonical local HTTP contract used by Research OS Friend.
///
/// This file contains no credentials and performs no network I/O. The actual
/// bridge server must be loopback-only and delegate writes to the existing
/// CalendarSyncCoordinator/guarded workflow.
final class ResearchOsCalendarBridgeContract {
  const ResearchOsCalendarBridgeContract._();

  static const host = '127.0.0.1';
  static const defaultPort = 8765;
  static const healthPath = '/v1/research-os/health';
  static const syncPath = '/v1/research-os/sync';
  static const syncStatusPathPrefix = '/v1/research-os/sync/';

  static const requestTimeoutSeconds = 20;

  static Uri healthUri({int port = defaultPort}) =>
      Uri.parse('http://$host:$port$healthPath');

  static Uri syncUri({int port = defaultPort}) =>
      Uri.parse('http://$host:$port$syncPath');

  static Uri syncStatusUri(String syncId, {int port = defaultPort}) =>
      Uri.parse('http://$host:$port$syncStatusPathPrefix$syncId');
}
