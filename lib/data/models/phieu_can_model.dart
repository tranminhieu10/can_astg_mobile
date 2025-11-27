class PhieuCanModel {
  final int? id; // ID trong SQLite
  final String? soPhieu;
  final String bienSo;
  final String khachHang;
  final double khoiLuongTong;
  final double khoiLuongBi;
  final double khoiLuongHang;
  final String thoiGian;
  final int isSynced; // 0: Chưa đồng bộ, 1: Đã đồng bộ

  PhieuCanModel({
    this.id,
    this.soPhieu,
    required this.bienSo,
    this.khachHang = "Khách lẻ",
    required this.khoiLuongTong,
    required this.khoiLuongBi,
    required this.khoiLuongHang,
    required this.thoiGian,
    this.isSynced = 0,
  });

  // Chuyển từ JSON (API/DB) sang Object
  factory PhieuCanModel.fromJson(Map<String, dynamic> json) {
    return PhieuCanModel(
      id: json['id'],
      soPhieu: json['soPhieu'],
      bienSo: json['bienSo'],
      khachHang: json['khachHang'] ?? "Khách lẻ",
      khoiLuongTong: (json['khoiLuongTong'] as num).toDouble(),
      khoiLuongBi: (json['khoiLuongBi'] as num).toDouble(),
      khoiLuongHang: (json['khoiLuongHang'] as num).toDouble(),
      thoiGian: json['thoiGian'],
      isSynced: json['isSynced'] ?? 1, // Mặc định từ API là đã sync
    );
  }

  // Chuyển sang Map để lưu DB hoặc gửi API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'soPhieu': soPhieu,
      'bienSo': bienSo,
      'khachHang': khachHang,
      'khoiLuongTong': khoiLuongTong,
      'khoiLuongBi': khoiLuongBi,
      'khoiLuongHang': khoiLuongHang,
      'thoiGian': thoiGian,
      'isSynced': isSynced,
    };
  }
}