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
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request).timeout(_timeout);
  }

  @override
  void close() => _inner.close();
}
