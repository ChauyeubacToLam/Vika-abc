/// Audio + the voice-set seam.
///
/// Build spec: `docs/reference/voice-coach/implementation-guide.md` §5.
///
/// The guide's illustrative sketch types `VoiceSet.resolve` as
/// `String Function(String)` (non-nullable), but the very same section's
/// prose requires: "if a logical key has no asset yet, playKey no-ops
/// safely ... and records the key — never throw." A resolver that always
/// returns a String can't signal "unmapped," so this file follows the real
/// requirement (matching `QueuedAssetVoicePlayer`'s own
/// `String? Function(String text)? assetResolver` shape) and makes
/// `resolve` nullable instead. Noted here since it's a deviation from the
/// guide's literal code sketch, not just its prose.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../services/generic_exercise_voice_assets.dart';
import '../services/queued_asset_voice_player.dart';

/// What every voice coach speaks through. Thin on purpose — all judgment
/// about *whether* to speak lives in `VoicePolicy`; this only plays a
/// resolved logical key.
abstract class VoiceSink {
  /// True while audio is currently playing or queued. Perishable cues
  /// (phase/hustle) consult this via `CueContext.sinkBusy` before deciding
  /// whether to speak at all.
  bool get isBusy;

  /// Resolves [logicalKey] via the active [VoiceSet], then plays the
  /// asset. Fire-and-forget from the caller's perspective — never throws,
  /// even for an unmapped key (see [VoiceSet]).
  Future<void> playKey(String logicalKey);

  /// Resolves once the sink drains. The [timeout] is plumbed through to the
  /// underlying player so callers that must observe a genuine audio-end (the
  /// setup-intro grace re-anchor) can pass a window generous enough that the
  /// player's own default 4s cap can't fire mid-line and masquerade as idle.
  Future<void> waitUntilIdle({Duration timeout = const Duration(seconds: 4)});

  /// Drops queued lines but lets the currently-playing one finish — the
  /// perishable-drop seam (e.g. stale activation counts after a broken hold).
  /// A thin passthrough to the player's existing FIFO trim; the player stays
  /// a dumb FIFO.
  void clearPending();

  Future<void> stop();

  void dispose();
}

/// The naming seam: logical keys (`'common.good_1'`) → real asset paths.
/// Swapping voices later is meant to be a different [VoiceSet] value —
/// callers never see the indirection. Exactly one voice set exists today:
/// [vika_v1].
class VoiceSet {
  const VoiceSet({required this.name, required this.resolve});

  final String name;

  /// Returns null when this voice set has no asset for [logicalKey] yet —
  /// the caller (`AssetVoiceSink`) treats that as a safe no-op, not an
  /// error.
  final String? Function(String logicalKey) resolve;

  /// The one voice set that exists today. Reuses the real, already-shipped
  /// asset map (`GenericExerciseVoiceAssets`) rather than duplicating it —
  /// every key that already has a recorded line keeps working unchanged.
  static const VoiceSet vika_v1 = VoiceSet(
    name: 'vika_v1',
    resolve: _resolveVikaV1,
  );

  static String? _resolveVikaV1(String logicalKey) {
    final key = logicalKey.trim();
    if (key.isEmpty) return null;
    return GenericExerciseVoiceAssets.commonFiles[key] ??
        GenericExerciseVoiceAssets.resolveAsset(key);
  }
}

/// Wraps the single [QueuedAssetVoicePlayer] — the one playback engine we
/// keep (Viettel TTS is gone; see design decision "TTS" in the guide's §0).
class AssetVoiceSink implements VoiceSink {
  AssetVoiceSink({
    QueuedAssetVoicePlayer? player,
    this.voiceSet = VoiceSet.vika_v1,
  }) : _player = player ??
            QueuedAssetVoicePlayer(
              assetMap: GenericExerciseVoiceAssets.commonFiles,
              assetSourcePrefix: GenericExerciseVoiceAssets.assetSourcePrefix,
              assetBundlePrefix: GenericExerciseVoiceAssets.assetBundlePrefix,
              assetResolver: GenericExerciseVoiceAssets.resolveAsset,
              logTag: 'VoiceCoach',
            );

  final QueuedAssetVoicePlayer _player;
  final VoiceSet voiceSet;

  bool _busy = false;

  /// Logical keys requested with no known asset mapping, seen so far this
  /// run. Not the hand-maintained `missing-audio.md` checklist from §8 of
  /// the guide, but the live, always-current version of the same signal —
  /// useful for spot-checking during development.
  final Set<String> _missingKeys = <String>{};
  Set<String> get missingKeysSeen => Set.unmodifiable(_missingKeys);

  @override
  bool get isBusy => _busy;

  @override
  Future<void> playKey(String logicalKey) async {
    final resolved = voiceSet.resolve(logicalKey);
    if (resolved == null) {
      // Safe no-op (§5): never throw, just log + record for the
      // missing-audio checklist.
      debugPrint(
        '[VoiceSink:${voiceSet.name}] no asset mapped for "$logicalKey" — '
        'skipping',
      );
      _missingKeys.add(logicalKey);
      return;
    }

    _busy = true;
    // The player does its own key -> filename resolution (assetMap /
    // assetResolver) and its own safe no-op if the asset file itself is
    // missing from the bundle — this call is intentionally on the
    // original logical key, not a translated path.
    await _player.speak(logicalKey);
    // QueuedAssetVoicePlayer doesn't expose a public isBusy/isPlaying
    // getter (only speak/waitUntilIdle/clearQueue/dispose — see
    // `queued_asset_voice_player.dart`), so `isBusy` is tracked here
    // instead of inside the wrapped player: flip true immediately, and
    // flip back false once the player reports it's genuinely idle again
    // (queue empty and nothing playing). Multiple overlapping calls are
    // harmless — every waiter resolves together once the player goes idle.
    // The waiter MUST register after speak() has enqueued the line: from an
    // idle player waitUntilIdle returns an already-completed future, so a
    // waiter registered pre-enqueue resolved instantly and left isBusy
    // false for the whole first utterance (perishables didn't drop, the
    // safety pump dispatched over playing audio).
    unawaited(
      _player.waitUntilIdle(timeout: const Duration(seconds: 30)).then((_) {
        _busy = false;
      }),
    );
  }

  @override
  Future<void> waitUntilIdle({Duration timeout = const Duration(seconds: 4)}) =>
      _player.waitUntilIdle(timeout: timeout);

  @override
  void clearPending() => _player.clearPendingButKeepCurrent();

  @override
  Future<void> stop() async {
    _player.clearQueue();
  }

  @override
  void dispose() => _player.dispose();
}
