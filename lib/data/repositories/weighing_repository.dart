import 'package:connectivity_plus/connectivity_plus.dart';
import '../local/database_helper.dart';
import '../services/api_service.dart';
import '../models/phieu_can_model.dart';

class WeighingRepository {
  final ApiService _api;
  final DatabaseHelper _db;

  WeighingRepository(this._api, this._db);

  Future<bool> _isConnected() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<PhieuCanModel?> findLatestUnfinishedTicketByPlate(String bienSo) {
    return _db.findLatestUnfinishedTicketByPlate(bienSo);
  }

  /// Lưu phiếu cân mới: offline-first
  Future<String> saveTicket(PhieuCanModel phieu) async {
    try {
      final localPhieu = phieu.copyWith(id: null, isSynced: 0);
      final localId = await _db.insertPhieu(localPhieu);

      final hasNetwork = await _isConnected();

      if (hasNetwork) {
        final success =
            await _api.postPhieuCan(localPhieu.copyWith(id: localId));
        if (success) {
          await _db.markAsSynced(localId);
          return "Đã lưu & Đồng bộ Azure";
        } else {
          return "Đã lưu Offline (Gửi server thất bại, sẽ tự đồng bộ khi mạng ổn định)";
        }
      } else {
        return "Đã lưu Offline (Không có mạng, sẽ đồng bộ sau)";
      }
    } catch (e) {
      return "Lỗi xử lý phiếu: $e";
    }
  }

  /// Cập nhật phiếu đã tồn tại
  Future<String> updateTicket(PhieuCanModel phieu) async {
    try {
      if (phieu.id == null) {
        return "Phiếu không hợp lệ (thiếu ID)";
      }

      final rows = await _db.updatePhieu(phieu);
      if (rows == 0) return "Không tìm thấy phiếu gốc";

      final hasNetwork = await _isConnected();

      if (hasNetwork) {
        final success = await _api.postPhieuCan(phieu);
        if (success) {
          await _db.markAsSynced(phieu.id!);
          return "Đã cập nhật & Đồng bộ Azure";
        } else {
          return "Đã cập nhật Offline (Gửi server thất bại, sẽ thử lại khi đồng bộ)";
        }
      } else {
        return "Đã cập nhật Offline (Không có mạng, sẽ đồng bộ sau)";
      }
    } catch (e) {
      return "Lỗi cập nhật phiếu: $e";
    }
  }

  /// Đồng bộ dữ liệu hai chiều
  ///
  /// - Up: gửi phiếu chưa sync (isSynced = 0) lên server
  /// - Down: kéo lịch sử từ server về, upsert vào DB local
  Future<String> syncData() async {
    if (!await _isConnected()) {
      return "Không có mạng, không thể đồng bộ.";
    }

    int upSuccess = 0;
    int upFailed = 0;
    int down = 0;

    try {
      // 1. Đẩy dữ liệu local chưa sync lên server
      final unsynced = await _db.getUnsyncedPhieu();
      for (final item in unsynced) {
        final ok = await _api.postPhieuCan(item);
        if (ok) {
          if (item.id != null) {
            await _db.markAsSynced(item.id!);
          }
          upSuccess++;
        } else {
          upFailed++;
        }
      }

      // 2. Kéo dữ liệu lịch sử từ server về (danh sách PhieuCanModel)
      final List<PhieuCanModel> serverData =
          await _api.getPhieuCanHistory();

      for (final item in serverData) {
        await _db.upsertFromServer(
          item.copyWith(isSynced: 1),
        );
        down++;
      }

      // 3. Xây dựng message cho người dùng
      if (upSuccess == 0 && upFailed == 0 && down == 0) {
        return "Không có dữ liệu cần đồng bộ.";
      }

      if (upFailed == 0) {
        return "Đồng bộ thành công: Gửi $upSuccess, Nhận $down";
      }

      return "Đồng bộ một phần: Gửi thành công $upSuccess, lỗi $upFailed, Nhận $down";
    } catch (e) {
      return "Lỗi Sync: $e";
    }
  }

  Future<bool> openBarrier() => _api.controlBarrier("OPEN");

  Future<void> deletePhieuCan(int id) => _db.deletePhieuCan(id);
}
