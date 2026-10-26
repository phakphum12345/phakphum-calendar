import 'dart:async';

import 'package:http/http.dart' as http;

class GoogleApiClient extends http.BaseClient {
  GoogleApiClient(
    this._headers, [
    http.Client? inner,
    Duration timeout = const Duration(seconds: 30),
  ])  : _inner = inner ?? http.Client(),
        _timeout = timeout;

  final Map<String, String> _headers;
  final http.Client _inner;
  final Duration _timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(_headers);
    final response = await _inner.send(request).timeout(_timeout);
    // A timeout on send() only bounds waiting for response headers. Google API
    // responses are streamed, so also bound idle time while the body is read.
    return response.copyWith(
      stream: response.stream.timeout(
        _timeout,
        onTimeout: (sink) {
          sink.addError(
            TimeoutException(
              'Google API response stream was idle for $_timeout.',
            ),
          );
          sink.close();
        },
      ),
    );
  }

  @override
  void close() => _inner.close();
}
