import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/phieu_can_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smart_weight_v2.db'); // Đổi tên DB để tránh cache cấu trúc cũ
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // Tạo bảng với đầy đủ cột hỗ trợ tính năng mới
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE phieu_can (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        soPhieu TEXT,
        bienSo TEXT,
        khachHang TEXT,
        loaiHang TEXT,
        khoiLuongTong REAL,
        khoiLuongBi REAL,
        khoiLuongHang REAL,
        thoiGian TEXT,
        nguoiCan TEXT,
        isSynced INTEGER DEFAULT 0,
        ghiChu TEXT
      )
    ''');
  }

  Future<int> insertPhieu(PhieuCanModel phieu) async {
    final db = await instance.database;
    return await db.insert('phieu_can', phieu.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Lấy danh sách phiếu cân, mới nhất lên đầu
  Future<List<PhieuCanModel>> getAllPhieuCan() async {
    final db = await instance.database;
    final result = await db.query('phieu_can', orderBy: 'id DESC');
    return result.map((json) => PhieuCanModel.fromJson(json)).toList();
  }

  // Lấy các phiếu chưa đồng bộ để gửi lên Server
  Future<List<PhieuCanModel>> getUnsyncedPhieu() async {
    final db = await instance.database;
    final result = await db.query('phieu_can', where: 'isSynced = ?', whereArgs: [0]);
    return result.map((json) => PhieuCanModel.fromJson(json)).toList();
  }

  Future<int> markAsSynced(int id) async {
    final db = await instance.database;
    return await db.update('phieu_can', {'isSynced': 1}, where: 'id = ?', whereArgs: [id]);
  }
  
  // Thêm hàm hỗ trợ tìm kiếm/lọc (Tùy chọn)
  Future<List<PhieuCanModel>> searchPhieu(String keyword) async {
    final db = await instance.database;
    final result = await db.query(
      'phieu_can',
      where: 'bienSo LIKE ? OR khachHang LIKE ? OR soPhieu LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%', '%$keyword%'],
      orderBy: 'id DESC'
    );
    return result.map((json) => PhieuCanModel.fromJson(json)).toList();
  }
}