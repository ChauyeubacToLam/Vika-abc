/// The façade. Thin on purpose — all judgment about *whether* to speak
/// lives in [VoicePolicy]; all sound lives in the [VoiceSink]. This class
/// owns content *resolution* only: picking a variation from a pool with no
/// immediate repeat, and the D8 bias toward the bigger praise line on a
/// high-quality rep.
///
/// Build spec: `docs/reference/voice-coach/implementation-guide.md` §6.
library;

import 'dart:async';
import 'dart:math';

import 'voice_content.dart';
import 'voice_policy.dart';
import 'voice_sink.dart';

class VoiceCoach {
  VoiceCoach({required VoiceSink sink, VoicePolicy? policy, Random? random})
      : _sink = sink,
        _policy = policy ?? VoicePolicy(),
        _rng = random ?? Random();

  final VoiceSink _sink;
  final VoicePolicy _policy;
  final Random _rng;

  /// formScore at/above this counts as a "standout" rep for D8's
  /// praiseBig bias.
  static const double _praiseBigFormScoreThreshold = 0.85;

  /// Chance a standout rep's praise draws from `VoiceLib.praiseBig`
  /// instead of the caller's own pool. Behaviour, not an exact number —
  /// tune on device.
  static const double _praiseBigBias = 0.5;

  /// Last key spoken per resolved-pool identity — how "no immediate
  /// repeat" is enforced without callers ever seeing pool bookkeeping.
  final Map<String, String> _lastPickByPool = {};

  /// True while the sink is playing/queued. Adapters read this to
  /// populate `CueContext.sinkBusy` for perishable cues (phase/hustle).
  bool get isBusy => _sink.isBusy;

  /// The brain decides if/when; if it says yes, resolve *what* to say and
  /// fire-and-forget it to the sink.
  void say(CueType type, VoiceContent content, CueContext ctx) {
    if (!_policy.decide(type, ctx)) return;
    final key = _resolveKey(type, content, ctx);
    if (key == null) return;
    unawaited(_sink.playKey(key));
  }

  Future<void> waitUntilIdle() => _sink.waitUntilIdle();

  void dispose() => _sink.dispose();

  /// Delegates to the policy — call at the start of every set to wipe
  /// hunger and all hard-rule memory (see [VoicePolicy.beginSet]).
  void beginSet() => _policy.beginSet();

  String? _resolveKey(CueType type, VoiceContent content, CueContext ctx) {
    var pool = content.keys;

    // `VoiceContent.key(k)` — if `k` has registered variations, treat it
    // as a pool of those variations instead of a literal, unplayable
    // dispatch key (see `VoiceLib.variations`).
    if (pool.length == 1) {
      final variations = VoiceLib.variations[pool.first];
      if (variations != null && variations.isNotEmpty) {
        pool = variations;
      }
    }

    // D8: on a standout rep, sometimes reach for the bigger praise line
    // instead of whatever pool the caller passed in.
    if (type == CueType.praise &&
        ctx.formScore >= _praiseBigFormScoreThreshold &&
        VoiceLib.praiseBig.isNotEmpty &&
        _rng.nextDouble() < _praiseBigBias) {
      pool = VoiceLib.praiseBig;
    }

    if (pool.isEmpty) return null;
    if (pool.length == 1) return pool.first;

    final poolId = pool.join('|');
    final last = _lastPickByPool[poolId];
    var candidates = pool;
    if (last != null) {
      final withoutLast = pool.where((k) => k != last).toList();
      if (withoutLast.isNotEmpty) candidates = withoutLast;
    }

    final pick = candidates[_rng.nextInt(candidates.length)];
    _lastPickByPool[poolId] = pick;
    return pick;
  }
}
