import 'package:dio/dio.dart';
import 'config_service.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
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

  /// Đăng nhập với email và password
  /// Trả về Map chứa: success, token, userId, userName, message
  Future<Map<String, dynamic>> login(String email, String password) async {
    // === TÀI KHOẢN TEST OFFLINE ===
    // Cho phép đăng nhập offline với admin/123
    if ((email == 'admin' || email == 'admin@astec.vn') && password == '123') {
      return {
        'success': true,
        'token': 'offline_test_token_astec_${DateTime.now().millisecondsSinceEpoch}',
        'userId': 'admin_001',
        'userName': 'Admin ASTEC',
        'message': 'Đăng nhập thành công (Offline Mode)',
      };
    }

    try {
      final client = await _getClient();
      
      final response = await client.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'success': true,
          'token': data['token'] ?? data['accessToken'] ?? '',
          'userId': data['userId'] ?? data['id'] ?? '',
          'userName': data['userName'] ?? data['name'] ?? data['fullName'] ?? '',
          'message': 'Đăng nhập thành công',
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Đăng nhập thất bại',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Lỗi kết nối máy chủ';
      
      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        
        if (statusCode == 401) {
          errorMessage = 'Sai email hoặc mật khẩu';
        } else if (statusCode == 404) {
          errorMessage = 'Tài khoản không tồn tại';
        } else if (data is Map && data['message'] != null) {
          errorMessage = data['message'];
        }
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Không thể kết nối đến máy chủ';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Lỗi mạng, vui lòng kiểm tra kết nối';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Đã xảy ra lỗi: $e',
      };
    }
  }

  /// Đổi mật khẩu
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String token,
  }) async {
    try {
      final client = await _getClient();
      client.options.headers['Authorization'] = 'Bearer $token';

      final response = await client.post('/api/auth/change-password', data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      });

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Đổi mật khẩu thành công',
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Đổi mật khẩu thất bại',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi: $e',
      };
    }
  }

  /// Kiểm tra token còn hiệu lực không
  Future<bool> validateToken(String token) async {
    try {
      final client = await _getClient();
      client.options.headers['Authorization'] = 'Bearer $token';

      final response = await client.get('/api/auth/validate');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
