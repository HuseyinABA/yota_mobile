import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        // Backend'den gelen token'ı al ve cihazın güvenli hafızasına kazı
        final token = response.data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        return true; // Giriş başarılı
      }
      return false;
    } catch (e) {
      print('[AUTH SERVICE ERROR] Login failed: $e');
      return false;
    }
  }
}