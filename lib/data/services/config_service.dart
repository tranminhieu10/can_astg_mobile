import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String keyApiUrl = 'api_url';
  static const String keyCameraUrl = 'camera_url';
  static const String keyMode = 'connection_mode'; // 'local' hoặc 'cloud'

  // === CẤU HÌNH 1: MẠNG NỘI BỘ (LAN) ===
  static const String localApi = 'http://192.168.1.35:5225'; 
  static const String localCamera = 'rtsp://admin:abcd1234@192.168.1.232:554/main';

  // === CẤU HÌNH 2: MẠNG AZURE (CLOUD) ===
  // (Bạn thay link Azure thật của bạn vào đây khi nào triển khai)
  static const String azureApi = 'https://smartweight-api.azurewebsites.net'; 
  static const String azureCamera = 'rtsp://camera.smartweight.com:554/stream1';

  // Lấy URL API hiện tại
  static Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyApiUrl) ?? localApi;
  }

  // Lấy URL Camera hiện tại
  static Future<String> getCameraUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyCameraUrl) ?? localCamera;
  }

  // Lấy chế độ đang dùng (để hiển thị lên UI)
  static Future<String> getCurrentMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyMode) ?? 'local';
  }

  // Lưu cấu hình tùy chỉnh
  static Future<void> saveConfig(String apiUrl, String cameraUrl, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyApiUrl, apiUrl);
    await prefs.setString(keyCameraUrl, cameraUrl);
    await prefs.setString(keyMode, mode);
  }
}