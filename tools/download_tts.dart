import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:vika/utils/constants.dart';

Future<void> main() async {
  if (Constants.viettelTtsToken.isEmpty) {
    stderr.writeln(
      'Missing VIETTEL_TTS_TOKEN. Run with: dart run -DVIETTEL_TTS_TOKEN=... tools/download_tts.dart',
    );
    exitCode = 64;
    return;
  }

  final phrases = {
    "Sẵn sàng, xuống": "san_sang_xuong.mp3",
    "Xuống": "xuong.mp3",
    "Giữ": "giu.mp3",
    "Lên": "len.mp3",
    "Tốt lắm": "tot_lam.mp3",
    "Tốt lắm, xuống": "tot_lam_xuong.mp3",
    "Sai tư thế, chú ý": "sai_tu_the.mp3",
    "Sai tư thế, chú ý, xuống": "sai_tu_the_xuong.mp3",
    "Đứng thẳng": "dung_thang.mp3",
    // Rep counting (1-15)
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
    // Specific feedback
    "Thấp hơn nữa": "thap_hon_nua.mp3",
    "Ưỡn ngực lên": "uon_nguc_len.mp3",
    "Hoàn thành bài tập": "hoan_thanh_bai_tap.mp3",
    // Numbers 16-30
    "16": "16.mp3",
    "17": "17.mp3",
    "18": "18.mp3",
    "19": "19.mp3",
    "20": "20.mp3",
    "21": "21.mp3",
    "22": "22.mp3",
    "23": "23.mp3",
    "24": "24.mp3",
    "25": "25.mp3",
    "26": "26.mp3",
    "27": "27.mp3",
    "28": "28.mp3",
    "29": "29.mp3",
    "30": "30.mp3",
    // New exercises feedback
    "Nâng hông cao hơn": "nang_hong_cao_hon.mp3",
    "Chỉnh góc gối": "chinh_goc_goi.mp3",
    "Chậm lại": "cham_lai.mp3",
    "Cuộn lên thêm": "cuon_len_them.mp3",
    "Không kéo cổ": "khong_keo_co.mp3",
    "Giữ gối gập": "giu_goi_gap.mp3",
    "Cuộn lên": "cuon_len.mp3",
    "Hạ xuống": "ha_xuong.mp3",
    "Đưa tay cao hơn": "dua_tay_cao_hon.mp3",
    "Mở chân rộng hơn": "mo_chan_rong_hon.mp3",
    "Mở": "mo.mp3",
    "Đóng": "dong.mp3",
    "Xuống thấp hơn": "xuong_thap_hon.mp3",
    "Giữ gót chân": "giu_got_chan.mp3",
    "Đứng lên": "dung_len.mp3",
    "Siết cơ bụng": "siet_co_bung.mp3",
    "Hạ hông xuống": "ha_hong_xuong.mp3",
    "Nghỉ": "nghi.mp3",
    "Đẩy lên": "day_len.mp3",
    "Sẵn sàng, lên": "san_sang_len.mp3",
    "Sẵn sàng": "san_sang.mp3",
    "Sẵn sàng, mở": "san_sang_mo.mp3",
  };

  const String apiUrl = 'https://viettelai.vn/tts/speech_synthesis';

  for (final entry in phrases.entries) {
    final text = entry.key;
    final filename = entry.value;
    final path = 'assets/audio/$filename';

    stdout.writeln('Downloading $text to $path...');
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
          'speed': 1.2,
          'tts_return_option': 3,
          'token': Constants.viettelTtsToken,
          'without_filter': false,
        }),
      );

      if (response.statusCode == 200) {
        final file = File(path);
        await file.writeAsBytes(response.bodyBytes);
        stdout.writeln('Saved $path successfully.');
      } else {
        stderr.writeln(
            'Failed to download $text: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      stderr.writeln('Error downloading $text: $e');
    }
  }
}
