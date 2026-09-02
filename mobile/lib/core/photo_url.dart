import 'config.dart';

/// Hosts that serve photos without CORS headers. Fine for an <img> on
/// their own site, blocked by the browser when the web build hotlinks
/// them — see the backend's MediaController, which exists for this.
const _proxiedHosts = {'api.hamroauto.com.np'};

/// Rewrites a stored photo URL into one the current build can actually
/// load.
///
/// URLs on [_proxiedHosts] are routed through the API's `/media/proxy`,
/// which re-serves the bytes from our own origin with permissive headers.
/// Native builds are not subject to CORS and would work either way, but
/// they use the same path so there is only one behaviour to reason about.
/// Anything else (S3/R2 URLs, which we control) is returned untouched.
String photoDisplayUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !_proxiedHosts.contains(uri.host)) return url;
  return '${AppConfig.apiBaseUrl}/media/proxy?src=${Uri.encodeQueryComponent(url)}';
}
