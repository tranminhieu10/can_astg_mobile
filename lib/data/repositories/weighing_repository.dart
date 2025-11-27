import 'package:connectivity_plus/connectivity_plus.dart';
import '../local/database_helper.dart'; 
import '../services/api_service.dart'; 
import '../models/phieu_can_model.dart'; 

class WeighingRepository {
  final ApiService _api;
  final DatabaseHelper _db;

  WeighingRepository(this._api, this._db);

  Future<String> saveTicket(PhieuCanModel phieu) async {
    var conn = await Connectivity().checkConnectivity();
    if (conn != ConnectivityResult.none) {
      try {
        bool ok = await _api.postPhieuCan(phieu);
        if (ok) {
          await _db.insertPhieu(PhieuCanModel(
            bienSo: phieu.bienSo, 
            khachHang: phieu.khachHang, // Thêm khachHang
            khoiLuongTong: phieu.khoiLuongTong, // Thay thế khoiLuong
            khoiLuongBi: phieu.khoiLuongBi,     // Thay thế khoiLuong
            khoiLuongHang: phieu.khoiLuongHang, // Thay thế khoiLuong
            thoiGian: phieu.thoiGian, 
            isSynced: 1
          ));
          return "Đã lưu lên Server";
        }
      } catch (e) { print(e); }
    }
    await _db.insertPhieu(phieu);
    return "Đã lưu Offline";
  }

  Future<int> syncData() async {
    var list = await _db.getUnsyncedPhieu();
    int count = 0;
    for (var item in list) {
      if (await _api.postPhieuCan(item)) {
        await _db.markAsSynced(item.id!);
        count++;
      }
    }
    return count;
  }

  Future<int> syncFromServer() async {
    var conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) return 0;

    var list = await _api.getPhieuCanHistory();
    int count = 0;
    for (var item in list) {
      await _db.insertPhieu(PhieuCanModel(
        id: item.id, 
        soPhieu: item.soPhieu, // Thêm soPhieu
        bienSo: item.bienSo, 
        khachHang: item.khachHang, // Thêm khachHang
        khoiLuongTong: item.khoiLuongTong, // Thay thế khoiLuong
        khoiLuongBi: item.khoiLuongBi,     // Thay thế khoiLuong
        khoiLuongHang: item.khoiLuongHang, // Thay thế khoiLuong
        thoiGian: item.thoiGian, 
        isSynced: 1
      ));
      count++;
    }
    return count;
  }

  Future<bool> openBarrier() => _api.controlBarrier("OPEN");
}