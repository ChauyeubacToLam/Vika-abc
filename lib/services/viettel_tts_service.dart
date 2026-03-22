import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import '../utils/constants.dart';

class ViettelTTSService {
  static final ViettelTTSService _instance = ViettelTTSService._internal();
  factory ViettelTTSService() => _instance;
  ViettelTTSService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _apiUrl = 'https://viettelai.vn/tts/speech_synthesis';

  Future<void> speak(String text) async {
    try {
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
