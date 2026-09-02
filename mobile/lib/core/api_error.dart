import 'package:dio/dio.dart';

/// Pulls the backend's own error message out of a failed API call instead
/// of showing a generic string — Nest sends `{ message: "..." }` (or an
/// array of validation messages) on every 4xx/5xx response.
String apiErrorMessage(Object error, {String fallback = 'Something went wrong. Try again.'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final message = data['message'];
      if (message is List && message.isNotEmpty) return message.first.toString();
      return message.toString();
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Could not reach the server. Check your connection.';
    }
  }
  return fallback;
}
