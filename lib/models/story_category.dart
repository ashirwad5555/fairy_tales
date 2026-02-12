import 'package:flutter/material.dart';
import 'story_book.dart';

class StoryCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<StoryBook> books;

  StoryCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.books,
  });
}
