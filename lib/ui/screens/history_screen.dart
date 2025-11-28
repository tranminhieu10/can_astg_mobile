import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; // Cần thêm intl vào pubspec.yaml

import '../../data/local/database_helper.dart';
import '../../data/models/phieu_can_model.dart';
import '../../logic/blocs/weighing_bloc.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<PhieuCanModel> _list = [];
  double _totalWeight = 0;
  int _totalTrucks = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 1. Tải dữ liệu Local hiện có lên trước cho nhanh
    _loadLocalData();
    
    // 2. Kích hoạt đồng bộ ngay khi vào màn hình
    // Dùng addPostFrameCallback để tránh lỗi gọi Bloc trong quá trình build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeighingBloc>().add(SyncDataEvent());
    });
  }

  // Hàm đọc dữ liệu từ SQLite lên giao diện
  Future<void> _loadLocalData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllPhieuCan();
    
    double sum = 0;
    for (var item in data) sum += item.khoiLuongHang;

    if (mounted) {
      setState(() {
        _list = data;
        _totalTrucks = data.length;
        _totalWeight = sum;
        _isLoading = false;
      });
    }
  }

  // Hàm xử lý khi vuốt xuống để refresh
  Future<void> _onRefresh() async {
    context.read<WeighingBloc>().add(SyncDataEvent());
    // Chờ 2 giây giả lập hoặc chờ Bloc trả về state (nhưng RefreshIndicator cần Future)
    await Future.delayed(Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Lịch Sử & Đồng Bộ"),
        backgroundColor: Colors.blue[800],
      ),
      // BlocListener: Nghe thông báo từ Bloc để reload list
      body: BlocListener<WeighingBloc, WeighingState>(
        listener: (context, state) {
          // Nếu có thông báo (VD: Đồng bộ xong, hoặc Lỗi)
          if (state.message.isNotEmpty) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: state.message.contains("Lỗi") ? Colors.red : Colors.green,
              )
            );

            // Nếu đồng bộ xong (không bận nữa) -> Tải lại dữ liệu từ DB
            if (!state.isBusy) {
              _loadLocalData();
            }
          }
        },
        child: Column(
          children: [
            // === CARD THỐNG KÊ ===
            _buildSummaryCard(),

            // === DANH SÁCH PHIẾU ===
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: _list.isEmpty 
                  ? Center(child: Text("Chưa có dữ liệu phiếu cân"))
                  : ListView.builder(
                      padding: EdgeInsets.all(12),
                      itemCount: _list.length,
                      itemBuilder: (context, index) {
                        return _buildHistoryItem(_list[index]);
                      },
                    ),
              ),
            ),
            
            // Loading indicator khi đang sync
            BlocBuilder<WeighingBloc, WeighingState>(
              builder: (context, state) {
                if (state.isBusy) {
                  return Container(
                    color: Colors.yellow[100],
                    padding: EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text("Đang đồng bộ với máy chủ...", style: TextStyle(color: Colors.orange[900])),
                      ],
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue[800]!, Colors.blue[600]!]),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 8, offset: Offset(0, 4))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Tổng Số Xe", "$_totalTrucks", Icons.local_shipping),
          Container(width: 1, height: 40, color: Colors.white30),
          _buildStatItem("Tổng Khối Lượng", "${NumberFormat("#,###").format(_totalWeight)} kg", Icons.scale),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        SizedBox(height: 5),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildHistoryItem(PhieuCanModel item) {
    final date = DateTime.tryParse(item.thoiGian);
    final dateStr = date != null ? DateFormat('dd/MM HH:mm').format(date) : item.thoiGian;

    return Card(
      elevation: 1,
      margin: EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: item.isSynced == 1 ? Colors.green[100] : Colors.orange[100],
          child: Icon(
            item.isSynced == 1 ? Icons.cloud_done : Icons.cloud_upload,
            color: item.isSynced == 1 ? Colors.green : Colors.orange,
            size: 20,
          ),
        ),
        title: Text(item.bienSo, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text("${item.khachHang} • ${item.loaiHang}", style: TextStyle(fontSize: 12)),
            Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              NumberFormat("#,###").format(item.khoiLuongHang), 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue[800])
            ),
            Text("kg", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}