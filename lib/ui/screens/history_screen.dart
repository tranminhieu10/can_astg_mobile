import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/phieu_can_model.dart';
import '../../data/services/name_cache_service.dart';
import '../../logic/blocs/weighing_bloc.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final NameCacheService _nameCacheService = NameCacheService();
  List<PhieuCanModel> _list = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeighingBloc>().add(SyncDataEvent());
    });
  }

  Future<void> _loadLocalData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllPhieuCan();
    if (mounted) {
      setState(() {
        _list = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: Text("Lịch Sử Cân"), backgroundColor: Colors.blue[800]),
      body: BlocListener<WeighingBloc, WeighingState>(
        listener: (context, state) {
          if (state.message.toLowerCase().contains("đồng bộ") || 
              state.message.toLowerCase().contains("thành công") ||
              state.message.toLowerCase().contains("xóa")) {
            _loadLocalData();
          }
        },
        child: Column(
          children: [
            BlocBuilder<WeighingBloc, WeighingState>(
              builder: (context, state) => state.isBusy 
                ? LinearProgressIndicator(color: Colors.blue[800], backgroundColor: Colors.blue[100]) 
                : SizedBox.shrink(),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => context.read<WeighingBloc>().add(SyncDataEvent()),
                child: _list.isEmpty
                    ? Center(child: Text(_isLoading ? "Đang tải..." : "Chưa có phiếu cân."))
                    : ListView.separated(
                        padding: EdgeInsets.all(12),
                        itemCount: _list.length,
                        separatorBuilder: (_, __) => SizedBox(height: 10),
                        itemBuilder: (context, index) => _buildHistoryItem(_list[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(PhieuCanModel item) {
    final dateStr = item.thoiGianCanTong != null 
      ? DateFormat('dd/MM HH:mm').format(DateTime.parse(item.thoiGianCanTong!)) 
      : 'N/A';

    // [FIX LỖI ẢNH 1] Lấy String trực tiếp
    final tenKhach = _nameCacheService.getTenKhachHang(item.maCongTyNhap);
    final tenHang = _nameCacheService.getTenHangHoa(item.maLoai);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _showTicketDetails(context, item),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Column(children: [
                Icon(item.isSynced == 1 ? Icons.cloud_done : Icons.cloud_upload, 
                     color: item.isSynced == 1 ? Colors.green : Colors.orange),
                Text(item.isSynced == 1 ? "Synced" : "Queue", style: TextStyle(fontSize: 10, color: Colors.grey))
              ]),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("#${item.id} - ${item.bienSo}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  // Hiển thị String đã lấy ở trên
                  Text(tenKhach, style: TextStyle(fontSize: 13, color: Colors.black87)),
                  Text(tenHang, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(NumberFormat("#,###").format(item.tlHang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue[900])),
                Text("kg", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showTicketDetails(BuildContext context, PhieuCanModel item) {
    final nf = NumberFormat("#,### 'kg'");
    // [FIX LỖI ẢNH 1] Chuẩn bị dữ liệu String trước
    final tenKhach = _nameCacheService.getTenKhachHang(item.maCongTyNhap);
    final tenHang = _nameCacheService.getTenHangHoa(item.maLoai);
    final tenNoiXuat = _nameCacheService.getTenNoiXuat(item.maCongTyBan);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Phiếu #${item.id}"),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildRow(Icons.local_shipping, "Biển số", item.bienSo, isBold: true),
            Divider(),
            // Sử dụng _buildRow (nhận String) thay vì _buildFutureRow
            _buildRow(Icons.person, "Khách hàng", tenKhach),
            _buildRow(Icons.store, "Nơi xuất", tenNoiXuat),
            _buildRow(Icons.category, "Loại hàng", tenHang),
            if (item.tenTaiXe != null) _buildRow(Icons.face, "Tài xế", item.tenTaiXe!),
            
            // Riêng người cân vẫn là Future nên dùng _buildFutureRow
            _buildFutureRow(Icons.badge, "Người cân", _nameCacheService.getTenNguoiCan(item.nguoiCan), item.nguoiCan ?? "N/A"),
            
            Divider(),
            _buildRow(Icons.download, "KL Tổng", nf.format(item.tlTong)),
            _buildRow(Icons.upload, "KL Bì", nf.format(item.tlBi)),
            _buildRow(Icons.scale, "KL Hàng", nf.format(item.tlHang), isBold: true, color: Colors.red),
          ]),
        ),
        actions: [
            TextButton(
              child: Text("Xóa", style: TextStyle(color: Colors.red)), 
              onPressed: () {
                Navigator.pop(context);
                context.read<WeighingBloc>().add(DeletePhieuCan(item.id!));
              }
            ),
            TextButton(child: Text("Đóng"), onPressed: () => Navigator.pop(context))
        ],
      ),
    );
  }

  // Widget hiển thị String thường
  Widget _buildRow(IconData icon, String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey), SizedBox(width: 8),
        Text("$label:", style: TextStyle(color: Colors.grey[800])), SizedBox(width: 4),
        Expanded(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontWeight: isBold?FontWeight.bold:FontWeight.normal, color: color)))
      ]),
    );
  }

  // Widget hiển thị Future (Chỉ dùng cho Người cân)
  Widget _buildFutureRow(IconData icon, String label, Future<String> future, String initial) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey), SizedBox(width: 8),
        Text("$label:", style: TextStyle(color: Colors.grey[800])), SizedBox(width: 4),
        Expanded(child: FutureBuilder<String>(
          future: future, initialData: initial,
          builder: (_, snap) => Text(snap.data ?? initial, textAlign: TextAlign.end)
        )),
      ]),
    );
  }
}