import 'package:shared_preferences/shared_preferences.dart';

class ReadingProgressManager {
  static Future<void> saveProgress(String bookTitle, double progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('progress_$bookTitle', progress);
  }

  static Future<double> getProgress(String bookTitle) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('progress_$bookTitle') ?? 0.0;
  }

  static Future<void> markAsComplete(String bookTitle) async {
    await saveProgress(bookTitle, 1.0);
  }
}
