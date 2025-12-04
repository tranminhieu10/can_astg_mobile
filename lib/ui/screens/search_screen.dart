import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/local/database_helper.dart';
import '../../data/models/phieu_can_model.dart';
import '../../data/services/name_cache_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final NameCacheService _nameCacheService = NameCacheService();
  final TextEditingController _controller = TextEditingController();

  List<PhieuCanModel> _allData = [];
  List<PhieuCanModel> _filteredData = [];

  String _filterType = 'Biển số';
  bool _isSearching = false;
  bool _isLoading = false;

  final Map<String, String> _criteria = {
    'Biển số': 'bienSo',
    'Số phiếu': 'id',
    'Khách hàng': 'maCongTyNhap', // map với mã khách
    'Loại hàng': 'maLoai',        // map với mã hàng
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await _nameCacheService.initCache();
    final list = await DatabaseHelper.instance.getAllPhieu();

    if (!mounted) return;

    setState(() {
      _allData = list;
      _filteredData = list;
      _isLoading = false;
      if (_controller.text.isNotEmpty) {
        _search(_controller.text);
      }
    });
  }

  void _search(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() => _isSearching = true);

    List<PhieuCanModel> results = [];

    if (query.isEmpty) {
      results = List.from(_allData);
    } else {
      results = _allData.where((item) {
        if (_filterType == 'Biển số') {
          return item.bienSo.toLowerCase().contains(lowerQuery);
        }
        if (_filterType == 'Số phiếu') {
          return item.id.toString().contains(lowerQuery);
        }

        // Tìm theo tên (dùng cache: Mã -> Tên)
        if (_filterType == 'Khách hàng') {
          final ten =
              _nameCacheService.getTenKhachHang(item.maCongTyNhap).toLowerCase();
          return ten.contains(lowerQuery);
        }
        if (_filterType == 'Loại hàng') {
          final ten =
              _nameCacheService.getTenHangHoa(item.maLoai).toLowerCase();
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Tra Cứu Thông Tin"),
        backgroundColor: Colors.blue[800],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
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
                            color: isSelected
                                ? Colors.blue[900]
                                : Colors.black,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Nhập ${_filterType.toLowerCase()}...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              _search('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _search,
                ),
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Đang tìm...",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredData.isEmpty
                    ? const Center(
                        child: Text(
                          "Không tìm thấy kết quả nào",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredData.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _buildResultCard(_filteredData[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(PhieuCanModel item) {
    final displayTime = item.thoiGianCanTong ?? item.thoiGianCanBi;
    final date = displayTime != null
        ? DateTime.tryParse(displayTime)
        : null;
    final dateStr =
        date != null ? DateFormat('dd/MM/yyyy').format(date) : 'N/A';

    final tenKhach = _nameCacheService.getTenKhachHang(item.maCongTyNhap);
    final tenHang = _nameCacheService.getTenHangHoa(item.maLoai);

    final synced = item.isSynced == 1;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  children: [
                    Icon(
                      synced ? Icons.cloud_done : Icons.cloud_upload,
                      size: 18,
                      color: synced ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      synced ? "Synced" : "Queue",
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            synced ? Colors.green[800] : Colors.orange[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Phiếu #${item.id}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.bienSo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$tenKhach - $tenHang",
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${NumberFormat("#,###").format(item.tlHang)} Kg",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
