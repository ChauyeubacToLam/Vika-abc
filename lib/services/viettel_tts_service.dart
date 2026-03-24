import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../utils/constants.dart';

class ViettelTTSService {
  static final ViettelTTSService _instance = ViettelTTSService._internal();
  factory ViettelTTSService() => _instance;
  ViettelTTSService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _apiUrl = 'https://viettelai.vn/tts/speech_synthesis';

  final Map<String, String> _assetMap = {
    "Sẵn sàng, xuống": "san_sang_xuong.mp3",
    "Xuống": "xuong.mp3",
    "Giữ": "giu.mp3",
    "Lên": "len.mp3",
    "Tốt lắm": "tot_lam.mp3",
    "Tốt lắm, xuống": "tot_lam_xuong.mp3",
    "Sai tư thế, chú ý": "sai_tu_the.mp3",
    "Sai tư thế, chú ý, xuống": "sai_tu_the_xuong.mp3",
  };

  Future<void> speak(String text) async {
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
          'speed': 1.0,
          'tts_return_option': 3,
          'token': Constants.viettelTtsToken,
          'without_filter': false,
        }),
      );

      if (response.statusCode == 200) {
        await _audioPlayer.play(BytesSource(response.bodyBytes));
      } else {
        print('TTS Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('TTS Exception: $e');
    }
  }
}
