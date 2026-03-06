import 'package:flutter/material.dart';

class SoundDebugScreen extends StatelessWidget {
  const SoundDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound Debug'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isLandscape ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sound test buttons in grid for landscape
                if (isLandscape)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: _buildSoundButtons(isLandscape, screenHeight),
                  )
                else
                  Column(
                    children: _buildSoundButtons(isLandscape, screenHeight),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSoundButtons(bool isLandscape, double screenHeight) {
    final buttonHeight = isLandscape ? null : 60.0;

    return [
      _buildSoundButton(
        label: 'Play Background Music',
        icon: Icons.music_note,
        color: Colors.blue,
        onPressed: () {/* Play background */},
        height: buttonHeight,
        isLandscape: isLandscape,
      ),
      if (!isLandscape) const SizedBox(height: 16),
      _buildSoundButton(
        label: 'Play Effect Sound',
        icon: Icons.volume_up,
        color: Colors.green,
        onPressed: () {/* Play effect */},
        height: buttonHeight,
        isLandscape: isLandscape,
      ),
      if (!isLandscape) const SizedBox(height: 16),
      _buildSoundButton(
        label: 'Play Narration',
        icon: Icons.record_voice_over,
        color: Colors.orange,
        onPressed: () {/* Play narration */},
        height: buttonHeight,
        isLandscape: isLandscape,
      ),
      if (!isLandscape) const SizedBox(height: 16),
      _buildSoundButton(
        label: 'Stop All Sounds',
        icon: Icons.stop,
        color: Colors.red,
        onPressed: () {/* Stop all */},
        height: buttonHeight,
        isLandscape: isLandscape,
      ),
    ];
  }

  Widget _buildSoundButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double? height,
    required bool isLandscape,
  }) {
    return SizedBox(
      height: height,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: isLandscape ? 20 : 24),
        label: Text(
          label,
          style: TextStyle(
            fontSize: isLandscape ? 12 : 16,
          ),
          textAlign: TextAlign.center,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 8 : 16,
            vertical: isLandscape ? 8 : 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
