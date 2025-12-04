import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String keyApiUrl = 'api_url';
  static const String keyCameraUrl = 'camera_url';
  static const String keyMode = 'connection_mode';

  // --- CẤU HÌNH MẶC ĐỊNH ---
  static const String localApi = 'http://192.168.1.35:5225'; 
  static const String localCamera = 'rtsp://admin:abcd1234@192.168.1.232:554/main';

  // Link Azure Web App của bạn
  static const String azureApi = 'https://api-tramcan-hieu-g7bcdmfydpb8cmd7.southeastasia-01.azurewebsites.net'; 
  static const String azureCamera = 'rtsp://admin:abcd1234@tramcan-hieu.dyndns.org:554/main';

  static Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyApiUrl) ?? azureApi;
  }

  static Future<String> getCameraUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyCameraUrl) ?? localCamera;
  }

  static Future<String> getCurrentMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyMode) ?? 'cloud';
  }

  static Future<void> saveConfig(String apiUrl, String cameraUrl, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyApiUrl, apiUrl);
    await prefs.setString(keyCameraUrl, cameraUrl);
    await prefs.setString(keyMode, mode);
  }
}