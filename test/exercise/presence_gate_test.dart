// ignore_for_file: constant_identifier_names

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'package:vika/exercise/presence_gate.dart';
import 'package:vika/utils/person_detector.dart';

// ---------------------------------------------------------------------------
// Fake presence source — settable fields, records call history.
// ---------------------------------------------------------------------------

class _FakePresenceSource implements PosePresenceSource {
  @override
  bool personDetected = false;
  @override
  double presenceScore = 0.0;

  final List<String> triggerReasons = [];
  int useActivatedCadenceCalls = 0;
  int usePausedCadenceCalls = 0;
  int closeCalls = 0;

  @override
  Future<bool> detect([Object? _]) async => personDetected;

  @override
  Future<void> triggerCheck({String reason = 'unknown'}) async {
    triggerReasons.add(reason);
  }

  @override
  Future<void> useActivatedCadence() async => useActivatedCadenceCalls++;

  @override
  Future<void> usePausedCadence() async => usePausedCadenceCalls++;

  @override
  Future<void> close() async => closeCalls++;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PoseLandmark _landmark(
  PoseLandmarkType type, {
  double x = 200,
  double y = 400,
  double z = 0,
  double likelihood = 0.99,
}) {
  return PoseLandmark(type: type, x: x, y: y, z: z, likelihood: likelihood);
}

// All landmarks at center; likelihood controls avg presence reported by gate.
Map<PoseLandmarkType, PoseLandmark> _allLandmarks({double likelihood = 0.99}) {
  return {
    for (final t in PoseLandmarkType.values)
      t: _landmark(t, likelihood: likelihood)
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('seeking — confirm / un-confirm', () {
    test('not confirmed before 400ms continuous presence', () {
      final fake = _FakePresenceSource()..personDetected = true;
      final gate = PresenceGate(detector: fake);
      final landmarks = _allLandmarks();

      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(0),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );
      expect(gate.personConfirmed, isFalse);

      final v = gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(399),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );
      expect(gate.personConfirmed, isFalse);
      expect(v.proceed, isFalse);
      expect(v.block, GateBlock.searching);
    });

    test('confirms at exactly 400ms continuous presence', () {
      final fake = _FakePresenceSource()..personDetected = true;
      final gate = PresenceGate(detector: fake);
      final landmarks = _allLandmarks();

      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(0),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );
      final v = gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(400),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );

      expect(gate.personConfirmed, isTrue);
      expect(v.proceed, isTrue); // confirmed → no longer blocked
    });

    test('streak resets when presence drops before confirmation', () {
      final fake = _FakePresenceSource()..personDetected = true;
      final gate = PresenceGate(detector: fake);
      final landmarks = _allLandmarks();

      // partial streak
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(0),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );

      // presence drops — streak resets
      fake.personDetected = false;
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(100),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );

      // presence returns — needs full 400ms again from zero
      fake.personDetected = true;
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(200),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(599),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );

      expect(gate.personConfirmed, isFalse);
    });

    test('personLostNow fires once when confirmed person un-confirms', () {
      final fake = _FakePresenceSource()..personDetected = true;
      final gate = PresenceGate(detector: fake);
      final landmarks = _allLandmarks();

      // Confirm
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(0),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(900),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );
      expect(gate.personConfirmed, isTrue);

      // Drop
      fake.personDetected = false;
      final v = gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(600),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );

      expect(gate.personConfirmed, isFalse);
      expect(v.personLostNow, isTrue);

      // Next frame — personLostNow does NOT repeat
      final v2 = gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(700),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );
      expect(v2.personLostNow, isFalse);
    });

    test('personLostNow is false in active phase', () {
      final fake = _FakePresenceSource()..personDetected = false;
      final gate = PresenceGate(detector: fake);

      final v = gate.onNoPose(
        now: DateTime.fromMillisecondsSinceEpoch(0),
        phase: GatePhase.active,
      );
      expect(v.personLostNow, isFalse);
    });

    test('personStableMs tracks unconfirmed seeking streak', () {
      final fake = _FakePresenceSource()..personDetected = true;
      final gate = PresenceGate(detector: fake);
      final landmarks = _allLandmarks();

      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(0),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );
      final v = gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(300),
        phase: GatePhase.seeking,
        landmarks: landmarks,
      );

      expect(v.personStableMs, greaterThanOrEqualTo(300));
    });
  });

  group('auto-pause / auto-resume', () {
    test('auto-pauses after 400ms absence during active', () {
      final fake = _FakePresenceSource()..personDetected = false;
      final gate = PresenceGate(detector: fake);

      gate.onNoPose(
        now: DateTime.fromMillisecondsSinceEpoch(0),
        phase: GatePhase.active,
      );
      expect(gate.isPaused, isFalse); // grace period

      gate.onNoPose(
        now: DateTime.fromMillisecondsSinceEpoch(399),
        phase: GatePhase.active,
      );
      expect(gate.isPaused, isFalse);

      gate.onNoPose(
        now: DateTime.fromMillisecondsSinceEpoch(400),
        phase: GatePhase.active,
      );
      expect(gate.isPaused, isTrue);
    });

    test('auto-resumes after 320ms continuous presence during active pause',
        () {
      final fake = _FakePresenceSource()..personDetected = false;
      final gate = PresenceGate(detector: fake);

      // Trigger auto-pause
      gate.onNoPose(
        now: DateTime.fromMillisecondsSinceEpoch(0),
        phase: GatePhase.active,
      );
      gate.onNoPose(
        now: DateTime.fromMillisecondsSinceEpoch(900),
        phase: GatePhase.active,
      );
      expect(gate.isPaused, isTrue);

      // Person returns — seeds resumePresenceSince at t=1000
      fake.personDetected = true;
      final landmarks = _allLandmarks();
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(1000),
        phase: GatePhase.active,
        landmarks: landmarks,
      );
      expect(gate.isPaused, isTrue); // 0ms elapsed since seen

      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(1319),
        phase: GatePhase.active,
        landmarks: landmarks,
      );
      expect(gate.isPaused, isTrue); // 319ms — just short

      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(1320),
        phase: GatePhase.active,
        landmarks: landmarks,
      );
      expect(gate.isPaused, isFalse); // 320ms — unpaused
    });

    test(
        'auto-pause switches detector to the paused cadence, not per-frame poke',
        () {
      final fake = _FakePresenceSource()..personDetected = false;
      final gate = PresenceGate(detector: fake);

      gate.onNoPose(
        now: DateTime.fromMillisecondsSinceEpoch(0),
        phase: GatePhase.active,
      );
      gate.onNoPose(
        now: DateTime.fromMillisecondsSinceEpoch(900),
        phase: GatePhase.active,
      );
      expect(gate.isPaused, isTrue);
      expect(
          fake.usePausedCadenceCalls, 1); // cadence dropped to 1s on the edge

      // Stay paused with pose present (person came back but not yet re-confirmed):
      // must NOT re-fire the old per-frame paused poke.
      fake.personDetected = true;
      final landmarks = _allLandmarks();
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(1000),
        phase: GatePhase.active,
        landmarks: landmarks,
      );
      expect(fake.triggerReasons.contains('paused_pose_present'), isFalse);
    });

    test('auto-resume restores the activated cadence', () {
      final fake = _FakePresenceSource()..personDetected = false;
      final gate = PresenceGate(detector: fake);

      gate.onNoPose(
        now: DateTime.fromMillisecondsSinceEpoch(0),
        phase: GatePhase.active,
      );
      gate.onNoPose(
        now: DateTime.fromMillisecondsSinceEpoch(900),
        phase: GatePhase.active,
      );
      expect(gate.isPaused, isTrue);

      fake.personDetected = true;
      final landmarks = _allLandmarks();
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(1000),
        phase: GatePhase.active,
        landmarks: landmarks,
      );
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(1320),
        phase: GatePhase.active,
        landmarks: landmarks,
      );
      expect(gate.isPaused, isFalse);
      expect(fake.useActivatedCadenceCalls, 1); // restored on the resume edge
    });

    test(
        'manual pause drops to the activated baseline, never the paused cadence',
        () {
      final fake = _FakePresenceSource()..personDetected = true;
      final gate = PresenceGate(detector: fake);

      gate.manualPause();

      expect(fake.useActivatedCadenceCalls, 1);
      expect(fake.usePausedCadenceCalls, 0);
    });

    test('manual pause is not cleared by presence', () {
      final fake = _FakePresenceSource()..personDetected = true;
      final gate = PresenceGate(detector: fake);
      final landmarks = _allLandmarks();

      gate.manualPause();
      expect(gate.isPaused, isTrue);

      // Sustained presence far beyond 320ms
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(0),
        phase: GatePhase.active,
        landmarks: landmarks,
      );
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(2000),
        phase: GatePhase.active,
        landmarks: landmarks,
      );

      expect(gate.isPaused, isTrue); // still paused
    });

    test('manualResume clears pause and seeds resume timer', () {
      final fake = _FakePresenceSource()..personDetected = true;
      final gate = PresenceGate(detector: fake);

      gate.manualPause();
      gate.manualResume(DateTime.fromMillisecondsSinceEpoch(0));

      expect(gate.isPaused, isFalse);
      expect(
        fake.triggerReasons,
        contains('manual_resume'),
      );
    });

    test('diagnosticMode disables auto-pause', () {
      final fake = _FakePresenceSource()..personDetected = false;
      final gate = PresenceGate(detector: fake, diagnosticMode: true);

      for (int ms = 0; ms <= 3000; ms += 200) {
        gate.onNoPose(
          now: DateTime.fromMillisecondsSinceEpoch(ms),
          phase: GatePhase.active,
        );
      }

      expect(gate.isPaused, isFalse);
    });
  });

  group('trouble triggers', () {
    test('pose_low_presence fires once per false→true, only in active', () {
      final fake = _FakePresenceSource()..personDetected = true;
      final gate = PresenceGate(detector: fake);
      final t = DateTime.fromMillisecondsSinceEpoch(0);

      final high = _allLandmarks(likelihood: 0.9);
      // avg presence = 0.2 < 0.35 threshold
      final low = _allLandmarks(likelihood: 0.2);

      // seeking-confirmed: trigger must NOT fire (active-only gate)
      // confirm person first with high-presence landmarks so _wasPoseLowPresence=false
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(0),
        phase: GatePhase.seeking,
        landmarks: high,
      );
      gate.onPose(
        now: DateTime.fromMillisecondsSinceEpoch(900),
        phase: GatePhase.seeking,
        landmarks: high,
      );
      // seeking-confirmed + low: updates _wasPoseLowPresence but must NOT trigger
      gate.onPose(now: t, phase: GatePhase.seeking, landmarks: low);
      expect(fake.triggerReasons.contains('pose_low_presence'), isFalse);

      // Reset _wasPoseLowPresence to false with a high frame before entering active
      gate.onPose(now: t, phase: GatePhase.seeking, landmarks: high);

      // active, first low frame → fires once
      gate.onPose(now: t, phase: GatePhase.active, landmarks: low);
      expect(
        fake.triggerReasons.where((r) => r == 'pose_low_presence').length,
        1,
      );

      // active, second low frame → no additional trigger
      gate.onPose(now: t, phase: GatePhase.active, landmarks: low);
      expect(
        fake.triggerReasons.where((r) => r == 'pose_low_presence').length,
        1,
      );

      // back to high then low again → fires once more (second transition)
      gate.onPose(now: t, phase: GatePhase.active, landmarks: high);
      gate.onPose(now: t, phase: GatePhase.active, landmarks: low);
      expect(
        fake.triggerReasons.where((r) => r == 'pose_low_presence').length,
        2,
      );
    });

    test('pose_frame_edge fires once per false→true, only in active', () {
      final fake = _FakePresenceSource()..personDetected = true;
      final gate = PresenceGate(detector: fake);
      final t = DateTime.fromMillisecondsSinceEpoch(0);
      const imageSize = Size(400, 800);

      // Build landmarks: all center except 2 outside frame → outsideCount >= 2
      final edgeLandmarks = <PoseLandmarkType, PoseLandmark>{
        for (final type in PoseLandmarkType.values)
          type: _landmark(type, x: 200, y: 400),
      };
      edgeLandmarks[PoseLandmarkType.leftAnkle] =
          _landmark(PoseLandmarkType.leftAnkle, x: -10, y: 200);
      edgeLandmarks[PoseLandmarkType.rightAnkle] =
          _landmark(PoseLandmarkType.rightAnkle, x: -10, y: 200);

      final safe = _allLandmarks(); // all center, no edge risk

      // active: trigger fires on first edge frame
      gate.onPose(
          now: t,
          phase: GatePhase.active,
          landmarks: edgeLandmarks,
          imageSize: imageSize);
      expect(
        fake.triggerReasons.where((r) => r == 'pose_frame_edge').length,
        1,
      );

      // active: second edge frame — no additional trigger
      gate.onPose(
          now: t,
          phase: GatePhase.active,
          landmarks: edgeLandmarks,
          imageSize: imageSize);
      expect(
        fake.triggerReasons.where((r) => r == 'pose_frame_edge').length,
        1,
      );

      // done phase: NOT in active → trigger must NOT fire even on transition
      gate.onPose(
          now: t, phase: GatePhase.active, landmarks: safe); // clears flag
      final countBefore =
          fake.triggerReasons.where((r) => r == 'pose_frame_edge').length;
      gate.onPose(
          now: t,
          phase: GatePhase.done,
          landmarks: edgeLandmarks,
          imageSize: imageSize);
      expect(
        fake.triggerReasons.where((r) => r == 'pose_frame_edge').length,
        countBefore,
      );
    });

    // Anomaly fires after long window (60 frames) warms up, then short window
    // drops by >0.15 for 3 consecutive frames (debouncer).
    // With baseline 0.9 and low 0.2: delta ≈ 0.3+ once short window fills.
    // Trigger confirmed at the 5th low frame (frames 63+64+65 satisfy debouncer).
    test('pose_anomaly fires once per false→true, in any non-blocked phase',
        () {
      final fake = _FakePresenceSource()..personDetected = true;
      final gate = PresenceGate(detector: fake);
      final t = DateTime.fromMillisecondsSinceEpoch(0);

      final high = _allLandmarks(likelihood: 0.9); // avg presence ~0.9
      final low = _allLandmarks(likelihood: 0.2); // avg presence ~0.2

      // Warm up long window (60 frames needed)
      for (int i = 0; i < 60; i++) {
        gate.onPose(now: t, phase: GatePhase.active, landmarks: high);
      }
      expect(fake.triggerReasons.contains('pose_anomaly'), isFalse);

      // Feed low-presence frames until anomaly fires (≤13 frames)
      for (int i = 0; i < 13; i++) {
        gate.onPose(now: t, phase: GatePhase.active, landmarks: low);
      }
      expect(
        fake.triggerReasons.where((r) => r == 'pose_anomaly').length,
        1,
      );

      // Additional low frames — no extra trigger
      gate.onPose(now: t, phase: GatePhase.active, landmarks: low);
      expect(
        fake.triggerReasons.where((r) => r == 'pose_anomaly').length,
        1,
      );
    });
  });

  group('pose_returned and blocked frame invariants', () {
    test('pose_returned fires before seeking-unconfirmed block', () {
      final fake = _FakePresenceSource()..personDetected = false;
      final gate = PresenceGate(detector: fake);
      final t = DateTime.fromMillisecondsSinceEpoch(0);

      // Establish a no-pose frame so _wasNoLandmarks = true
      gate.onNoPose(now: t, phase: GatePhase.seeking);
      fake.triggerReasons.clear();

      // Next frame has pose but person still unconfirmed → must fire pose_returned
      // before the searching block
      final verdict = gate.onPose(
        now: t,
        phase: GatePhase.seeking,
        landmarks: _allLandmarks(),
      );

      expect(fake.triggerReasons, contains('pose_returned'));
      expect(verdict.proceed, isFalse);
      expect(verdict.block, GateBlock.searching);
    });

    test('blocked frames do not feed the anomaly detector', () {
      final fake = _FakePresenceSource()..personDetected = false;
      final gate = PresenceGate(detector: fake);
      final landmarks = _allLandmarks(likelihood: 0.9);
      final t = DateTime.fromMillisecondsSinceEpoch(0);

      // 100 seeking-unconfirmed frames — all blocked; anomaly window never fills
      for (int i = 0; i < 100; i++) {
        gate.onPose(now: t, phase: GatePhase.seeking, landmarks: landmarks);
      }

      expect(fake.triggerReasons.any((r) => r == 'pose_anomaly'), isFalse);
    });

    test('active-paused frames do not feed the anomaly detector', () {
      final fake = _FakePresenceSource();
      final gate = PresenceGate(detector: fake);
      final t = DateTime.fromMillisecondsSinceEpoch(0);

      // Warm up anomaly window with high presence
      fake.personDetected = true;
      final high = _allLandmarks(likelihood: 0.9);
      for (int i = 0; i < 60; i++) {
        gate.onPose(now: t, phase: GatePhase.active, landmarks: high);
      }

      // Trigger auto-pause: seed _personLostSince at t=0, check at t=900ms
      fake.personDetected = false;
      gate.onNoPose(
          now: DateTime.fromMillisecondsSinceEpoch(0), phase: GatePhase.active);
      gate.onNoPose(
          now: DateTime.fromMillisecondsSinceEpoch(900),
          phase: GatePhase.active);
      expect(gate.isPaused, isTrue);
      fake.triggerReasons.removeWhere((r) => r == 'pose_anomaly');

      // Feed many low-presence frames while paused — they are blocked (active+paused)
      // so the anomaly detector must not accumulate them
      final low = _allLandmarks(likelihood: 0.2);
      for (int i = 0; i < 20; i++) {
        gate.onPose(now: t, phase: GatePhase.active, landmarks: low);
      }

      expect(fake.triggerReasons.any((r) => r == 'pose_anomaly'), isFalse);
    });
  });

  group('onActivated', () {
    test('onActivated calls useActivatedCadence', () {
      final fake = _FakePresenceSource();
      final gate = PresenceGate(detector: fake);

      gate.onActivated();

      expect(fake.useActivatedCadenceCalls, 1);
    });
  });

  group('close', () {
    test('close delegates to detector', () async {
      final fake = _FakePresenceSource();
      final gate = PresenceGate(detector: fake);

      await gate.close();

      expect(fake.closeCalls, 1);
    });
  });
}
