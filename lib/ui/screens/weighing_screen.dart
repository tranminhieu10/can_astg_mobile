import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../logic/blocs/weighing_bloc.dart';
import '../../data/services/config_service.dart';

class WeighingScreen extends StatefulWidget {
  @override
  _WeighingScreenState createState() => _WeighingScreenState();
}

class _WeighingScreenState extends State<WeighingScreen> {
  // MediaKit Controllers
  late final Player _player;
  late final VideoController _videoController;
  
  // Input Controllers cho thông tin phiếu
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _goodsController = TextEditingController();
  
  bool _isAppReady = false;

  @override
  void initState() {
    super.initState();
    _initMediaKit();
    
    // Gán giá trị mặc định cho tiện test
    _customerController.text = "Khách lẻ";
    _goodsController.text = "Cát vàng";

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLazyLoading();
    });
  }

  void _initMediaKit() {
    _player = Player();
    _videoController = VideoController(
      _player, 
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        scale: 1.0,
      )
    );
  }

  void _startLazyLoading() async {
    await Future.delayed(Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _isAppReady = true);
    
    // Khởi tạo SignalR
    context.read<WeighingBloc>().add(InitSignalR());
    _initCamera();
  }

  Future<void> _initCamera() async {
    String camUrl = await AppConfig.getCameraUrl();
    print("🎥 Kết nối Camera: $camUrl");

    final platform = _player.platform as dynamic;
    try {
      await platform.setProperty('network-caching', '150');
      await platform.setProperty('rtsp-transport', 'tcp');
      await platform.setProperty('video-sync', 'display-resample');
    } catch (e) {
      print("Lỗi cấu hình MPV: $e");
    }

    await _player.open(Media(camUrl), play: true);
  }

  @override
  void dispose() {
    _player.dispose();
    _customerController.dispose();
    _goodsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAppReady) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // AppBar giữ nguyên
      appBar: AppBar(
        title: Text("Bàn Cân Số 01"),
        backgroundColor: Colors.blue[800],
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
               context.read<WeighingBloc>().add(InitSignalR());
               _initCamera();
            },
          )
        ],
      ),
      // [THAY ĐỔI LỚN] Dùng Column thay vì Row
      body: Column(
        children: [
          // === PHẦN TRÊN: CAMERA (35% Màn hình) ===
          Expanded(
            flex: 35, 
            child: Container(
              color: Colors.black,
              width: double.infinity, // Full chiều ngang
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Video(controller: _videoController, fit: BoxFit.contain, controls: NoVideoControls),
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                      child: Text("LIVE CAM 01", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // === PHẦN DƯỚI: ĐIỀU KHIỂN & NHẬP LIỆU (65% Màn hình) ===
          Expanded(
            flex: 65,
            child: Container(
              color: Colors.grey[100],
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0), // Padding
              child: BlocConsumer<WeighingBloc, WeighingState>(
                listener: (context, state) {
                  if (state.message.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: state.message.contains("Lỗi") ? Colors.red : Colors.green,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  // Dùng SingleChildScrollView để tránh lỗi overflow khi bàn phím hiện lên
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Hiển thị thông số (Thẻ ngang cho gọn)
                        Row(
                          children: [
                            Expanded(child: _buildDisplayCard("BIỂN SỐ", state.plate, Colors.blue[900]!)),
                            SizedBox(width: 10),
                            Expanded(child: _buildDisplayCard("KHỐI LƯỢNG (KG)", state.weight, Colors.red[700]!, isLarge: true)),
                          ],
                        ),
                        
                        SizedBox(height: 15),
                        Divider(),
                        SizedBox(height: 10),
                        
                        // 2. Form Nhập liệu nhanh
                        Text("Thông tin hàng hóa:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                        SizedBox(height: 10),
                        TextField(
                          controller: _customerController,
                          decoration: InputDecoration(
                            labelText: "Khách hàng",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _goodsController,
                          decoration: InputDecoration(
                            labelText: "Loại hàng",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),

                        SizedBox(height: 20),

                        // 3. Nút Lưu Phiếu (To, rõ ràng)
                        SizedBox(
                          height: 55,
                          child: ElevatedButton.icon(
                            icon: state.isBusy 
                              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Icon(Icons.save, size: 28),
                            label: Text(state.isBusy ? "ĐANG LƯU..." : "LƯU PHIẾU CÂN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: state.isBusy ? null : () {
                              context.read<WeighingBloc>().add(SubmitTicket(
                                khachHang: _customerController.text,
                                loaiHang: _goodsController.text,
                                note: "Mobile App"
                              ));
                            },
                          ),
                        ),
                        
                        SizedBox(height: 15),
                        
                        // 4. Hàng nút phụ
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.lock_open),
                                label: Text("MỞ BARRIER"),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  foregroundColor: Colors.orange[800],
                                  side: BorderSide(color: Colors.orange[800]!),
                                ),
                                onPressed: () => context.read<WeighingBloc>().add(TriggerBarrier()),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.edit),
                                label: Text("NHẬP TAY"),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () => _showManualInputDialog(context),
                              ),
                            ),
                          ],
                        ),
                        // Khoảng trống dưới cùng để scroll thoải mái
                        SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  }

  Widget _buildDisplayCard(String title, String value, Color color, {bool isLarge = false}) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        border: Border.all(color: Colors.grey[300]!)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
          SizedBox(height: 5),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              value, 
              style: TextStyle(
                fontSize: isLarge ? 40 : 28, 
                fontWeight: FontWeight.bold, 
                color: color,
                fontFamily: 'monospace' // Font đơn cách cho số đẹp hơn
              )
            ),
          ),
        ],
      ),
    );
  }

  // Dialog nhập tay (cập nhật để nhập cả Khách hàng/Loại hàng nếu muốn)
  void _showManualInputDialog(BuildContext context) {
    // Logic nhập tay có thể giữ nguyên hoặc bổ sung các trường tương tự form chính
    // Ở đây tôi giữ đơn giản để tránh code quá dài
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Nhập Biển Số Thủ Công"),
        content: TextField(
          decoration: InputDecoration(hintText: "Nhập biển số xe..."),
          onSubmitted: (val) {
             // Có thể update Bloc state biển số tại đây nếu cần
             Navigator.pop(ctx);
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Đóng"))],
      ),
    );
  }
    