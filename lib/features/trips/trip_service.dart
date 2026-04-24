import '../../core/network/api_client.dart';

class TripService {
  final ApiClient _apiClient = ApiClient();

  // Muavinin tabletine düşecek olan o anki seferin Yolcu Manifestosu
  Future<List<dynamic>?> getManifest(int tripId) async {
    try {
      final response = await _apiClient.dio.get('/tickets/manifest/$tripId');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']; // Dolu koltukların listesi
      }
      return null;
    } catch (e) {
      print('[TRIP SERVICE ERROR] Manifesto çekilemedi: $e');
      return null;
    }
  }
}