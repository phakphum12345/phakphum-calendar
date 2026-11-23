/// Canonical local HTTP contract used by Research OS Friend.
///
/// This file contains no credentials and performs no network I/O. The actual
/// bridge server must be loopback-only and delegate writes to the existing
/// CalendarSyncCoordinator/guarded workflow. The caller must supply the port
/// discovered from the running bridge; this contract does not reserve a port.
final class ResearchOsCalendarBridgeContract {
  const ResearchOsCalendarBridgeContract._();

  static const host = '127.0.0.1';
  static const healthPath = '/v1/research-os/health';
  static const syncPath = '/v1/research-os/sync';
  static const syncStatusPathPrefix = '/v1/research-os/sync/';

  static const requestTimeoutSeconds = 20;

  static Uri healthUri({required int port}) => _uri(port, healthPath);

  static Uri syncUri({required int port}) => _uri(port, syncPath);

  static Uri syncStatusUri(String syncId, {required int port}) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(syncId)) {
      throw ArgumentError.value(syncId, 'syncId', 'Must be a bounded opaque ID.');
    }
    return _uri(port, '$syncStatusPathPrefix$syncId');
  }

  static Uri _uri(int port, String path) {
    if (port < 1 || port > 65535) {
      throw ArgumentError.value(port, 'port', 'Must be a valid discovered TCP port.');
    }
    return Uri(scheme: 'http', host: host, port: port, path: path);
  }
}
