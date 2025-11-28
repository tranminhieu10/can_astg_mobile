import 'package:dio/dio.dart';
import '../models/phieu_can_model.dart';
import 'config_service.dart';

class ApiService {
  // Cấu hình Timeout ngắn hơn để App không bị treo khi mạng lag
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // Hàm helper để lấy URL động từ Cấu hình
  Future<Dio> _getClient() async {
    String baseUrl = await AppConfig.getApiUrl();
    _dio.options.baseUrl = baseUrl;
    return _dio;
  }

  // 1. Gửi phiếu cân lên Server (Sync Up)
  Future<bool> postPhieuCan(PhieuCanModel phieu) async {
    try {
      final client = await _getClient();
      // Chuyển object sang JSON
      final data = phieu.toJson();
      
      // Loại bỏ ID local để Server tự sinh ID mới (tránh xung đột khóa chính)
      data.remove('id'); 

      final response = await client.post('/api/phieucan', data: data);
      
      // Chấp nhận cả 200 (OK) và 201 (Created)
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Lỗi gửi API: $e");
      return false;
    }
  }

  // 2. Lấy lịch sử từ Server về (Sync Down)
  Future<List<PhieuCanModel>> getPhieuCanHistory() async {
    try {
      final client = await _getClient();
      final response = await client.get('/api/phieucan');
      
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((e) => PhieuCanModel.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      print("Lỗi lấy lịch sử API: $e");
      return [];
    }
  }

  // 3. Điều khiển Barrier
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