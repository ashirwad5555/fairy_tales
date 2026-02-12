import 'package:flutter/material.dart';
import '../models/story_book.dart';
import '../managers/audio_manager.dart';
import '../managers/haptic_helper.dart';
import '../managers/favorites_manager.dart';
import '../managers/reading_progress_manager.dart';
import '../screens/book_reader_screen.dart';

class BookCard extends StatefulWidget {
  final StoryBook book;
  final int delay;
  final AnimationController animation;
  final bool isDarkMode;

  const BookCard({
    Key? key,
    required this.book,
    required this.delay,
    required this.animation,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> {
  bool _isFavorite = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBookData();
  }

  Future<void> _loadBookData() async {
    final isFav = await FavoritesManager.isFavorite(widget.book.title);
    final progress = await ReadingProgressManager.getProgress(
      widget.book.title,
    );
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _progress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final slideAnimation =
        Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: widget.animation,
            curve: Interval(
              widget.delay / 1000,
              (widget.delay + 400) / 1000,
              curve: Curves.easeOut,
            ),
          ),
        );

    return SlideTransition(
      position: slideAnimation,
      child: GestureDetector(
        onTap: () async {
          await HapticHelper.mediumImpact();
          AudioManager().playSound('page_turn');
          if (mounted) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    BookReaderScreen(
                      book: widget.book,
                      isDarkMode: widget.isDarkMode,
                      onProgressUpdate: (progress) {
                        if (mounted) {
                          setState(() => _progress = progress);
                        }
                      },
                    ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
              ),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 140,
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF2C2C54) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.book.coverColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.book.coverColor,
                      widget.book.coverColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.book.coverImage,
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.book.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF2C3E50),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: _isFavorite
                                  ? Colors.red
                                  : (widget.isDarkMode
                                        ? Colors.white70
                                        : const Color(0xFF7F8C8D)),
                            ),
                            onPressed: () async {
                              await HapticHelper.lightImpact();
                              AudioManager().playSound('favorite');
                              await FavoritesManager.toggleFavorite(
                                widget.book.title,
                              );
                              if (mounted) {
                                setState(() => _isFavorite = !_isFavorite);
                              }
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: widget.isDarkMode
                                ? Colors.white70
                                : const Color(0xFF7F8C8D),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.book.author,
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.isDarkMode
                                  ? Colors.white70
                                  : const Color(0xFF7F8C8D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_progress > 0)
                        Column(
                          children: [
                            LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.book.coverColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(_progress * 100).toInt()}% complete',
                              style: TextStyle(
                                fontSize: 10,
                                color: widget.isDarkMode
                                    ? Colors.white60
                                    : const Color(0xFF7F8C8D),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: widget.book.coverColor,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
