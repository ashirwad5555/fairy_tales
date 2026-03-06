import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _soundEnabled = true;
  bool _isInitialized = false;

  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // Set audio context for mobile
      await _player.setAudioContext(
        const AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: [
              AVAudioSessionOptions.mixWithOthers,
            ],
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );

      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);

      _isInitialized = true;
      debugPrint('✅ AudioManager initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing AudioManager: $e');
    }
  }

  Future<void> playSound(String soundName) async {
    if (!_soundEnabled) {
      debugPrint('🔇 Sound is disabled');
      return;
    }

    try {
      await _initialize();

      // Get current state
      final state = _player.state;

      // Stop current sound if playing
      if (state == PlayerState.playing) {
        await _player.stop();
      }

      // Small delay to ensure previous sound stopped
      await Future.delayed(const Duration(milliseconds: 50));

      // Play the sound
      final source = AssetSource('sounds/$soundName.mp3');
      await _player.play(source, volume: 1.0);

      debugPrint('🔊 Playing: $soundName.mp3');
    } catch (e) {
      debugPrint('❌ Error playing sound "$soundName": $e');
      debugPrint('📁 Checking: assets/sounds/$soundName.mp3');

      // Try to verify file exists
      try {
        await rootBundle.load('assets/sounds/$soundName.mp3');
        debugPrint('✅ File exists but failed to play');
      } catch (fileError) {
        debugPrint('❌ File not found: $fileError');
      }
    }
  }

  Future<void> preloadSound(String soundName) async {
    try {
      await _initialize();
      final source = AssetSource('sounds/$soundName.mp3');
      await _player.setSource(source);
      debugPrint('✅ Preloaded: $soundName');
    } catch (e) {
      debugPrint('❌ Error preloading $soundName: $e');
    }
  }

  Future<void> preloadAllSounds() async {
    final sounds = [
      'welcome',
      'tap',
      'toggle',
      'page_turn',
      'book_open',
      'book_close',
      'favorite',
    ];

    for (final sound in sounds) {
      try {
        await rootBundle.load('assets/sounds/$sound.mp3');
        debugPrint('✅ Verified: $sound.mp3');
      } catch (e) {
        debugPrint('❌ Missing: $sound.mp3');
      }
    }
  }

  void toggleSound(bool enabled) {
    _soundEnabled = enabled;
    debugPrint('🔊 Sound ${enabled ? "enabled" : "disabled"}');
  }

  bool get isSoundEnabled => _soundEnabled;

  Future<void> dispose() async {
    try {
      await _player.stop();
      await _player.dispose();
      _isInitialized = false;
      debugPrint('✅ AudioManager disposed');
    } catch (e) {
      debugPrint('❌ Error disposing AudioManager: $e');
    }
  }
}
