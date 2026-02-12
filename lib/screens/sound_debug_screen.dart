import 'package:flutter/material.dart';
import '../managers/audio_manager.dart';

class SoundDebugScreen extends StatefulWidget {
  const SoundDebugScreen({Key? key}) : super(key: key);

  @override
  State<SoundDebugScreen> createState() => _SoundDebugScreenState();
}

class _SoundDebugScreenState extends State<SoundDebugScreen> {
  final List<String> sounds = [
    'welcome',
    'tap',
    'toggle',
    'page_turn',
    'book_open',
    'book_close',
    'favorite',
  ];

  String _status = 'Ready to test sounds';

  void _testSound(String soundName) async {
    setState(() => _status = 'Playing: $soundName');
    try {
      await AudioManager().playSound(soundName);
      setState(() => _status = 'Played: $soundName ✅');
    } catch (e) {
      setState(() => _status = 'Error: $e ❌');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound Test'),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple.shade50,
            child: Text(
              _status,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sounds.length,
              itemBuilder: (context, index) {
                final sound = sounds[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.music_note, color: Colors.purple),
                    title: Text(
                      sound,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text('assets/sounds/$sound.mp3'),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_filled, size: 40),
                      color: Colors.purple,
                      onPressed: () => _testSound(sound),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () async {
                setState(() => _status = 'Verifying all sounds...');
                await AudioManager().preloadAllSounds();
                setState(() => _status = 'Check debug console for results');
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Verify All Sounds'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
