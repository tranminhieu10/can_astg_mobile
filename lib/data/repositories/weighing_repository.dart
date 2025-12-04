import 'package:connectivity_plus/connectivity_plus.dart';
import '../local/database_helper.dart'; 
import '../services/api_service.dart'; 
import '../models/phieu_can_model.dart'; 

class WeighingRepository {
  final ApiService _api;
  final DatabaseHelper _db;

  WeighingRepository(this._api, this._db);

  Future<bool> _isConnected() async {
    // [FIX LỖI ẢNH 2] Dùng cú pháp của bản 5.0.2 (So sánh trực tiếp, không dùng contains)
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<PhieuCanModel?> findLatestUnfinishedTicketByPlate(String bienSo) {
    return _db.findLatestUnfinishedTicketByPlate(bienSo);
  }

  Future<String> saveTicket(PhieuCanModel phieu) async {
    try {
      final localPhieu = phieu.copyWith(id: null, isSynced: 0);
      final localId = await _db.insertPhieu(localPhieu);

      if (await _isConnected()) {
        final success = await _api.postPhieuCan(localPhieu.copyWith(id: localId));
        if (success) {
          await _db.markAsSynced(localId);
          return "Đã lưu & Đồng bộ Azure";
        }
      }
      return "Đã lưu Offline (Chờ mạng)";
    } catch (e) {
      return "Lỗi xử lý: $e";
    }
  }

  Future<String> updateTicket(PhieuCanModel phieu) async {
    try {
      int rows = await _db.updatePhieu(phieu);
      if (rows == 0) return "Không tìm thấy phiếu gốc";

      if (await _isConnected()) {
        bool success = await _api.postPhieuCan(phieu);
        if (success) {
          await _db.markAsSynced(phieu.id!);
          return "Đã cập nhật & Đồng bộ Azure";
        }
      }
      return "Đã cập nhật Offline";
    } catch (e) { return "Lỗi cập nhật: $e"; }
  }

  Future<String> syncData() async {
    if (!await _isConnected()) return "Không có mạng";

    int up = 0, down = 0;
    try {
      var unsynced = await _db.getUnsyncedPhieu();
      for (var item in unsynced) {
        if (await _api.postPhieuCan(item)) {
          await _db.markAsSynced(item.id!);
          up++;
        }
      }
      var serverData = await _api.getPhieuCanHistory();
      for (var item in serverData) {
        await _db.insertPhieu(item.copyWith(isSynced: 1, id: null)); 
        down++;
      }
      return "Đồng bộ: Gửi $up, Nhận $down";
    } catch (e) { return "Lỗi Sync: $e"; }
  }

  Future<bool> openBarrier() => _api.controlBarrier("OPEN");
  Future<void> deletePhieuCan(int id) => _db.deletePhieuCan(id);
}