import 'api_service.dart';

class NameCacheService {
  static final NameCacheService _instance = NameCacheService._internal();
  factory NameCacheService() => _instance;
  NameCacheService._internal();

  final ApiService _apiService = ApiService();

  final Map<String, String> _khachHangCache = {};
  final Map<String, String> _noiXuatCache = {};
  final Map<String, String> _hangHoaCache = {};
  final Map<String, String> _nguoiCanCache = {};

  bool _isInitialized = false;

  Future<void> initCache() async {
    if (_isInitialized) return;
    try {
      final results = await Future.wait([
        _apiService.getCongTyNhap(),
        _apiService.getCongTyBan(),
        _apiService.getLoaiHang(),
      ]);

      for (var item in results[0]) {
        _khachHangCache[item['maCongTy'].toString()] = item['tenCongTy'].toString();
      }
      for (var item in results[1]) {
        _noiXuatCache[item['maCongTy'].toString()] = item['tenCongTy'].toString();
      }
      for (var item in results[2]) {
        _hangHoaCache[item['maLoai'].toString()] = item['tenLoai'].toString();
      }
      _isInitialized = true;
    } catch (e) {
      print("Lỗi cache: $e");
    }
  }

  // CÁC HÀM NÀY TRẢ VỀ STRING (ĐỒNG BỘ) -> ĐỂ KHỚP VỚI UI
  String getTenKhachHang(String? ma) => _khachHangCache[ma] ?? ma ?? "N/A";
  String getTenNoiXuat(String? ma) => _noiXuatCache[ma] ?? ma ?? "N/A";
  String getTenHangHoa(String? ma) => _hangHoaCache[ma] ?? ma ?? "N/A";
  
  // Hàm này trả về Future (Bất đồng bộ) -> Dùng FutureBuilder
  Future<String> getTenNguoiCan(String? ma) async {
    if (ma == null || ma.isEmpty) return "Admin";
    if (_nguoiCanCache.containsKey(ma)) return _nguoiCanCache[ma]!;
    try {
      final ten = await _apiService.getTenNguoiCan(ma);
      _nguoiCanCache[ma] = ten;
      return ten;
    } catch (e) { return ma; }
  }

  void clear() {
    _khachHangCache.clear();
    _noiXuatCache.clear();
    _hangHoaCache.clear();
    _nguoiCanCache.clear();
    _isInitialized = false;
  }
}