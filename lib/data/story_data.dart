import 'package:flutter/material.dart';
import '../models/story_category.dart';
import 'story_repository.dart';

// Legacy synchronous list — kept empty; data now loaded via StoryRepository.
// Use StoryRepository.loadCategories() everywhere instead.
final List<StoryCategory> categories = [];

// Helper to load once and cache
List<StoryCategory>? _cachedCategories;

Future<List<StoryCategory>> getCategories() async {
  _cachedCategories ??= await StoryRepository.loadCategories();
  return _cachedCategories!;
}
