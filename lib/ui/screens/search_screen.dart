import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../logic/blocs/weighing_bloc.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/phieu_can_model.dart';
import '../../data/services/name_cache_service.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final NameCacheService _nameCacheService = NameCacheService();
  final _controller = TextEditingController();
  List<PhieuCanModel> _allData = [];
  List<PhieuCanModel> _filteredData = [];
  String _filterType = 'Biển số';
  bool _isSearching = false;

  final Map<String, String> _criteria = {
    'Biển số': 'bienSo',
    'Số phiếu': 'id',
    'Khách hàng': 'maCongTyNhap', // Map với trường Mã trong Model mới
    'Loại hàng': 'maLoai',        // Map với trường Mã
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final list = await DatabaseHelper.instance.getAllPhieuCan();
    if (mounted) {
      setState(() {
        _allData = list;
        _filteredData = list;
        // Chạy lại bộ lọc nếu có text sẵn
        if (_controller.text.isNotEmpty) _search(_controller.text);
      });
    }
  }

  void _search(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() => _isSearching = true);

    List<PhieuCanModel> results = [];

    if (query.isEmpty) {
      results = List.from(_allData);
    } else {
      results = _allData.where((item) {
        if (_filterType == 'Biển số') return item.bienSo.toLowerCase().contains(lowerQuery);
        if (_filterType == 'Số phiếu') return item.id.toString().contains(lowerQuery);
        
        // LOGIC MỚI: Tìm theo tên (Dùng cache dịch Mã -> Tên)
        if (_filterType == 'Khách hàng') {
          final ten = _nameCacheService.getTenKhachHang(item.maCongTyNhap).toLowerCase();
          return ten.contains(lowerQuery);
        }
        if (_filterType == 'Loại hàng') {
          final ten = _nameCacheService.getTenHangHoa(item.maLoai).toLowerCase();
          return ten.contains(lowerQuery);
        }
        return false;
      }).toList();
    }

    setState(() {
      _filteredData = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: Text("Tra Cứu Thông Tin"), backgroundColor: Colors.blue[800]),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _criteria.keys.map((key) {
                      final isSelected = _filterType == key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(key),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _filterType = key);
                              _search(_controller.text);
                            }
                          },
                          selectedColor: Colors.blue[100],
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.blue[900] : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Nhập ${_filterType.toLowerCase()}...",
                    prefixIcon: Icon(Icons.search),
                    filled: true, fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    suffixIcon: _controller.text.isNotEmpty 
                      ? IconButton(icon: Icon(Icons.clear), onPressed: () { _controller.clear(); _search(''); }) 
                      : null
                  ),
                  onChanged: _search,
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _filteredData.isEmpty
              ? Center(child: Text("Không tìm thấy kết quả nào", style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: EdgeInsets.all(12),
                  itemCount: _filteredData.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10),
                  itemBuilder: (context, index) => _buildResultCard(_filteredData[index]),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(PhieuCanModel item) {
    final displayTime = item.thoiGianCanTong ?? item.thoiGianCanBi;
    final date = displayTime != null ? DateTime.tryParse(displayTime) : null;
    final dateStr = date != null ? DateFormat('dd/MM/yyyy').format(date) : 'N/A';
    
    // Dùng NameCacheService
    final tenKhach = _nameCacheService.getTenKhachHang(item.maCongTyNhap);
    final tenHang = _nameCacheService.getTenHangHoa(item.maLoai);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Phiếu #${item.id}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 12)),
            Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(),
            Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.blue[800], size: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.bienSo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("$tenKhach - $tenHang", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    ],
                  ),
                ),
                Text("${NumberFormat("#,###").format(item.tlHang)} Kg", 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red[700])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}