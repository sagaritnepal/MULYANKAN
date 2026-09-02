import 'package:dio/dio.dart';
import 'config.dart';
import 'secure_storage.dart';
import 'server_clock.dart';

/// Thin wrapper around Dio: attaches the bearer token, transparently
/// refreshes it once on a 401, and syncs [ServerClock] whenever a response
/// carries a `serverNow` field so countdowns stay server-authoritative.
class ApiClient {
  static final ApiClient instance = ApiClient._();
  late final Dio dio;
  bool _refreshing = false;

  ApiClient._() {
    dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl, connectTimeout: const Duration(seconds: 15)));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.readAccess();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onResponse: (response, handler) {
        final body = response.data;
        if (body is Map && body['serverNow'] is int) {
          ServerClock.sync(body['serverNow'] as int);
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final isAuthRoute = error.requestOptions.path.contains('/auth/');
        if (status == 401 && !isAuthRoute && !_refreshing) {
          _refreshing = true;
          try {
            final refreshed = await _tryRefresh();
            _refreshing = false;
            if (refreshed) {
              final retryToken = await TokenStorage.readAccess();
              error.requestOptions.headers['Authorization'] = 'Bearer $retryToken';
              final response = await dio.fetch(error.requestOptions);
              return handler.resolve(response);
            }
          } catch (_) {
            _refreshing = false;
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await TokenStorage.readRefresh();
    if (refreshToken == null) return false;
    try {
      final res = await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl))
          .post('/auth/refresh', data: {'refreshToken': refreshToken});
      await TokenStorage.save(res.data['accessToken'], res.data['refreshToken']);
      return true;
    } catch (_) {
      await TokenStorage.clear();
      return false;
    }
  }
}
