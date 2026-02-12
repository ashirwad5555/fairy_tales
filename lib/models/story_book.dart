import 'package:flutter/material.dart';

class StoryBook {
  final String title;
  final String coverImage;
  final Color coverColor;
  final String story;
  final String author;
  final String? lottieAnimation;

  StoryBook({
    required this.title,
    required this.coverImage,
    required this.coverColor,
    required this.story,
    required this.author,
    this.lottieAnimation,
  });
}
