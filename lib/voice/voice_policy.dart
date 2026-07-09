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

  /// Escalates with how long a fault has persisted; a relief valve forces
  /// a near-certain cue past a persistence threshold. Used by
  /// [CueType.correct].
  correction,

  /// The bare hunger-scaled roll with no extra hard rules layered on top.
  /// Used by [CueType.instruction].
  base,

  /// Rolled, but perishable: [CueType.phase] drops rather than queues late
  /// if the sink is busy; [CueType.hustle] is additionally capped to one
  /// per set and only eligible on the final reps.
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
  });

  /// Sentinel meaning "no relief valve for this type" — a persistence/idle
  /// value this large is never reached in practice.
  static const int _noRelief = 1 << 30;

  final CueMode mode;

  /// Probability when hunger/persistence is zero.
  final double base;

  /// Added per unit of hunger (silence), or — for [CueType.correct] only —
  /// per unit of `ctx.faultPersistence`.
  final double step;

  /// Ceiling applied AFTER personality scaling.
  final double cap;

  /// Relief valve: once the cue's silence streak reaches this, it fires
  /// near-certainly instead of rolling. The streak source differs by type:
  /// [CueType.correct] reads `ctx.faultPersistence` (adapter-computed),
  /// [CueType.count] reads the policy-internal idle counter. Left at
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
}

/// Ship-day defaults (design doc decision D2): praise 35% base / +10 per
/// idle rep / capped at 85%; count anchors rep 1 then rolls ~70% on the
/// middles, saturating at 90% — never certainty — with a relief valve only
/// after 6 straight silent counts; correction escalates 25 → 55 → 85 by fault persistence with a
/// relief valve past 3 persisted reps; hustle a flat 50%, capped at 50;
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
  CueType.instruction: CueTuning(CueMode.base, base: 1.0),
  // cap 0.90, not 1.0: with cap 1.0 the hunger step made the roll CERTAIN
  // after just 2 silent counts — a learnable "quiet twice → next always
  // counts" rhythm (Nam heard it as alternating even numbers). Every middle
  // rep must stay a real draw; only the reliefAfter guard may force one,
  // and it is sized so it can't shape rhythm (see CueTuning.reliefAfter).
  CueType.count: CueTuning(
    CueMode.always,
    base: 0.70,
    step: 0.15,
    cap: 0.90,
    reliefAfter: 6,
  ),
  CueType.praise:
      CueTuning(CueMode.variableRatio, base: 0.35, step: 0.10, cap: 0.85),
  CueType.correct: CueTuning(
    CueMode.correction,
    base: 0.25,
    step: 0.30,
    cap: 0.85,
    reliefAfter: 4,
  ),
  CueType.hustle: CueTuning(CueMode.perishable, base: 0.50, cap: 0.50),
  CueType.phase: CueTuning(CueMode.perishable, base: 0.45, cap: 1.0),
};

double _clampD(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

/// The pure brain. See the library doc comment for the guide reference;
/// see below for the handful of interpretation calls this implementation
/// makes where the guide's prose and its illustrative code sketch diverge
/// (all flagged explicitly so a reviewer can revisit them):
///
/// - `correct`'s escalating probability reads `ctx.faultPersistence`
///   (adapter-computed, survives across silent reps) as the "idle" input
///   to [_p] — not the policy-internal per-key hunger counter. The prose
///   is explicit ("probability escalates with ctx.faultPersistence") and
///   this is the only way `reliefAfter` (also stated in terms of
///   `faultPersistence`) is comparable to the same value the escalation
///   uses. The internal hunger map is still updated for `correct`'s key on
///   every silent call (uniform `decide()` bookkeeping) but is not
///   consulted by `_correct` itself.
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
  })  : _rng = random ?? Random(),
        _clockMs = clockMs ?? _wallClockMs;

  final Random _rng;
  // Reserved for future latency-aware rules (e.g. cooldowns keyed on wall
  // time rather than rep count); no current rule reads it, but it's part
  // of the locked constructor shape ("injected Random + clock") and tests
  // rely on being able to inject a fake clock even before any rule reads it.
  final int Function() _clockMs;

  /// Current policy-clock time in epoch milliseconds — real wall clock in
  /// production, whatever the injected `clockMs` returns in tests.
  int get nowMs => _clockMs();

  /// Chattiness, 0.5 (quiet) .. 1.5 (chatty). v1 ships 1.0. Multiplies only
  /// `base + step·idle` inside [_p] — never `cap`, never a hard rule, never
  /// a relief valve.
  final double personality;

  final Map<CueType, CueTuning> tuning;

  static int _wallClockMs() => DateTime.now().millisecondsSinceEpoch;

  // --- per-set memory. beginSet() clears all of it. ----------------------

  /// Hunger: how many times in a row a given key was eligible but stayed
  /// silent. Keyed per-content for correct/instruction, per-type for
  /// everything else — see [_key]. This is the locked mechanism that keeps
  /// silence on one fault from raising the odds for another.
  final Map<String, int> _idle = {};

  int _lastPraiseRep = -2;
  int _lastOutcomeRep = -1;
  bool _hustledThisSet = false;

  /// Call at the start of every set: wipes hunger and all hard-rule memory.
  void beginSet() {
    _idle.clear();
    _lastPraiseRep = -2;
    _lastOutcomeRep = -1;
    _hustledThisSet = false;
  }

  /// The one entry point. Given a cue request, decide whether it speaks
  /// now, and update hunger/hard-rule memory accordingly.
  bool decide(CueType type, CueContext ctx) {
    final speak = _shouldSpeak(type, ctx);
    final key = _key(type, ctx);
    if (speak) {
      _onSpoke(type, ctx.repNumber, key);
    } else {
      _idle[key] = (_idle[key] ?? 0) + 1;
    }
    return speak;
  }

  /// The locked per-fault hunger key: correct/soft/instruction hunger is scoped
  /// to the specific fault/metric (`ctx.contentKey`) so staying silent
  /// about one fault never raises the odds for another; every other type
  /// collapses to a single per-set counter.
  String _key(CueType type, CueContext ctx) {
    return (type == CueType.correct ||
            type == CueType.soft ||
            type == CueType.instruction)
        ? '${type.name}:${ctx.contentKey}'
        : type.name;
  }

  void _onSpoke(CueType type, int repNumber, String key) {
    _idle[key] = 0;
    if (type == CueType.praise) _lastPraiseRep = repNumber;
    if (type == CueType.praise ||
        type == CueType.correct ||
        type == CueType.soft ||
        type == CueType.hustle) {
      _lastOutcomeRep = repNumber;
    }
    if (type == CueType.hustle) _hustledThisSet = true;
  }

  /// scale: `(base + step·idle) · personality`, clamped by `cap`. The
  /// heart of "hunger" — shared by every mode that rolls a die.
  double _p(CueTuning t, int idle) =>
      _clampD((t.base + t.step * idle) * personality, 0.0, t.cap);

  bool _shouldSpeak(CueType type, CueContext ctx) {
    switch (type) {
      case CueType.safety:
        return true; // Always, highest priority, bypasses hunger.
      case CueType.instruction:
        return _instruction(ctx);
      case CueType.count:
        return _count(ctx);
      case CueType.praise:
        return _praise(ctx);
      case CueType.correct:
        return _correct(ctx);
      case CueType.soft:
        return _soft(ctx);
      case CueType.hustle:
        return _hustle(ctx);
      case CueType.phase:
        return _phase(ctx);
    }
  }

  bool _instruction(CueContext ctx) {
    final t = tuning[CueType.instruction]!;
    final idle = _idle[_key(CueType.instruction, ctx)] ?? 0;
    return _rng.nextDouble() < _p(t, idle);
  }

  bool _count(CueContext ctx) {
    if (ctx.repNumber <= 1) return true; // Rep 1 always fires — the anchor.
    final t = tuning[CueType.count]!;
    final idle = _idle[_key(CueType.count, ctx)] ?? 0;
    if (idle >= t.reliefAfter) {
      // Relief valve — the ONLY deterministic path after rep 1. Exists
      // solely so a set can never go essentially uncounted; at 6 straight
      // silent counts it can't bind more than once in a typical set, so it
      // can't create a learnable rhythm. Deliberately consumes no roll,
      // like _correct's valve, so transcripts stay reproducible.
      return true;
    }
    return _rng.nextDouble() < _p(t, idle);
    // Count is not an outcome cue: it never reads/writes _lastOutcomeRep,
    // so it may freely co-occur with a praise/correct cue on the same rep.
  }

  bool _praise(CueContext ctx) {
    if (_lastPraiseRep == ctx.repNumber - 1) {
      return false; // Never twice in a row.
    }
    if (_lastOutcomeRep == ctx.repNumber) {
      return false; // At most one outcome cue per rep.
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
    return _rng.nextDouble() < scaled;
  }

  bool _correct(CueContext ctx) {
    if (_lastOutcomeRep == ctx.repNumber) {
      return false; // At most one outcome cue per rep.
    }
    final t = tuning[CueType.correct]!;
    if (t.firstOccurrenceCertain && ctx.faultPersistence == 0) {
      return true;
    }
    if (ctx.faultPersistence >= t.reliefAfter) {
      // Relief valve: never let a persistent, unaddressed fault go silent
      // forever. Near-certain and personality-immune by design.
      return true;
    }
    return _rng.nextDouble() < _p(t, ctx.faultPersistence);
  }

  bool _soft(CueContext ctx) {
    if (_lastOutcomeRep == ctx.repNumber) {
      return false; // At most one outcome cue per rep.
    }
    final t = tuning[CueType.soft];
    if (t == null) return false;
    final idle = _idle[_key(CueType.soft, ctx)] ?? 0;
    return _rng.nextDouble() < _p(t, idle);
  }

  bool _hustle(CueContext ctx) {
    if (_hustledThisSet) return false; // At most one per set.
    if (_lastOutcomeRep == ctx.repNumber) {
      return false; // At most one outcome cue per rep.
    }
    if (!ctx.isFinalReps) return false; // Only eligible on the final reps.
    final t = tuning[CueType.hustle]!;
    return _rng.nextDouble() < _p(t, 0);
  }

  bool _phase(CueContext ctx) {
    if (ctx.sinkBusy) return false; // Perishable: drop, don't queue late.
    if (ctx.repNumber <= 2) {
      return true; // Early reps teach the movement rhythm.
    }
    final t = tuning[CueType.phase]!;
    return _rng.nextDouble() < _p(t, 0);
  }
}
