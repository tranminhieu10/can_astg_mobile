import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../logic/blocs/weighing_bloc.dart';
import '../../data/services/config_service.dart';
import '../../data/services/api_service.dart';

class WeighingScreen extends StatefulWidget {
  const WeighingScreen({Key? key}) : super(key: key);

  @override
  State<WeighingScreen> createState() => _WeighingScreenState();
}

class _WeighingScreenState extends State<WeighingScreen> {
  final ApiService _apiService = ApiService();
  
  // Form controllers
  final TextEditingController _noteController = TextEditingController();

  // Dropdown values
  String? _selectedCongTyNhap;
  String? _selectedCongTyBan;
  String? _selectedLoaiHang;

  // Dropdown data
  List<dynamic> _congTyNhapList = [];
  List<dynamic> _congTyBanList = [];
  List<dynamic> _loaiHangList = [];
  bool _isLoadingDropdowns = false;

  // Camera
  late final Player _player;
  late final VideoController _videoController;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _initCamera();
    _loadDropdownData();
  }

  Future<void> _initCamera() async {
    try {
      final url = await AppConfig.getCameraUrl();
      await _player.open(
        Media(url),
        play: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Không mở được camera: $e';
      });
    }
  }

  Future<void> _loadDropdownData() async {
    if (!mounted) return;
    setState(() => _isLoadingDropdowns = true);
    
    try {
      final results = await Future.wait([
        _apiService.getCongTyNhap(),
        _apiService.getCongTyBan(),
        _apiService.getLoaiHang(),
      ]);

      if (!mounted) return;
      
      setState(() {
        _congTyNhapList = results[0];
        _congTyBanList = results[1];
        _loaiHangList = results[2];
        _isLoadingDropdowns = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingDropdowns = false);
      if (mounted) {
        _showSnackBar(context, 'Lỗi tải danh mục: $e');
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ----------------- HANDLERS -----------------

  void _onWeighGross(BuildContext context, WeighingState state) {
    if (_selectedCongTyNhap == null || _selectedCongTyBan == null || _selectedLoaiHang == null) {
      _showSnackBar(
        context,
        'Vui lòng chọn đủ: Công ty nhập, Công ty bán, Loại hàng.',
      );
      return;
    }

    context.read<WeighingBloc>().add(
          WeighGross(
            maCongTyNhap: _selectedCongTyNhap!,
            maCongTyBan: _selectedCongTyBan!,
            maLoai: _selectedLoaiHang!,
            note: _noteController.text.trim(),
          ),
        );
  }

  void _onWeighTare(BuildContext context) {
    context.read<WeighingBloc>().add(WeighTare());
  }

  void _onSaveTicket(BuildContext context) {
    context.read<WeighingBloc>().add(SaveTicket());
  }

  void _onClear(BuildContext context) {
    if (!mounted) return;
    setState(() {
      _selectedCongTyNhap = null;
      _selectedCongTyBan = null;
      _selectedLoaiHang = null;
      _noteController.clear();
    });
    context.read<WeighingBloc>().add(ClearWeighing());
  }

  void _onOpenBarrier(BuildContext context) {
    context.read<WeighingBloc>().add(TriggerBarrier());
  }

  void _onSync(BuildContext context) {
    context.read<WeighingBloc>().add(SyncDataEvent());
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  // ----------------- BUILD -----------------

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WeighingBloc, WeighingState>(
      listenWhen: (previous, current) => previous.message != current.message,
      listener: (context, state) {
        _showSnackBar(context, state.message);
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Cân xe'),
            actions: [
              if (_isLoadingDropdowns)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadDropdownData,
                tooltip: 'Tải lại danh mục',
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 8.0),
              child: _buildActionButtons(context, state),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (state.isBusy)
                  LinearProgressIndicator(
                    color: Colors.blue[800],
                    backgroundColor: Colors.blue[100],
                    minHeight: 3,
                  ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // CAMERA
                        SizedBox(
                          height: 220,
                          child: _buildCameraPanel(),
                        ),
                        const SizedBox(height: 8),

                        // TRỌNG LƯỢNG + BIỂN SỐ + STATUS
                        _buildWeightHeader(state),
                        const SizedBox(height: 8),
                        _buildPlateAndStatus(state),
                        const SizedBox(height: 8),
                        
                        // FORM VỚI DROPDOWN
                        _buildForm(context, state),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----------------- WIDGET CON -----------------

  Widget _buildWeightHeader(WeighingState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.scale, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TRỌNG LƯỢNG HIỆN TẠI',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          state.weight,
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'kg',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlateAndStatus(WeighingState state) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.blueGrey),
                const SizedBox(width: 8),
                const Text(
                  'Biển số:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.plate,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Wrap(
          spacing: 4,
          children: [
            Chip(
              label: Text(
                state.canTongDone ? 'ĐÃ CÂN TỔNG' : 'CHƯA CÂN TỔNG',
                style: TextStyle(
                  color: state.canTongDone ? Colors.white : Colors.grey[800],
                  fontSize: 11,
                ),
              ),
              backgroundColor:
                  state.canTongDone ? Colors.green : Colors.grey.shade300,
            ),
            Chip(
              label: Text(
                state.canBiDone ? 'ĐÃ CÂN BÌ' : 'CHƯA CÂN BÌ',
                style: TextStyle(
                  color: state.canBiDone ? Colors.white : Colors.grey[800],
                  fontSize: 11,
                ),
              ),
              backgroundColor:
                  state.canBiDone ? Colors.indigo : Colors.grey.shade300,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, WeighingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'THÔNG TIN PHIẾU CÂN',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        
        // DROPDOWN CÔNG TY NHẬP
        _buildDropdown(
          label: 'Công ty nhập',
          icon: Icons.factory,
          value: _selectedCongTyNhap,
          items: _congTyNhapList,
          onChanged: (value) => setState(() => _selectedCongTyNhap = value),
          idField: 'maCongTy',
          nameField: 'tenCongTy',
        ),
        const SizedBox(height: 8),

        // DROPDOWN CÔNG TY BÁN
        _buildDropdown(
          label: 'Công ty bán',
          icon: Icons.local_shipping,
          value: _selectedCongTyBan,
          items: _congTyBanList,
          onChanged: (value) => setState(() => _selectedCongTyBan = value),
          idField: 'maCongTy',
          nameField: 'tenCongTy',
        ),
        const SizedBox(height: 8),

        // DROPDOWN LOẠI HÀNG
        _buildDropdown(
          label: 'Loại hàng',
          icon: Icons.inventory_2,
          value: _selectedLoaiHang,
          items: _loaiHangList,
          onChanged: (value) => setState(() => _selectedLoaiHang = value),
          idField: 'maLoai',
          nameField: 'tenLoai',
        ),
        const SizedBox(height: 8),

        // GHI CHÚ
        TextField(
          controller: _noteController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Ghi chú (tùy chọn)',
            prefixIcon: Icon(Icons.note_alt_outlined),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),

        if (state.phieuHienTai != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.yellow.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(
              state.isUpdating
                  ? 'ĐANG TIẾP TỤC PHIẾU CÂN CHƯA HOÀN THÀNH'
                  : 'PHIẾU CÂN MỚI ĐANG SOẠN',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<dynamic> items,
    required Function(String?) onChanged,
    required String idField,
    required String nameField,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      isExpanded: true,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item[idField].toString(),
          child: Text(
            item[nameField].toString(),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      hint: Text('Chọn $label'),
    );
  }

  Widget _buildActionButtons(BuildContext context, WeighingState state) {
    final isBusy = state.isBusy;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    isBusy ? null : () => _onWeighGross(context, state),
                icon: const Icon(Icons.scale),
                label: const Text('CHỐT CÂN TỔNG'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isBusy || !state.canTongDone
                    ? null
                    : () => _onWeighTare(context),
                icon: const Icon(Icons.scale_outlined),
                label: const Text('CHỐT CÂN BÌ'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : () => _onSaveTicket(context),
                icon: const Icon(Icons.save),
                label: const Text('LƯU PHIẾU'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : () => _onClear(context),
                icon: const Icon(Icons.refresh),
                label: const Text('LÀM LẠI'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : () => _onOpenBarrier(context),
                icon: const Icon(Icons.door_front_door),
                label: const Text('MỞ BARRIER'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : () => _onSync(context),
                icon: const Icon(Icons.cloud_sync),
                label: const Text('ĐỒNG BỘ'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCameraPanel() {
    if (_cameraError != null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Text(
          _cameraError!,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: Video(
          controller: _videoController,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}