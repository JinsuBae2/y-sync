import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';

enum ServerAvailability { available, unavailable }

class ServerAvailabilityNotifier extends Notifier<ServerAvailability> {
  @override
  ServerAvailability build() => ServerAvailability.available;

  void markAvailable() => state = ServerAvailability.available;

  void markUnavailable() => state = ServerAvailability.unavailable;
}

final serverAvailabilityProvider =
    NotifierProvider<ServerAvailabilityNotifier, ServerAvailability>(
      ServerAvailabilityNotifier.new,
    );

final healthCheckDioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
    ),
  ),
);

final serverHealthCheckProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    try {
      await ref.read(healthCheckDioProvider).get<void>('/hello');
      ref.read(serverAvailabilityProvider.notifier).markAvailable();
      return true;
    } on DioException {
      ref.read(serverAvailabilityProvider.notifier).markUnavailable();
      return false;
    }
  };
});

bool isServerUnavailableError(DioException error) {
  final statusCode = error.response?.statusCode;
  if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
    return true;
  }

  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    _ => false,
  };
}
