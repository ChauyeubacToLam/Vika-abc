/// The brain: pure and deterministic given its injected [Random] and clock.
/// No I/O, no knowledge of exercise semantics. This is where "not
/// predictive" (design doc decision D1) is actually built — hunger keeps an
/// average cadence without a learnable rhythm, hard rules stop back-to-back
/// chatter, and relief valves stop the coach from ever going fully silent.
///
/// Build spec: `docs/reference/voice-coach/implementation-guide.md` §4.
/// That section is explicitly "review/test this hardest" — see the class
/// doc comment on [VoicePolicy] for the interpretation calls made where the
/// guide's prose and its illustrative code sketch didn't fully agree.
library;

import 'dart:math';

import 'voice_content.dart' show CueContext, CueType;

/// How a [CueType] is gated in [VoicePolicy._shouldSpeak]. Names the shape
/// of the rule; the numbers live in [CueTuning].
enum CueMode {
  /// Never rolls a die: safety always speaks, bypassing hunger entirely.
  always,

  /// Base probability that climbs with hunger (silence), plus its own hard
  /// rules (never twice in a row; at most one outcome cue per rep). Used by
  /// [CueType.praise].
  variableRatio,

  /// Escalates with how long a fault/reminder streak has persisted; a relief
  /// valve may force a near-certain cue past a persistence threshold. Used by
  /// [CueType.criticalFault] and [CueType.reminder].
  correction,

  /// The bare hunger-scaled roll with no extra hard rules layered on top.
  /// Used by [CueType.setup].
  base,

  /// Rolled, but perishable: [CueType.phase] and [CueType.hustle] drop
  /// rather than queue late if the sink is busy.
  perishable,
}

/// Reference numbers for one [CueType]. [kDefaultTuning] is the fleet
/// default; pilot exercises may pass a local map while device-testing a
/// locked behavior shape.
class CueTuning {
  const CueTuning(
    this.mode, {
    this.base = 0.0,
    this.step = 0.0,
    this.cap = 1.0,
    this.reliefAfter = _noRelief,
    this.firstOccurrenceCertain = false,
    this.scalePraiseByFormScore = true,
    this.postFireIdlePenalty = 0,
  });

  /// Sentinel meaning "no relief valve for this type" — a persistence/idle
  /// value this large is never reached in practice.
  static const int _noRelief = 1 << 30;

  final CueMode mode;

  /// Probability when hunger/persistence is zero.
  final double base;

  /// Added per unit of hunger (silence), or — for [CueType.criticalFault] only —
  /// per unit of `ctx.faultPersistence`.
  final double step;

  /// Ceiling applied AFTER personality scaling.
  final double cap;

  /// Relief valve: once the cue's silence streak reaches this, it fires
  /// near-certainly instead of rolling. The streak source differs by type:
  /// [CueType.criticalFault] and [CueType.reminder] read
  /// `ctx.faultPersistence` (adapter-computed), [CueType.count] reads the
  /// policy-internal idle counter. Left at
  /// [_noRelief] for every other type, which has no relief valve.
  ///
  /// Sizing rule (Nam, 2026-07-08): a relief valve is a saturation guard,
  /// not a scheduler. Size it at the degenerate edge (the thing it exists
  /// to prevent — e.g. a whole set going by uncounted), never tight enough
  /// to bind on a typical set: a floor that binds every set is a metronome.
  final int reliefAfter;

  /// Opt-in correction hard rule: a fault's first appearance in a streak
  /// speaks with certainty. Default stays false so non-pilot exercises keep
  /// the current base-roll behaviour.
  final bool firstOccurrenceCertain;

  /// Legacy D8 praise scaling. Kept on by default to avoid changing other
  /// exercises while Glute Bridge removes the multiplier locally.
  final bool scalePraiseByFormScore;

  /// Optional stochastic backoff after a cue speaks. A value of 2 starts the
  /// next eligible roll two hunger steps below baseline, then normal silent
  /// attempts climb it back. This is deliberately not a fixed cooldown.
  final int postFireIdlePenalty;
}

/// Current fleet defaults: count is deterministic registration feedback; praise
/// is a 35% base / +10 per idle rep / capped at 85%; correction escalates
/// 25 → 55 → 85 by fault persistence with a relief valve past 3 persisted reps;
/// reminder is quieter and only speaks where an exercise declares rep-start
/// phase keys; hustle is adapter-armed, persistence-shaped, and may apply a
/// post-fire negative-hunger backoff when an exercise enables it;
/// phase anchors reps 1-2, then tapers to a flat rolled rate and still drops
/// if the sink is busy; safety unconditional; instruction a flat, always-on
/// base roll. Tune the numbers on device — the shape is what's locked, not
/// these values.
///
/// NOTE on `count`'s mode: the guide's own kDefaultTuning sketch tags
/// `CueType.count` with `CueMode.always` alongside safety, but its prose
/// (§4 "per-mode bodies") describes rep-1-always-then-~70%-rolled-after —
/// not unconditional. [VoicePolicy] dispatches by [CueType] rather than by
/// [CueMode] precisely to resolve that: safety is truly unconditional,
/// count is an anchored roll. `mode` is kept as documentation/intent, not
/// as the dispatch key.
const Map<CueType, CueTuning> kDefaultTuning = {
  CueType.safety: CueTuning(CueMode.always),
  CueType.setup: CueTuning(CueMode.base, base: 1.0),
  // COUNT = REGISTRATION (re-ruled 07-11, decisions.md "Count = registration"):
  // every landed rep is counted, deterministically and personality-immune —
  // the spoken number is the user's only proof the rep registered (they don't
  // watch the screen). Supersedes both prior thinning shapes (07-07
  // cap-0.90/relief-6 and the 07-08 pilot 0.50/+0.10). base 1.0 short-circuits
  // the roll in _count; re-thinning an exercise means an explicit base < 1.0.
  CueType.count: CueTuning(CueMode.always, base: 1.0),
  CueType.praise:
      CueTuning(CueMode.variableRatio, base: 0.35, step: 0.10, cap: 0.85),
  CueType.criticalFault: CueTuning(
    CueMode.correction,
    base: 0.25,
    step: 0.30,
    cap: 0.85,
    reliefAfter: 4,
  ),
  CueType.reminder:
      CueTuning(CueMode.correction, base: 0.20, step: 0.10, cap: 0.50),
  CueType.hustle: CueTuning(
    CueMode.perishable,
    base: 0.50,
    cap: 0.50,
    postFireIdlePenalty: 2,
  ),
  CueType.phase: CueTuning(CueMode.perishable, base: 0.45, cap: 1.0),
};

double _clampD(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

/// The pure brain. See the library doc comment for the guide reference;
/// see below for the handful of interpretation calls this implementation
/// makes where the guide's prose and its illustrative code sketch diverge
/// (all flagged explicitly so a reviewer can revisit them):
///
/// - `correct`/`reminder` escalating probability reads `ctx.faultPersistence`
///   (adapter-computed, survives across silent reps) as the "idle" input
///   to [_p] — not the policy-internal per-key hunger counter. The prose
///   is explicit ("probability escalates with ctx.faultPersistence") and
///   this is the only way `reliefAfter` (also stated in terms of
///   `faultPersistence`) is comparable to the same value the escalation
///   uses. The internal hunger map is still updated for `correct`/`reminder`
///   keys on every silent call (uniform `decide()` bookkeeping) but is not
///   consulted by those correction-shaped bodies.
/// - `CueMode.base` (instruction) has no described behaviour in the
///   guide's per-mode bullet list. Interpreted as the bare `_p` roll using
///   the policy-internal per-content hunger, no extra hard rules — the
///   plainest reading of "base" as "no bells and whistles beyond the
///   hunger formula" other modes layer on top of.
class VoicePolicy {
  VoicePolicy({
    Random? random,
    int Function()? clockMs,
    this.personality = 1.0,
    this.tuning = kDefaultTuning,
    this.outcomeCollisionGapMs = 500,
    this.maxOutcomeCuesPerRep = 2,
  })  : _rng = random ?? Random(),
        _clockMs = clockMs ?? _wallClockMs;

  final Random _rng;
  final int Function() _clockMs;

  /// Current policy-clock time in epoch milliseconds — real wall clock in
  /// production, whatever the injected `clockMs` returns in tests.
  int get nowMs => _clockMs();

  /// Chattiness, 0.5 (quiet) .. 1.5 (chatty). v1 ships 1.0. Multiplies only
  /// `base + step·idle` inside [_p] — never `cap`, never a hard rule, never
  /// a relief valve.
  final double personality;

  final Map<CueType, CueTuning> tuning;

  /// Minimum silence (ms) after the previous outcome cue's audio ended before
  /// another outcome may start — the system's only time cooldown, measured
  /// from audio end so long lines can't chain. Policy-level: every exercise
  /// inherits this one default, it is NOT tuned per exercise (Nam 2026-07-09).
  /// Tests may inject their own for determinism.
  final int outcomeCollisionGapMs;

  /// Saturation cap for outcome cues in a single rep (the per-MOMENT rule's
  /// hard ceiling; the 2nd slot is criticalFault-only). Policy-level default —
  /// one place to tune, inherited by every exercise (Nam 2026-07-09).
  final int maxOutcomeCuesPerRep;

  static int _wallClockMs() => DateTime.now().millisecondsSinceEpoch;

  // --- per-set memory. beginSet() clears all of it. ----------------------

  /// Hunger: how many times in a row a given key was eligible but stayed
  /// silent. Keyed per-content for correct/soft/reminder/setup, per-type for
  /// everything else — see [_key]. This is the locked mechanism that keeps
  /// silence on one fault from raising the odds for another.
  final Map<String, int> _idle = {};

  int _lastPraiseRep = -2;
  int? _lastOutcomeAudioEndMs;
  bool _outcomeAudioPending = false;
  int _outcomeRepNumber = -1;
  int _outcomesThisRep = 0;
  final Set<String> _outcomeFaultKeysThisRep = <String>{};

  int? get lastOutcomeAudioEndMs => _lastOutcomeAudioEndMs;

  /// WHY the most recent [decide] said yes/no — set by every decision body,
  /// read by `VoiceCoach.say`'s device log so a transcript explains itself
  /// (anchor vs roll vs gap vs cap). Debug observability only: never read by
  /// any decision logic, so the policy stays pure.
  String lastReason = '';

  /// Roll helper that also records the reason string. [tag] names the cue
  /// body, [extra] carries body-specific context (idle/persistence).
  bool _rollWithReason(String tag, double p, {String extra = ''}) {
    final hit = _rng.nextDouble() < p;
    lastReason = '$tag p=${p.toStringAsFixed(2)}$extra ${hit ? 'HIT' : 'miss'}';
    return hit;
  }

  /// Call at the start of every set: wipes hunger and all hard-rule memory.
  void beginSet() {
    _idle.clear();
    _lastPraiseRep = -2;
    _lastOutcomeAudioEndMs = null;
    _outcomeAudioPending = false;
    _outcomeRepNumber = -1;
    _outcomesThisRep = 0;
    _outcomeFaultKeysThisRep.clear();
  }

  /// Called by [VoiceCoach] when the sink reports that the accepted outcome
  /// cue's audio has finished. This is the clock edge used by the collision
  /// gap, deliberately measured from audio end rather than trigger time.
  void markOutcomeAudioEnded([int? endedMs]) {
    _outcomeAudioPending = false;
    _lastOutcomeAudioEndMs = endedMs ?? nowMs;
  }

  /// The one entry point. Given a cue request, decide whether it speaks
  /// now, and update hunger/hard-rule memory accordingly.
  bool decide(CueType type, CueContext ctx) {
    final speak = _shouldSpeak(type, ctx);
    final key = _key(type, ctx);
    if (speak) {
      _onSpoke(type, ctx, key);
    } else {
      _idle[key] = (_idle[key] ?? 0) + 1;
    }
    return speak;
  }

  /// The locked per-fault hunger key: correct/soft/reminder/setup hunger is
  /// scoped to the specific fault/metric (`ctx.contentKey`) so staying silent
  /// about one fault never raises the odds for another; every other type
  /// collapses to a single per-set counter.
  String _key(CueType type, CueContext ctx) {
    return (type == CueType.criticalFault ||
            type == CueType.softFault ||
            type == CueType.reminder ||
            type == CueType.setup)
        ? '${type.name}:${ctx.contentKey}'
        : type.name;
  }

  void _onSpoke(CueType type, CueContext ctx, String key) {
    final postFireIdlePenalty = tuning[type]?.postFireIdlePenalty ?? 0;
    _idle[key] = postFireIdlePenalty > 0 ? -postFireIdlePenalty : 0;
    if (type == CueType.praise) _lastPraiseRep = ctx.repNumber;
    if (_isOutcomeCue(type)) {
      _recordOutcome(type, ctx);
    }
  }

  bool _isOutcomeCue(CueType type) {
    return type == CueType.praise ||
        type == CueType.criticalFault ||
        type == CueType.softFault ||
        type == CueType.reminder ||
        type == CueType.hustle;
  }

  void _recordOutcome(CueType type, CueContext ctx) {
    _syncOutcomeRep(ctx.repNumber);
    _outcomesThisRep++;
    _outcomeAudioPending = true;
    if ((type == CueType.criticalFault ||
            type == CueType.softFault ||
            type == CueType.reminder) &&
        ctx.contentKey.isNotEmpty) {
      _outcomeFaultKeysThisRep.add(ctx.contentKey);
    }
  }

  void _syncOutcomeRep(int repNumber) {
    if (_outcomeRepNumber == repNumber) return;
    _outcomeRepNumber = repNumber;
    _outcomesThisRep = 0;
    _outcomeFaultKeysThisRep.clear();
  }

  bool _canStartOutcome(CueType type, CueContext ctx) {
    _syncOutcomeRep(ctx.repNumber);

    if (_outcomeAudioPending) {
      lastReason = 'outcome-audio-still-playing';
      return false;
    }

    final lastEnd = _lastOutcomeAudioEndMs;
    if (lastEnd != null && nowMs < lastEnd + outcomeCollisionGapMs) {
      lastReason =
          'collision-gap (${lastEnd + outcomeCollisionGapMs - nowMs}ms left)';
      return false;
    }

    if (_outcomesThisRep == 0) {
      return true;
    }

    if (type != CueType.criticalFault) {
      lastReason = 'second-outcome-slot-is-critical-only';
      return false;
    }
    if (_outcomesThisRep >= maxOutcomeCuesPerRep) {
      lastReason = 'outcome-cap-$maxOutcomeCuesPerRep-reached-this-rep';
      return false;
    }

    final contentKey = ctx.contentKey;
    if (contentKey.isEmpty || _outcomeFaultKeysThisRep.contains(contentKey)) {
      lastReason = 'same-fault-already-voiced-this-rep';
      return false;
    }

    return true;
  }

  /// scale: `(base + step·idle) · personality`, clamped by `cap`. The
  /// heart of "hunger" — shared by every mode that rolls a die. `idle` may be
  /// negative for post-fire stochastic backoff.
  double _p(CueTuning t, int idle) =>
      _clampD((t.base + t.step * idle) * personality, 0.0, t.cap);

  bool _shouldSpeak(CueType type, CueContext ctx) {
    switch (type) {
      case CueType.safety:
        lastReason = 'safety-always';
        return true; // Always, highest priority, bypasses hunger.
      case CueType.setup:
        return _setup(ctx);
      case CueType.count:
        return _count(ctx);
      case CueType.praise:
        return _praise(ctx);
      case CueType.criticalFault:
        return _criticalFault(ctx);
      case CueType.softFault:
        return _softFault(ctx);
      case CueType.reminder:
        return _reminder(ctx);
      case CueType.hustle:
        return _hustle(ctx);
      case CueType.phase:
        return _phase(ctx);
    }
  }

  bool _setup(CueContext ctx) {
    final t = tuning[CueType.setup]!;
    final idle = _idle[_key(CueType.setup, ctx)] ?? 0;
    // PERSONALITY-IMMUNE (hard rule 2): setup cues are structural — intro /
    // activation countdown / ready / set-complete fire exactly once at their
    // moment, always. A quiet coach (personality 0.5) must not coin-flip the
    // setup intro, so the scalar is deliberately left out of this one body;
    // tests still silence the channel by zeroing base/cap.
    final p = _clampD(t.base + t.step * idle, 0.0, t.cap);
    // At the saturated base 1.0 the roll is a foregone conclusion.
    // Short-circuit it so a deterministic cue never spends a draw from the
    // shared RNG — that keeps the stochastic cadence of the probabilistic
    // cues (and every scripted-random test) reproducible.
    if (p >= 1.0) {
      lastReason = 'setup-deterministic';
      return true;
    }
    return _rollWithReason('setup-roll', p);
  }

  bool _count(CueContext ctx) {
    if (ctx.repNumber <= 1) {
      lastReason = 'count-rep1-anchor';
      return true; // Rep 1 always fires — the anchor.
    }
    if (ctx.isFinalReps) {
      lastReason = 'count-final-anchor';
      return true; // Finish anchor: last 2 reps always.
    }
    final t = tuning[CueType.count]!;
    final idle = _idle[_key(CueType.count, ctx)] ?? 0;
    if (idle >= t.reliefAfter) {
      lastReason = 'count-relief-valve';
      return true;
    }
    // REGISTRATION, not chatter (re-ruled 07-11): users don't watch the
    // screen, so the spoken number is the only proof a rep landed — a silent
    // rep is ambiguous between "counted but quiet" and "didn't register".
    // The fleet default is therefore base 1.0 (every landed rep is counted)
    // and the computation is PERSONALITY-IMMUNE like _setup — a quiet coach
    // must not thin the trust signal. The roll machinery below survives only
    // for explicit re-thinning configs (base < 1.0), e.g. tests.
    final p = _clampD(t.base + t.step * idle, 0.0, t.cap);
    if (p >= 1.0) {
      lastReason = 'count-registration-deterministic';
      return true;
    }
    return _rollWithReason('count-roll', p, extra: ' idle=$idle');
    // Count is not an outcome cue: it never reads/writes _lastOutcomeRep,
    // so it may freely co-occur with a praise/correct cue on the same rep.
  }

  bool _praise(CueContext ctx) {
    if (_lastPraiseRep == ctx.repNumber - 1) {
      lastReason = 'praise-never-twice-in-a-row';
      return false; // Never twice in a row.
    }
    if (!_canStartOutcome(CueType.praise, ctx)) {
      return false;
    }
    final t = tuning[CueType.praise]!;
    final idle = _idle[_key(CueType.praise, ctx)] ?? 0;
    final roll = _p(t, idle);
    final scaled = t.scalePraiseByFormScore
        ? _clampD(
            roll * (0.6 + 0.4 * _clampD(ctx.formScore, 0.0, 1.0)),
            0.0,
            t.cap,
          )
        : roll;
    return _rollWithReason('praise-roll', scaled, extra: ' idle=$idle');
  }

  bool _criticalFault(CueContext ctx) {
    if (!_canStartOutcome(CueType.criticalFault, ctx)) {
      return false;
    }
    final t = tuning[CueType.criticalFault]!;
    if (t.firstOccurrenceCertain && ctx.faultPersistence == 0) {
      lastReason = 'critical-first-occurrence-certain';
      return true;
    }
    if (ctx.faultPersistence >= t.reliefAfter) {
      // Relief valve: never let a persistent, unaddressed fault go silent
      // forever. Near-certain and personality-immune by design.
      lastReason = 'critical-persistence-relief-valve';
      return true;
    }
    return _rollWithReason(
      'critical-roll',
      _p(t, ctx.faultPersistence),
      extra: ' persist=${ctx.faultPersistence}',
    );
  }

  bool _softFault(CueContext ctx) {
    if (!_canStartOutcome(CueType.softFault, ctx)) {
      return false;
    }
    final t = tuning[CueType.softFault];
    if (t == null) {
      lastReason = 'soft-no-tuning-configured';
      return false;
    }
    final idle = _idle[_key(CueType.softFault, ctx)] ?? 0;
    return _rollWithReason('soft-roll', _p(t, idle), extra: ' idle=$idle');
  }

  bool _reminder(CueContext ctx) {
    if (!_canStartOutcome(CueType.reminder, ctx)) {
      return false;
    }
    final t = tuning[CueType.reminder]!;
    if (t.firstOccurrenceCertain && ctx.faultPersistence == 0) {
      lastReason = 'reminder-streak-first-deterministic';
      return true;
    }
    if (ctx.faultPersistence >= t.reliefAfter) {
      lastReason = 'reminder-persistence-relief-valve';
      return true;
    }
    return _rollWithReason(
      'reminder-roll',
      _p(t, ctx.faultPersistence),
      extra: ' streak=${ctx.faultPersistence}',
    );
  }

  bool _hustle(CueContext ctx) {
    if (!_canStartOutcome(CueType.hustle, ctx)) {
      return false;
    }
    if (ctx.sinkBusy) {
      lastReason = 'hustle-perishable-sink-busy';
      return false; // Perishable: drop, don't queue late.
    }
    final t = tuning[CueType.hustle]!;
    final idle = _idle[_key(CueType.hustle, ctx)] ?? 0;
    return _rollWithReason('hustle-roll', _p(t, idle), extra: ' idle=$idle');
  }

  bool _phase(CueContext ctx) {
    if (ctx.sinkBusy) {
      lastReason = 'phase-perishable-sink-busy';
      return false; // Perishable: drop, don't queue late.
    }
    if (ctx.repNumber <= 2) {
      lastReason = 'phase-early-rep-anchor';
      return true; // Early reps teach the movement rhythm.
    }
    final t = tuning[CueType.phase]!;
    return _rollWithReason('phase-roll', _p(t, 0));
  }
}
