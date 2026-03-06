import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';
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

  // TTS fields
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  bool _isPaused = false;

  // Word highlighting fields
  int _currentWordStart = -1;
  int _currentWordEnd = -1;
  double _ttsProgress = 0.0;
  List<String> _words = [];
  int _currentWordIndex = -1;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _words = widget.book.story.split(RegExp(r'\s+'));
    _initTts();
    _setupAnimations();

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

  void _setupAnimations() {
    _bookOpenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _leftPageAngle = Tween<double>(end: 0, begin: -math.pi / 2.5).animate(
      CurvedAnimation(
        parent: _bookOpenController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

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
    _scrollController.addListener(_updateScrollProgress);
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
          _currentWordStart = -1;
          _currentWordEnd = -1;
          _currentWordIndex = -1;
          _ttsProgress = 1.0;
        });
        ReadingProgressManager.saveProgress(widget.book.title, 1.0);
        widget.onProgressUpdate(1.0);
      }
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
          _currentWordStart = -1;
          _currentWordEnd = -1;
          _currentWordIndex = -1;
        });
      }
    });

    _flutterTts.setPauseHandler(() {
      if (mounted) setState(() => _isPaused = true);
    });

    _flutterTts.setContinueHandler(() {
      if (mounted) setState(() => _isPaused = false);
    });

    // Word range handler — fires for each word spoken
    _flutterTts.setProgressHandler(
      (String text, int startOffset, int endOffset, String word) {
        if (!mounted) return;

        // Find current word index by character offset
        int charCount = 0;
        int wordIdx = 0;
        for (int i = 0; i < _words.length; i++) {
          if (charCount >= startOffset) {
            wordIdx = i;
            break;
          }
          charCount += _words[i].length + 1; // +1 for space
          wordIdx = i;
        }

        final progress = _words.isEmpty ? 0.0 : (wordIdx + 1) / _words.length;

        setState(() {
          _currentWordStart = startOffset;
          _currentWordEnd = endOffset;
          _currentWordIndex = wordIdx;
          _ttsProgress = progress.clamp(0.0, 1.0);
        });

        // Save TTS progress & notify parent
        ReadingProgressManager.saveProgress(widget.book.title, _ttsProgress);
        widget.onProgressUpdate(_ttsProgress);

        // Auto-scroll to keep highlighted word visible
        _autoScrollToWord(wordIdx);
      },
    );
  }

  void _autoScrollToWord(int wordIndex) {
    if (!_scrollController.hasClients) return;
    final totalWords = _words.length;
    if (totalWords == 0) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    // Estimate scroll position based on word index
    // Offset by 150 (image height) + 24 spacing
    final estimatedScroll =
        ((wordIndex / totalWords) * maxScroll).clamp(0.0, maxScroll);

    _scrollController.animateTo(
      estimatedScroll,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _toggleSpeech() async {
    await HapticHelper.mediumImpact();

    if (_isSpeaking && !_isPaused) {
      await _flutterTts.pause();
    } else if (_isPaused) {
      // Resume from beginning (flutter_tts doesn't support resume mid-text on all platforms)
      await _flutterTts.speak(widget.book.story);
    } else {
      setState(() {
        _currentWordStart = -1;
        _currentWordEnd = -1;
        _currentWordIndex = -1;
        _ttsProgress = 0.0;
      });
      await _flutterTts.speak(widget.book.story);
    }
  }

  Future<void> _stopSpeech() async {
    await _flutterTts.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
        _currentWordStart = -1;
        _currentWordEnd = -1;
        _currentWordIndex = -1;
        _ttsProgress = 0.0;
      });
    }
  }

  void _updateScrollProgress() {
    if (_scrollController.hasClients && !_isSpeaking) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final progress = maxScroll > 0 ? currentScroll / maxScroll : 0.0;

      if ((progress - _scrollProgress).abs() > 0.01) {
        if (mounted) setState(() => _scrollProgress = progress);
        ReadingProgressManager.saveProgress(widget.book.title, progress);
        widget.onProgressUpdate(progress);
      }
    }
  }

  Future<void> _closeBook() async {
    await _stopSpeech();
    await HapticHelper.mediumImpact();
    AudioManager().playSound('book_open');

    setState(() => _isBookOpen = false);

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

    await _contentController.reverse();
    await _bookOpenController.reverse();

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _bookOpenController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Build highlighted story text using TextSpan
  Widget _buildHighlightedText(bool isDark) {
    if (_currentWordStart < 0 || !_isSpeaking) {
      // No highlight — plain text
      return Text(
        widget.book.story,
        key: _textKey,
        style: TextStyle(
          fontSize: 18,
          height: 1.8,
          color: isDark ? Colors.white : const Color(0xFF2C3E50),
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.justify,
      );
    }

    final story = widget.book.story;
    final safeStart = _currentWordStart.clamp(0, story.length);
    final safeEnd = _currentWordEnd.clamp(safeStart, story.length);

    final baseColor = isDark ? Colors.white : const Color(0xFF2C3E50);
    final dimColor = baseColor.withOpacity(0.35);

    return RichText(
      key: _textKey,
      textAlign: TextAlign.justify,
      text: TextSpan(
        children: [
          // Text before highlighted word — dim
          if (safeStart > 0)
            TextSpan(
              text: story.substring(0, safeStart),
              style: TextStyle(
                fontSize: 18,
                height: 1.8,
                color: dimColor,
                letterSpacing: 0.3,
              ),
            ),
          // Highlighted current word
          TextSpan(
            text: story.substring(safeStart, safeEnd),
            style: TextStyle(
              fontSize: 19,
              height: 1.8,
              color: isDark ? Colors.white : widget.book.coverColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
              backgroundColor:
                  widget.book.coverColor.withOpacity(isDark ? 0.35 : 0.18),
            ),
          ),
          // Text after highlighted word — normal
          if (safeEnd < story.length)
            TextSpan(
              text: story.substring(safeEnd),
              style: TextStyle(
                fontSize: 18,
                height: 1.8,
                color: baseColor,
                letterSpacing: 0.3,
              ),
            ),
        ],
      ),
    );
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

  Widget _buildListenButton(bool isDark) {
    final color = isDark ? Colors.white : widget.book.coverColor;

    return GestureDetector(
      onTap: _toggleSpeech,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isSpeaking
              ? widget.book.coverColor
              : widget.book.coverColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.book.coverColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isSpeaking && !_isPaused
                  ? Icons.pause_rounded
                  : Icons.volume_up_rounded,
              size: 18,
              color: _isSpeaking ? Colors.white : color,
            ),
            const SizedBox(width: 4),
            Text(
              _isSpeaking && !_isPaused
                  ? 'Pause'
                  : _isPaused
                      ? 'Resume'
                      : 'Listen',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _isSpeaking ? Colors.white : color,
              ),
            ),
            if (_isSpeaking) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _stopSpeech,
                child: Icon(
                  Icons.stop_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Dual-track progress bar:
  /// - Grey track = scroll position (manual reading)
  /// - Colored fill = TTS spoken progress
  Widget _buildProgressBar() {
    final displayProgress = _isSpeaking ? _ttsProgress : _scrollProgress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              // Background track
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Scroll progress (dimmed, shows manual reading position)
              if (!_isSpeaking && _scrollProgress > 0)
                FractionallySizedBox(
                  widthFactor: _scrollProgress.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.book.coverColor.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              // TTS / primary progress (solid color)
              if (displayProgress > 0)
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 200),
                  widthFactor: displayProgress.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.book.coverColor,
                          widget.book.coverColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: widget.book.coverColor.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isSpeaking
                    ? '🔊 ${(_ttsProgress * 100).toStringAsFixed(0)}% listened'
                    : '📖 ${(_scrollProgress * 100).toStringAsFixed(0)}% read',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.book.coverColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isSpeaking && _currentWordIndex >= 0)
                Text(
                  'Word ${_currentWordIndex + 1} / ${_words.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.book.coverColor.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookContent(bool isDark) {
    return FadeTransition(
      opacity: _contentController,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
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
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : widget.book.coverColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'by ${widget.book.author}',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              isDark ? Colors.white70 : const Color(0xFF7F8C8D),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildListenButton(isDark),
              ],
            ),
          ),

          // ── Progress Bar ─────────────────────────────────────
          _buildProgressBar(),

          // ── Story Content ─────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                    // Cover image / emoji
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

                    // ── Highlighted Story Text ─────────────────
                    _buildHighlightedText(isDark),

                    const SizedBox(height: 32),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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

  // ...existing code... (_buildBookOpenAnimation unchanged)
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
                Positioned(
                  left: 0,
                  child: Transform(
                    alignment: Alignment.centerRight,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
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
                            child: Text(widget.book.coverImage,
                                style: const TextStyle(fontSize: 60)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
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
                            child: Text(widget.book.coverImage,
                                style: const TextStyle(fontSize: 60)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
}
