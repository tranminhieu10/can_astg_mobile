import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/phieu_can_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smart_weight_v3.db'); // Đổi tên DB để reset
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE phieu_can (
        id INTEGER PRIMARY KEY AUTOINCREMENT, soPhieu TEXT, bienSo TEXT,
        maCongTyNhap TEXT, maCongTyBan TEXT, maLoai TEXT, tenTaiXe TEXT, loaiPhieu INTEGER DEFAULT 1,
        tlTong REAL, tlBi REAL, tlHang REAL,
        thoiGianCanTong TEXT, thoiGianCanBi TEXT, nguoiCan TEXT,
        isSynced INTEGER DEFAULT 0, ghiChu TEXT, hinhAnhUrl TEXT
      )
    ''');
  }
  // Các hàm CRUD
  Future<int> insertPhieu(PhieuCanModel phieu) async {
    final db = await instance.database;
    return await db.insert('phieu_can', phieu.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<PhieuCanModel>> getAllPhieuCan() async {
    final db = await instance.database;
    final result = await db.query('phieu_can', orderBy: 'id DESC');
    return result.map((json) => PhieuCanModel.fromJson(json)).toList();
  }
  Future<PhieuCanModel?> findLatestUnfinishedTicketByPlate(String bienSo) async {
    final db = await instance.database;
    final results = await db.query('phieu_can', where: 'bienSo = ? AND tlBi = 0', whereArgs: [bienSo], orderBy: 'id DESC', limit: 1);
    if (results.isNotEmpty) return PhieuCanModel.fromJson(results.first);
    return null;
  }
  Future<List<PhieuCanModel>> getUnsyncedPhieu() async {
    final db = await instance.database;
    final result = await db.query('phieu_can', where: 'isSynced = ?', whereArgs: [0]);
    return result.map((json) => PhieuCanModel.fromJson(json)).toList();
  }
  Future<int> markAsSynced(int id) async {
    final db = await instance.database;
    return await db.update('phieu_can', {'isSynced': 1}, where: 'id = ?', whereArgs: [id]);
  }
  Future<int> updatePhieu(PhieuCanModel phieu) async {
    final db = await instance.database;
    return await db.update('phieu_can', phieu.toJson(), where: 'id = ?', whereArgs: [phieu.id]);
  }
  Future<int> deletePhieuCan(int id) async {
    final db = await instance.database;
    return await db.delete('phieu_can', where: 'id = ?', whereArgs: [id]);
  }
}