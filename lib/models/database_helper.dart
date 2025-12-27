import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'diary.dart';
import 'picture.dart';
import 'diary_date.dart';
import 'mood.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'journal.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 創建日記表
    await db.execute('''
      CREATE TABLE diaries (
        id TEXT PRIMARY KEY,
        create_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        content TEXT NOT NULL,
        location TEXT,
        mood_value TEXT,
        mood_why TEXT
      )
    ''');

    // 創建圖片表
    await db.execute('''
      CREATE TABLE pictures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        diary_id TEXT NOT NULL,
        picture_url TEXT NOT NULL,
        caption TEXT,
        is_local_file INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (diary_id) REFERENCES diaries (id) ON DELETE CASCADE
      )
    ''');
  }

  // 插入日記
  Future<void> insertDiary(Diary diary) async {
    final db = await database;

    // 插入日記
    await db.insert('diaries', {
      'id': diary.id,
      'create_time': diary.createTime.millisecondsSinceEpoch,
      'update_time': diary.updateTime.millisecondsSinceEpoch,
      'is_deleted': diary.isDeleted ? 1 : 0,
      'date': diary.date.toDateString(),
      'content': diary.content,
      'location': diary.location,
      'mood_value': diary.mood?.value,
      'mood_why': diary.mood?.why,
    });

    // 插入圖片
    for (final picture in diary.pictures) {
      await db.insert('pictures', {
        'diary_id': diary.id,
        'picture_url': picture.pictureUrl,
        'caption': picture.caption,
        'is_local_file': picture.isLocalFile ? 1 : 0,
      });
    }
  }

  // 更新日記
  Future<void> updateDiary(Diary diary) async {
    final db = await database;

    // 更新日記
    await db.update(
      'diaries',
      {
        'update_time': diary.updateTime.millisecondsSinceEpoch,
        'is_deleted': diary.isDeleted ? 1 : 0,
        'date': diary.date.toDateString(),
        'content': diary.content,
        'location': diary.location,
        'mood_value': diary.mood?.value,
        'mood_why': diary.mood?.why,
      },
      where: 'id = ?',
      whereArgs: [diary.id],
    );

    // 刪除舊的圖片
    await db.delete('pictures', where: 'diary_id = ?', whereArgs: [diary.id]);

    // 插入新的圖片
    for (final picture in diary.pictures) {
      await db.insert('pictures', {
        'diary_id': diary.id,
        'picture_url': picture.pictureUrl,
        'caption': picture.caption,
        'is_local_file': picture.isLocalFile ? 1 : 0,
      });
    }
  }

  // 刪除日記
  Future<void> deleteDiary(String id) async {
    final db = await database;
    await db.delete('diaries', where: 'id = ?', whereArgs: [id]);
    // 圖片會因為外鍵約束自動刪除
  }

  // 獲取單個日記
  Future<Diary?> getDiary(String id) async {
    final db = await database;

    final diaryMaps = await db.query(
      'diaries',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );

    if (diaryMaps.isEmpty) return null;

    final diaryMap = diaryMaps.first;
    final pictures = await _getPicturesForDiary(id);

    return _mapToDiary(diaryMap, pictures);
  }

  // 獲取所有日記
  Future<List<Diary>> getAllDiaries() async {
    final db = await database;

    final diaryMaps = await db.query(
      'diaries',
      where: 'is_deleted = 0',
      orderBy: 'create_time DESC',
    );

    final diaries = <Diary>[];
    for (final diaryMap in diaryMaps) {
      final diaryId = diaryMap['id'] as String;
      final pictures = await _getPicturesForDiary(diaryId);
      diaries.add(_mapToDiary(diaryMap, pictures));
    }

    return diaries;
  }

  // 獲取特定日記的圖片
  Future<List<Picture>> _getPicturesForDiary(String diaryId) async {
    final db = await database;

    final pictureMaps = await db.query(
      'pictures',
      where: 'diary_id = ?',
      whereArgs: [diaryId],
    );

    return pictureMaps.map((map) => Picture(
      pictureUrl: map['picture_url'] as String,
      caption: map['caption'] as String?,
      isLocalFile: (map['is_local_file'] as int) == 1,
    )).toList();
  }

  // 將數據庫行映射為 Diary 對象
  Diary _mapToDiary(Map<String, dynamic> map, List<Picture> pictures) {
    return Diary(
      id: map['id'] as String,
      createTime: DateTime.fromMillisecondsSinceEpoch(map['create_time'] as int),
      updateTime: DateTime.fromMillisecondsSinceEpoch(map['update_time'] as int),
      isDeleted: (map['is_deleted'] as int) == 1,
      date: DiaryDate.fromString(map['date'] as String),
      content: map['content'] as String,
      pictures: pictures,
      location: map['location'] as String?,
      mood: Mood.fromString(
        map['mood_value'] as String?,
        map['mood_why'] as String?,
      ),
    );
  }

  // 關閉數據庫
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
