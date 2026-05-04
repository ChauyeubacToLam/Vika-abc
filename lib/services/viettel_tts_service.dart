import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../utils/constants.dart';

class ViettelTTSService {
  static final ViettelTTSService _instance = ViettelTTSService._internal();
  factory ViettelTTSService() => _instance;
  ViettelTTSService._internal() {
    _configFuture = _configurePlayer();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      debugPrint('[TTS] player state: $state');
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      debugPrint('[TTS] completed');
      _isPlaying = false;
      if (_isClearingQueue) {
        return;
      }
      _processQueue();
    });
  }

  Future<void> _configurePlayer() async {
    try {
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: {AVAudioSessionOptions.defaultToSpeaker},
          ),
        ),
      );
      _isConfigured = true;
    } catch (e) {
      debugPrint('[TTS] configure failed: $e');
    }
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _apiUrl = 'https://viettelai.vn/tts/speech_synthesis';

  // Voice queue for sequential playback (Approach A)
  final List<String> _queue = [];
  bool _isPlaying = false;
  bool _isClearingQueue = false;
  bool _isConfigured = false;
  Future<void>? _configFuture;

  final Map<String, String> _assetMap = {
    "Xuống": "xuong.mp3",
    "Giữ": "giu.mp3",
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
    "Chậm lại": "cham_lai.mp3",
    "tốt": "tot.mp3",
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
    "nhớ xuống thấp hơn": "nho_xuong_thap_hon.mp3",
    "nhớ giữ gót chân": "nho_giu_got_chan.mp3",
    "nhớ chậm lại": "nho_cham_lai.mp3",
    "Nhớ không nâng gót chân": "nho_khong_nang_got_chan.mp3",
    "Đừng nhấc hông lên trước": "dung_nhac_hong_len_truoc.mp3",
    "Giữ gót chân": "giu_got_chan.mp3",
    "Đứng lên": "dung_len.mp3",
    "Siết cơ bụng": "siet_co_bung.mp3",
    "Hạ hông xuống": "ha_hong_xuong.mp3",
    "Nghỉ": "nghi.mp3",
    "Đẩy lên": "day_len.mp3",
    "Sẵn sàng": "san_sang.mp3",
  };

  /// Add text to the voice queue. Plays sequentially.
  Future<void> speak(String text) async {
    _queue.add(text);
    if (!_isPlaying && !_isClearingQueue) {
      _processQueue();
    }
    debugPrint('[TTS] queued: $text');
  }

  /// Clear pending queue and stop current playback.
  /// Call when starting a new rep to prevent stale commands.
  void clearQueue() async {
    _queue.clear();
    if (_isClearingQueue) {
      debugPrint('[TTS] queue clear already in progress');
      return;
    }
    if (!_isPlaying) {
      debugPrint('[TTS] queue cleared (idle)');
      return;
    }

    _isClearingQueue = true;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    _isPlaying = false;
    _isClearingQueue = false;
    debugPrint('[TTS] queue cleared');
    _processQueue();
  }

  /// Drop queued phrases but let the current phrase finish.
  /// Useful when a higher-priority cue should play next without cutting audio mid-word.
  void clearPendingButKeepCurrent() {
    _queue.clear();
    debugPrint('[TTS] pending queue cleared');
  }

  Future<void> _processQueue() async {
    if (_queue.isEmpty || _isPlaying || _isClearingQueue) return;
    _isPlaying = true;

    if (!_isConfigured && _configFuture != null) {
      await _configFuture;
    }

    final text = _queue.removeAt(0);
    try {
      await _playText(text);
    } catch (e) {
      debugPrint('[TTS] process queue exception: $e');
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
          debugPrint('[TTS] asset played: $assetPath');
          return;
        } catch (e) {
          debugPrint('[TTS] asset fallback for "$text": $e');
          // Fall back to API if not cached locally
        }
      }

      // 2. Fall back to Viettel API
      if (Constants.viettelTtsToken.isEmpty) {
        debugPrint(
          '[TTS] missing VIETTEL_TTS_TOKEN. Provide it with --dart-define.',
        );
        _isPlaying = false;
        _processQueue();
        return;
      }

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
        debugPrint('[TTS] API bytes played for: $text');
      } else {
        debugPrint(
            '[TTS] API error: ${response.statusCode} - ${response.body}');
        _isPlaying = false;
        _processQueue();
      }
    } catch (e) {
      debugPrint('[TTS] play exception: $e');
      _isPlaying = false;
      _processQueue();
    }
  }
}
