import 'package:flutter/material.dart';
import '../data/story_data.dart';
import '../managers/audio_manager.dart';
import '../managers/haptic_helper.dart';
import '../widgets/floating_star.dart';
import '../widgets/category_card.dart';
import 'sound_debug_screen.dart'; // Add this import

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeToggle;

  const HomeScreen({
    Key? key,
    required this.isDarkMode,
    required this.onThemeToggle,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    AudioManager().playSound('welcome');
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
        ? [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
            const Color(0xFF0F3460),
          ]
        : [
            const Color(0xFFFFF8E7),
            const Color(0xFFFFE5E5),
            const Color(0xFFE5F3FF),
          ];

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
          child: Column(
            children: [
              // Header with controls
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            _soundEnabled ? Icons.volume_up : Icons.volume_off,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF9B59B6),
                          ),
                          onPressed: () async {
                            await HapticHelper.lightImpact();
                            setState(() => _soundEnabled = !_soundEnabled);
                            AudioManager().toggleSound(_soundEnabled);
                          },
                        ),
                        // Add debug button (remove in production)
                        IconButton(
                          icon: Icon(
                            Icons.bug_report,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF9B59B6),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SoundDebugScreen(),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            widget.isDarkMode
                                ? Icons.light_mode
                                : Icons.dark_mode,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF9B59B6),
                          ),
                          onPressed: () async {
                            await HapticHelper.lightImpact();
                            AudioManager().playSound('toggle');
                            widget.onThemeToggle(!widget.isDarkMode);
                          },
                        ),
                      ],
                    ),
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _controller,
                          curve: Curves.elasticOut,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_stories,
                            color:
                                isDark ? Colors.white : const Color(0xFFFF6B9D),
                            size: 40,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Bedtime Stories',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFFFF6B9D),
                              shadows: [
                                Shadow(
                                  color: Colors.purple.withOpacity(0.3),
                                  offset: const Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _controller,
                      child: Text(
                        '✨ Choose your adventure! ✨',
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              isDark ? Colors.white70 : const Color(0xFF9B59B6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Floating stars decoration
              SizedBox(
                height: 60,
                child: Stack(
                  children: [
                    const Positioned(
                      left: 30,
                      top: 10,
                      child: FloatingStar(
                        size: 24,
                        duration: Duration(seconds: 2),
                      ),
                    ),
                    const Positioned(
                      right: 50,
                      top: 20,
                      child: FloatingStar(
                        size: 18,
                        duration: Duration(seconds: 3),
                      ),
                    ),
                    Positioned(
                      left: MediaQuery.of(context).size.width / 2 - 10,
                      top: 5,
                      child: const FloatingStar(
                        size: 16,
                        duration: Duration(seconds: 4),
                      ),
                    ),
                  ],
                ),
              ),
              // Categories Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    return CategoryCard(
                      category: categories[index],
                      delay: index * 150,
                      animation: _controller,
                      isDarkMode: widget.isDarkMode,
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
