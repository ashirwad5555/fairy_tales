import 'package:shared_preferences/shared_preferences.dart';

class FavoritesManager {
  static Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('favorites') ?? [];
  }

  static Future<void> toggleFavorite(String bookTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();

    if (favorites.contains(bookTitle)) {
      favorites.remove(bookTitle);
    } else {
      favorites.add(bookTitle);
    }

    await prefs.setStringList('favorites', favorites);
  }

  static Future<bool> isFavorite(String bookTitle) async {
    final favorites = await getFavorites();
    return favorites.contains(bookTitle);
  }
}
