import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class HRVMeasurement {
  final String id;
  final DateTime timestamp;
  final int heartRate;
  final double sdnn;
  final double rmssd;
  final double pnn50;
  final double lf;
  final double hf;
  final double lfHfRatio;
  final int stressIndex;
  final int recoveryPotential;
  final String notes;

  HRVMeasurement({
    String? id,
    required this.timestamp,
    required this.heartRate,
    required this.sdnn,
    required this.rmssd,
    required this.pnn50,
    required this.lf,
    required this.hf,
    required this.lfHfRatio,
    required this.stressIndex,
    required this.recoveryPotential,
    this.notes = '',
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'heartRate': heartRate,
      'sdnn': sdnn,
      'rmssd': rmssd,
      'pnn50': pnn50,
      'lf': lf,
      'hf': hf,
      'lfHfRatio': lfHfRatio,
      'stressIndex': stressIndex,
      'recoveryPotential': recoveryPotential,
      'notes': notes,
    };
  }

  factory HRVMeasurement.fromMap(Map<String, dynamic> map) {
    return HRVMeasurement(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      heartRate: map['heartRate'],
      sdnn: map['sdnn'],
      rmssd: map['rmssd'],
      pnn50: map['pnn50'],
      lf: map['lf'],
      hf: map['hf'],
      lfHfRatio: map['lfHfRatio'],
      stressIndex: map['stressIndex'],
      recoveryPotential: map['recoveryPotential'],
      notes: map['notes'] ?? '',
    );
  }
}

class HRVDatabase {
  static final HRVDatabase _instance = HRVDatabase._internal();
  static Database? _database;

  factory HRVDatabase() {
    return _instance;
  }

  HRVDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'hrv_measurements.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE hrv_measurements (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        heartRate INTEGER NOT NULL,
        sdnn REAL NOT NULL,
        rmssd REAL NOT NULL,
        pnn50 REAL NOT NULL,
        lf REAL NOT NULL,
        hf REAL NOT NULL,
        lfHfRatio REAL NOT NULL,
        stressIndex INTEGER NOT NULL,
        recoveryPotential INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    // Index qilish search speed uchun
    await db.execute('''
      CREATE INDEX idx_timestamp ON hrv_measurements(timestamp)
    ''');
  }

  /// Yangi measurement saqlash
  Future<void> saveMeasurement(HRVMeasurement measurement) async {
    final db = await database;
    await db.insert(
      'hrv_measurements',
      measurement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Barcha measurements olish
  Future<List<HRVMeasurement>> getAllMeasurements() async {
    final db = await database;
    final maps = await db.query(
      'hrv_measurements',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => HRVMeasurement.fromMap(maps[i]));
  }

  /// Oxirgi measurement olish
  Future<HRVMeasurement?> getLatestMeasurement() async {
    final db = await database;
    final maps = await db.query(
      'hrv_measurements',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return HRVMeasurement.fromMap(maps[0]);
  }

  /// Shaxs measurements (bugungi)
  Future<List<HRVMeasurement>> getTodayMeasurements() async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final maps = await db.query(
      'hrv_measurements',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) => HRVMeasurement.fromMap(maps[i]));
  }

  /// O'tgan 7 kunlik measurements
  Future<List<HRVMeasurement>> getLast7DaysMeasurements() async {
    final db = await database;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(Duration(days: 7));

    final maps = await db.query(
      'hrv_measurements',
      where: 'timestamp >= ?',
      whereArgs: [sevenDaysAgo.toIso8601String()],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) => HRVMeasurement.fromMap(maps[i]));
  }

  /// O'tgan 30 kunlik measurements
  Future<List<HRVMeasurement>> getLast30DaysMeasurements() async {
    final db = await database;
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(Duration(days: 30));

    final maps = await db.query(
      'hrv_measurements',
      where: 'timestamp >= ?',
      whereArgs: [thirtyDaysAgo.toIso8601String()],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) => HRVMeasurement.fromMap(maps[i]));
  }

  /// Measurement o'chirish
  Future<void> deleteMeasurement(String id) async {
    final db = await database;
    await db.delete(
      'hrv_measurements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Measurement yangilash (notes qo'shish)
  Future<void> updateMeasurementNotes(String id, String notes) async {
    final db = await database;
    await db.update(
      'hrv_measurements',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// O'rtacha HRV qiymatlarini hisoblash
  Future<Map<String, double>> getAverageStats(List<HRVMeasurement> measurements) async {
    if (measurements.isEmpty) {
      return {
        'avgHeartRate': 0,
        'avgSDNN': 0,
        'avgRMSSD': 0,
        'avgStressIndex': 0,
      };
    }

    double avgHeartRate = measurements.fold<double>(0, (sum, m) => sum + m.heartRate) / measurements.length;
    double avgSDNN = measurements.fold<double>(0, (sum, m) => sum + m.sdnn) / measurements.length;
    double avgRMSSD = measurements.fold<double>(0, (sum, m) => sum + m.rmssd) / measurements.length;
    double avgStressIndex = measurements.fold<double>(0, (sum, m) => sum + m.stressIndex) / measurements.length;

    return {
      'avgHeartRate': avgHeartRate,
      'avgSDNN': avgSDNN,
      'avgRMSSD': avgRMSSD,
      'avgStressIndex': avgStressIndex,
    };
  }

  /// Barcha ma'lumotlarni export qilish (CSV)
  Future<String> exportToCSV(List<HRVMeasurement> measurements) async {
    StringBuffer csv = StringBuffer();
    csv.writeln('Timestamp,Heart Rate,SDNN,RMSSD,pNN50,LF,HF,LF/HF Ratio,Stress Index,Recovery Potential,Notes');

    for (var m in measurements) {
      csv.writeln('${m.timestamp},${m.heartRate},${m.sdnn.toStringAsFixed(2)},${m.rmssd.toStringAsFixed(2)},${m.pnn50.toStringAsFixed(2)},${m.lf.toStringAsFixed(2)},${m.hf.toStringAsFixed(2)},${m.lfHfRatio.toStringAsFixed(2)},${m.stressIndex},${m.recoveryPotential},${m.notes}');
    }

    return csv.toString();
  }

  /// Database o'chirish (debug uchun)
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('hrv_measurements');
  }
}
