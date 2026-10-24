/// Web uses its current origin; native USB builds need an absolute URL.
String resolvePlannerBaseUrl(String configured, {
  required bool isWeb,
  Uri? pageUri,
}) {
  final value = configured.trim();
  if (value == '/') {
    // A bare slash plus Dio's /api path would become //api/... .
    if (isWeb && pageUri != null && pageUri.hasAuthority) {
      return pageUri.origin;
    }
    return 'http://127.0.0.1:8080';
  }
  final uri = Uri.tryParse(value);
  if (uri != null && ['http', 'https'].contains(uri.scheme) && uri.hasAuthority) {
    return value.replaceFirst(RegExp(r'/$'), '');
  }
  return 'http://127.0.0.1:8080';
}
