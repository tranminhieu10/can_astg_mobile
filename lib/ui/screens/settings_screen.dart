import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/services/config_service.dart';
import '../../data/services/name_cache_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiController = TextEditingController();
  final TextEditingController _cameraController = TextEditingController();

  /// 'local' hoặc 'cloud' (theo AppConfig.getCurrentMode)
  String _selectedMode = 'cloud';

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isTestingApi = false;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);

    // Các hàm này trong AppConfig đều trả về String (không nullable)
    final apiUrl = await AppConfig.getApiUrl();
    final cameraUrl = await AppConfig.getCameraUrl();
    final mode = await AppConfig.getCurrentMode(); // 'local' hoặc 'cloud'

    if (!mounted) return;

    // Đảm bảo mode chỉ là 'local' hoặc 'cloud'
    final normalizedMode =
        (mode == 'local' || mode == 'cloud') ? mode : 'cloud';

    setState(() {
      _apiController.text = apiUrl;
      _cameraController.text = cameraUrl;
      _selectedMode = normalizedMode;
      _isLoading = false;
    });
  }

  Future<bool> _testApiUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    try {
      final uri = Uri.parse(trimmed);
      final client = HttpClient();

      final req =
          await client.getUrl(uri).timeout(const Duration(seconds: 8));
      final res =
          await req.close().timeout(const Duration(seconds: 8));
      client.close();

      // Server có phản hồi (kể cả 400, 404) thì coi như kết nối ok
      return res.statusCode >= 200 && res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _onTestApi() async {
    final url = _apiController.text.trim();
    if (url.isEmpty) {
      _showSnackBar("Vui lòng nhập API URL trước.");
      return;
    }

    setState(() => _isTestingApi = true);
    final ok = await _testApiUrl(url);
    setState(() => _isTestingApi = false);

    if (ok) {
      _showSnackBar("Kết nối API thành công.");
    } else {
      _showSnackBar(
        "Không kết nối được tới API. Vui lòng kiểm tra lại địa chỉ hoặc mạng.",
      );
    }
  }

  Future<void> _onSave() async {
    final apiUrl = _apiController.text.trim();
    final cameraUrl = _cameraController.text.trim();

    if (apiUrl.isEmpty) {
      _showSnackBar("API URL không được để trống.");
      return;
    }

    setState(() => _isSaving = true);

    // AppConfig của bạn dùng 1 hàm saveConfig để lưu cả 3 giá trị
    await AppConfig.saveConfig(apiUrl, cameraUrl, _selectedMode);

    setState(() => _isSaving = false);

    _showSnackBar("Đã lưu cấu hình hệ thống.");
  }

  Future<void> _onClearCache() async {
    setState(() => _isClearingCache = true);

    // NameCacheService hiện có hàm clear()
    final cache = NameCacheService();
    cache.clear();

    // Cho UX mượt hơn một chút
    await Future.delayed(const Duration(milliseconds: 200));

    setState(() => _isClearingCache = false);
    _showSnackBar(
      "Đã xóa cache danh mục. Dữ liệu sẽ được tải lại từ server khi cần.",
    );
  }

  @override
  void dispose() {
    _apiController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isLoading || _isSaving || _isTestingApi || _isClearingCache;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt hệ thống'),
      ),
      body: Column(
        children: [
          if (busy)
            LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.blue[50],
              color: Colors.blue[800],
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildApiAndCameraCard(),
                  const SizedBox(height: 16),
                  _buildModeCard(),
                  const SizedBox(height: 16),
                  _buildCacheCard(),
                ],
              ),
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildApiAndCameraCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KẾT NỐI HỆ THỐNG',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiController,
              decoration: const InputDecoration(
                labelText: 'API URL',
                hintText: 'VD: http://192.168.1.35:5225',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cameraController,
              decoration: const InputDecoration(
                labelText: 'Camera URL (RTSP / HTTP)',
                hintText: 'VD: rtsp://user:pass@ip:port/...',
                prefixIcon: Icon(Icons.videocam),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'API URL dùng cho kết nối tới server WTM/Azure.\n'
              'Camera URL dùng để xem hình ảnh xe trên màn hình cân.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard() {
    final isLocal = _selectedMode == 'local';
    final isCloud = _selectedMode == 'cloud';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CHẾ ĐỘ HOẠT ĐỘNG',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Local / Nội bộ'),
                  selected: isLocal,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedMode = 'local');
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Cloud (Azure)'),
                  selected: isCloud,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedMode = 'cloud');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isLocal
                  ? 'Chế độ LOCAL: hệ thống ưu tiên kết nối mạng nội bộ, phù hợp trạm cân trong nhà máy/kho bãi.'
                  : 'Chế độ CLOUD: dữ liệu ưu tiên đồng bộ với server Azure, phù hợp khi cần giám sát từ xa.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DANH MỤC & CACHE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ứng dụng lưu cache các danh mục (khách hàng, nơi xuất, loại hàng) để tăng tốc và hỗ trợ làm việc offline.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: _isClearingCache
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_sweep),
              label: const Text('Xóa cache danh mục'),
              onPressed: _isClearingCache ? null : _onClearCache,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: _isTestingApi
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: const Text('Kiểm tra API'),
              onPressed: _isTestingApi ? null : _onTestApi,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: const Text('Lưu cấu hình'),
              onPressed: _isSaving ? null : _onSave,
            ),
          ),
        ],
      ),
    );
  }
}
