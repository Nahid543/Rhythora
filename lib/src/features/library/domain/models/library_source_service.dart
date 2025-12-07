import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'library_source_settings.dart';

class LibrarySourceService {
  static const String _key = 'library_source_settings';

  static Future<void> save(LibrarySourceSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings.toJson());
    await prefs.setString(_key, jsonString);
  }

  static Future<LibrarySourceSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);
      
      if (jsonString == null) {
        return const LibrarySourceSettings();
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return LibrarySourceSettings.fromJson(json);
    } catch (e) {
      return const LibrarySourceSettings();
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
