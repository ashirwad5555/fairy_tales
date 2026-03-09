import 'package:flutter/material.dart';
import 'story_page.dart';

class StoryBook {
  final String title;
  final String coverImage;
  final Color coverColor;
  final String story;
  final String author;
  final String? lottieAnimation;
  final String storyType; // "text" | "pages"
  final List<StoryPage> pages;

  StoryBook({
    required this.title,
    required this.coverImage,
    required this.coverColor,
    required this.story,
    required this.author,
    this.lottieAnimation,
    this.storyType = 'text',
    this.pages = const [],
  });

  bool get isPagedStory => storyType == 'pages' && pages.isNotEmpty;

  /// Full concatenated story text used for TTS
  String get fullStoryText =>
      isPagedStory ? pages.map((p) => p.text).join(' ') : story;
}
