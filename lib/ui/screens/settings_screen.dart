import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/config_service.dart';
import '../../logic/blocs/weighing_bloc.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiController = TextEditingController();
  final _cameraController = TextEditingController();
  String _currentMode = 'local'; // 'local' hoặc 'cloud'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _apiController.text = await AppConfig.getApiUrl();
    _cameraController.text = await AppConfig.getCameraUrl();
    _currentMode = await AppConfig.getCurrentMode();
    setState(() => _isLoading = false);
  }

  // Hàm chuyển đổi chế độ nhanh
  void _switchMode(String mode) {
    setState(() {
      _currentMode = mode;
      if (mode == 'local') {
        _apiController.text = AppConfig.localApi;
        _cameraController.text = AppConfig.localCamera;
      } else {
        _apiController.text = AppConfig.azureApi;
        _cameraController.text = AppConfig.azureCamera;
      }
    });
  }

  Future<void> _saveSettings() async {
    await AppConfig.saveConfig(
      _apiController.text, 
      _cameraController.text,
      _currentMode
    );
    
    // Khởi động lại kết nối SignalR
    context.read<WeighingBloc>().add(InitSignalR());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã lưu cấu hình $_currentMode thành công!")));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Cấu Hình Kết Nối")),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("CHỌN CHẾ ĐỘ HOẠT ĐỘNG:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                SizedBox(height: 10),
                
                // === THẺ CHỌN CHẾ ĐỘ ===
                Row(
                  children: [
                    Expanded(
                      child: _buildModeCard(
                        title: "NỘI BỘ (LAN)",
                        icon: Icons.computer,
                        mode: 'local',
                        color: Colors.green,
                        desc: "Dùng IP: 192.168.1.35"
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildModeCard(
                        title: "CLOUD (AZURE)",
                        icon: Icons.cloud,
                        mode: 'cloud',
                        color: Colors.blue,
                        desc: "Kết nối qua Internet"
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 30),
                Text("CHI TIẾT CẤU HÌNH:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                SizedBox(height: 10),

                TextField(
                  controller: _apiController,
                  decoration: InputDecoration(
                    labelText: "API Server URL",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                    suffixIcon: _currentMode == 'local' ? Icon(Icons.wifi, color: Colors.green) : Icon(Icons.public, color: Colors.blue)
                  ),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: _cameraController,
                  decoration: InputDecoration(
                    labelText: "RTSP Camera URL",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.videocam),
                  ),
                ),

                SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: Icon(Icons.save),
                  label: Text("LƯU CẤU HÌNH", style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: _currentMode == 'local' ? Colors.green : Colors.blue
                  ),
                  onPressed: _saveSettings,
                )
              ],
            ),
          ),
    );
  }

  Widget _buildModeCard({
    required String title, 
    required IconData icon, 
    required String mode, 
    required Color color,
    required String desc
  }) {
    bool isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[200],
          border: Border.all(
            color: isSelected ? color : Colors.transparent, 
            width: 2
          ),
          borderRadius: BorderRadius.circular(10)
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: isSelected ? color : Colors.grey),
            SizedBox(height: 10),
            Text(title, style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: isSelected ? color : Colors.black87
            )),
            SizedBox(height: 5),
            Text(desc, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}