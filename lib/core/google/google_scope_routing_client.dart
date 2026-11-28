import 'dart:async';

import 'package:http/http.dart' as http;

import 'google_scopes.dart';

typedef GoogleScopeClientFactory =
    Future<http.Client> Function(List<String> scopes);

/// Routes Calendar read requests and mutations through separate OAuth grants.
///
/// Preview/list/get requests use the read-only Calendar scope. Write requests
/// request the Calendar write scope only when the provider mutation is sent,
/// which keeps opening a preview from requesting write access.
class GoogleScopeRoutingClient extends http.BaseClient {
  GoogleScopeRoutingClient({
    required this.clientForScopes,
    List<String> readScopes = GoogleScopes.calendarRead,
    List<String> writeScopes = GoogleScopes.calendarWrite,
  }) : _readScopes = List<String>.unmodifiable(readScopes),
       _writeScopes = List<String>.unmodifiable(writeScopes) {
    if (_readScopes.isEmpty || _writeScopes.isEmpty) {
      throw ArgumentError('Calendar read and write scopes must not be empty.');
    }
  }

  final GoogleScopeClientFactory clientForScopes;
  final List<String> _readScopes;
  final List<String> _writeScopes;
  final Map<String, Future<http.Client>> _clients = {};
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw StateError('Google Calendar client is closed.');

    final scopes = switch (request.method.toUpperCase()) {
      'GET' || 'HEAD' => _readScopes,
      'POST' || 'PUT' || 'PATCH' || 'DELETE' => _writeScopes,
      final method => throw UnsupportedError(
        'Unsupported Google Calendar HTTP method: $method',
      ),
    };
    final client = await _clientFor(scopes);
    if (_closed) throw StateError('Google Calendar client is closed.');
    return client.send(request);
  }

  Future<http.Client> _clientFor(List<String> scopes) async {
    final key = scopes.join('\u0000');
    final pending = _clients.putIfAbsent(
      key,
      () => clientForScopes(List<String>.unmodifiable(scopes)),
    );
    try {
      return await pending;
    } catch (_) {
      if (identical(_clients[key], pending)) _clients.remove(key);
      rethrow;
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final pending in _clients.values) {
      unawaited(
        pending
            .then<void>((client) {
              client.close();
            })
            .catchError((Object _) {}),
      );
    }
    _clients.clear();
  }
}
