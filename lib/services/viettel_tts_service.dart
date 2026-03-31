import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../utils/constants.dart';

class ViettelTTSService {
  static final ViettelTTSService _instance = ViettelTTSService._internal();
  factory ViettelTTSService() => _instance;
  ViettelTTSService._internal() {
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _processQueue();
    });
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _apiUrl = 'https://viettelai.vn/tts/speech_synthesis';

  // Voice queue for sequential playback (Approach A)
  final List<String> _queue = [];
  bool _isPlaying = false;

  final Map<String, String> _assetMap = {
    "Sẵn sàng, xuống": "san_sang_xuong.mp3",
    "Xuống": "xuong.mp3",
    "Giữ": "giu.mp3",
    "Lên": "len.mp3",
    "Tốt lắm": "tot_lam.mp3",
    "Tốt lắm, xuống": "tot_lam_xuong.mp3",
    "Sai tư thế, chú ý": "sai_tu_the.mp3",
    "Sai tư thế, chú ý, xuống": "sai_tu_the_xuong.mp3",
    // New: rep counting (1-15)
    "1": "1.mp3",
    "2": "2.mp3",
    "3": "3.mp3",
    "4": "4.mp3",
    "5": "5.mp3",
    "6": "6.mp3",
    "7": "7.mp3",
    "8": "8.mp3",
    "9": "9.mp3",
    "10": "10.mp3",
    "11": "11.mp3",
    "12": "12.mp3",
    "13": "13.mp3",
    "14": "14.mp3",
    "15": "15.mp3",
    // New: specific feedback
    "Thấp hơn nữa": "thap_hon_nua.mp3",
    "Ưỡn ngực lên": "uon_nguc_len.mp3",
    "Hoàn thành bài tập": "hoan_thanh_bai_tap.mp3",
  };

  /// Add text to the voice queue. Plays sequentially.
  Future<void> speak(String text) async {
    _queue.add(text);
    if (!_isPlaying) {
      _processQueue();
    }
  }

  /// Clear pending queue and stop current playback.
  /// Call when starting a new rep to prevent stale commands.
  void clearQueue() {
    _queue.clear();
    _audioPlayer.stop();
    _isPlaying = false;
  }

  Future<void> _processQueue() async {
    if (_queue.isEmpty || _isPlaying) return;
    _isPlaying = true;
    final text = _queue.removeAt(0);
    try {
      await _playText(text);
    } catch (e) {
      print('TTS Exception: $e');
      _isPlaying = false;
      _processQueue(); // Try next in queue
    }
  }

  Future<void> _playText(String text) async {
    try {
      // 1. Check local assets to reduce lag
      if (_assetMap.containsKey(text)) {
        final filename = _assetMap[text]!;
        final assetPath = 'assets/audio/$filename';
        try {
          await rootBundle.load(assetPath);
          await _audioPlayer.play(AssetSource('audio/$filename'));
          return;
        } catch (_) {
          // Fall back to API if not cached locally
        }
      }

      // 2. Fall back to Viettel API
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'accept': '*/*',
        },
        body: jsonEncode({
          'text': text,
          'voice': 'hn-quynhanh',
          'speed': 1.2,
          'tts_return_option': 3,
          'token': Constants.viettelTtsToken,
          'without_filter': false,
        }),
      );

      if (response.statusCode == 200) {
        await _audioPlayer.play(BytesSource(response.bodyBytes));
      } else {
        print('TTS Error: ${response.statusCode} - ${response.body}');
        _isPlaying = false;
        _processQueue();
      }
    } catch (e) {
      print('TTS Exception: $e');
      _isPlaying = false;
      _processQueue();
    }
  }
}
