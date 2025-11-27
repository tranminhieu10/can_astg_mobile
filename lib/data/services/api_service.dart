import 'package:dio/dio.dart';
import '../models/phieu_can_model.dart';
import 'config_service.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<Dio> _getClient() async {
    String baseUrl = await AppConfig.getApiUrl();
    _dio.options.baseUrl = baseUrl;
    return _dio;
  }

  // Gửi phiếu lên
  Future<bool> postPhieuCan(PhieuCanModel phieu) async {
    try {
      final client = await _getClient();
      final response = await client.post('/api/phieucan', data: phieu.toJson());
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // [MỚI] Lấy lịch sử về (Sync Down)
  Future<List<PhieuCanModel>> getPhieuCanHistory() async {
    try {
      final client = await _getClient();
      final response = await client.get('/api/phieucan');
      if (response.statusCode == 200) {
        return (response.data as List).map((e) => PhieuCanModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Lỗi lấy lịch sử: $e");
      return [];
    }
  }

  // Điều khiển Barrier
  Future<bool> controlBarrier(String cmd) async {
    try {
      final client = await _getClient();
      final response = await client.post('/api/control/barrier', data: {'cmd': cmd});
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}