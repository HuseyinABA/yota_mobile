import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Platform (Web/Mobil) kontrolü için eklendi

class ApiClient {
  late Dio dio;
  
  // Zeki URL Seçici: Web'deysek localhost, Android emülatördeysek 10.0.2.2 kullanır.
  static const String baseUrl = kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api';

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        print('[API ERROR] ${e.response?.statusCode} - ${e.message}');
        return handler.next(e);
      },
    ));
  }
}