class PhieuCanModel {
  final int? id;            // ID tự tăng trong SQLite
  final String? soPhieu;    // Mã phiếu hiển thị (nếu cần)
  final String bienSo;
  final String khachHang;   // Thêm cho Thống kê
  final String loaiHang;    // Thêm cho Thống kê (Cát, Đá, Sỏi...)
  final double khoiLuongTong;
  final double khoiLuongBi;
  final double khoiLuongHang;
  final String thoiGian;
  final String nguoiCan;    // Thêm cho Tìm kiếm (User đăng nhập)
  final int isSynced;       // 0: Chưa đồng bộ, 1: Đã đồng bộ
  final String ghiChu;      // Ghi chú thêm

  PhieuCanModel({
    this.id,
    this.soPhieu,
    required this.bienSo,
    this.khachHang = "Khách lẻ",
    this.loaiHang = "Hàng thường",
    required this.khoiLuongTong,
    required this.khoiLuongBi,
    required this.khoiLuongHang,
    required this.thoiGian,
    this.nguoiCan = "Admin",
    this.isSynced = 0,
    this.ghiChu = "",
  });

  // Chuyển từ JSON/Map (SQLite hoặc API) sang Object
  factory PhieuCanModel.fromJson(Map<String, dynamic> json) {
    return PhieuCanModel(
      id: json['id'],
      soPhieu: json['soPhieu'],
      bienSo: json['bienSo'],
      khachHang: json['khachHang'] ?? "Khách lẻ",
      loaiHang: json['loaiHang'] ?? "Hàng thường",
      khoiLuongTong: (json['khoiLuongTong'] as num?)?.toDouble() ?? 0.0,
      khoiLuongBi: (json['khoiLuongBi'] as num?)?.toDouble() ?? 0.0,
      khoiLuongHang: (json['khoiLuongHang'] as num?)?.toDouble() ?? 0.0,
      thoiGian: json['thoiGian'],
      nguoiCan: json['nguoiCan'] ?? "Admin",
      isSynced: json['isSynced'] ?? 0,
      ghiChu: json['ghiChu'] ?? "",
    );
  }

  // Chuyển sang Map để lưu xuống SQLite hoặc gửi lên Server
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'soPhieu': soPhieu,
      'bienSo': bienSo,
      'khachHang': khachHang,
      'loaiHang': loaiHang,
      'khoiLuongTong': khoiLuongTong,
      'khoiLuongBi': khoiLuongBi,
      'khoiLuongHang': khoiLuongHang,
      'thoiGian': thoiGian,
      'nguoiCan': nguoiCan,
      'isSynced': isSynced,
      'ghiChu': ghiChu,
    };
  }
}