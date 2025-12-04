import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/phieu_can_model.dart';

class DatabaseHelper {
  static const String _dbName = 'smart_weight_v3.db';
  static const int _dbVersion = 2; // Tăng version khi có thay đổi cấu trúc
  static const String _tablePhieu = 'phieu_can';

  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Bảng chính phiếu cân
    await db.execute('''
      CREATE TABLE $_tablePhieu (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        soPhieu TEXT,
        bienSo TEXT NOT NULL,
        maCongTyNhap TEXT,
        maCongTyBan TEXT,
        maLoai TEXT,
        tenTaiXe TEXT,
        loaiPhieu INTEGER,
        tlTong REAL,
        tlBi REAL,
        tlHang REAL,
        thoiGianCanTong TEXT,
        thoiGianCanBi TEXT,
        nguoiCan TEXT,
        isSynced INTEGER NOT NULL DEFAULT 0,
        ghiChu TEXT,
        hinhAnhUrl TEXT
      )
    ''');

    // Index để tăng tốc truy vấn
    await db.execute(
      'CREATE INDEX idx_phieu_can_bienso ON $_tablePhieu(bienSo)',
    );
    await db.execute(
      'CREATE INDEX idx_phieu_can_time ON $_tablePhieu(thoiGianCanTong)',
    );
    await db.execute(
      'CREATE INDEX idx_phieu_can_synced ON $_tablePhieu(isSynced)',
    );
  }

  Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // Nếu DB cũ chưa có index, tạo thêm – an toàn, không xoá dữ liệu
    if (oldVersion < 2) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_phieu_can_bienso ON $_tablePhieu(bienSo)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_phieu_can_time ON $_tablePhieu(thoiGianCanTong)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_phieu_can_synced ON $_tablePhieu(isSynced)',
      );
    }
  }

  // ----------------- CRUD CƠ BẢN -----------------

  Future<int> insertPhieu(PhieuCanModel phieu) async {
    final db = await database;
    final data = Map<String, dynamic>.from(phieu.toJson());

    // Để DB tự tăng id
    data.remove('id');

    return db.insert(
      _tablePhieu,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updatePhieu(PhieuCanModel phieu) async {
    if (phieu.id == null) return 0;
    final db = await database;
    final data = Map<String, dynamic>.from(phieu.toJson());

    return db.update(
      _tablePhieu,
      data,
      where: 'id = ?',
      whereArgs: [phieu.id],
    );
  }

  Future<void> deletePhieuCan(int id) async {
    final db = await database;
    await db.delete(
      _tablePhieu,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<PhieuCanModel>> getAllPhieu() async {
    final db = await database;
    final maps = await db.query(
      _tablePhieu,
      orderBy: 'thoiGianCanTong DESC',
    );
    return maps.map((e) => PhieuCanModel.fromJson(e)).toList();
  }

  Future<PhieuCanModel?> getLatestPhieuCan() async {
    final db = await instance.database;
    final result = await db.query(
      _tablePhieu,
      orderBy: 'id DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return PhieuCanModel.fromJson(result.first);
    }
    return null;
  }

  /// Lịch sử theo ngày (từ 00:00 đến 23:59:59 ngày đó)
  Future<List<PhieuCanModel>> getHistoryByDate(DateTime date) async {
    final db = await database;

    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    final maps = await db.query(
      _tablePhieu,
      where: 'thoiGianCanTong >= ? AND thoiGianCanTong < ?',
      whereArgs: [startIso, endIso],
      orderBy: 'thoiGianCanTong DESC',
    );

    return maps.map((e) => PhieuCanModel.fromJson(e)).toList();
  }

  /// Tìm theo biển số (contains, không phân biệt hoa thường)
  Future<List<PhieuCanModel>> searchByBienSo(String keyword) async {
    final db = await database;
    final key = '%${keyword.trim()}%';
    final maps = await db.query(
      _tablePhieu,
      where: 'LOWER(bienSo) LIKE LOWER(?)',
      whereArgs: [key],
      orderBy: 'thoiGianCanTong DESC',
    );
    return maps.map((e) => PhieuCanModel.fromJson(e)).toList();
  }

  // ----------------- SYNC HỖ TRỢ -----------------

  /// Lấy tất cả phiếu chưa đồng bộ (isSynced = 0)
  Future<List<PhieuCanModel>> getUnsyncedPhieu() async {
    final db = await database;
    final maps = await db.query(
      _tablePhieu,
      where: 'isSynced = 0',
      orderBy: 'thoiGianCanTong ASC',
    );
    return maps.map((e) => PhieuCanModel.fromJson(e)).toList();
  }

  Future<void> markAsSynced(int id) async {
    final db = await database;
    await db.update(
      _tablePhieu,
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Tìm phiếu mới nhất theo biển số mà chưa hoàn thành (chưa có bì hoặc chưa có hàng)
  Future<PhieuCanModel?> findLatestUnfinishedTicketByPlate(
      String plate) async {
    final db = await database;
    final maps = await db.query(
      _tablePhieu,
      where:
          'bienSo = ? AND (tlBi IS NULL OR tlBi = 0 OR tlHang IS NULL OR tlHang = 0)',
      whereArgs: [plate],
      orderBy: 'thoiGianCanTong DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return PhieuCanModel.fromJson(maps.first);
  }

  /// Upsert phiếu từ server: nếu đã tồn tại (biển số + thời gian cân tổng)
  /// thì update, ngược lại insert mới.
  ///
  /// - Dùng cho sync phia server -> local
  /// - Mặc định đánh dấu isSynced = 1
  Future<void> upsertFromServer(PhieuCanModel phieu) async {
    final db = await database;

    // Nếu không có thời gian cân tổng thì coi như phiếu mới
    if (phieu.thoiGianCanTong == null || phieu.thoiGianCanTong!.isEmpty) {
      await insertPhieu(phieu.copyWith(isSynced: 1, id: null));
      return;
    }

    final maps = await db.query(
      _tablePhieu,
      where: 'bienSo = ? AND thoiGianCanTong = ?',
      whereArgs: [phieu.bienSo, phieu.thoiGianCanTong],
      limit: 1,
    );

    if (maps.isEmpty) {
      // Insert phiếu mới
      await insertPhieu(phieu.copyWith(isSynced: 1, id: null));
    } else {
      // Cập nhật phiếu cũ
      final existingId = maps.first['id'] as int;
      final updated = phieu.copyWith(
        id: existingId,
        isSynced: 1,
      );
      await updatePhieu(updated);
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _database = null;
  }
}
