import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/local/database_helper.dart'; // Đảm bảo import đúng đường dẫn
import 'settings_screen.dart';
import 'search_screen.dart';
import 'history_screen.dart'; // Màn hình thống kê/Lịch sử
import 'weighing_screen.dart'; // LƯU Ý: Đây là file cũ DashboardScreen được đổi tên

class HomeDashboard extends StatefulWidget {
  @override
  _HomeDashboardState createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  // Trạng thái bàn cân
  bool _isScale1Active = false;
  String _lastActivity1 = "Chưa có dữ liệu";
  
  // Giả lập trạng thái bàn 2 (Vì chưa có logic kết nối bàn 2)
  bool _isScale2Active = true; 

  @override
  void initState() {
    super.initState();
    _checkScaleStatus();
  }

  // Logic kiểm tra trạng thái hoạt động dựa trên 15 phút
  Future<void> _checkScaleStatus() async {
    // Lấy phiếu cân mới nhất từ DB
    final allPhieu = await DatabaseHelper.instance.getAllPhieuCan();
    
    if (allPhieu.isNotEmpty) {
      final lastPhieu = allPhieu.first; // Vì query đã orderBy id DESC [cite: 7]
      final lastTime = DateTime.parse(lastPhieu.thoiGian);
      final diff = DateTime.now().difference(lastTime).inMinutes;

      setState(() {
        // Nếu nhỏ hơn 15 phút -> Đang hoạt động
        _isScale1Active = diff < 15;
        _lastActivity1 = DateFormat('HH:mm dd/MM').format(lastTime);
      });
    } else {
      setState(() {
        _isScale1Active = false;
        _lastActivity1 = "Chưa hoạt động";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("QUẢN LÝ TRẠM CÂN", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Admin User", style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(icon: Icon(Icons.notifications), onPressed: () {}),
          CircleAvatar(child: Text("AD"), backgroundColor: Colors.white, radius: 18),
          SizedBox(width: 10),
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
              
              // === ROW 1: HAI BÀN CÂN ===
              Row(
                children: [
                  Expanded(
                    child: _buildScaleStatusCard(
                      title: "BÀN CÂN SỐ 01",
                      subtitle: "Hoạt động lần cuối:\n$_lastActivity1",
                      isActive: _isScale1Active,
                      onTap: () {
                         // Chuyển sang màn hình cân (Dashboard cũ)
                         Navigator.push(context, MaterialPageRoute(builder: (_) => WeighingScreen())); // Cần đổi tên file cũ
                      },
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: _buildScaleStatusCard(
                      title: "BÀN CÂN SỐ 02",
                      subtitle: "Đang hoạt động\nIP: 192.168.1.36",
                      isActive: _isScale2Active,
                      onTap: () {
                        // Logic cho bàn 2
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đang kết nối bàn cân 2...")));
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: 25),
              Text("CHỨC NĂNG QUẢN LÝ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900])),
              SizedBox(height: 15),

              // === GRID CÁC CHỨC NĂNG ===
              // ... Trong home_dashboard.dart

// === GRID CÁC CHỨC NĂNG ===
GridView.count(
  shrinkWrap: true,
  physics: NeverScrollableScrollPhysics(),
  crossAxisCount: 2,
  crossAxisSpacing: 15,
  mainAxisSpacing: 15,
  // [QUAN TRỌNG] Giảm tỷ lệ xuống 1.0 (vuông) hoặc 0.9 (cao hơn) để đủ chỗ chứa chữ
  childAspectRatio: 1.0, 
  children: [
    _buildFeatureCard(
      icon: Icons.bar_chart, // Đã sửa lỗi icon directions_truck ở bài trước
      color: Colors.purple,
      title: "THỐNG KÊ",
      desc: "Theo khách hàng,\nloại hàng...", // Xuống dòng chủ động cho đẹp
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen())),
    ),
    _buildFeatureCard(
      icon: Icons.search,
      color: Colors.orange,
      title: "TRA CỨU",
      desc: "Tìm theo biển số,\nsố phiếu...",
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen())),
    ),
    _buildFeatureCard(
      icon: Icons.settings,
      color: Colors.grey,
      title: "CẤU HÌNH",
      desc: "API, Camera,\nKết nối mạng",
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()));
        _checkScaleStatus();
      },
    ),
    _buildFeatureCard(
      icon: Icons.person_search,
      color: Colors.teal,
      title: "NGƯỜI DÙNG",
      desc: "Quản lý nhân viên,\nphân quyền",
      onTap: () {},
    ),
  ],
)
            ],
          ),
        ),
      ),
    );
  }

  // Widget thẻ trạng thái bàn cân
  Widget _buildScaleStatusCard({
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: isActive ? Colors.green : Colors.red, width: 5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.monitor_weight, color: isActive ? Colors.green : Colors.red, size: 30),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? "Active" : "Paused",
                      style: TextStyle(
                        color: isActive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12
                      ),
                    ),
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

  // Widget thẻ chức năng
  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
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
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color),
                radius: 25,
              ),
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