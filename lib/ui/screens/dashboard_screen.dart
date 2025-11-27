import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Sử dụng MediaKit (Nhẹ, mượt, hỗ trợ tốt Windows/Android)
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../logic/blocs/weighing_bloc.dart';
import '../../data/services/config_service.dart';
import 'settings_screen.dart';
import 'history_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Khai báo Controller của MediaKit
  late final Player _player;
  late final VideoController _controller;
  
  bool _isAppReady = false; // Biến kiểm soát quá trình khởi động

  @override
  void initState() {
    super.initState();
    
    // 1. Khởi tạo Player ngay lập tức
    _player = Player();
    
    // 2. Tạo Controller cho Video Widget
    _controller = VideoController(
      _player, 
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true, // MediaKit xử lý GPU rất tốt
        scale: 1.0,
      )
    );

    // 3. Chiến thuật Lazy Loading: Đợi UI vẽ xong mới kết nối mạng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLazyLoading();
    });
  }

  void _startLazyLoading() async {
    // Delay 0.5s để hiện khung giao diện trước
    await Future.delayed(Duration(milliseconds: 500));
    if (!mounted) return;
    
    setState(() => _isAppReady = true);

    // Bắt đầu kết nối SignalR
    context.read<WeighingBloc>().add(InitSignalR());
    
    // Bắt đầu load Camera
    _initCamera();
  }

  Future<void> _initCamera() async {
    // Lấy link Camera từ Cài đặt
    String camUrl = await AppConfig.getCameraUrl();
    print("🎥 MediaKit đang kết nối: $camUrl");

    // === CẤU HÌNH TỐI ƯU (FIX LỖI SETPROPERTY) ===
    
    // Ép kiểu dynamic để gọi lệnh native xuống MPV (Backend của MediaKit)
    final platform = _player.platform as dynamic;

    try {
      // Giảm độ trễ xuống thấp nhất (Low Latency)
      await platform.setProperty('network-caching', '150'); 
      // Bắt buộc dùng TCP để hình ảnh ổn định, không vỡ hình
      await platform.setProperty('rtsp-transport', 'tcp');
      // Đồng bộ hình ảnh để mượt mà hơn
      await platform.setProperty('video-sync', 'display-resample');
    } catch (e) {
      print("Lỗi cấu hình MPV: $e");
    }

    // Mở luồng Video
    await _player.open(
      Media(camUrl),
      play: true, // Tự động phát
    );
  }

  @override
  void dispose() {
    // Giải phóng tài nguyên khi thoát
    _player.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // MÀN HÌNH CHỜ (SPLASH)
    if (!_isAppReady) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 15),
              Text("Đang khởi động hệ thống...", style: TextStyle(color: Colors.grey))
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        elevation: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Trạm Cân Thông Minh", style: TextStyle(fontWeight: FontWeight.bold)),
            // Hiển thị chế độ đang chạy (Local hay Cloud)
            FutureBuilder<String>(
              future: AppConfig.getCurrentMode(),
              builder: (context, snapshot) {
                String modeText = "---";
                Color statusColor = Colors.white70;
                if (snapshot.hasData) {
                  if (snapshot.data == 'cloud') {
                    modeText = "☁️ Azure Cloud";
                    statusColor = Colors.orangeAccent;
                  } else {
                    modeText = "🏠 Mạng Nội Bộ (LAN)";
                    statusColor = Colors.lightGreenAccent;
                  }
                }
                return Text(modeText, style: TextStyle(fontSize: 12, color: statusColor));
              },
            )
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            tooltip: "Lịch sử",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen())),
          ),
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: "Cài đặt",
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()));
              if (result == true) {
                 // Nếu người dùng Lưu cấu hình -> Stop và Load lại
                 await _player.stop(); 
                 setState(() {});
                 _initCamera();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.cloud_sync),
            tooltip: "Đồng bộ",
            onPressed: () => context.read<WeighingBloc>().add(SyncOffline()),
          ),
        ],
      ),
      body: Column(
        children: [
          // === KHU VỰC 1: CAMERA MONITOR (MEDIA KIT) ===
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Widget Video của MediaKit
                  Video(
                    controller: _controller,
                    fit: BoxFit.contain, // Giữ đúng tỷ lệ hình ảnh
                    controls: NoVideoControls, // Ẩn thanh tua/play/pause
                  ),
                  
                  // Nhãn LIVE
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                      child: Text("LIVE CAM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  )
                ],
              ),
            ),
          ),
          
          // === KHU VỰC 2: THÔNG TIN & ĐIỀU KHIỂN ===
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(12.0),
              child: BlocConsumer<WeighingBloc, WeighingState>(
                listener: (context, state) {
                  if (state.message.isNotEmpty) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: state.message.contains("Lỗi") ? Colors.red : Colors.green[700],
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  return Column(
                    children: [
                      // Thẻ Biển Số
                      _buildInfoCard("BIỂN SỐ XE", state.plate, Colors.blue[800]!, Icons.directions_car),
                      
                      SizedBox(height: 10),
                      
                      // Thẻ Khối Lượng
                      _buildInfoCard("KHỐI LƯỢNG (KG)", state.weight, Colors.red[700]!, Icons.scale, isLarge: true),
                      
                      Spacer(),
                      
                      // NÚT CÂN XE
                      SizedBox(
                        width: double.infinity, 
                        height: 65,
                        child: ElevatedButton.icon(
                          icon: state.isBusy 
                              ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : Icon(Icons.save, size: 32),
                          label: Text(state.isBusy ? "ĐANG LƯU..." : "LƯU PHIẾU CÂN", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 4,
                          ),
                          onPressed: state.isBusy ? null : () => context.read<WeighingBloc>().add(SubmitTicket()),
                        ),
                      ),
                      
                      SizedBox(height: 12),
                      
                      // HÀNG NÚT PHỤ
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.lock_open),
                              label: Text("MỞ BARRIER"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[800], 
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => context.read<WeighingBloc>().add(TriggerBarrier()),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.edit_note),
                              label: Text("NHẬP THỦ CÔNG"),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.blue[700]!, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showManualInputDialog(context),
                            ),
                          ),
                        ],
                      )
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, Color color, IconData icon, {bool isLarge = false}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(10), 
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        border: Border.all(color: Colors.grey[300]!)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, color: Colors.grey[600], size: 26), 
            SizedBox(width: 10), 
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700]))
          ]),
          Text(value, style: TextStyle(
            fontSize: isLarge ? 36 : 26, 
            fontWeight: FontWeight.bold, 
            color: color, 
            fontFamily: 'monospace'
          )),
        ],
      ),
    );
  }

  void _showManualInputDialog(BuildContext context) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Nhập Xe Thủ Công"),
        content: TextField(
          controller: noteController, 
          decoration: InputDecoration(hintText: "Biển số / Ghi chú...", border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Hủy")),
          ElevatedButton(
            onPressed: () { 
              Navigator.pop(ctx); 
              context.read<WeighingBloc>().add(SubmitTicket(note: noteController.text)); 
            }, 
            child: Text("Lưu & Cân")
          ),
        ],
      ),
    );
  }
}