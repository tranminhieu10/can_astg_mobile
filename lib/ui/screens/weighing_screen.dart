import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import '../../logic/blocs/weighing_bloc.dart';
import '../../data/services/config_service.dart';
import '../../data/services/api_service.dart'; // Import API Service

class WeighingScreen extends StatefulWidget {
  @override
  _WeighingScreenState createState() => _WeighingScreenState();
}

class _WeighingScreenState extends State<WeighingScreen> {
  final ApiService _apiService = ApiService();
  
  // Các biến để lưu giá trị chọn từ Dropdown (Lưu Mã ID)
  String? _selectedKhachHang; // MaCongTyNhap
  String? _selectedNoiXuat;   // MaCongTyBan
  String? _selectedHangHoa;   // MaLoai
  final _noteController = TextEditingController();

  // Danh sách dữ liệu cho Dropdown
  List<dynamic> _listKhachHang = [];
  List<dynamic> _listNoiXuat = [];
  List<dynamic> _listHangHoa = [];
  bool _isLoadingMasterData = true;

  @override
  void initState() {
    super.initState();
    _loadMasterData();
    
    // Kích hoạt SignalR
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeighingBloc>().add(InitSignalR());
    });
  }

  // Tải danh mục từ API Azure
  Future<void> _loadMasterData() async {
    try {
      final kh = await _apiService.getCongTyNhap();
      final nx = await _apiService.getCongTyBan();
      final hh = await _apiService.getLoaiHang();

      if (mounted) {
        setState(() {
          _listKhachHang = kh;
          _listNoiXuat = nx;
          _listHangHoa = hh;
          
          // Set mặc định nếu có dữ liệu
          if (kh.isNotEmpty) _selectedKhachHang = kh[0]['maCongTy'];
          if (nx.isNotEmpty) _selectedNoiXuat = nx[0]['maCongTy'];
          if (hh.isNotEmpty) _selectedHangHoa = hh[0]['maLoai'];
          
          _isLoadingMasterData = false;
        });
      }
    } catch (e) {
      print("Lỗi tải danh mục: $e");
      if (mounted) setState(() => _isLoadingMasterData = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Bàn Cân Online"),
        backgroundColor: Colors.blue[900],
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: () => context.read<WeighingBloc>().add(ClearWeighing())),
        ],
      ),
      body: Column(
        children: [
          // 1. Camera View
          Expanded(flex: 4, child: const _IsolatedCameraView()),

          // 2. Control Panel
          Expanded(
            flex: 6,
            child: BlocConsumer<WeighingBloc, WeighingState>(
              listener: (context, state) {
                if (state.message.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(state.message),
                    backgroundColor: state.message.toLowerCase().contains("lỗi") ? Colors.red : Colors.green,
                  ));
                }
              },
              builder: (context, state) {
                // Logic điền lại dữ liệu khi tìm thấy phiếu dở dang
                if (state.phieuHienTai != null) {
                   // Cố gắng map lại giá trị dropdown nếu mã khớp
                   if (_listKhachHang.any((e) => e['maCongTy'] == state.phieuHienTai!.maCongTyNhap)) {
                      _selectedKhachHang = state.phieuHienTai!.maCongTyNhap;
                   }
                   if (_listHangHoa.any((e) => e['maLoai'] == state.phieuHienTai!.maLoai)) {
                      _selectedHangHoa = state.phieuHienTai!.maLoai;
                   }
                   if (_noteController.text.isEmpty) {
                      _noteController.text = state.phieuHienTai!.ghiChu;
                   }
                }

                // Khóa nhập liệu nếu đang cân bì hoặc update
                final bool canEdit = !state.canTongDone || (!state.isUpdating && !state.canTongDone);
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Thông số cân
                        Row(
                          children: [
                            Expanded(child: _buildDisplayBox("BIỂN SỐ", state.plate, Colors.blue[900]!)),
                            SizedBox(width: 12),
                            Expanded(child: _buildDisplayBox("KHỐI LƯỢNG", state.weight, Colors.red[700]!, isBig: true)),
                          ],
                        ),
                        SizedBox(height: 12),
                        
                        // Thông tin chi tiết phiếu
                        Row(
                          children: [
                            Expanded(child: _buildInfoTag("TỔNG", state.phieuHienTai?.tlTong ?? 0, Colors.blue)),
                            SizedBox(width: 8),
                            Expanded(child: _buildInfoTag("BÌ", state.phieuHienTai?.tlBi ?? 0, Colors.green)),
                            SizedBox(width: 8),
                            Expanded(child: _buildInfoTag("HÀNG", state.phieuHienTai?.tlHang ?? 0, Colors.orange)),
                          ],
                        ),
                        
                        // Ảnh xe (nếu có)
                        if (state.phieuHienTai?.hinhAnhUrl != null)
                          _buildImagePreview(context, state.phieuHienTai!.hinhAnhUrl!),

                        Divider(height: 24),

                        // Form nhập liệu (Dropdown)
                        if (_isLoadingMasterData) 
                          LinearProgressIndicator()
                        else 
                          _buildDropdowns(canEdit),
                        
                        SizedBox(height: 16),
                        _buildActionButtons(context, state),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget Dropdown
  Widget _buildDropdowns(bool enabled) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSingleDropdown(
                label: "Khách Hàng (Nhận)",
                value: _selectedKhachHang,
                items: _listKhachHang,
                valueField: 'maCongTy',
                textField: 'tenCongTy',
                icon: Icons.person,
                enabled: enabled,
                onChanged: (val) => setState(() => _selectedKhachHang = val),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _buildSingleDropdown(
                label: "Loại Hàng",
                value: _selectedHangHoa,
                items: _listHangHoa,
                valueField: 'maLoai',
                textField: 'tenLoai',
                icon: Icons.category,
                enabled: enabled,
                onChanged: (val) => setState(() => _selectedHangHoa = val),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        // Dropdown Nơi Xuất (Công ty Bán)
        _buildSingleDropdown(
          label: "Nơi Xuất (Bên Bán)",
          value: _selectedNoiXuat,
          items: _listNoiXuat,
          valueField: 'maCongTy',
          textField: 'tenCongTy',
          icon: Icons.store,
          enabled: enabled,
          onChanged: (val) => setState(() => _selectedNoiXuat = val),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _noteController,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: "Ghi chú",
            prefixIcon: Icon(Icons.note),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleDropdown({
    required String label,
    required String? value,
    required List<dynamic> items,
    required String valueField,
    required String textField,
    required IconData icon,
    required bool enabled,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        filled: !enabled,
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item[valueField].toString(),
          child: Text(
            item[textField].toString(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13),
          ),
        );
      }).toList(),
      onChanged: enabled ? onChanged : null,
      isExpanded: true,
    );
  }

  // Action Buttons
  Widget _buildActionButtons(BuildContext context, WeighingState state) {
    final bool canWeighGross = !state.isBusy && !state.canTongDone && !state.isUpdating;
    final bool canWeighTare = !state.isBusy && state.canTongDone && !state.canBiDone;
    final bool canSave = !state.isBusy && state.canTongDone && state.canBiDone;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(Icons.download), label: Text("CÂN TỔNG"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], padding: EdgeInsets.symmetric(vertical: 12)),
                onPressed: canWeighGross ? () {
                  if (_selectedKhachHang == null || _selectedHangHoa == null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Vui lòng chọn Khách hàng và Hàng hóa!")));
                    return;
                  }
                  context.read<WeighingBloc>().add(WeighGross(
                    maCongTyNhap: _selectedKhachHang!,
                    maCongTyBan: _selectedNoiXuat ?? "KHO_DEFAULT",
                    maLoai: _selectedHangHoa!,
                    note: _noteController.text
                  ));
                } : null,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(Icons.upload), label: Text("CÂN BÌ"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], padding: EdgeInsets.symmetric(vertical: 12)),
                onPressed: canWeighTare ? () => context.read<WeighingBloc>().add(WeighTare()) : null,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(Icons.save), 
            label: Text(state.isUpdating ? "CẬP NHẬT PHIẾU" : "LƯU PHIẾU HOÀN THÀNH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple[800], padding: EdgeInsets.symmetric(vertical: 14)),
            onPressed: canSave ? () => context.read<WeighingBloc>().add(SaveTicket()) : null,
          ),
        ),
      ],
    );
  }

  // ... (Giữ nguyên các hàm _buildDisplayBox, _buildInfoTag, _buildImagePreview, _IsolatedCameraView từ code cũ của bạn vì chúng là UI thuần túy)
  
  Widget _buildDisplayBox(String title, String value, Color color, {bool isBig = false}) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold)),
        Align(alignment: Alignment.centerRight, child: Text(value, style: TextStyle(fontSize: isBig ? 28 : 20, fontWeight: FontWeight.bold, color: color, fontFamily: 'monospace')))
      ]),
    );
  }

  Widget _buildInfoTag(String label, double val, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(val.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }
  
  Widget _buildImagePreview(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black, body: PhotoView(imageProvider: CachedNetworkImageProvider(url))))),
      child: Container(
        margin: EdgeInsets.only(top: 10), height: 80,
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Padding(padding: EdgeInsets.all(10), child: Icon(Icons.image, color: Colors.blue)),
          Text("Ảnh xe đã lưu", style: TextStyle(color: Colors.blue[800])),
          Spacer(),
          CachedNetworkImage(imageUrl: url, width: 80, height: 80, fit: BoxFit.cover)
        ]),
      ),
    );
  }
}

class _IsolatedCameraView extends StatefulWidget {
  const _IsolatedCameraView();
  @override
  __IsolatedCameraViewState createState() => __IsolatedCameraViewState();
}

class __IsolatedCameraViewState extends State<_IsolatedCameraView> {
  late final Player _player = Player();
  late final VideoController _videoController = VideoController(_player);
  @override
  void initState() {
    super.initState();
    AppConfig.getCameraUrl().then((url) => _player.open(Media(url), play: true));
  }
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.black, child: Video(controller: _videoController, fit: BoxFit.contain));
  }
}