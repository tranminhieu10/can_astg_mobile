import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../data/local/database_helper.dart'; 
import '../../data/services/api_service.dart';
import '../../data/services/name_cache_service.dart';
import '../../logic/blocs/auth_bloc.dart';

class HomeDashboard extends StatefulWidget {
  @override
  _HomeDashboardState createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final ApiService _apiService = ApiService();
  
  // Trạng thái bàn cân
  bool _isScale1Active = false;
  String _lastActivity1 = "Chưa có dữ liệu";
  bool _isScale2Active = true; // Giả lập bàn 2 như code gốc

  @override
  void initState() {
    super.initState();
    // 1. Khởi tạo Cache Danh Mục (Logic mới)
    NameCacheService().initCache();
    // 2. Kiểm tra trạng thái
    _checkScaleStatus();
  }

  Future<void> _checkScaleStatus() async {
    final lastPhieu = await DatabaseHelper.instance.getLatestPhieuCan();
    
    if (mounted) {
      setState(() {
        if (lastPhieu != null) {
          final displayTime = lastPhieu.thoiGianCanTong ?? lastPhieu.thoiGianCanBi;
          if (displayTime != null) {
            try {
              final lastTime = DateTime.parse(displayTime);
              final diff = DateTime.now().difference(lastTime).inMinutes;
              _isScale1Active = diff < 60; // Active nếu < 60p
              _lastActivity1 = DateFormat('HH:mm dd/MM').format(lastTime);
            } catch (e) {
              _lastActivity1 = "Lỗi thời gian";
            }
          }
        } else {
          _isScale1Active = false;
          _lastActivity1 = "Chưa hoạt động";
        }
      });
    }
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Đăng xuất"),
          content: const Text("Bạn có chắc muốn đăng xuất khỏi ứng dụng?"),
          actions: <Widget>[
            TextButton(
              child: const Text("HỦY"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("ĐĂNG XUẤT", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                context.read<AuthBloc>().add(LogoutEvent());
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleBarrierCommand(String command) async {
    Navigator.of(context).pop(); // Đóng dialog
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đang gửi lệnh $command...")));
    
    final bool success = await _apiService.controlBarrier(command);
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? 'Thành công!' : 'Thất bại! Kiểm tra kết nối.'),
      backgroundColor: success ? Colors.green : Colors.red,
    ));
  }

  void _showBarrierControlDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Điều Khiển Barrier"),
          content: Text("Chọn hành động bạn muốn thực hiện:"),
          actions: <Widget>[
            TextButton(child: Text("MỞ BARRIER", style: TextStyle(color: Colors.blue)), onPressed: () => _handleBarrierCommand('OPEN')),
            TextButton(child: Text("ĐÓNG BARRIER", style: TextStyle(color: Colors.orange)), onPressed: () => _handleBarrierCommand('CLOSE')),
            TextButton(child: Text("HỦY", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.of(context).pop()),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final userName = authState.userName ?? 'Admin User';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("QUẢN LÝ TRẠM CÂN", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(userName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
              ],
            );
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
          PopupMenuButton<String>(
            icon: const CircleAvatar(child: Text("AD"), backgroundColor: Colors.white, radius: 18),
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutConfirmDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Thông tin cá nhân'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _checkScaleStatus,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("TRẠM CÂN & GIÁM SÁT", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900])),
              SizedBox(height: 15),
              
              // ROW 1: HAI BÀN CÂN
              Row(
                children: [
                  Expanded(
                    child: _buildScaleStatusCard(
                      title: "BÀN CÂN SỐ 01",
                      subtitle: "Hoạt động lần cuối:\n$_lastActivity1",
                      isActive: _isScale1Active,
                      onTap: () => Navigator.pushNamed(context, '/weighing'),
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: _buildScaleStatusCard(
                      title: "BÀN CÂN SỐ 02",
                      subtitle: "Đang hoạt động\nIP: 192.168.1.36",
                      isActive: _isScale2Active,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bàn 2 chưa kết nối API"))),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 25),
              Text("CHỨC NĂNG QUẢN LÝ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900])),
              SizedBox(height: 15),

              // GRID MENU (Giữ nguyên GridView của bạn)
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.0, // Vuông vắn
                children: [
                  _buildFeatureCard(
                    icon: Icons.bar_chart, 
                    color: Colors.purple, 
                    title: "THỐNG KÊ", 
                    desc: "Theo khách hàng,\nloại hàng...", 
                    onTap: () => Navigator.pushNamed(context, '/history')
                  ),
                  _buildFeatureCard(
                    icon: Icons.search, 
                    color: Colors.orange, 
                    title: "TRA CỨU", 
                    desc: "Tìm theo biển số,\nsố phiếu...", 
                    onTap: () => Navigator.pushNamed(context, '/search')
                  ),
                  _buildFeatureCard(
                    icon: Icons.traffic, 
                    color: Colors.blue, 
                    title: "ĐIỀU KHIỂN BARRIER", 
                    desc: "Mở/Đóng khẩn cấp\ntừ xa", 
                    onTap: _showBarrierControlDialog
                  ),
                  _buildFeatureCard(
                    icon: Icons.settings, 
                    color: Colors.grey, 
                    title: "CẤU HÌNH", 
                    desc: "API, Camera,\nKết nối mạng", 
                    onTap: () async {
                      await Navigator.pushNamed(context, '/settings');
                      _checkScaleStatus();
                      NameCacheService().initCache(); // Reload cache nếu đổi cấu hình
                    }
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScaleStatusCard({required String title, required String subtitle, required bool isActive, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: isActive ? Colors.green : Colors.red, width: 5))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.monitor_weight, color: isActive ? Colors.green : Colors.red, size: 30),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: (isActive ? Colors.green : Colors.red).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(isActive ? "Active" : "Paused", style: TextStyle(color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                ],
              ),
              SizedBox(height: 12),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 5),
              Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({required IconData icon, required Color color, required String title, required String desc, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color), radius: 25),
              SizedBox(height: 10),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text(desc, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}