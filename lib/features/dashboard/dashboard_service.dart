import '../../core/network/api_client.dart';

class DashboardService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>?> getSystemStats() async {
    try {
      // Backend'deki o meşhur stats rotamıza GET isteği atıyoruz
      final response = await _apiClient.dio.get('/dashboard/stats');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']; // İstatistikleri döndür
      }
      return null;
    } catch (e) {
      print('[DASHBOARD SERVICE ERROR] İstatistikler çekilemedi: $e');
      return null;
    }
  }
}