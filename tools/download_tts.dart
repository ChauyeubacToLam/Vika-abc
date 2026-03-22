import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String token = '3e96c274c2f6f3a20677b5464bd49446';

Future<void> main() async {
  final phrases = {
    "Xuống": "xuong.mp3",
    "Giữ": "giu.mp3",
    "Lên": "len.mp3",
    "Tốt lắm": "tot_lam.mp3",
    "Sai tư thế, chú ý": "sai_tu_the.mp3",
    "Đứng thẳng": "dung_thang.mp3",
  };

  const String apiUrl = 'https://viettelai.vn/tts/speech_synthesis';

  for (final entry in phrases.entries) {
    final text = entry.key;
    final filename = entry.value;
    final path = 'assets/audio/$filename';

    print('Downloading $text to $path...');
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'accept': '*/*',
        },
        body: jsonEncode({
          'text': text,
          'voice': 'hn-quynhanh',
          'speed': 1.0,
          'tts_return_option': 3,
          'token': token,
          'without_filter': false,
        }),
      );

      if (response.statusCode == 200) {
        final file = File(path);
        await file.writeAsBytes(response.bodyBytes);
        print('Saved $path successfully.');
      } else {
        print('Failed to download $text: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error downloading $text: $e');
    }
  }
}
