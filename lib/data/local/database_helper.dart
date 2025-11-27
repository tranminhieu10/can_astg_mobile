import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/phieu_can_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smart_weight_final.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    // [FIX TYPO] Hàm chuẩn là openDatabase
    return await openDatabase(path, version: 1, onCreate: (db, version) {
      db.execute('CREATE TABLE phieu_can (id INTEGER PRIMARY KEY, bienSo TEXT, khoiLuong REAL, thoiGian TEXT, isSynced INTEGER DEFAULT 0, ghiChu TEXT)');
    });
  }

  Future<int> insertPhieu(PhieuCanModel phieu) async {
    final db = await instance.database;
    return await db.insert('phieu_can', phieu.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PhieuCanModel>> getAllPhieuCan() async {
    final db = await instance.database;
    final result = await db.query('phieu_can', orderBy: 'id DESC');
    return result.map((json) => PhieuCanModel.fromJson(json)).toList();
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
}