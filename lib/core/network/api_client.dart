import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../json/json_values.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';

class UnauthorizedTick extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final unauthorizedTickProvider = NotifierProvider<UnauthorizedTick, int>(
  UnauthorizedTick.new,
);

class ApiClient {
  ApiClient({required this.store, Dio? dio, this.onUnauthorized})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.normalizedBase,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              headers: const {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await store.read('token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final response = error.response;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          final path = error.requestOptions.path;
          final isAuthCall =
              path.contains('/auth/login') ||
              path.contains('/auth/refresh') ||
              path.contains('/auth/patient-signup');
          if (response?.statusCode == 401 && !alreadyRetried && !isAuthCall) {
            final refreshed = await _refresh();
            if (refreshed) {
              final request = error.requestOptions;
              request.extra['retried'] = true;
              final token = await store.read('token');
              request.headers['Authorization'] = 'Bearer $token';
              try {
                final replay = await _dio.fetch(request);
                return handler.resolve(replay);
              } catch (replayError) {
                if (replayError is DioException) {
                  return handler.next(replayError);
                }
              }
            } else {
              await store.clear();
              onUnauthorized?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStore store;
  final Dio _dio;
  void Function()? onUnauthorized;

  Future<bool> _refresh() async {
    final token = await store.read('token');
    if (token == null || token.isEmpty) return false;
    try {
      final response = await _dio.post<Object?>(
        '/auth/refresh',
        data: {'token': token},
        options: Options(extra: const {'retried': true}),
      );
      final body = asMap(response.data);
      final next = firstString(body, ['token']);
      if (next.isEmpty) return false;
      await store.write('token', next);
      final role = firstString(body, ['role']);
      final userId = firstString(body, ['userId']);
      final tenantId = firstString(body, ['tenantId']);
      if (role.isNotEmpty) await store.write('role', role);
      if (userId.isNotEmpty) await store.write('userId', userId);
      if (tenantId.isNotEmpty) await store.write('tenantId', tenantId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Object?> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _send(() => _dio.get(path, queryParameters: query));

  Future<Object?> post(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) => _send(() => _dio.post(path, data: data, queryParameters: query));

  Future<Object?> put(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) => _send(() => _dio.put(path, data: data, queryParameters: query));

  Future<Object?> delete(String path) => _send(() => _dio.delete(path));

  Future<Object?> _send(Future<Response<Object?>> Function() call) async {
    DioException? last;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await call();
        return response.data;
      } on DioException catch (error) {
        last = error;
        final code = error.response?.statusCode;
        final method = error.requestOptions.method.toUpperCase();
        final transient =
            error.response == null || code == 502 || code == 503 || code == 504;
        if (!transient || method != 'GET' || attempt == 2) {
          throw ApiException(
            apiMessage(error.response?.data, _fallbackMessage(error)),
            statusCode: code,
          );
        }
        await Future<void>.delayed(Duration(milliseconds: 700 * (attempt + 1)));
      }
    }
    throw ApiException(
      apiMessage(
        last?.response?.data,
        'The DigiMed service did not respond. Try again in a moment.',
      ),
      statusCode: last?.response?.statusCode,
    );
  }

  String _fallbackMessage(DioException error) {
    final code = error.response?.statusCode;
    if (error.response == null || code == 502 || code == 503 || code == 504) {
      return 'The DigiMed service did not respond. Try again in a moment.';
    }
    return 'The DigiMed service could not complete that request.';
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(store: ref.watch(tokenStoreProvider));
  client.onUnauthorized = () {
    ref.read(unauthorizedTickProvider.notifier).bump();
  };
  return client;
});
