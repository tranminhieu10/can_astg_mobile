import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/local/database_helper.dart';
import '../../data/models/phieu_can_model.dart';
import '../../data/repositories/weighing_repository.dart';

// Màn hình lịch sử cân
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<PhieuCanModel>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getAllPhieuCan();
    setState(() {
      _data = list;
      _isLoading = false;
    });
  }

  // Hàm gọi Repository để kéo dữ liệu về Server
  Future<void> _pullFromServer() async {
    setState(() => _isLoading = true);

    // Lấy Repository từ context (được inject ở trên cây widget)
    final repo = context.read<WeighingRepository>();

    // Gọi hàm sync
    final int count = await repo.syncFromServer();

    // Load lại dữ liệu local
    await _loadData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã tải thêm $count phiếu từ Server!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch Sử Cân'),
        actions: [
          // Nút tải từ server
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: 'Tải dữ liệu cũ từ Server',
            onPressed: _pullFromServer,
          ),
          // Nút refresh dữ liệu local
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (data == null || data.isEmpty)
              ? const Center(
                  child: Text('Chưa có dữ liệu. Bấm nút ☁️ để tải về.'),
                )
              : ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              item.isSynced == 1 ? Colors.green : Colors.orange,
                          child: Icon(
                            item.isSynced == 1
                                ? Icons.cloud_done
                                : Icons.cloud_off,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          item.bienSo,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${item.khoiLuongHang} kg\n'
                          '${item.thoiGian.replaceAll('T', ' ')}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}
