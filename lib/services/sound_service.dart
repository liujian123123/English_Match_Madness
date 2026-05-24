import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _successPlayer = AudioPlayer();
  final AudioPlayer _failurePlayer = AudioPlayer();
  bool _initialized = false;

  /// 中断当前所有音频播放
  Future<void> stopAll() async {
    try {
      await _tts.stop();
      await _successPlayer.stop();
      await _failurePlayer.stop();
    } catch (_) {}
  }

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);

    // Preload WAV data
    await _successPlayer.setSource(BytesSource(_generateSuccessWav()));
    await _failurePlayer.setSource(BytesSource(_generateFailureWav()));
    _initialized = true;
  }

  Future<void> speakEnglish(String word) async {
    if (!_initialized) await init();
    try {
      await _tts.speak(word);
    } catch (_) {}
  }

  Future<void> playSuccess() async {
    if (!_initialized) await init();
    try {
      await _successPlayer.stop();
      await _successPlayer.setSource(BytesSource(_generateSuccessWav()));
      await _successPlayer.resume();
    } catch (_) {}
  }

  Future<void> playFailure() async {
    if (!_initialized) await init();
    try {
      await _failurePlayer.stop();
      await _failurePlayer.setSource(BytesSource(_generateFailureWav()));
      await _failurePlayer.resume();
    } catch (_) {}
  }

  void dispose() {
    _successPlayer.dispose();
    _failurePlayer.dispose();
    _tts.stop();
  }

  /// Generate a pleasant ascending tone (C5→E5→G5 arpeggio) for success sound
  static Uint8List _generateSuccessWav() {
    const sampleRate = 22050;
    final bytes = <int>[];

    // C5 (523Hz) for 100ms
    bytes.addAll(_sineSamples(sampleRate, 523.25, 100, 0.6));
    // E5 (659Hz) for 100ms
    bytes.addAll(_sineSamples(sampleRate, 659.25, 100, 0.6));
    // G5 (784Hz) for 150ms
    bytes.addAll(_sineSamples(sampleRate, 783.99, 150, 0.5));

    return _buildWav(bytes, sampleRate);
  }

  /// Generate a sad descending tone (E4→C4) for failure sound
  static Uint8List _generateFailureWav() {
    const sampleRate = 22050;
    final bytes = <int>[];

    // E4 (330Hz) for 200ms sliding to C4 (262Hz) for 200ms
    const numSamples = sampleRate * 400 ~/ 1000;
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final progress = i / numSamples;
      final freq = 330 + (262 - 330) * progress;
      final value = sin(2 * pi * freq * t);
      double envelope = 1.0;
      if (i < 200) envelope = i / 200.0;
      if (i > numSamples - 300) envelope = (numSamples - i) / 300.0;
      final sample = ((value * 0.5 * 0.5 + 0.5) * 255).round().clamp(0, 255);
      bytes.add((sample * envelope).round().clamp(0, 255));
    }

    return _buildWav(bytes, sampleRate);
  }

  static List<int> _sineSamples(int sampleRate, double freq, int durationMs, double volume) {
    final numSamples = sampleRate * durationMs ~/ 1000;
    final samples = <int>[];
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final value = sin(2 * pi * freq * t);
      // Apply envelope (fade in/out) to avoid clicks
      double envelope = 1.0;
      if (i < 200) envelope = i / 200.0; // fade in
      if (i > numSamples - 200) envelope = (numSamples - i) / 200.0; // fade out
      // 8-bit unsigned PCM
      final sample = ((value * volume * 0.5 + 0.5) * 255).round().clamp(0, 255);
      samples.add((sample * envelope).round().clamp(0, 255));
    }
    return samples;
  }

  static Uint8List _buildWav(List<int> samples, int sampleRate) {
    final dataSize = samples.length;
    final fileSize = 44 + dataSize;
    final bytes = ByteData(fileSize);

    // RIFF header
    bytes.setUint8(0, 0x52); // R
    bytes.setUint8(1, 0x49); // I
    bytes.setUint8(2, 0x46); // F
    bytes.setUint8(3, 0x46); // F
    bytes.setUint32(4, fileSize - 8, Endian.little);
    bytes.setUint8(8, 0x57); // W
    bytes.setUint8(9, 0x41); // A
    bytes.setUint8(10, 0x56); // V
    bytes.setUint8(11, 0x45); // E

    // fmt chunk
    bytes.setUint8(12, 0x66); // f
    bytes.setUint8(13, 0x6D); // m
    bytes.setUint8(14, 0x74); // t
    bytes.setUint8(15, 0x20); // space
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate, Endian.little); // byte rate
    bytes.setUint16(32, 1, Endian.little); // block align
    bytes.setUint16(34, 8, Endian.little); // bits per sample

    // data chunk
    bytes.setUint8(36, 0x64); // d
    bytes.setUint8(37, 0x61); // a
    bytes.setUint8(38, 0x74); // t
    bytes.setUint8(39, 0x61); // a
    bytes.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      bytes.setUint8(44 + i, samples[i]);
    }

    return bytes.buffer.asUint8List();
  }
}