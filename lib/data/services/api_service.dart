import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../models/phieu_can_model.dart';
import 'config_service.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  Future<Dio> _getClient() async {
    String baseUrl = await AppConfig.getApiUrl();
    _dio.options.baseUrl = baseUrl;
    return _dio;
  }

  // 1. Post Phiếu Cân
  Future<bool> postPhieuCan(PhieuCanModel phieu) async {
    try {
      final client = await _getClient();
      final data = phieu.toJson();
      // Server thường tự sinh ID, nên xóa id nếu là 0 hoặc null khi tạo mới
      if (phieu.id == null || phieu.id == 0) {
        data.remove('id');
      }
      final response = await client.post('/api/PhieuCan', data: data);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Lỗi POST API: $e");
      return false;
    }
  }

  // 2. Lấy danh sách phiếu
  Future<List<PhieuCanModel>> getPhieuCanHistory() async {
    try {
      final client = await _getClient();
      final response = await client.get('/api/PhieuCan/recent?limit=20');
      if (response.statusCode == 200) {
        return (response.data as List).map((e) => PhieuCanModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 3. Upload ảnh
  Future<String?> uploadImage(String filePath) async {
    try {
      final client = await _getClient();
      String fileName = filePath.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: MediaType("image", "jpeg"),
        ),
      });
      final response = await client.post('/api/Upload/image', data: formData);
      return response.statusCode == 200 ? response.data['url'] : null;
    } catch (e) { return null; }
  }

  // 4. Lấy Danh Mục
  Future<List<dynamic>> getCongTyNhap() async {
    try {
      final client = await _getClient();
      final res = await client.get('/api/DanhMuc/congtynhap');
      return res.statusCode == 200 ? res.data : [];
    } catch (e) { return []; }
  }

  Future<List<dynamic>> getCongTyBan() async {
    try {
      final client = await _getClient();
      final res = await client.get('/api/DanhMuc/congtyban');
      return res.statusCode == 200 ? res.data : [];
    } catch (e) { return []; }
  }

  Future<List<dynamic>> getLoaiHang() async {
    try {
      final client = await _getClient();
      final res = await client.get('/api/DanhMuc/loaihang');
      return res.statusCode == 200 ? res.data : [];
    } catch (e) { return []; }
  }

  // 5. Lấy tên người cân
  Future<String> getTenNguoiCan(String ma) async {
    try {
      // Logic giả lập, thay thế bằng API thực nếu có
      return ma == "ADMIN" ? "Quản trị viên" : ma;
    } catch (e) { 
      return ma; 
    }
  }

  // 6. Điều khiển Barrier
  Future<bool> controlBarrier(String cmd) async {
    try {
      final client = await _getClient();
      await client.post('/api/control/barrier', data: {'cmd': cmd});
      return true;
    } catch (e) { return false; }
  }
}