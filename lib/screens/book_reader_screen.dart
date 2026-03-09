import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';
import '../models/story_book.dart';
import '../models/story_page.dart';
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
  // ── Animation controllers ──────────────────────────────────
  late AnimationController _bookOpenController;
  late AnimationController _contentController;
  late AnimationController _pageTransitionController;
  late Animation<double> _leftPageAngle;
  late Animation<double> _rightPageAngle;
  late Animation<double> _pageSlideAnimation;
  late Animation<double> _pageFadeAnimation;
  late ScrollController _scrollController;

  bool _isBookOpen = false;
  double _scrollProgress = 0.0;

  // ── TTS fields ─────────────────────────────────────────────
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  bool _isPaused = false;

  // ── Text story highlighting fields ─────────────────────────
  int _currentWordStart = -1;
  int _currentWordEnd = -1;
  double _ttsProgress = 0.0;
  List<String> _words = [];
  int _currentWordIndex = -1;
  final GlobalKey _textKey = GlobalKey();

  // ── Paged story fields ─────────────────────────────────────
  int _currentPageIndex = 0;
  bool _isPageTransitioning = false;

  // Build a word list per page for TTS word tracking
  late List<List<String>> _pageWords;
  // Cumulative word offsets so we can map global wordIdx → page
  late List<int> _pageWordOffsets;

  @override
  void initState() {
    super.initState();

    if (widget.book.isPagedStory) {
      _pageWords =
          widget.book.pages.map((p) => p.text.split(RegExp(r'\s+'))).toList();
      _pageWordOffsets = [];
      int offset = 0;
      for (final pw in _pageWords) {
        _pageWordOffsets.add(offset);
        offset += pw.length;
      }
      _words = widget.book.fullStoryText.split(RegExp(r'\s+'));
    } else {
      _words = widget.book.story.split(RegExp(r'\s+'));
      _pageWords = [];
      _pageWordOffsets = [];
    }

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

  // ── Animations ─────────────────────────────────────────────
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

    _pageTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _pageSlideAnimation = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(
          parent: _pageTransitionController, curve: Curves.easeOutCubic),
    );

    _pageFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _pageTransitionController, curve: Curves.easeOut),
    );

    _pageTransitionController.value = 1.0;

    _scrollController = ScrollController();
    _scrollController.addListener(_updateScrollProgress);
  }

  // ── TTS ────────────────────────────────────────────────────
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

    _flutterTts.setProgressHandler(
      (String text, int startOffset, int endOffset, String word) {
        if (!mounted) return;

        int charCount = 0;
        int wordIdx = 0;
        for (int i = 0; i < _words.length; i++) {
          if (charCount >= startOffset) {
            wordIdx = i;
            break;
          }
          charCount += _words[i].length + 1;
          wordIdx = i;
        }

        final progress = _words.isEmpty ? 0.0 : (wordIdx + 1) / _words.length;

        setState(() {
          _currentWordStart = startOffset;
          _currentWordEnd = endOffset;
          _currentWordIndex = wordIdx;
          _ttsProgress = progress.clamp(0.0, 1.0);
        });

        ReadingProgressManager.saveProgress(widget.book.title, _ttsProgress);
        widget.onProgressUpdate(_ttsProgress);

        // For paged stories: auto-advance page to match spoken word
        if (widget.book.isPagedStory) {
          _syncPageToWordIndex(wordIdx);
        } else {
          _autoScrollToWord(wordIdx);
        }
      },
    );
  }

  // ── Page sync with TTS ─────────────────────────────────────
  void _syncPageToWordIndex(int globalWordIdx) {
    int targetPage = 0;
    for (int i = _pageWordOffsets.length - 1; i >= 0; i--) {
      if (globalWordIdx >= _pageWordOffsets[i]) {
        targetPage = i;
        break;
      }
    }

    if (targetPage != _currentPageIndex && !_isPageTransitioning) {
      _animateToPage(targetPage, auto: true);
    }
  }

  Future<void> _animateToPage(int index, {bool auto = false}) async {
    if (_isPageTransitioning) return;
    if (index < 0 || index >= widget.book.pages.length) return;

    setState(() => _isPageTransitioning = true);

    await _pageTransitionController.reverse();
    if (mounted) {
      setState(() => _currentPageIndex = index);
      await HapticHelper.lightImpact();
    }
    await _pageTransitionController.forward();

    if (mounted) setState(() => _isPageTransitioning = false);

    // Update scroll-style progress for paged stories
    if (!auto) {
      final progress = (index + 1) / widget.book.pages.length;
      ReadingProgressManager.saveProgress(widget.book.title, progress);
      widget.onProgressUpdate(progress);
      setState(() => _scrollProgress = progress);
    }
  }

  void _autoScrollToWord(int wordIndex) {
    if (!_scrollController.hasClients) return;
    final totalWords = _words.length;
    if (totalWords == 0) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
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
      await _flutterTts.speak(widget.book.fullStoryText);
    } else {
      setState(() {
        _currentWordStart = -1;
        _currentWordEnd = -1;
        _currentWordIndex = -1;
        _ttsProgress = 0.0;
        if (widget.book.isPagedStory) _currentPageIndex = 0;
      });
      await _flutterTts.speak(widget.book.fullStoryText);
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
    _pageTransitionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────
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
              if (_isBookOpen)
                widget.book.isPagedStory
                    ? _buildPagedBookContent(isDark)
                    : _buildTextBookContent(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared Header ──────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close,
                size: 30,
                color: isDark ? Colors.white : widget.book.coverColor),
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
                    color: isDark ? Colors.white70 : const Color(0xFF7F8C8D),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          _buildListenButton(isDark),
        ],
      ),
    );
  }

  // ── Listen Button ──────────────────────────────────────────
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
                child: const Icon(Icons.stop_rounded,
                    size: 16, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Progress Bar ───────────────────────────────────────────
  Widget _buildProgressBar() {
    final displayProgress = _isSpeaking ? _ttsProgress : _scrollProgress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
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
              if (displayProgress > 0)
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 200),
                  widthFactor: displayProgress.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        widget.book.coverColor,
                        widget.book.coverColor.withOpacity(0.7),
                      ]),
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
                    : widget.book.isPagedStory
                        ? '📖 Page ${_currentPageIndex + 1} of ${widget.book.pages.length}'
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

  // ════════════════════════════════════════════════════════════
  // PAGED STORY READER
  // ════════════════════════════════════════════════════════════
  Widget _buildPagedBookContent(bool isDark) {
    final page = widget.book.pages[_currentPageIndex];
    final totalPages = widget.book.pages.length;

    return FadeTransition(
      opacity: _contentController,
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildProgressBar(),

          // ── Main page area ────────────────────────────────
          Expanded(
            child: AnimatedBuilder(
              animation: _pageTransitionController,
              builder: (context, child) {
                return Opacity(
                  opacity: _pageFadeAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, _pageSlideAnimation.value),
                    child: child,
                  ),
                );
              },
              child: _buildStoryPage(page, isDark),
            ),
          ),

          // ── Page navigation dots + arrows ─────────────────
          _buildPageNavigation(totalPages, isDark),
        ],
      ),
    );
  }

  Widget _buildStoryPage(StoryPage page, bool isDark) {
    final pageText = page.text;

    // Find highlighted word offset within this page's text
    int localStart = -1;
    int localEnd = -1;

    if (_isSpeaking && _currentWordIndex >= 0) {
      final pageOffset = _pageWordOffsets[_currentPageIndex];
      final localWordIdx = _currentWordIndex - pageOffset;
      if (localWordIdx >= 0 &&
          localWordIdx < _pageWords[_currentPageIndex].length) {
        // Compute character offsets within this page's text
        int charCount = 0;
        for (int i = 0; i < localWordIdx; i++) {
          charCount += _pageWords[_currentPageIndex][i].length + 1;
        }
        localStart = charCount;
        localEnd =
            charCount + _pageWords[_currentPageIndex][localWordIdx].length;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          // ── Full-screen image area ─────────────────────────
          Expanded(
            flex: 7,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Story image
                  Image.asset(
                    page.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.book.coverColor.withOpacity(0.6),
                            widget.book.coverColor,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.book.coverImage,
                          style: const TextStyle(fontSize: 100),
                        ),
                      ),
                    ),
                  ),
                  // Gradient overlay at bottom so text is readable
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.15),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Speaking indicator pulse
                  if (_isSpeaking && !_isPaused)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _buildSpeakingIndicator(),
                    ),
                ],
              ),
            ),
          ),

          // ── Text panel at bottom ───────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C54) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: widget.book.coverColor.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: _buildPageText(pageText, localStart, localEnd, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildPageText(
      String text, int localStart, int localEnd, bool isDark) {
    final baseColor = isDark ? Colors.white : const Color(0xFF2C3E50);

    if (localStart < 0 || !_isSpeaking) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 17,
          height: 1.7,
          color: baseColor,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
        textAlign: TextAlign.center,
      );
    }

    final safeStart = localStart.clamp(0, text.length);
    final safeEnd = localEnd.clamp(safeStart, text.length);
    final dimColor = baseColor.withOpacity(0.35);

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: [
        if (safeStart > 0)
          TextSpan(
            text: text.substring(0, safeStart),
            style: TextStyle(
                fontSize: 17, height: 1.7, color: dimColor, letterSpacing: 0.2),
          ),
        TextSpan(
          text: text.substring(safeStart, safeEnd),
          style: TextStyle(
            fontSize: 18,
            height: 1.7,
            color: isDark ? Colors.white : widget.book.coverColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
            backgroundColor:
                widget.book.coverColor.withOpacity(isDark ? 0.35 : 0.15),
          ),
        ),
        if (safeEnd < text.length)
          TextSpan(
            text: text.substring(safeEnd),
            style: TextStyle(
                fontSize: 17,
                height: 1.7,
                color: baseColor,
                letterSpacing: 0.2),
          ),
      ]),
    );
  }

  Widget _buildSpeakingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volume_up_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          ...List.generate(
            3,
            (i) => _AnimatedBar(
              delay: Duration(milliseconds: i * 120),
              color: widget.book.coverColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageNavigation(int totalPages, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          _buildNavButton(
            icon: Icons.arrow_back_ios_rounded,
            enabled: _currentPageIndex > 0 && !_isPageTransitioning,
            onTap: () => _animateToPage(_currentPageIndex - 1),
            isDark: isDark,
          ),

          // Page dots
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(totalPages, (i) {
                    final isActive = i == _currentPageIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? widget.book.coverColor
                            : widget.book.coverColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

          // Next button
          _buildNavButton(
            icon: Icons.arrow_forward_ios_rounded,
            enabled:
                _currentPageIndex < totalPages - 1 && !_isPageTransitioning,
            onTap: () => _animateToPage(_currentPageIndex + 1),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: enabled
              ? widget.book.coverColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? widget.book.coverColor
                : widget.book.coverColor.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? widget.book.coverColor
              : widget.book.coverColor.withOpacity(0.3),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // TEXT STORY READER (unchanged behaviour)
  // ════════════════════════════════════════════════════════════
  Widget _buildTextBookContent(bool isDark) {
    return FadeTransition(
      opacity: _contentController,
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildProgressBar(),
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
                    if (widget.book.lottieAnimation != null)
                      SizedBox(
                        height: 150,
                        child: Center(
                          child: Text(widget.book.coverImage,
                              style: const TextStyle(fontSize: 80)),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: widget.book.coverColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(widget.book.coverImage,
                            style: const TextStyle(fontSize: 80)),
                      ),
                    const SizedBox(height: 24),
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

  Widget _buildHighlightedText(bool isDark) {
    if (_currentWordStart < 0 || !_isSpeaking) {
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
      text: TextSpan(children: [
        if (safeStart > 0)
          TextSpan(
            text: story.substring(0, safeStart),
            style: TextStyle(
                fontSize: 18, height: 1.8, color: dimColor, letterSpacing: 0.3),
          ),
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
        if (safeEnd < story.length)
          TextSpan(
            text: story.substring(safeEnd),
            style: TextStyle(
                fontSize: 18,
                height: 1.8,
                color: baseColor,
                letterSpacing: 0.3),
          ),
      ]),
    );
  }

  // ── Book open animation (unchanged) ───────────────────────
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
                            color: Colors.black.withOpacity(0.1), width: 2),
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
                            color: Colors.black.withOpacity(0.1), width: 2),
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

// ── Animated sound-bar widget for speaking indicator ──────────
class _AnimatedBar extends StatefulWidget {
  final Duration delay;
  final Color color;

  const _AnimatedBar({required this.delay, required this.color});

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _anim = Tween<double>(begin: 4, end: 14).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        width: 3,
        height: _anim.value,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
