import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../data/local/database_helper.dart';
import '../../data/models/phieu_can_model.dart';
import '../../data/services/name_cache_service.dart';
import '../../logic/blocs/weighing_bloc.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final NameCacheService _nameCacheService = NameCacheService();

  List<PhieuCanModel> _list = [];
  bool _isLoading = false;

  DateTime? _selectedDate;
  bool _showAllDates = false;

  int _totalCount = 0;
  double _totalWeight = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadLocalData();
    // Sau khi màn hình dựng xong, trigger sync một lần
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeighingBloc>().add(SyncDataEvent());
    });
  }

  Future<void> _loadLocalData() async {
    setState(() => _isLoading = true);

    await _nameCacheService.initCache();

    final db = DatabaseHelper.instance;
    List<PhieuCanModel> data;

    if (_showAllDates || _selectedDate == null) {
      data = await db.getAllPhieu();
    } else {
      data = await db.getHistoryByDate(_selectedDate!);
    }

    if (!mounted) return;

    double totalWeight = 0;
    for (final item in data) {
      totalWeight += item.tlHang;
    }

    setState(() {
      _list = data;
      _isLoading = false;
      _totalCount = data.length;
      _totalWeight = totalWeight;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _showAllDates = false;
      });
      _loadLocalData();
    }
  }

  String _formatDateLabel() {
    if (_showAllDates || _selectedDate == null) return 'Tất cả ngày';
    return DateFormat('dd/MM/yyyy').format(_selectedDate!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Lịch Sử Cân"),
        backgroundColor: Colors.blue[800],
      ),
      body: BlocListener<WeighingBloc, WeighingState>(
        listener: (context, state) {
          final msg = state.message.toLowerCase();
          if (msg.contains("đồng bộ") ||
              msg.contains("thành công") ||
              msg.contains("xóa")) {
            _loadLocalData();
          }
        },
        child: Column(
          children: [
            BlocBuilder<WeighingBloc, WeighingState>(
              builder: (context, state) => state.isBusy
                  ? LinearProgressIndicator(
                      color: Colors.blue[800],
                      backgroundColor: Colors.blue[100],
                    )
                  : const SizedBox.shrink(),
            ),
            _buildFilterBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    context.read<WeighingBloc>().add(SyncDataEvent()),
                child: _list.isEmpty
                    ? Center(
                        child: Text(
                          _isLoading
                              ? "Đang tải..."
                              : "Chưa có phiếu cân trong khoảng này.",
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _buildHistoryItem(context, _list[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: _showAllDates ? null : _pickDate,
                icon: const Icon(Icons.date_range),
                label: Text(_formatDateLabel()),
              ),
              const Spacer(),
              Row(
                children: [
                  const Text(
                    'Tất cả',
                    style: TextStyle(fontSize: 12),
                  ),
                  Switch(
                    value: _showAllDates,
                    onChanged: (value) {
                      setState(() => _showAllDates = value);
                      _loadLocalData();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Số phiếu: $_totalCount   |   Khối lượng: ${NumberFormat("#,###").format(_totalWeight)} kg',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, PhieuCanModel item) {
    final dateStr = item.thoiGianCanTong != null
        ? DateFormat('dd/MM HH:mm')
            .format(DateTime.parse(item.thoiGianCanTong!))
        : 'N/A';

    final tenKhach = _nameCacheService.getTenKhachHang(item.maCongTyNhap);
    final tenHang = _nameCacheService.getTenHangHoa(item.maLoai);
    final tenNoiXuat = _nameCacheService.getTenNoiXuat(item.maCongTyBan);

    final synced = item.isSynced == 1;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _showTicketDetails(context, item),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    synced ? Icons.cloud_done : Icons.cloud_upload,
                    color: synced ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    synced ? "Synced" : "Queue",
                    style: TextStyle(
                      fontSize: 11,
                      color: synced ? Colors.green[800] : Colors.orange[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.bienSo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tenKhach,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      tenHang,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      tenNoiXuat,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat("#,###").format(item.tlHang),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue[900],
                    ),
                  ),
                  const Text(
                    "kg",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTicketDetails(BuildContext context, PhieuCanModel item) {
    final tenKhach = _nameCacheService.getTenKhachHang(item.maCongTyNhap);
    final tenHang = _nameCacheService.getTenHangHoa(item.maLoai);
    final tenNoiXuat = _nameCacheService.getTenNoiXuat(item.maCongTyBan);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Phiếu #${item.id}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRow(
                Icons.local_shipping,
                "Biển số",
                item.bienSo,
                isBold: true,
              ),
              const Divider(),
              _buildRow(Icons.person, "Khách hàng", tenKhach),
              _buildRow(Icons.store, "Nơi xuất", tenNoiXuat),
              _buildRow(Icons.category, "Loại hàng", tenHang),
              const Divider(),
              _buildRow(
                Icons.scale,
                "Tổng",
                "${NumberFormat('#,###').format(item.tlTong)} kg",
              ),
              _buildRow(
                Icons.scale_outlined,
                "Bì",
                "${NumberFormat('#,###').format(item.tlBi)} kg",
              ),
              _buildRow(
                Icons.inventory_2,
                "Hàng",
                "${NumberFormat('#,###').format(item.tlHang)} kg",
                isBold: true,
              ),
              const Divider(),
              _buildRow(
                Icons.person_outline,
                "Người cân",
                item.nguoiCan ?? "N/A",
              ),
              _buildRow(
                Icons.schedule,
                "Thời gian",
                item.thoiGianCanTong ?? "N/A",
              ),
              if (item.ghiChu != null && item.ghiChu!.isNotEmpty)
                _buildRow(Icons.note, "Ghi chú", item.ghiChu!),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Đóng"),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    IconData icon,
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$label:",
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
