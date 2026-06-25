import 'custom_entry.dart';
import 'database_helper.dart';

class CustomEntryManager {
  static final CustomEntryManager _instance = CustomEntryManager._internal();
  final DatabaseHelper _db = DatabaseHelper();

  factory CustomEntryManager() {
    return _instance;
  }

  CustomEntryManager._internal();

  Future<List<CustomEntry>> getAll() async {
    return _db.getAllCustomEntries();
  }

  Future<CustomEntry?> getById(String id) async {
    return _db.getCustomEntry(id);
  }

  Future<void> add(CustomEntry entry) async {
    await _db.insertCustomEntry(entry);
  }

  Future<void> update(CustomEntry entry) async {
    await _db.updateCustomEntry(entry);
  }

  Future<void> delete(String id) async {
    await _db.softDeleteCustomEntry(id);
  }
}
