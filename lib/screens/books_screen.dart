import 'package:flutter/material.dart';
import '../models/story_category.dart';
import '../managers/haptic_helper.dart';
import '../widgets/book_card.dart';

class BooksScreen extends StatefulWidget {
  final StoryCategory category;
  final bool isDarkMode;

  const BooksScreen({
    Key? key,
    required this.category,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColors = isDark
        ? [widget.category.color.withOpacity(0.2), const Color(0xFF1A1A2E)]
        : [widget.category.color.withOpacity(0.3), const Color(0xFFFFF8E7)];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bgColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        size: 30,
                        color: isDark ? Colors.white : widget.category.color,
                      ),
                      onPressed: () async {
                        await HapticHelper.lightImpact();
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      widget.category.icon,
                      color: isDark ? Colors.white : widget.category.color,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.category.name,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : widget.category.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.category.books.length,
                  itemBuilder: (context, index) {
                    return BookCard(
                      book: widget.category.books[index],
                      delay: index * 100,
                      animation: _controller,
                      isDarkMode: isDark,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
