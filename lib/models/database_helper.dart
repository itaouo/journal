import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'diary.dart';
import 'picture.dart';
import 'diary_date.dart';
import 'record.dart';
import 'meal.dart';
import 'review.dart';
import 'review_type.dart';
import 'custom_entry.dart';

class DiarySyncMetadata {
  final String? driveJsonFileId;
  final String syncStatus;
  final List<String> pendingDriveDeletes;

  const DiarySyncMetadata({
    this.driveJsonFileId,
    required this.syncStatus,
    this.pendingDriveDeletes = const [],
  });

  static const statusPending = 'pending';
  static const statusSynced = 'synced';
  static const statusFailed = 'failed';
}

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
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE pictures ADD COLUMN drive_file_id TEXT');
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE diaries ADD COLUMN drive_json_file_id TEXT",
      );
      await db.execute(
        "ALTER TABLE diaries ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'pending'",
      );
      await db.execute(
        'ALTER TABLE diaries ADD COLUMN pending_drive_deletes TEXT',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE diaries ADD COLUMN is_locked INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE pictures ADD COLUMN is_encrypted INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE reviews (
          id TEXT PRIMARY KEY,
          create_time INTEGER NOT NULL,
          update_time INTEGER NOT NULL,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          review_type TEXT NOT NULL,
          title TEXT NOT NULL,
          summary TEXT NOT NULL DEFAULT '',
          key_quotes TEXT NOT NULL DEFAULT '',
          thoughts TEXT NOT NULL DEFAULT '',
          rating INTEGER,
          rating_note TEXT,
          experience_date TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE review_pictures (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          review_id TEXT NOT NULL,
          picture_url TEXT NOT NULL,
          caption TEXT,
          is_local_file INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (review_id) REFERENCES reviews (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE custom_entries (
          id TEXT PRIMARY KEY,
          template_id TEXT NOT NULL,
          create_time INTEGER NOT NULL,
          update_time INTEGER NOT NULL,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          is_locked INTEGER NOT NULL DEFAULT 0,
          fields_json TEXT NOT NULL DEFAULT '{}'
        )
      ''');
    }
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
        mood_why TEXT,
        drive_json_file_id TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        pending_drive_deletes TEXT,
        is_locked INTEGER NOT NULL DEFAULT 0
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
        drive_file_id TEXT,
        is_encrypted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (diary_id) REFERENCES diaries (id) ON DELETE CASCADE
      )
    ''');

    // 創建記錄表
    await db.execute('''
      CREATE TABLE records (
        id TEXT PRIMARY KEY,
        create_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL,
        occur_time INTEGER NOT NULL,
        meal_type TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE reviews (
        id TEXT PRIMARY KEY,
        create_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        review_type TEXT NOT NULL,
        title TEXT NOT NULL,
        summary TEXT NOT NULL DEFAULT '',
        key_quotes TEXT NOT NULL DEFAULT '',
        thoughts TEXT NOT NULL DEFAULT '',
        rating INTEGER,
        rating_note TEXT,
        experience_date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE review_pictures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        review_id TEXT NOT NULL,
        picture_url TEXT NOT NULL,
        caption TEXT,
        is_local_file INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (review_id) REFERENCES reviews (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_entries (
        id TEXT PRIMARY KEY,
        template_id TEXT NOT NULL,
        create_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        is_locked INTEGER NOT NULL DEFAULT 0,
        fields_json TEXT NOT NULL DEFAULT '{}'
      )
    ''');
  }


  // 插入日記
  Future<void> insertDiary(
    Diary diary, {
    String syncStatus = DiarySyncMetadata.statusPending,
    String? driveJsonFileId,
    List<String> pendingDriveDeletes = const [],
  }) async {
    final db = await database;

    // 插入日記
    await db.insert('diaries', {
      'id': diary.id,
      'create_time': diary.createTime.millisecondsSinceEpoch,
      'update_time': diary.updateTime.millisecondsSinceEpoch,
      'is_deleted': diary.isDeleted ? 1 : 0,
      'date': diary.date.toDateString(),
      'content': diary.content,
      'is_locked': diary.isLocked ? 1 : 0,
      'drive_json_file_id': driveJsonFileId,
      'sync_status': syncStatus,
      'pending_drive_deletes': _encodePendingDeletes(pendingDriveDeletes),
    });

    // 插入圖片
    for (final picture in diary.pictures) {
      await db.insert('pictures', {
        'diary_id': diary.id,
        'picture_url': picture.pictureUrl,
        'caption': picture.caption,
        'is_local_file': picture.isLocalFile ? 1 : 0,
        'drive_file_id': picture.driveFileId,
        'is_encrypted': picture.isEncrypted ? 1 : 0,
      });
    }
  }

  // 更新日記
  Future<void> updateDiary(
    Diary diary, {
    String syncStatus = DiarySyncMetadata.statusPending,
    String? driveJsonFileId,
    List<String>? pendingDriveDeletes,
    bool preserveDriveJsonFileId = true,
  }) async {
    final db = await database;

    final existingMeta = await getDiarySyncMetadata(diary.id);
    final resolvedDriveJsonFileId = driveJsonFileId ??
        (preserveDriveJsonFileId ? existingMeta?.driveJsonFileId : null);
    final resolvedPendingDeletes = pendingDriveDeletes ??
        existingMeta?.pendingDriveDeletes ??
        const <String>[];

    // 更新日記
    await db.update(
      'diaries',
      {
        'update_time': diary.updateTime.millisecondsSinceEpoch,
        'is_deleted': diary.isDeleted ? 1 : 0,
        'date': diary.date.toDateString(),
        'content': diary.content,
        'is_locked': diary.isLocked ? 1 : 0,
        'drive_json_file_id': resolvedDriveJsonFileId,
        'sync_status': syncStatus,
        'pending_drive_deletes': _encodePendingDeletes(resolvedPendingDeletes),
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
        'drive_file_id': picture.driveFileId,
        'is_encrypted': picture.isEncrypted ? 1 : 0,
      });
    }
  }

  Future<void> upsertDiary(Diary diary) async {
    final existing = await getDiary(diary.id);
    if (existing == null) {
      await insertDiary(diary);
    } else {
      await updateDiary(diary);
    }
  }

  Future<void> upsertDiaryFromCloud(
    Diary diary, {
    required String driveJsonFileId,
  }) async {
    final existing = await getDiary(diary.id);
    if (existing == null) {
      await insertDiary(
        diary,
        syncStatus: DiarySyncMetadata.statusSynced,
        driveJsonFileId: driveJsonFileId,
      );
    } else {
      await updateDiary(
        diary,
        syncStatus: DiarySyncMetadata.statusSynced,
        driveJsonFileId: driveJsonFileId,
        pendingDriveDeletes: const [],
      );
    }
  }

  Future<DiarySyncMetadata?> getDiarySyncMetadata(String id) async {
    final db = await database;
    final rows = await db.query(
      'diaries',
      columns: ['drive_json_file_id', 'sync_status', 'pending_drive_deletes'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _mapToSyncMetadata(rows.first);
  }

  Future<List<String>> getPendingSyncDiaryIds() async {
    final db = await database;
    final rows = await db.query(
      'diaries',
      columns: ['id'],
      where: "sync_status IN (?, ?) AND is_deleted = 0",
      whereArgs: [
        DiarySyncMetadata.statusPending,
        DiarySyncMetadata.statusFailed,
      ],
    );
    return rows.map((row) => row['id'] as String).toList();
  }

  Future<int> getPendingSyncCount() async {
    final ids = await getPendingSyncDiaryIds();
    return ids.length;
  }

  Future<void> updateSyncStatus(
    String id, {
    required String syncStatus,
    String? driveJsonFileId,
    List<String> pendingDriveDeletes = const [],
  }) async {
    final db = await database;
    final updates = <String, Object?>{
      'sync_status': syncStatus,
      'pending_drive_deletes': _encodePendingDeletes(pendingDriveDeletes),
    };
    if (driveJsonFileId != null) {
      updates['drive_json_file_id'] = driveJsonFileId;
    }
    await db.update(
      'diaries',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  String? _encodePendingDeletes(List<String> ids) {
    if (ids.isEmpty) return null;
    return jsonEncode(ids);
  }

  List<String> _decodePendingDeletes(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.map((item) => item.toString()).toList();
  }

  DiarySyncMetadata _mapToSyncMetadata(Map<String, dynamic> map) {
    return DiarySyncMetadata(
      driveJsonFileId: map['drive_json_file_id'] as String?,
      syncStatus: map['sync_status'] as String? ??
          DiarySyncMetadata.statusPending,
      pendingDriveDeletes:
          _decodePendingDeletes(map['pending_drive_deletes'] as String?),
    );
  }

  Future<void> updateDiaryLockStatus(String id, bool isLocked) async {
    final db = await database;
    await db.update(
      'diaries',
      {
        'is_locked': isLocked ? 1 : 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
        'sync_status': DiarySyncMetadata.statusPending,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
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

    return pictureMaps.map((map) {
      final driveFileId = map['drive_file_id'] as String?;
      final pictureUrl = map['picture_url'] as String;
      final isLocalFile = (map['is_local_file'] as int) == 1;

      return Picture(
        pictureUrl: pictureUrl,
        caption: map['caption'] as String?,
        isLocalFile: isLocalFile,
        driveFileId: driveFileId,
        isEncrypted: (map['is_encrypted'] as int? ?? 0) == 1,
      );
    }).toList();
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
      isLocked: (map['is_locked'] as int? ?? 0) == 1,
    );
  }

  // 插入記錄
  Future<void> insertRecord(dynamic record) async {
    final db = await database;
    if (record is Meal) {
      await db.insert('records', {
        'id': record.id,
        'create_time': record.createTime.millisecondsSinceEpoch,
        'update_time': record.updateTime.millisecondsSinceEpoch,
        'occur_time': record.occurTime.millisecondsSinceEpoch,
        'meal_type': record.mealType,
      });
    } else if (record is Record) {
      await db.insert('records', {
        'id': record.id,
        'create_time': record.createTime.millisecondsSinceEpoch,
        'update_time': record.updateTime.millisecondsSinceEpoch,
        'occur_time': record.occurTime.millisecondsSinceEpoch,
        'meal_type': null,
      });
    }
  }

  // 獲取所有記錄
  Future<List<Record>> getAllRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('records');

    return List<Record>.from(maps.map((map) => Record(
      id: map['id'] as String,
      createTime: DateTime.fromMillisecondsSinceEpoch(map['create_time'] as int),
      updateTime: DateTime.fromMillisecondsSinceEpoch(map['update_time'] as int),
      occurTime: DateTime.fromMillisecondsSinceEpoch(map['occur_time'] as int),
    )));
  }

  // 獲取所有餐食記錄
  Future<List<Meal>> getAllMeals() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'records',
      where: 'meal_type IS NOT NULL',
    );

    return List<Meal>.from(maps.map((map) => Meal(
      id: map['id'] as String,
      createTime: DateTime.fromMillisecondsSinceEpoch(map['create_time'] as int),
      updateTime: DateTime.fromMillisecondsSinceEpoch(map['update_time'] as int),
      occurTime: DateTime.fromMillisecondsSinceEpoch(map['occur_time'] as int),
      mealType: map['meal_type'] as String,
    )));
  }

  // 插入餐食記錄
  Future<void> insertMeal(Meal meal) async {
    await insertRecord(meal);
  }

  // 更新餐食記錄
  Future<void> updateMeal(Meal meal) async {
    await updateRecord(meal);
  }

  // 刪除餐食記錄
  Future<void> deleteMeal(String id) async {
    await deleteRecord(id);
  }

  // 根據 ID 獲取餐食記錄
  Future<Meal?> getMeal(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'records',
      where: 'id = ? AND meal_type IS NOT NULL',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return Meal(
      id: map['id'] as String,
      createTime: DateTime.fromMillisecondsSinceEpoch(map['create_time'] as int),
      updateTime: DateTime.fromMillisecondsSinceEpoch(map['update_time'] as int),
      occurTime: DateTime.fromMillisecondsSinceEpoch(map['occur_time'] as int),
      mealType: map['meal_type'] as String,
    );
  }

  // 根據 ID 獲取記錄
  Future<Record?> getRecord(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'records',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return Record(
      id: map['id'] as String,
      createTime: DateTime.fromMillisecondsSinceEpoch(map['create_time'] as int),
      updateTime: DateTime.fromMillisecondsSinceEpoch(map['update_time'] as int),
      occurTime: DateTime.fromMillisecondsSinceEpoch(map['occur_time'] as int),
    );
  }

  // 更新記錄
  Future<void> updateRecord(dynamic record) async {
    final db = await database;
    if (record is Meal) {
      await db.update(
        'records',
        {
          'create_time': record.createTime.millisecondsSinceEpoch,
          'update_time': record.updateTime.millisecondsSinceEpoch,
          'occur_time': record.occurTime.millisecondsSinceEpoch,
          'meal_type': record.mealType,
        },
        where: 'id = ?',
        whereArgs: [record.id],
      );
    } else if (record is Record) {
      await db.update(
        'records',
        {
          'create_time': record.createTime.millisecondsSinceEpoch,
          'update_time': record.updateTime.millisecondsSinceEpoch,
          'occur_time': record.occurTime.millisecondsSinceEpoch,
          'meal_type': null,
        },
        where: 'id = ?',
        whereArgs: [record.id],
      );
    }
  }

  // 刪除記錄
  Future<void> deleteRecord(String id) async {
    final db = await database;
    await db.delete(
      'records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<String>> getLockedDiaryIds() async {
    final db = await database;
    final rows = await db.query(
      'diaries',
      columns: ['id'],
      where: 'is_locked = 1 AND is_deleted = 0',
    );
    return rows.map((row) => row['id'] as String).toList();
  }

  Future<bool> hasLockedDiaries() async {
    final ids = await getLockedDiaryIds();
    return ids.isNotEmpty;
  }

  Future<bool> hasPendingLockedSync() async {
    final db = await database;
    final rows = await db.query(
      'diaries',
      columns: ['id'],
      where:
          "is_locked = 1 AND is_deleted = 0 AND sync_status IN (?, ?)",
      whereArgs: [
        DiarySyncMetadata.statusPending,
        DiarySyncMetadata.statusFailed,
      ],
    );
    return rows.isNotEmpty;
  }

  Future<void> markAllDiariesPendingSync() async {
    final db = await database;
    await db.update(
      'diaries',
      {
        'sync_status': DiarySyncMetadata.statusPending,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'is_deleted = 0',
    );
  }

  Future<void> insertReview(Review review) async {
    final db = await database;
    await db.insert('reviews', _reviewToMap(review));
    for (final picture in review.pictures) {
      await db.insert('review_pictures', {
        'review_id': review.id,
        'picture_url': picture.pictureUrl,
        'caption': picture.caption,
        'is_local_file': picture.isLocalFile ? 1 : 0,
      });
    }
  }

  Future<void> updateReview(Review review) async {
    final db = await database;
    await db.update(
      'reviews',
      _reviewToMap(review),
      where: 'id = ?',
      whereArgs: [review.id],
    );
    await db.delete(
      'review_pictures',
      where: 'review_id = ?',
      whereArgs: [review.id],
    );
    for (final picture in review.pictures) {
      await db.insert('review_pictures', {
        'review_id': review.id,
        'picture_url': picture.pictureUrl,
        'caption': picture.caption,
        'is_local_file': picture.isLocalFile ? 1 : 0,
      });
    }
  }

  Future<void> deleteReview(String id) async {
    final db = await database;
    await db.delete('reviews', where: 'id = ?', whereArgs: [id]);
  }

  Future<Review?> getReview(String id) async {
    final db = await database;
    final rows = await db.query(
      'reviews',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final reviewId = rows.first['id'] as String;
    final pictures = await _getPicturesForReview(reviewId);
    return _mapToReview(rows.first, pictures);
  }

  Future<List<Review>> getAllReviews() async {
    final db = await database;
    final rows = await db.query(
      'reviews',
      where: 'is_deleted = 0',
      orderBy: 'experience_date DESC, create_time DESC',
    );
    final reviews = <Review>[];
    for (final row in rows) {
      final reviewId = row['id'] as String;
      final pictures = await _getPicturesForReview(reviewId);
      reviews.add(_mapToReview(row, pictures));
    }
    return reviews;
  }

  Future<List<Picture>> _getPicturesForReview(String reviewId) async {
    final db = await database;
    final pictureMaps = await db.query(
      'review_pictures',
      where: 'review_id = ?',
      whereArgs: [reviewId],
    );
    return pictureMaps.map((map) {
      return Picture(
        pictureUrl: map['picture_url'] as String,
        caption: map['caption'] as String?,
        isLocalFile: (map['is_local_file'] as int) == 1,
      );
    }).toList();
  }

  Map<String, Object?> _reviewToMap(Review review) {
    return {
      'id': review.id,
      'create_time': review.createTime.millisecondsSinceEpoch,
      'update_time': review.updateTime.millisecondsSinceEpoch,
      'is_deleted': review.isDeleted ? 1 : 0,
      'review_type': review.reviewType.name,
      'title': review.title,
      'summary': review.summary,
      'key_quotes': review.keyQuotes,
      'thoughts': review.thoughts,
      'rating': review.rating,
      'rating_note': review.ratingNote,
      'experience_date': review.experienceDate.toDateString(),
    };
  }

  Review _mapToReview(Map<String, dynamic> map, List<Picture> pictures) {
    return Review(
      id: map['id'] as String,
      createTime: DateTime.fromMillisecondsSinceEpoch(map['create_time'] as int),
      updateTime: DateTime.fromMillisecondsSinceEpoch(map['update_time'] as int),
      isDeleted: (map['is_deleted'] as int) == 1,
      reviewType: ReviewType.fromString(map['review_type'] as String),
      title: map['title'] as String,
      summary: map['summary'] as String? ?? '',
      keyQuotes: map['key_quotes'] as String? ?? '',
      thoughts: map['thoughts'] as String? ?? '',
      rating: map['rating'] as int?,
      ratingNote: map['rating_note'] as String?,
      experienceDate: DiaryDate.fromString(map['experience_date'] as String),
      pictures: pictures,
    );
  }

  Future<void> insertCustomEntry(CustomEntry entry) async {
    final db = await database;
    await db.insert('custom_entries', _customEntryToMap(entry));
  }

  Future<void> updateCustomEntry(CustomEntry entry) async {
    final db = await database;
    await db.update(
      'custom_entries',
      _customEntryToMap(entry),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> softDeleteCustomEntry(String id) async {
    final db = await database;
    await db.update(
      'custom_entries',
      {
        'is_deleted': 1,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<CustomEntry?> getCustomEntry(String id) async {
    final db = await database;
    final rows = await db.query(
      'custom_entries',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _mapToCustomEntry(rows.first);
  }

  Future<List<CustomEntry>> getAllCustomEntries() async {
    final db = await database;
    final rows = await db.query(
      'custom_entries',
      where: 'is_deleted = 0',
      orderBy: 'update_time DESC, create_time DESC',
    );
    return rows.map(_mapToCustomEntry).toList();
  }

  Future<List<CustomEntry>> getCustomEntriesByTemplateId(String templateId) async {
    final db = await database;
    final rows = await db.query(
      'custom_entries',
      where: 'template_id = ? AND is_deleted = 0',
      whereArgs: [templateId],
      orderBy: 'update_time DESC, create_time DESC',
    );
    return rows.map(_mapToCustomEntry).toList();
  }

  Map<String, Object?> _customEntryToMap(CustomEntry entry) {
    return {
      'id': entry.id,
      'template_id': entry.templateId,
      'create_time': entry.createTime.millisecondsSinceEpoch,
      'update_time': entry.updateTime.millisecondsSinceEpoch,
      'is_deleted': entry.isDeleted ? 1 : 0,
      'is_locked': entry.isLocked ? 1 : 0,
      'fields_json': entry.fieldValuesJson,
    };
  }

  CustomEntry _mapToCustomEntry(Map<String, dynamic> map) {
    return CustomEntry(
      id: map['id'] as String,
      createTime: DateTime.fromMillisecondsSinceEpoch(map['create_time'] as int),
      updateTime: DateTime.fromMillisecondsSinceEpoch(map['update_time'] as int),
      isDeleted: (map['is_deleted'] as int) == 1,
      templateId: map['template_id'] as String,
      isLocked: (map['is_locked'] as int) == 1,
      fieldValues: _decodeFieldValues(map['fields_json'] as String?),
    );
  }

  Map<String, dynamic> _decodeFieldValues(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  // 關閉數據庫
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
