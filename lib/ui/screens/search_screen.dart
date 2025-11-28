import 'package:flutter/material.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/phieu_can_model.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<PhieuCanModel> _allData = [];
  List<PhieuCanModel> _filteredData = [];
  String _filterType = 'Biển số'; // Mặc định

  // Danh sách tiêu chí tìm kiếm
  final Map<String, String> _criteria = {
    'Biển số': 'bienSo',
    'Số phiếu': 'id', // Hoặc soPhieu nếu có
    'Khách hàng': 'khachHang',
    'Loại hàng': 'loaiHang',
    'Người cân': 'nguoiCan',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final list = await DatabaseHelper.instance.getAllPhieuCan();
    setState(() {
      _allData = list;
      _filteredData = list;
    });
  }

  void _search(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredData = _allData.where((item) {
        // Logic lọc dựa trên tiêu chí đang chọn
        switch (_filterType) {
          case 'Biển số': 
            return item.bienSo.toLowerCase().contains(lowerQuery);
          case 'Số phiếu': 
            return item.id.toString().contains(lowerQuery);
          case 'Khách hàng': 
            return item.khachHang.toLowerCase().contains(lowerQuery);
          case 'Loại hàng': 
            return item.loaiHang.toLowerCase().contains(lowerQuery);
          case 'Người cân': 
            return item.nguoiCan.toLowerCase().contains(lowerQuery);
          default: 
            return item.bienSo.toLowerCase().contains(lowerQuery);
        }
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Tra Cứu Thông Tin"),
        backgroundColor: Colors.blue[800],
      ),
      body: Column(
        children: [
          // === KHUNG TÌM KIẾM ===
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Thanh chọn tiêu chí (Horizontal Scroll nếu màn hình nhỏ)
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
                              setState(() {
                                _filterType = key;
                                _search(_controller.text); // Tìm kiếm lại ngay khi đổi tiêu chí
                              });
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
                // Ô nhập liệu
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Nhập ${_filterType.toLowerCase()} cần tìm...",
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _controller.text.isNotEmpty 
                      ? IconButton(icon: Icon(Icons.clear), onPressed: () {
                          _controller.clear();
                          _search('');
                        }) 
                      : null
                  ),
                  onChanged: _search,
                ),
              ],
            ),
          ),
          
          // === DANH SÁCH KẾT QUẢ ===
          Expanded(
            child: _filteredData.isEmpty 
            ? Center(child: Text("Không tìm thấy kết quả nào", style: TextStyle(color: Colors.grey)))
            : ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: _filteredData.length,
              itemBuilder: (context, index) {
                final item = _filteredData[index];
                return _buildResultCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(PhieuCanModel item) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Phiếu #${item.id}", 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])
                ),
                Text(
                  item.thoiGian.split('T')[0], // Chỉ lấy ngày
                  style: TextStyle(fontSize: 12, color: Colors.grey)
                ),
              ],
            ),
            Divider(),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.local_shipping, color: Colors.blue[800]),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.bienSo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("${item.khachHang} - ${item.loaiHang}", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    ],
                  ),
                ),
                Text(
                  "${item.khoiLuongHang} Kg",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red[700]),
                )
              ],
            ),
            SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text("Người cân: ${item.nguoiCan}", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
            )
          ],
        ),
      ),
    );
  }
}