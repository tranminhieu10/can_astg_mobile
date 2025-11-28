import 'package:connectivity_plus/connectivity_plus.dart';
import '../local/database_helper.dart'; 
import '../services/api_service.dart'; 
import '../models/phieu_can_model.dart'; 

class WeighingRepository {
  final ApiService _api;
  final DatabaseHelper _db;

  WeighingRepository(this._api, this._db);

  /// Kiểm tra kết nối mạng (Hỗ trợ connectivity_plus bản mới trả về List)
  Future<bool> _isConnected() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// ==========================================================
  /// 1. LƯU PHIẾU (Logic Offline-First an toàn dữ liệu)
  /// ==========================================================
  Future<String> saveTicket(PhieuCanModel phieu) async {
    try {
      // BƯỚC 1: Luôn INSERT vào SQLite trước với trạng thái chưa đồng bộ (isSynced = 0)
      // Điều này đảm bảo nếu App bị crash hoặc mất mạng ngay sau đó, dữ liệu vẫn còn.
      PhieuCanModel localPhieu = PhieuCanModel(
        bienSo: phieu.bienSo,
        khachHang: phieu.khachHang,       // Map đủ trường mới
        loaiHang: phieu.loaiHang,
        khoiLuongTong: phieu.khoiLuongTong,
        khoiLuongBi: phieu.khoiLuongBi,
        khoiLuongHang: phieu.khoiLuongHang,
        thoiGian: phieu.thoiGian,
        nguoiCan: phieu.nguoiCan,
        ghiChu: phieu.ghiChu,
        isSynced: 0, // Mặc định chưa đồng bộ
      );

      // Lưu vào DB và lấy ID
      int localId = await _db.insertPhieu(localPhieu);

      // BƯỚC 2: Kiểm tra mạng. Nếu có mạng -> Gửi ngay lập tức
      if (await _isConnected()) {
        bool success = await _api.postPhieuCan(localPhieu);
        
        if (success) {
          // BƯỚC 3: Nếu gửi thành công -> Update trạng thái Local thành "Đã Sync" (1)
          await _db.markAsSynced(localId);
          return "Đã lưu và đồng bộ lên Server";
        }
      }
      
      // Nếu không có mạng hoặc gửi lỗi -> Vẫn báo thành công (vì đã lưu Offline)
      return "Đã lưu Offline (Sẽ tự động đồng bộ)";
    } catch (e) {
      return "Lỗi lưu phiếu: $e";
    }
  }

  /// ==========================================================
  /// 2. ĐỒNG BỘ DỮ LIỆU 2 CHIỀU (Gửi đi & Tải về)
  /// ==========================================================
  Future<String> syncData() async {
    if (!await _isConnected()) {
      return "Không có kết nối mạng để đồng bộ";
    }

    int uploadCount = 0;
    int downloadCount = 0;

    try {
      // --- CHIỀU ĐI (UPLOAD): Gửi các phiếu Offline lên Server ---
      var unsyncedList = await _db.getUnsyncedPhieu();
      for (var item in unsyncedList) {
        if (await _api.postPhieuCan(item)) {
          // Gửi xong thì đánh dấu đã sync
          await _db.markAsSynced(item.id!);
          uploadCount++;
        }
      }

      // --- CHIỀU VỀ (DOWNLOAD): Tải lịch sử từ Server về máy ---
      var serverList = await _api.getPhieuCanHistory();
      for (var serverItem in serverList) {
        // Tạo đối tượng Sync (isSynced = 1)
        var syncItem = PhieuCanModel(
          // id: serverItem.id, // Bỏ qua ID server để SQLite tự sinh ID, tránh trùng lặp
          soPhieu: serverItem.soPhieu,
          bienSo: serverItem.bienSo,
          khachHang: serverItem.khachHang,
          loaiHang: serverItem.loaiHang,
          khoiLuongTong: serverItem.khoiLuongTong,
          khoiLuongBi: serverItem.khoiLuongBi,
          khoiLuongHang: serverItem.khoiLuongHang,
          thoiGian: serverItem.thoiGian,
          nguoiCan: serverItem.nguoiCan,
          ghiChu: serverItem.ghiChu,
          isSynced: 1 // Đánh dấu đã đồng bộ
        );

        // Insert vào DB (DatabaseHelper cần cấu hình conflictAlgorithm: replace)
        // Lưu ý: Logic này đơn giản là thêm mới. Nếu muốn tránh trùng lặp nâng cao, 
        // bạn cần check xem soPhieu đã tồn tại chưa trước khi insert.
        await _db.insertPhieu(syncItem);
        downloadCount++;
      }

      return "Đồng bộ: Gửi $uploadCount phiếu, Tải về $downloadCount phiếu";
    } catch (e) {
      return "Lỗi quá trình đồng bộ: $e";
    }
  }

  /// Điều khiển mở Barrier
  Future<bool> openBarrier() => _api.controlBarrier("OPEN");
}