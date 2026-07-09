// Unit tests for VoicePolicy — the pure brain of the voice-coach refactor.
//
// Build spec: docs/reference/voice-coach/implementation-guide.md §10.
// "Assert the behaviour, not the numbers" — these tests check invariants
// (never-twice-in-a-row, one-outcome-per-rep, escalation direction, relief
// valves, per-fault independence, personality bounds, reproducibility),
// not the exact tuned probabilities (those are expected to move on device).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/voice/voice_content.dart';
import 'package:vika/voice/voice_policy.dart';

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

Map<CueType, CueTuning> _gluteBridgePilotTuning() => {
      ...kDefaultTuning,
      CueType.count: const CueTuning(
        CueMode.always,
        base: 0.50,
        step: 0.10,
        cap: 1.0,
      ),
      CueType.praise: const CueTuning(
        CueMode.variableRatio,
        base: 0.50,
        step: 0.10,
        cap: 0.85,
        scalePraiseByFormScore: false,
      ),
      CueType.correct: const CueTuning(
        CueMode.correction,
        base: 0.25,
        step: 0.30,
        cap: 0.85,
        firstOccurrenceCertain: true,
      ),
      CueType.soft: const CueTuning(
        CueMode.variableRatio,
        base: 0.20,
        step: 0.08,
        cap: 0.55,
      ),
      CueType.hustle: const CueTuning(CueMode.perishable, base: 0.0, cap: 0.0),
    };

void main() {
  group('praise', () {
    test('never fires twice in a row, even with a favourable roll', () {
      // 0.0 is below every positive probability this policy will ever
      // compute, i.e. "always take it if the hard rules allow it".
      final policy = VoicePolicy(random: _ScriptedRandom([0.0]));

      expect(
        policy.decide(CueType.praise, const CueContext(repNumber: 5)),
        isTrue,
      );
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
      // 1 -> 0.35. A roll of 0.30 sits between the two.
      final lowQuality = VoicePolicy(random: _ScriptedRandom([0.30]));
      expect(
        lowQuality.decide(
          CueType.praise,
          const CueContext(repNumber: 1, formScore: 0.0),
        ),
        isFalse,
      );

      final highQuality = VoicePolicy(random: _ScriptedRandom([0.30]));
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
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.0]),
        tuning: _gluteBridgePilotTuning(),
      );

      expect(
        policy.decide(CueType.praise, const CueContext(repNumber: 1)),
        isTrue,
      );
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

  group('one outcome cue per rep', () {
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
          CueType.correct,
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
  });

  group('hustle', () {
    test('only fires on final reps, and at most once per set', () {
      final policy = VoicePolicy(random: _ScriptedRandom([0.0]));

      expect(
        policy.decide(
          CueType.hustle,
          const CueContext(repNumber: 1, isFinalReps: false),
        ),
        isFalse,
        reason: 'not in the final stretch yet',
      );
      expect(
        policy.decide(
          CueType.hustle,
          const CueContext(repNumber: 9, isFinalReps: true),
        ),
        isTrue,
      );
      expect(
        policy.decide(
          CueType.hustle,
          const CueContext(repNumber: 10, isFinalReps: true),
        ),
        isFalse,
        reason: 'already used its one hustle for this set',
      );

      policy.beginSet();
      expect(
        policy.decide(
          CueType.hustle,
          const CueContext(repNumber: 9, isFinalReps: true),
        ),
        isTrue,
        reason: 'a new set resets the once-per-set cap',
      );
    });
  });

  group('correction', () {
    test('probability rises with faultPersistence', () {
      // 25% -> 55% -> 85% by persistence (0, 1, 2). A fixed 0.30 roll
      // misses the first tier and hits the rest.
      final policy = VoicePolicy(random: _ScriptedRandom([0.30]));
      expect(
        policy.decide(
          CueType.correct,
          const CueContext(
            repNumber: 1,
            faultPersistence: 0,
            contentKey: 'heel',
          ),
        ),
        isFalse,
      );

      final policy2 = VoicePolicy(random: _ScriptedRandom([0.30]));
      expect(
        policy2.decide(
          CueType.correct,
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
      // valve bypasses the roll entirely once persistence >= reliefAfter.
      final policy = VoicePolicy(random: _ScriptedRandom([0.99]));
      expect(
        policy.decide(
          CueType.correct,
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
          CueType.correct,
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
          CueType.correct: const CueTuning(
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
          CueType.correct,
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
          CueType.correct,
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

  group('soft', () {
    test('first occurrence is still a roll, not deterministic', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.99]),
        tuning: _gluteBridgePilotTuning(),
      );

      expect(
        policy.decide(
          CueType.soft,
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
          CueType.soft,
          const CueContext(repNumber: 1, contentKey: 'hip_extension'),
        ),
        isTrue,
      );
      expect(
        policy.decide(
          CueType.correct,
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
          CueType.instruction: const CueTuning(
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
            CueType.instruction,
            const CueContext(repNumber: 1, contentKey: 'setup_a'),
          ),
          isFalse,
        );
        expect(
          policy.decide(
            CueType.instruction,
            const CueContext(repNumber: 2, contentKey: 'setup_a'),
          ),
          isFalse,
        );
        expect(
          policy.decide(
            CueType.instruction,
            const CueContext(repNumber: 3, contentKey: 'setup_a'),
          ),
          isFalse,
        );
        expect(
          policy.decide(
            CueType.instruction,
            const CueContext(repNumber: 4, contentKey: 'setup_a'),
          ),
          isTrue,
          reason: 'setup_a has built enough hunger (idle 3) to fire',
        );

        expect(
          policy.decide(
            CueType.instruction,
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
        // (25%) tier.
        final hammered = VoicePolicy(
          random: _ScriptedRandom([0.90, 0.90, 0.90, 0.20]),
        );
        hammered.decide(
          CueType.correct,
          const CueContext(
            repNumber: 1,
            faultPersistence: 0,
            contentKey: 'faultA',
          ),
        );
        hammered.decide(
          CueType.correct,
          const CueContext(
            repNumber: 2,
            faultPersistence: 1,
            contentKey: 'faultA',
          ),
        );
        hammered.decide(
          CueType.correct,
          const CueContext(
            repNumber: 3,
            faultPersistence: 2,
            contentKey: 'faultA',
          ),
        );
        final hammeredResult = hammered.decide(CueType.correct, ctxB);

        // A fresh policy asked about fault B with the same final roll and
        // no fault-A history at all.
        final fresh = VoicePolicy(random: _ScriptedRandom([0.20]));
        final freshResult = fresh.decide(CueType.correct, ctxB);

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
        CueType.instruction: const CueTuning(
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
          CueType.instruction,
          const CueContext(repNumber: 1, contentKey: 'x'),
        ),
        isFalse,
      );
      expect(
        justUnderCap.decide(
          CueType.instruction,
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
          CueType.instruction,
          const CueContext(repNumber: 1, contentKey: 'x'),
        ),
        isFalse,
      );
      expect(
        justOverCap.decide(
          CueType.instruction,
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

      // A very quiet coach still fires the relief valve near-certainly.
      final quietCorrect = VoicePolicy(
        personality: 0.1,
        random: _ScriptedRandom([0.99]),
      );
      expect(
        quietCorrect.decide(
          CueType.correct,
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

    test(
        'roll saturates below certainty — a skip streak never forces '
        'the next count by probability alone', () {
      // 0.95 beats the 0.90 cap every time. Under the old cap of 1.0 the
      // hunger step made the roll certain after 2 silent counts — a
      // learnable "quiet twice → next always counts" rhythm. Below the
      // relief point every middle rep must remain a real draw.
      final policy = VoicePolicy(random: _ScriptedRandom([0.95]));
      for (var rep = 2; rep <= 7; rep++) {
        expect(
          policy.decide(CueType.count, CueContext(repNumber: rep)),
          isFalse,
          reason: 'rep $rep: p is capped at 0.90, so a 0.95 roll must lose',
        );
      }
    });

    test(
        'relief valve: only 6 straight silent counts force one, '
        'and speaking resets the streak', () {
      final policy = VoicePolicy(random: _ScriptedRandom([0.999]));
      for (var rep = 2; rep <= 7; rep++) {
        expect(
          policy.decide(CueType.count, CueContext(repNumber: rep)),
          isFalse,
        );
      }
      expect(
        policy.decide(CueType.count, const CueContext(repNumber: 8)),
        isTrue,
        reason: 'idle streak reached reliefAfter (6) — the uncounted-set '
            'guard, the only deterministic count after rep 1',
      );
      expect(
        policy.decide(CueType.count, const CueContext(repNumber: 9)),
        isFalse,
        reason: 'the forced count reset the streak; the roll governs again',
      );
    });

    test('glute bridge pilot count reaches certainty after five skips', () {
      final policy = VoicePolicy(
        random: _ScriptedRandom([0.999]),
        tuning: _gluteBridgePilotTuning(),
      );

      expect(
        policy.decide(CueType.count, const CueContext(repNumber: 1)),
        isTrue,
        reason: 'rep 1 remains the anchor',
      );
      for (var rep = 2; rep <= 6; rep++) {
        expect(
          policy.decide(CueType.count, CueContext(repNumber: rep)),
          isFalse,
          reason: 'rep $rep is still below 1.0 with a 0.999 roll',
        );
      }
      expect(
        policy.decide(CueType.count, const CueContext(repNumber: 7)),
        isTrue,
        reason: 'after five straight silent counts, 0.50 + 5*0.10 = 1.0',
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
          results.add(policy.decide(CueType.correct, ctx));
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
      final run3 = runTranscript(9999);

      expect(run1, equals(run2));
      expect(run1, isNot(equals(run3)));
    });
  });
}
