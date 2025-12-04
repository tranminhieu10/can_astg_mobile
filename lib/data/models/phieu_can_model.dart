class PhieuCanModel {
  final int? id;
  final String? soPhieu;
  final String bienSo;
  final String? maCongTyNhap; 
  final String? maCongTyBan;
  final String? maLoai; 
  final String? tenTaiXe;
  final int loaiPhieu;
  final double tlTong;
  final double tlBi;
  final double tlHang;
  final String? thoiGianCanTong;
  final String? thoiGianCanBi;
  final String? nguoiCan;
  final int isSynced;
  final String ghiChu;
  final String? hinhAnhUrl; 

  PhieuCanModel({
    this.id, this.soPhieu, required this.bienSo,
    this.maCongTyNhap, this.maCongTyBan, this.maLoai, this.tenTaiXe,
    this.loaiPhieu = 1, required this.tlTong, required this.tlBi, required this.tlHang,
    this.thoiGianCanTong, this.thoiGianCanBi, this.nguoiCan,
    this.isSynced = 0, this.ghiChu = "", this.hinhAnhUrl
  });

  factory PhieuCanModel.fromJson(Map<String, dynamic> json) {
    return PhieuCanModel(
      id: json['id'], soPhieu: json['soPhieu'], bienSo: json['bienSo'] ?? '',
      maCongTyNhap: json['maCongTyNhap'], maCongTyBan: json['maCongTyBan'], maLoai: json['maLoai'], tenTaiXe: json['tenTaiXe'],
      loaiPhieu: json['loaiPhieu'] ?? 1,
      tlTong: (json['tlTong'] as num?)?.toDouble() ?? 0.0,
      tlBi: (json['tlBi'] as num?)?.toDouble() ?? 0.0,
      tlHang: (json['tlHang'] as num?)?.toDouble() ?? 0.0,
      thoiGianCanTong: json['thoiGianCanTong'], thoiGianCanBi: json['thoiGianCanBi'], nguoiCan: json['nguoiCan'],
      isSynced: (json['isSynced'] == 1 || json['isSynced'] == true) ? 1 : 0,
      ghiChu: json['ghiChu'] ?? "", hinhAnhUrl: json['hinhAnhUrl'] ?? json['hinhAnh'], 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id, 'soPhieu': soPhieu, 'bienSo': bienSo,
      'maCongTyNhap': maCongTyNhap, 'maCongTyBan': maCongTyBan, 'maLoai': maLoai, 'tenTaiXe': tenTaiXe, 'loaiPhieu': loaiPhieu,
      'tlTong': tlTong, 'tlBi': tlBi, 'tlHang': tlHang,
      'thoiGianCanTong': thoiGianCanTong, 'thoiGianCanBi': thoiGianCanBi, 'nguoiCan': nguoiCan,
      'isSynced': isSynced, 'ghiChu': ghiChu, 'hinhAnhUrl': hinhAnhUrl,
    };
  }

  PhieuCanModel copyWith({int? id, int? isSynced, String? hinhAnhUrl, double? tlBi, double? tlHang, String? thoiGianCanBi}) {
    return PhieuCanModel(
      id: id ?? this.id, soPhieu: this.soPhieu, bienSo: this.bienSo,
      maCongTyNhap: this.maCongTyNhap, maCongTyBan: this.maCongTyBan, maLoai: this.maLoai, tenTaiXe: this.tenTaiXe, loaiPhieu: this.loaiPhieu,
      tlTong: this.tlTong, tlBi: tlBi ?? this.tlBi, tlHang: tlHang ?? this.tlHang,
      thoiGianCanTong: this.thoiGianCanTong, thoiGianCanBi: thoiGianCanBi ?? this.thoiGianCanBi, nguoiCan: this.nguoiCan,
      isSynced: isSynced ?? this.isSynced, ghiChu: this.ghiChu, hinhAnhUrl: hinhAnhUrl ?? this.hinhAnhUrl,
    );
  }
}