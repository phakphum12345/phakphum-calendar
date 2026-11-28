import 'dart:async';

import 'package:http/http.dart' as http;

class GoogleApiClient extends http.BaseClient {
  GoogleApiClient(
    this._headers, [
    http.Client? inner,
    this._timeout = const Duration(seconds: 30),
  ]) : _headersProvider = null,
       _inner = inner ?? http.Client();

  GoogleApiClient.withHeaderProvider(
    this._headersProvider, {
    http.Client? inner,
    this._timeout = const Duration(seconds: 30),
  }) : _headers = const <String, String>{},
       _inner = inner ?? http.Client();

  final Map<String, String> _headers;
  final Future<Map<String, String>> Function()? _headersProvider;
  final http.Client _inner;
  final Duration _timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = _headersProvider == null
        ? _headers
        : await _headersProvider().timeout(_timeout);
    request.headers.addAll(headers);
    final response = await _inner.send(request).timeout(_timeout);
    // A timeout on send() only bounds waiting for response headers. Google API
    // responses are streamed, so also bound idle time while the body is read.
    return http.StreamedResponse(
      response.stream.timeout(
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
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
