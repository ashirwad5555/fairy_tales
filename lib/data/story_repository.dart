import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/story_book.dart';
import '../models/story_page.dart';
import '../models/story_category.dart';

class StoryRepository {
  static const Map<String, IconData> _iconMap = {
    'star_rounded': Icons.star_rounded,
    'science_rounded': Icons.science_rounded,
    'castle_rounded': Icons.castle_rounded,
    'computer_rounded': Icons.computer_rounded,
    'book_rounded': Icons.book_rounded,
    'favorite_rounded': Icons.favorite_rounded,
    'nature_rounded': Icons.nature_rounded,
    'music_note_rounded': Icons.music_note_rounded,
  };

  static Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    final value = int.parse(
      clean.length == 6 ? 'FF$clean' : clean,
      radix: 16,
    );
    return Color(value);
  }

  static Future<List<StoryCategory>> loadCategories() async {
    final jsonString = await rootBundle.loadString('assets/data/stories.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    return _parseCategories(jsonData);
  }

  static List<StoryCategory> _parseCategories(Map<String, dynamic> data) {
    final List<dynamic> categoriesJson = data['categories'] as List<dynamic>;

    return categoriesJson.map((catJson) {
      final Map<String, dynamic> cat = catJson as Map<String, dynamic>;

      final List<StoryBook> books =
          (cat['books'] as List<dynamic>).map((bookJson) {
        final Map<String, dynamic> b = bookJson as Map<String, dynamic>;

        // Parse pages if present
        final List<StoryPage> pages = ((b['pages'] as List<dynamic>?) ?? [])
            .map((p) => StoryPage.fromJson(p as Map<String, dynamic>))
            .toList();

        return StoryBook(
          title: b['title'] as String,
          coverImage: b['coverImage'] as String,
          coverColor: _hexToColor(b['coverColor'] as String),
          author: b['author'] as String,
          lottieAnimation: b['lottieAnimation'] as String?,
          story: b['story'] as String? ?? '',
          storyType: b['storyType'] as String? ?? 'text',
          pages: pages,
        );
      }).toList();

      return StoryCategory(
        name: cat['name'] as String,
        icon: _iconMap[cat['icon']] ?? Icons.book_rounded,
        color: _hexToColor(cat['color'] as String),
        books: books,
      );
    }).toList();
  }

  static Map<String, dynamic> categoriesToJson(List<StoryCategory> categories) {
    return {
      'categories': categories
          .map((c) => {
                'name': c.name,
                'icon': _iconMap.entries
                    .firstWhere(
                      (e) => e.value == c.icon,
                      orElse: () =>
                          const MapEntry('book_rounded', Icons.book_rounded),
                    )
                    .key,
                'color':
                    '#${c.color.value.toRadixString(16).substring(2).toUpperCase()}',
                'books': c.books
                    .map((b) => {
                          'title': b.title,
                          'coverImage': b.coverImage,
                          'coverColor':
                              '#${b.coverColor.value.toRadixString(16).substring(2).toUpperCase()}',
                          'author': b.author,
                          'lottieAnimation': b.lottieAnimation,
                          'storyType': b.storyType,
                          'story': b.story,
                          'pages': b.pages.map((p) => p.toJson()).toList(),
                        })
                    .toList(),
              })
          .toList(),
    };
  }
}
