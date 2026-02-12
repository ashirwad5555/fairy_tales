import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/story_book.dart';
import '../managers/audio_manager.dart';
import '../managers/haptic_helper.dart';
import '../managers/reading_progress_manager.dart';

class BookReaderScreen extends StatefulWidget {
  final StoryBook book;
  final bool isDarkMode;
  final Function(double) onProgressUpdate;

  const BookReaderScreen({
    Key? key,
    required this.book,
    required this.isDarkMode,
    required this.onProgressUpdate,
  }) : super(key: key);

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen>
    with TickerProviderStateMixin {
  late AnimationController _bookOpenController;
  late AnimationController _contentController;
  late Animation<double> _leftPageAngle;
  late Animation<double> _rightPageAngle;
  late ScrollController _scrollController;
  bool _isBookOpen = false;
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();

    _bookOpenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // FIXED: Inverted the animation to simulate opening towards the viewer
    // Left page rotates to the RIGHT (positive angle) when book opens
    _leftPageAngle = Tween<double>(end: 0, begin: -math.pi / 2.5).animate(
      CurvedAnimation(
        parent: _bookOpenController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    // Right page rotates to the LEFT (negative angle) when book opens
    _rightPageAngle = Tween<double>(end: 0, begin: math.pi / 2.5).animate(
      CurvedAnimation(
        parent: _bookOpenController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scrollController = ScrollController();
    _scrollController.addListener(_updateProgress);

    // Start the book opening animation
    Future.delayed(const Duration(milliseconds: 300), () async {
      await HapticHelper.heavyImpact();
      AudioManager().playSound('book_open');
      _bookOpenController.forward().then((_) {
        if (mounted) {
          setState(() => _isBookOpen = true);
          _contentController.forward();
        }
      });
    });
  }

  void _updateProgress() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final progress = maxScroll > 0 ? currentScroll / maxScroll : 0.0;

      if ((progress - _scrollProgress).abs() > 0.05) {
        if (mounted) {
          setState(() => _scrollProgress = progress);
        }
        ReadingProgressManager.saveProgress(widget.book.title, progress);
        widget.onProgressUpdate(progress);
      }
    }
  }

  Future<void> _closeBook() async {
    await HapticHelper.mediumImpact();
    AudioManager().playSound('book_open');

    setState(() => _isBookOpen = false);

    // Reverse the animation by swapping begin and end
    _leftPageAngle = Tween<double>(begin: -math.pi / 2.5, end: 0).animate(
      CurvedAnimation(
        parent: _bookOpenController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _rightPageAngle = Tween<double>(begin: math.pi / 2.5, end: 0).animate(
      CurvedAnimation(
        parent: _bookOpenController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    // Fade out content first
    await _contentController.reverse();

    // Then close the book
    await _bookOpenController.reverse();

    // Pop the screen after animation completes
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _bookOpenController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColors = isDark
        ? [widget.book.coverColor.withOpacity(0.2), const Color(0xFF1A1A2E)]
        : [widget.book.coverColor.withOpacity(0.2), const Color(0xFFFFF8E7)];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bgColors,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              if (!_isBookOpen) _buildBookOpenAnimation(),
              if (_isBookOpen) _buildBookContent(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookOpenAnimation() {
    return Center(
      child: AnimatedBuilder(
        animation: _bookOpenController,
        builder: (context, child) {
          return SizedBox(
            width: 300,
            height: 400,
            child: Stack(
              children: [
                // Left page - rotates outward to the left
                Positioned(
                  left: 0,
                  child: Transform(
                    alignment: Alignment.centerRight,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Perspective
                      ..rotateY(_leftPageAngle.value),
                    child: Container(
                      width: 150,
                      height: 400,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            widget.book.coverColor,
                            widget.book.coverColor.withOpacity(0.9),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 15,
                            offset: Offset(-5 * _bookOpenController.value, 5),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.black.withOpacity(0.1),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Transform.scale(
                          scale: 1 - (_bookOpenController.value * 0.3),
                          child: Opacity(
                            opacity: 1 - (_bookOpenController.value * 0.5),
                            child: Text(
                              widget.book.coverImage,
                              style: const TextStyle(fontSize: 60),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Right page - rotates outward to the right
                Positioned(
                  right: 0,
                  child: Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Perspective
                      ..rotateY(_rightPageAngle.value),
                    child: Container(
                      width: 150,
                      height: 400,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            widget.book.coverColor,
                            widget.book.coverColor.withOpacity(0.9),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 15,
                            offset: Offset(5 * _bookOpenController.value, 5),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.black.withOpacity(0.1),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Transform.scale(
                          scale: 1 - (_bookOpenController.value * 0.3),
                          child: Opacity(
                            opacity: 1 - (_bookOpenController.value * 0.5),
                            child: Text(
                              widget.book.coverImage,
                              style: const TextStyle(fontSize: 60),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Center spine shadow for realism
                Positioned(
                  left: 145,
                  top: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: 1 - _bookOpenController.value,
                    child: Container(
                      width: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookContent(bool isDark) {
    return FadeTransition(
      opacity: _contentController,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 30,
                    color: isDark ? Colors.white : widget.book.coverColor,
                  ),
                  onPressed: _closeBook,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : widget.book.coverColor,
                        ),
                      ),
                      Text(
                        'by ${widget.book.author}',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              isDark ? Colors.white70 : const Color(0xFF7F8C8D),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_scrollProgress > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(
                value: _scrollProgress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.book.coverColor,
                ),
              ),
            ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C54) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: widget.book.coverColor.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    if (widget.book.lottieAnimation != null)
                      SizedBox(
                        height: 150,
                        child: Center(
                          child: Text(
                            widget.book.coverImage,
                            style: const TextStyle(fontSize: 80),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: widget.book.coverColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          widget.book.coverImage,
                          style: const TextStyle(fontSize: 80),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      widget.book.story,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.8,
                        color: isDark ? Colors.white : const Color(0xFF2C3E50),
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.star, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Icon(Icons.star, color: Colors.amber, size: 28),
                        SizedBox(width: 8),
                        Icon(Icons.star, color: Colors.amber, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
