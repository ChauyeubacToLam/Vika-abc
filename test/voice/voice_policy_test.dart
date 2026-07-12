// Unit tests for VoicePolicy — the pure brain of the voice-coach refactor.
//
// Build spec: docs/reference/voice-coach/implementation-guide.md §10.
// "Assert the behaviour, not the numbers" — these tests check invariants
// (never-twice-in-a-row, one-outcome-per-rep, escalation direction, relief
// valves, per-fault independence, personality bounds, reproducibility),
// not the exact tuned probabilities (those are expected to move on device).

import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/voice/voice_coach.dart';
import 'package:vika/voice/voice_content.dart';
import 'package:vika/voice/voice_policy.dart';
import 'package:vika/voice/voice_sink.dart';

/// A [Random] that plays back a fixed script of `nextDouble()` results
/// instead of actually being random — this is what makes probability
/// thresholds in [VoicePolicy] deterministically testable. Once the script
/// is exhausted, it keeps repeating the last value (so a test can under-
/// specify trailing "don't care" rolls without an index-out-of-range).
class _ScriptedRandom implements Random {
  _ScriptedRandom(this._doubles);

  final List<double> _doubles;
  int _i = 0;

  @override
  double nextDouble() {
    if (_doubles.isEmpty) return 0.0;
    final v = _i < _doubles.length ? _doubles[_i] : _doubles.last;
    if (_i < _doubles.length) _i++;
    return v;
  }

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

class _GateableVoiceSink implements VoiceSink {
  final List<String> keys = [];
  Completer<void>? _idleCompleter;
  bool _busy = false;

  @override
  bool get isBusy => _busy;

  @override
  Future<void> playKey(String logicalKey) async {
    keys.add(logicalKey);
    _busy = true;
    _idleCompleter ??= Completer<void>();
  }

  void finishCurrentLine() {
    _busy = false;
    final completer = _idleCompleter;
    _idleCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return _idleCompleter?.future ?? Future<void>.value();
  }

  @override
  void clearPending() {}

  @override
  Future<void> stop() async {
    finishCurrentLine();
  }

  @override
  void dispose() {
    finishCurrentLine();
  }
}

Map<CueType, CueTuning> _gluteBridgePilotTuning() => {
      ...kDefaultTuning,
      // count: no override — mirrors the real pilot map, which inherits the
      // fleet default (base 1.0, every rep counted; registration ruling 07-11).
      CueType.praise: const CueTuning(
        CueMode.variableRatio,
        base: 0.50,
        step: 0.10,
        cap: 0.85,
        scalePraiseByFormScore: false,
      ),
      CueType.criticalFault: const CueTuning(
        CueMode.correction,
        base: 0.25,
        step: 0.30,
        cap: 0.85,
        firstOccurrenceCertain: true,
      ),
      CueType.softFault: const CueTuning(
        CueMode.variableRatio,
        base: 0.20,
        step: 0.08,
        cap: 0.55,
      ),
      CueType.reminder: const CueTuning(
        CueMode.correction,
        base: 0.30,
        step: 0.15,
        cap: 0.65,
        firstOccurrenceCertain: true,
      ),
      CueType.hustle: const CueTuning(
        CueMode.perishable,
        base: 0.50,
        step: 0.20,
        cap: 0.90,
        postFireIdlePenalty: 2,
      ),
    };

VoicePolicy _gluteBridgePilotPolicy({
  Random? random,
  int Function()? clockMs,
}) {
  return VoicePolicy(
    random: random,
    clockMs: clockMs,
    tuning: _gluteBridgePilotTuning(),
    outcomeCollisionGapMs: 500,
    maxOutcomeCuesPerRep: 2,
  );
}

void main() {
  group('praise', () {
    test('never fires twice in a row, even with a favourable roll', () {
      // 0.0 is below every positive probability this policy will ever
      // compute, i.e. "always take it if the hard rules allow it".
      // gap 0 isolates the never-twice hard rule from the (now-default)
      // collision gap, which has its own coverage in the per-moment group.
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.0]),
        outcomeCollisionGapMs: 0,
      );

      expect(
        policy.decide(CueType.praise, const CueContext(repNumber: 5)),
        isTrue,
      );
      policy.markOutcomeAudioEnded();
      expect(
        policy.decide(CueType.praise, const CueContext(repNumber: 6)),
        isFalse,
        reason: 'back-to-back praise must be refused regardless of the roll',
      );
      expect(
        policy.decide(CueType.praise, const CueContext(repNumber: 7)),
        isTrue,
        reason: 'once a rep has passed without praising, it may fire again',
      );
    });

    test('D8: a higher formScore raises the praise chance', () {
      // base 0.35 * (0.6 + 0.4*formScore): formScore 0 -> 0.21, formScore
      // 1 -> 0.35. A roll of 0.30 sits between the two. D8 formScore scaling
      // left the calibrated default (07-12, scalePraiseByFormScore now false),
      // so test the mechanism via an explicit tuning that enables it.
      final d8Tuning = {
        ...kDefaultTuning,
        CueType.praise: const CueTuning(
          CueMode.variableRatio,
          base: 0.35,
          step: 0.10,
          cap: 0.85,
        ),
      };
      final lowQuality =
          VoicePolicy(random: _ScriptedRandom([0.30]), tuning: d8Tuning);
      expect(
        lowQuality.decide(
          CueType.praise,
          const CueContext(repNumber: 1, formScore: 0.0),
        ),
        isFalse,
      );

      final highQuality =
          VoicePolicy(random: _ScriptedRandom([0.30]), tuning: d8Tuning);
      expect(
        highQuality.decide(
          CueType.praise,
          const CueContext(repNumber: 1, formScore: 1.0),
        ),
        isTrue,
      );
    });

    test('can opt out of the D8 formScore probability multiplier', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.30]),
        tuning: {
          ...kDefaultTuning,
          CueType.praise: const CueTuning(
            CueMode.variableRatio,
            base: 0.35,
            step: 0.10,
            cap: 0.85,
            scalePraiseByFormScore: false,
          ),
        },
      );

      expect(
        policy.decide(
          CueType.praise,
          const CueContext(repNumber: 1, formScore: 0.0),
        ),
        isTrue,
        reason: 'without the D8 multiplier, a 0.30 roll hits the flat 0.35 '
            'base chance even when formScore is low',
      );
    });

    test('glute bridge pilot still never praises twice in a row', () {
      // gap 0 isolates the never-twice hard rule from the collision gap
      // (the gap has its own coverage in the per-moment group below).
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.0]),
        tuning: _gluteBridgePilotTuning(),
        outcomeCollisionGapMs: 0,
      );

      expect(
        policy.decide(CueType.praise, const CueContext(repNumber: 1)),
        isTrue,
      );
      policy.markOutcomeAudioEnded();
      expect(
        policy.decide(CueType.praise, const CueContext(repNumber: 2)),
        isFalse,
      );
      expect(
        policy.decide(CueType.praise, const CueContext(repNumber: 3)),
        isTrue,
      );
    });
  });

  group('per-moment outcome exclusivity', () {
    test('praise firing blocks correct and hustle on the same rep', () {
      final policy = VoicePolicy(random: _ScriptedRandom([0.0]));

      expect(
        policy.decide(
          CueType.praise,
          const CueContext(repNumber: 3, isFinalReps: true),
        ),
        isTrue,
      );
      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 3, contentKey: 'heel'),
        ),
        isFalse,
        reason: 'a rep already has its outcome cue (praise)',
      );
      expect(
        policy.decide(
          CueType.hustle,
          const CueContext(repNumber: 3, isFinalReps: true),
        ),
        isFalse,
        reason: 'a rep already has its outcome cue (praise)',
      );
    });

    test('count is not an outcome cue — it may co-occur with praise', () {
      final policy = VoicePolicy(random: _ScriptedRandom([0.0]));
      const ctx = CueContext(repNumber: 1);

      expect(policy.decide(CueType.count, ctx), isTrue); // rep-1 anchor
      expect(
        policy.decide(CueType.praise, ctx),
        isTrue,
        reason: 'count claiming the rep must not block praise on it',
      );
    });

    test('second different critical can speak after the collision gap', () {
      var now = 0;
      final policy = _gluteBridgePilotPolicy(
        random: _ScriptedRandom([0.99]),
        clockMs: () => now,
      );

      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 1, contentKey: 'hyperextension'),
        ),
        isTrue,
      );
      policy.markOutcomeAudioEnded(1000);

      now = 1499;
      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 1, contentKey: 'neck_head'),
        ),
        isFalse,
        reason: 'gap is measured from the previous outcome audio end',
      );

      now = 1500;
      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 1, contentKey: 'neck_head'),
        ),
        isTrue,
      );
    });

    test('soft fault never takes the second slot', () {
      var now = 0;
      final policy = _gluteBridgePilotPolicy(
        random: _ScriptedRandom([0.0]),
        clockMs: () => now,
      );

      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 1, contentKey: 'hyperextension'),
        ),
        isTrue,
      );
      policy.markOutcomeAudioEnded(0);
      now = 500;

      expect(
        policy.decide(
          CueType.softFault,
          const CueContext(repNumber: 1, contentKey: 'hip_extension'),
        ),
        isFalse,
      );
    });

    test('same fault never revoices inside one rep', () {
      var now = 0;
      final policy = _gluteBridgePilotPolicy(
        random: _ScriptedRandom([0.0]),
        clockMs: () => now,
      );

      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 1, contentKey: 'hyperextension'),
        ),
        isTrue,
      );
      policy.markOutcomeAudioEnded(0);
      now = 500;

      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 1, contentKey: 'hyperextension'),
        ),
        isFalse,
      );
    });

    test('cap 2 binds a third would-be critical in one rep', () {
      var now = 0;
      final policy = _gluteBridgePilotPolicy(
        random: _ScriptedRandom([0.99]),
        clockMs: () => now,
      );

      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 1, contentKey: 'hyperextension'),
        ),
        isTrue,
      );
      policy.markOutcomeAudioEnded(0);
      now = 500;
      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 1, contentKey: 'neck_head'),
        ),
        isTrue,
      );
      policy.markOutcomeAudioEnded(500);
      now = 1000;

      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 1, contentKey: 'knee_angle'),
        ),
        isFalse,
      );
    });

    test('blocked critical keeps first-occurrence certainty', () {
      var now = 0;
      final policy = _gluteBridgePilotPolicy(
        random: _ScriptedRandom([0.99]),
        clockMs: () => now,
      );

      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 1, contentKey: 'hyperextension'),
        ),
        isTrue,
      );
      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 1, contentKey: 'neck_head'),
        ),
        isFalse,
        reason: 'audio is still pending, so this is blocked, not spent',
      );
      policy.markOutcomeAudioEnded(0);
      now = 500;

      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 1, contentKey: 'neck_head'),
        ),
        isTrue,
        reason: 'ctx still says persistence 0, so firstOccurrenceCertain wins',
      );
    });

    test('coach stamps the gap from audio end, not trigger time', () async {
      var now = 0;
      final sink = _GateableVoiceSink();
      final policy = _gluteBridgePilotPolicy(
        random: _ScriptedRandom([0.99]),
        clockMs: () => now,
      );
      final coach = VoiceCoach(
        sink: sink,
        policy: policy,
        random: _ScriptedRandom([0.0]),
      );
      addTearDown(coach.dispose);

      expect(
        coach.say(
          CueType.criticalFault,
          VoiceContent.key('glute_bridge.hyperextension'),
          const CueContext(repNumber: 1, contentKey: 'hyperextension'),
        ),
        isTrue,
      );

      now = 10000;
      expect(
        coach.say(
          CueType.criticalFault,
          VoiceContent.key('glute_bridge.neck_head'),
          const CueContext(repNumber: 1, contentKey: 'neck_head'),
        ),
        isFalse,
        reason: 'the first line has not ended, even though trigger time is old',
      );

      sink.finishCurrentLine();
      await Future<void>.delayed(Duration.zero);

      now = 10499;
      expect(
        coach.say(
          CueType.criticalFault,
          VoiceContent.key('glute_bridge.neck_head'),
          const CueContext(repNumber: 1, contentKey: 'neck_head'),
        ),
        isFalse,
      );

      now = 10500;
      expect(
        coach.say(
          CueType.criticalFault,
          VoiceContent.key('glute_bridge.neck_head'),
          const CueContext(repNumber: 1, contentKey: 'neck_head'),
        ),
        isTrue,
      );
    });
  });

  group('hustle', () {
    Map<CueType, CueTuning> hustleTuning({
      double base = 0.20,
      double step = 0.30,
      double cap = 0.80,
      int postFireIdlePenalty = 0,
    }) {
      return {
        ...kDefaultTuning,
        CueType.hustle: CueTuning(
          CueMode.perishable,
          base: base,
          step: step,
          cap: cap,
          postFireIdlePenalty: postFireIdlePenalty,
        ),
      };
    }

    test('quiet at hunger 0, then fires after armed silence raises hunger', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.25, 0.25]),
        tuning: hustleTuning(),
        outcomeCollisionGapMs: 0,
      );

      expect(
        policy.decide(
          CueType.hustle,
          const CueContext(repNumber: 1, isFinalReps: false),
        ),
        isFalse,
        reason: '0.25 misses the 0.20 base chance at hunger 0',
      );
      expect(
        policy.decide(
          CueType.hustle,
          const CueContext(repNumber: 2, isFinalReps: false),
        ),
        isTrue,
        reason: 'the same roll hits after one armed-but-silent attempt',
      );
    });

    test('firing resets the hunger climb', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.25, 0.25, 0.25]),
        tuning: hustleTuning(),
        outcomeCollisionGapMs: 0,
      );

      expect(
        policy.decide(CueType.hustle, const CueContext(repNumber: 1)),
        isFalse,
      );
      expect(
        policy.decide(CueType.hustle, const CueContext(repNumber: 2)),
        isTrue,
      );
      policy.markOutcomeAudioEnded();
      expect(
        policy.decide(CueType.hustle, const CueContext(repNumber: 3)),
        isFalse,
        reason: 'after a fire, the 0.25 roll is back above the 0.20 base',
      );
    });

    test('two fires in one set are allowed', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.0]),
        tuning: hustleTuning(),
        outcomeCollisionGapMs: 0,
      );

      expect(
        policy.decide(CueType.hustle, const CueContext(repNumber: 1)),
        isTrue,
      );
      policy.markOutcomeAudioEnded();
      expect(
        policy.decide(CueType.hustle, const CueContext(repNumber: 2)),
        isTrue,
        reason: 'the old once-per-set latch is gone',
      );
    });

    test('post-fire backoff mutes the next eligible pushes without a hard gate',
        () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.0, 0.35, 0.35, 0.35]),
        tuning: hustleTuning(
          base: 0.50,
          step: 0.20,
          cap: 0.90,
          postFireIdlePenalty: 2,
        ),
        outcomeCollisionGapMs: 0,
      );

      expect(policy.decide(CueType.hustle, const CueContext(repNumber: 1)),
          isTrue);
      policy.markOutcomeAudioEnded();
      expect(
        policy.decide(CueType.hustle, const CueContext(repNumber: 2)),
        isFalse,
        reason: 'after a fire, the next eligible roll starts at 0.10',
      );
      expect(
        policy.decide(CueType.hustle, const CueContext(repNumber: 3)),
        isFalse,
        reason: 'the following eligible roll is still muted at 0.30',
      );
      expect(
        policy.decide(CueType.hustle, const CueContext(repNumber: 4)),
        isTrue,
        reason: 'silent eligible attempts climb back to the normal 0.50 base',
      );
    });

    test('still loses the second in-rep outcome slot', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.0]),
        tuning: hustleTuning(base: 1.0, cap: 1.0),
        outcomeCollisionGapMs: 0,
      );

      expect(
        policy.decide(CueType.praise, const CueContext(repNumber: 1)),
        isTrue,
      );
      policy.markOutcomeAudioEnded();
      expect(
        policy.decide(CueType.hustle, const CueContext(repNumber: 1)),
        isFalse,
        reason: 'hustle is not allowed to take the second in-rep slot',
      );
    });

    test('fires even when isFinalReps is false', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.99]),
        tuning: hustleTuning(base: 1.0, cap: 1.0),
      );

      expect(
        policy.decide(
          CueType.hustle,
          const CueContext(repNumber: 3, isFinalReps: false),
        ),
        isTrue,
        reason: 'final-reps is no longer a policy gate',
      );
    });

    test('drops when the sink is busy', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.0]),
        tuning: hustleTuning(base: 1.0, cap: 1.0),
      );

      expect(
        policy.decide(
          CueType.hustle,
          const CueContext(repNumber: 3, sinkBusy: true),
        ),
        isFalse,
        reason: 'hustle is perishable at the fire moment',
      );
    });
  });

  group('correction', () {
    test('probability rises with faultPersistence', () {
      // 25% -> 55% -> 85% by persistence (0, 1, 2). A fixed 0.30 roll
      // misses the first tier and hits the rest. The calibrated default now
      // has firstOccurrenceCertain (persistence 0 = certain), so isolate the
      // roll-based escalation with an explicit no-first-certain tuning.
      final rollingCritical = {
        ...kDefaultTuning,
        CueType.criticalFault: const CueTuning(
          CueMode.correction,
          base: 0.25,
          step: 0.30,
          cap: 0.85,
        ),
      };
      final policy =
          VoicePolicy(random: _ScriptedRandom([0.30]), tuning: rollingCritical);
      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(
            repNumber: 1,
            faultPersistence: 0,
            contentKey: 'heel',
          ),
        ),
        isFalse,
      );

      final policy2 =
          VoicePolicy(random: _ScriptedRandom([0.30]), tuning: rollingCritical);
      expect(
        policy2.decide(
          CueType.criticalFault,
          const CueContext(
            repNumber: 1,
            faultPersistence: 1,
            contentKey: 'heel',
          ),
        ),
        isTrue,
      );
    });

    test('relief valve fires near-certainly past reliefAfter', () {
      // 0.99 would miss every escalation tier (cap 0.85) but the relief
      // valve bypasses the roll entirely once persistence >= reliefAfter. The
      // calibrated default dropped the relief valve (redundant with
      // firstOccurrenceCertain), so test the mechanism via an explicit tuning.
      final reliefCritical = {
        ...kDefaultTuning,
        CueType.criticalFault: const CueTuning(
          CueMode.correction,
          base: 0.25,
          step: 0.30,
          cap: 0.85,
          reliefAfter: 4,
        ),
      };
      final policy =
          VoicePolicy(random: _ScriptedRandom([0.99]), tuning: reliefCritical);
      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(
            repNumber: 1,
            faultPersistence: 4,
            contentKey: 'heel',
          ),
        ),
        isTrue,
      );
    });

    test('relief valve still respects one-outcome-cue-per-rep', () {
      final policy = VoicePolicy(random: _ScriptedRandom([0.0, 0.99]));
      expect(
        policy.decide(
          CueType.praise,
          const CueContext(repNumber: 1),
        ),
        isTrue,
      );
      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(
            repNumber: 1,
            faultPersistence: 99,
            contentKey: 'heel',
          ),
        ),
        isFalse,
        reason: 'even a maxed-out relief valve cannot claim a second '
            'outcome cue on the same rep',
      );
    });

    test('first occurrence certainty is opt-in', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.99]),
        tuning: {
          ...kDefaultTuning,
          CueType.criticalFault: const CueTuning(
            CueMode.correction,
            base: 0.0,
            step: 0.0,
            cap: 0.0,
            firstOccurrenceCertain: true,
          ),
        },
      );

      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(
            repNumber: 1,
            faultPersistence: 0,
            contentKey: 'hip_extension',
          ),
        ),
        isTrue,
        reason: 'the first sighting bypasses the losing roll only when this '
            'pilot flag is enabled',
      );
      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(
            repNumber: 2,
            faultPersistence: 1,
            contentKey: 'hip_extension',
          ),
        ),
        isFalse,
        reason: 'later reps go back to the configured escalation roll',
      );
    });
  });

  group('reminder', () {
    Map<CueType, CueTuning> reminderTuning({
      double base = 0.30,
      double step = 0.15,
      double cap = 0.65,
      bool firstOccurrenceCertain = true,
    }) {
      return {
        ...kDefaultTuning,
        CueType.reminder: CueTuning(
          CueMode.correction,
          base: base,
          step: step,
          cap: cap,
          firstOccurrenceCertain: firstOccurrenceCertain,
        ),
      };
    }

    test('streak 0 is deterministic when the pilot flag is enabled', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.99]),
        tuning: reminderTuning(base: 0.0, step: 0.0, cap: 0.0),
        outcomeCollisionGapMs: 0,
      );

      expect(
        policy.decide(
          CueType.reminder,
          const CueContext(
            repNumber: 2,
            contentKey: 'hyperextension',
            faultPersistence: 0,
          ),
        ),
        isTrue,
      );
      policy.markOutcomeAudioEnded();
      expect(
        policy.decide(
          CueType.reminder,
          const CueContext(
            repNumber: 3,
            contentKey: 'hyperextension',
            faultPersistence: 1,
          ),
        ),
        isFalse,
        reason: 'only the first reminder in the streak bypasses the roll',
      );
    });

    test('streak n rolls from base plus step times reminder streak', () {
      final hit = VoicePolicy(
        random: _ScriptedRandom([0.44]),
        tuning: reminderTuning(),
      );
      expect(
        hit.decide(
          CueType.reminder,
          const CueContext(
            repNumber: 3,
            contentKey: 'hyperextension',
            faultPersistence: 1,
          ),
        ),
        isTrue,
        reason: '0.30 + 0.15 * 1 = 0.45, so 0.44 hits',
      );

      final miss = VoicePolicy(
        random: _ScriptedRandom([0.46]),
        tuning: reminderTuning(),
      );
      expect(
        miss.decide(
          CueType.reminder,
          const CueContext(
            repNumber: 3,
            contentKey: 'hyperextension',
            faultPersistence: 1,
          ),
        ),
        isFalse,
        reason: 'the same streak misses just above the 0.45 tier',
      );
    });

    test('probability respects the configured cap', () {
      final cappedMiss = VoicePolicy(
        random: _ScriptedRandom([0.66]),
        tuning: reminderTuning(),
      );
      expect(
        cappedMiss.decide(
          CueType.reminder,
          const CueContext(
            repNumber: 6,
            contentKey: 'hyperextension',
            faultPersistence: 99,
          ),
        ),
        isFalse,
        reason: 'even huge streaks cap at 0.65',
      );

      final cappedHit = VoicePolicy(
        random: _ScriptedRandom([0.64]),
        tuning: reminderTuning(),
      );
      expect(
        cappedHit.decide(
          CueType.reminder,
          const CueContext(
            repNumber: 6,
            contentKey: 'hyperextension',
            faultPersistence: 99,
          ),
        ),
        isTrue,
      );
    });

    test('counts as an outcome and blocks same-fault correction in that rep',
        () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.0]),
        tuning: reminderTuning(),
        outcomeCollisionGapMs: 0,
      );

      expect(
        policy.decide(
          CueType.reminder,
          const CueContext(
            repNumber: 2,
            contentKey: 'hyperextension',
            faultPersistence: 0,
          ),
        ),
        isTrue,
      );
      policy.markOutcomeAudioEnded();

      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(
            repNumber: 2,
            contentKey: 'hyperextension',
            faultPersistence: 0,
          ),
        ),
        isFalse,
        reason: 'same contentKey already spoke as the reminder',
      );
      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(
            repNumber: 2,
            contentKey: 'neck_head',
            faultPersistence: 0,
          ),
        ),
        isTrue,
        reason: 'the second slot is still critical-only for a different fault',
      );
    });

    test('gap blocks it and it never takes the second in-rep slot', () {
      var now = 0;
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.0]),
        clockMs: () => now,
        tuning: reminderTuning(),
        outcomeCollisionGapMs: 500,
      );

      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(repNumber: 1, contentKey: 'neck_head'),
        ),
        isTrue,
      );
      policy.markOutcomeAudioEnded(1000);

      now = 1499;
      expect(
        policy.decide(
          CueType.reminder,
          const CueContext(
            repNumber: 2,
            contentKey: 'hyperextension',
            faultPersistence: 0,
          ),
        ),
        isFalse,
        reason: 'collision gap is measured from the previous outcome audio end',
      );

      now = 1500;
      expect(
        policy.decide(
          CueType.reminder,
          const CueContext(
            repNumber: 2,
            contentKey: 'hyperextension',
            faultPersistence: 0,
          ),
        ),
        isTrue,
      );
      policy.markOutcomeAudioEnded(1500);

      expect(
        policy.decide(
          CueType.reminder,
          const CueContext(
            repNumber: 2,
            contentKey: 'neck_head',
            faultPersistence: 0,
          ),
        ),
        isFalse,
        reason: 'reminder is not allowed to take the second outcome slot',
      );
    });
  });

  group('soft', () {
    test('first occurrence is still a roll, not deterministic', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.99]),
        tuning: _gluteBridgePilotTuning(),
      );

      expect(
        policy.decide(
          CueType.softFault,
          const CueContext(repNumber: 1, contentKey: 'hip_extension'),
        ),
        isFalse,
      );
    });

    test('claims the outcome slot when it fires', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.0]),
        tuning: _gluteBridgePilotTuning(),
      );

      expect(
        policy.decide(
          CueType.softFault,
          const CueContext(repNumber: 1, contentKey: 'hip_extension'),
        ),
        isTrue,
      );
      expect(
        policy.decide(
          CueType.criticalFault,
          const CueContext(
            repNumber: 1,
            faultPersistence: 0,
            contentKey: 'hip_extension',
          ),
        ),
        isFalse,
        reason: 'soft is an outcome cue, so a critical correction cannot also '
            'claim the same rep',
      );
    });
  });

  group('per-fault hunger independence', () {
    test(
      'instruction: silence on one content key does not raise another\'s '
      'odds',
      () {
        // Custom tuning with no baseline chance at idle 0, so hunger is
        // the only thing that can make it fire: idle 0/1/2 -> 0/0.2/0.4
        // (all miss a 0.50 roll), idle 3 -> 0.6 (hits).
        final tuning = {
          ...kDefaultTuning,
          CueType.setup: const CueTuning(
            CueMode.base,
            base: 0.0,
            step: 0.20,
            cap: 1.0,
          ),
        };
        final policy = VoicePolicy(
          random: _ScriptedRandom([0.50]),
          tuning: tuning,
        );

        expect(
          policy.decide(
            CueType.setup,
            const CueContext(repNumber: 1, contentKey: 'setup_a'),
          ),
          isFalse,
        );
        expect(
          policy.decide(
            CueType.setup,
            const CueContext(repNumber: 2, contentKey: 'setup_a'),
          ),
          isFalse,
        );
        expect(
          policy.decide(
            CueType.setup,
            const CueContext(repNumber: 3, contentKey: 'setup_a'),
          ),
          isFalse,
        );
        expect(
          policy.decide(
            CueType.setup,
            const CueContext(repNumber: 4, contentKey: 'setup_a'),
          ),
          isTrue,
          reason: 'setup_a has built enough hunger (idle 3) to fire',
        );

        expect(
          policy.decide(
            CueType.setup,
            const CueContext(repNumber: 5, contentKey: 'setup_b'),
          ),
          isFalse,
          reason: 'setup_b must start fresh — setup_a\'s hunger must not '
              'leak into it',
        );
      },
    );

    test(
      'correct: fault A\'s silence history does not change fault B\'s '
      'decision',
      () {
        const ctxB = CueContext(
          repNumber: 4,
          faultPersistence: 0,
          contentKey: 'faultB',
        );

        // Hammer fault A with several silent (missed) calls on one policy
        // instance, then ask about fault B with a roll that hits the base
        // (25%) tier. No-first-certain tuning so fault A actually MISSES its
        // rolls (the calibrated default would fire A's first occurrence and
        // trip outcome-pending) — this test is about hunger independence.
        final rollingCritical = {
          ...kDefaultTuning,
          CueType.criticalFault: const CueTuning(
            CueMode.correction,
            base: 0.25,
            step: 0.30,
            cap: 0.85,
          ),
        };
        final hammered = VoicePolicy(
          random: _ScriptedRandom([0.90, 0.90, 0.90, 0.20]),
          tuning: rollingCritical,
        );
        hammered.decide(
          CueType.criticalFault,
          const CueContext(
            repNumber: 1,
            faultPersistence: 0,
            contentKey: 'faultA',
          ),
        );
        hammered.decide(
          CueType.criticalFault,
          const CueContext(
            repNumber: 2,
            faultPersistence: 1,
            contentKey: 'faultA',
          ),
        );
        hammered.decide(
          CueType.criticalFault,
          const CueContext(
            repNumber: 3,
            faultPersistence: 2,
            contentKey: 'faultA',
          ),
        );
        final hammeredResult = hammered.decide(CueType.criticalFault, ctxB);

        // A fresh policy asked about fault B with the same final roll and
        // no fault-A history at all.
        final fresh = VoicePolicy(
          random: _ScriptedRandom([0.20]),
          tuning: rollingCritical,
        );
        final freshResult = fresh.decide(CueType.criticalFault, ctxB);

        expect(hammeredResult, isTrue); // 0.20 hits the 25% base tier.
        expect(
          hammeredResult,
          equals(freshResult),
          reason: 'fault A\'s silent streak must not change fault B\'s '
              'outcome for an identical roll',
        );
      },
    );
  });

  group('personality', () {
    test('scales base+step but the roll never exceeds cap', () {
      // base 0, step 1.0, cap 0.5: at idle 1, raw (base+step*idle) is 1.0
      // and an extreme personality (10x) would blow that to 10.0 without
      // clamping — the roll must still cap at exactly 0.5.
      final tuning = {
        ...kDefaultTuning,
        CueType.setup: const CueTuning(
          CueMode.base,
          base: 0.0,
          step: 1.0,
          cap: 0.5,
        ),
      };

      final justUnderCap = VoicePolicy(
        personality: 10.0,
        random: _ScriptedRandom([0.0, 0.49]),
        tuning: tuning,
      );
      expect(
        justUnderCap.decide(
          CueType.setup,
          const CueContext(repNumber: 1, contentKey: 'x'),
        ),
        isFalse,
      );
      expect(
        justUnderCap.decide(
          CueType.setup,
          const CueContext(repNumber: 2, contentKey: 'x'),
        ),
        isTrue,
        reason: '0.49 is just under the 0.5 cap',
      );

      final justOverCap = VoicePolicy(
        personality: 10.0,
        random: _ScriptedRandom([0.0, 0.51]),
        tuning: tuning,
      );
      expect(
        justOverCap.decide(
          CueType.setup,
          const CueContext(repNumber: 1, contentKey: 'x'),
        ),
        isFalse,
      );
      expect(
        justOverCap.decide(
          CueType.setup,
          const CueContext(repNumber: 2, contentKey: 'x'),
        ),
        isFalse,
        reason: '0.51 must miss — personality can never push the roll '
            'past cap',
      );
    });

    test('never overrides hard rules or the relief valve', () {
      // A very quiet coach (0.1) still enforces "never twice in a row".
      final quietPraise = VoicePolicy(
        personality: 0.1,
        random: _ScriptedRandom([0.0]),
      );
      expect(
        quietPraise.decide(CueType.praise, const CueContext(repNumber: 1)),
        isTrue,
      );
      expect(
        quietPraise.decide(CueType.praise, const CueContext(repNumber: 2)),
        isFalse,
      );

      // A very quiet coach still fires the relief valve near-certainly. The
      // relief valve left the calibrated default (07-12); test it explicitly.
      final quietCorrect = VoicePolicy(
        personality: 0.1,
        random: _ScriptedRandom([0.99]),
        tuning: {
          ...kDefaultTuning,
          CueType.criticalFault: const CueTuning(
            CueMode.correction,
            base: 0.25,
            step: 0.30,
            cap: 0.85,
            reliefAfter: 4,
          ),
        },
      );
      expect(
        quietCorrect.decide(
          CueType.criticalFault,
          const CueContext(
            repNumber: 1,
            faultPersistence: 4,
            contentKey: 'heel',
          ),
        ),
        isTrue,
      );
    });
  });

  group('count', () {
    test('rep 1 always fires, regardless of an unfavourable roll', () {
      final policy = VoicePolicy(random: _ScriptedRandom([0.999]));
      expect(
        policy.decide(CueType.count, const CueContext(repNumber: 1)),
        isTrue,
      );
    });

    test('final two reps always fire when the adapter marks them final', () {
      final policy = VoicePolicy(random: _ScriptedRandom([0.999]));

      expect(
        policy.decide(
          CueType.count,
          const CueContext(repNumber: 9, isFinalReps: true),
        ),
        isTrue,
      );
      expect(
        policy.decide(
          CueType.count,
          const CueContext(repNumber: 10, isFinalReps: true),
        ),
        isTrue,
      );
    });

    test(
        'REGISTRATION (07-11): every landed rep is counted under the fleet '
        'default, regardless of an unfavourable roll', () {
      // The count is trust feedback, not chatter — users don't watch the
      // screen, so the spoken number is the only proof a rep registered.
      final policy = VoicePolicy(random: _ScriptedRandom([0.999]));
      for (var rep = 1; rep <= 12; rep++) {
        expect(
          policy.decide(CueType.count, CueContext(repNumber: rep)),
          isTrue,
          reason: 'rep $rep must be counted — no thinning at base 1.0',
        );
      }
    });

    test('count is personality-immune — a quiet coach still counts every rep',
        () {
      final policy = VoicePolicy(
        personality: 0.1,
        random: _ScriptedRandom([0.999]),
      );
      for (var rep = 2; rep <= 6; rep++) {
        expect(
          policy.decide(CueType.count, CueContext(repNumber: rep)),
          isTrue,
          reason: 'registration feedback must not be thinned by personality',
        );
      }
    });

    test(
        'an explicit re-thinning config (base < 1.0) still rolls — the '
        'mechanism survives the 07-11 default', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.95]),
        tuning: {
          ...kDefaultTuning,
          CueType.count:
              const CueTuning(CueMode.always, base: 0.5, step: 0.0, cap: 0.9),
        },
      );
      expect(
        policy.decide(CueType.count, const CueContext(repNumber: 2)),
        isFalse,
        reason: 'a 0.95 roll loses against an explicit thinned base',
      );
      expect(
        policy.decide(CueType.count, const CueContext(repNumber: 1)),
        isTrue,
        reason: 'the rep-1 anchor holds even under a thinned config',
      );
    });
  });

  group('phase', () {
    test('reps 1-2 are deterministic anchors when the sink is free', () {
      final policy = VoicePolicy(random: _ScriptedRandom([0.999]));

      expect(
        policy.decide(CueType.phase, const CueContext(repNumber: 1)),
        isTrue,
      );
      expect(
        policy.decide(CueType.phase, const CueContext(repNumber: 2)),
        isTrue,
      );
      expect(
        policy.decide(
          CueType.phase,
          const CueContext(repNumber: 1, sinkBusy: true),
        ),
        isFalse,
        reason: 'phase anchors still respect the perishable sink-busy gate',
      );
    });

    test('post-anchor free-sink phase rate is about 45%', () {
      final rolls = List<double>.generate(1000, (i) => (i % 100) / 100);
      final policy = VoicePolicy(random: _ScriptedRandom(rolls));

      var spoken = 0;
      for (var rep = 3; rep < 1003; rep++) {
        if (policy.decide(CueType.phase, CueContext(repNumber: rep))) {
          spoken++;
        }
      }

      expect(spoken / 1000, closeTo(0.45, 0.001));
    });

    test('realistic busy ascent pattern does not starve phase cues', () {
      const reps = 5000;
      const starvationFloor = 0.35;
      final policy = VoicePolicy(random: Random(20260708));

      var postAnchorReps = 0;
      var repsWithAnyPhaseCue = 0;

      for (var rep = 1; rep <= reps; rep++) {
        final descent = policy.decide(
          CueType.phase,
          CueContext(repNumber: rep, sinkBusy: false),
        );
        final bottom = policy.decide(
          CueType.phase,
          CueContext(repNumber: rep, sinkBusy: false),
        );
        final ascent = policy.decide(
          CueType.phase,
          CueContext(repNumber: rep, sinkBusy: true),
        );

        if (rep <= 2) continue;
        postAnchorReps++;
        if (descent || bottom || ascent) {
          repsWithAnyPhaseCue++;
        }
      }

      final coverage = repsWithAnyPhaseCue / postAnchorReps;
      // ignore: avoid_print
      print(
        'phase effective coverage with busy ascent: '
        '${(coverage * 100).toStringAsFixed(1)}%',
      );

      expect(
        coverage,
        greaterThan(starvationFloor),
        reason: 'with descent/bottom free and ascent busy, the post-anchor '
            'phase taper should still reach enough reps to be useful',
      );
    });
  });

  group('reproducibility', () {
    List<bool> runTranscript(int seed) {
      final policy = VoicePolicy(random: Random(seed));
      final results = <bool>[];
      for (var rep = 1; rep <= 30; rep++) {
        final clean = rep % 3 != 0;
        final isFinalReps = rep >= 25;
        final ctx = CueContext(
          repNumber: rep,
          isFinalReps: isFinalReps,
          clean: clean,
          formScore: clean ? 1.0 : 0.5,
          faultPersistence: clean ? 0 : rep ~/ 3,
          contentKey: clean ? '' : 'heel',
        );
        results.add(policy.decide(CueType.count, ctx));
        if (clean) {
          results.add(policy.decide(CueType.praise, ctx));
        } else {
          results.add(policy.decide(CueType.criticalFault, ctx));
        }
        if (isFinalReps) {
          results.add(policy.decide(CueType.hustle, ctx));
        }
      }
      return results;
    }

    test('same seed reproduces the transcript; a different seed differs', () {
      final run1 = runTranscript(1234);
      final run2 = runTranscript(1234);
      expect(run1, equals(run2));

      // Counts are deterministic since the 07-11 registration ruling, so far
      // fewer draws remain in this transcript and any single alternate seed
      // can coincide with the baseline. The stochastic-cadence property is
      // "seeds CAN differ", so require at least one of several seeds to
      // diverge instead of pinning one specific pair.
      final anyDiffers = [9999, 5678, 424242, 31337]
          .any((seed) => runTranscript(seed).toString() != run1.toString());
      expect(anyDiffers, isTrue,
          reason: 'different seeds must be able to produce a different '
              'transcript — the stochastic layer is still live');
    });
  });
}
