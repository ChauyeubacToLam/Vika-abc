/// Pure data layer for the voice-coach content catalog.
///
/// No I/O in this file — see `voice_sink.dart` for the file that actually
/// touches audio, and `voice_policy.dart` for the brain that decides *if* a
/// cue speaks. This file only answers "what exists to say" and "what does
/// this exercise's footprint look like."
///
/// Build spec: `docs/reference/voice-coach/implementation-guide.md` §3.
library;

/// What kind of cue is being spoken. Drives which cadence rule in
/// `VoicePolicy` applies (see `voice_policy.dart`).
enum CueType {
  /// The rep/hold counter ("Một", "Hai", ...). Not an "outcome" cue — it
  /// may co-occur with a [praise] or [criticalFault] cue on the same rep.
  count,

  /// Clean-rep acknowledgement ("Tốt lắm!"). Variable-ratio, never twice
  /// in a row, at most one outcome cue per rep.
  praise,

  /// A critical form fault (a fault whose `affectsForm` is true) — the
  /// real-time "fires immediately" cue. First occurrence in a rep is
  /// certain; persistence escalates. This IS what the behaviour spec calls
  /// "safety fires immediately": there is no separate injury cue, the
  /// critical fault is it.
  criticalFault,

  /// A non-critical measured fault (`affectsForm` false). Warmer than
  /// [criticalFault], still honest: the rep is not praised as clean, but the
  /// user gets a light nudge. Hunger + base probability, never
  /// first-occurrence-deterministic.
  softFault,

  /// Short feedforward line at the next rep-start edge after a live critical
  /// fault was seen in the previous rep. Outcome-class; same fault key as the
  /// correction path so it cannot double-speak inside that next rep.
  reminder,

  /// Deterministic structure copy: setup intro, ready, rest, set-complete.
  /// Always eligible to speak; the adapter latches each moment so it fires
  /// exactly once (behaviour spec hard-rule #2).
  setup,

  /// Sparse effort push. Arms on a stretched inter-rep gap, fires only at
  /// entry into the exercise's declared effort phase, and may pair with the
  /// one-remaining count anchor when the target proves it. Never mid-gap, and
  /// no per-set cap.
  hustle,

  /// Movement/phase cue (e.g. squat's "Xuống" / "Giữ" / "Đứng lên").
  /// Perishable — dropped rather than queued if the sink is already busy.
  phase,

  /// Life/safety line. Always speaks, bypasses hunger, highest priority.
  safety,
}

/// Everything the pure brain (`VoicePolicy`) is told about a cue request.
/// It carries no exercise semantics of its own — the adapter
/// (`PolicyVoiceCoach`) computes every field here from frame-to-frame
/// diffing so the policy itself stays exercise-agnostic.
class CueContext {
  const CueContext({
    required this.repNumber,
    this.isFinalReps = false,
    this.clean = true,
    this.formScore = 1.0,
    this.faultPersistence = 0,
    this.contentKey = '',
    this.sinkBusy = false,
  });

  /// 1-based rep (or hold-tick) number.
  final int repNumber;

  /// Whether this rep falls within the final stretch of the set — hustle
  /// eligibility. The adapter decides this from the exercise's target rep
  /// count.
  final bool isFinalReps;

  /// True when this rep had no fault at all.
  final bool clean;

  /// 0..1 rep quality score. 1.0 when the exercise doesn't expose one.
  /// Drives D8: a cleaner rep gets a higher praise chance and biases the
  /// resolver toward the bigger praise line.
  final double formScore;

  /// How many consecutive reps THIS fault (named by [contentKey]) has
  /// been present. 0 = first time seen this streak. Adapter-computed —
  /// the policy never tracks this itself.
  final int faultPersistence;

  /// The specific fault/metric id (for `criticalFault`/`softFault`/`reminder`/
  /// `setup`) — this is the hunger key, so staying silent about one fault never
  /// raises the odds for another.
  final String contentKey;

  /// True if the sink is already playing/queued. Perishable cues
  /// (`hustle`/`phase`) drop rather than queue up and arrive late.
  final bool sinkBusy;

  CueContext copyWith({
    int? repNumber,
    bool? isFinalReps,
    bool? clean,
    double? formScore,
    int? faultPersistence,
    String? contentKey,
    bool? sinkBusy,
  }) {
    return CueContext(
      repNumber: repNumber ?? this.repNumber,
      isFinalReps: isFinalReps ?? this.isFinalReps,
      clean: clean ?? this.clean,
      formScore: formScore ?? this.formScore,
      faultPersistence: faultPersistence ?? this.faultPersistence,
      contentKey: contentKey ?? this.contentKey,
      sinkBusy: sinkBusy ?? this.sinkBusy,
    );
  }
}

/// What to say. Resolution (which variation to pick, no-immediate-repeat,
/// and the D8 bias toward `praiseBig` on a high-quality rep) all live in
/// `VoiceCoach`, not here — this class is pure data.
class VoiceContent {
  const VoiceContent._(this.keys);

  /// One logical key. If [VoiceLib.variations] has an entry for this key,
  /// the coach picks one of its variations at random (never repeating the
  /// immediately-prior pick).
  factory VoiceContent.key(String logicalKey) => VoiceContent._([logicalKey]);

  /// Several logical keys to choose from at random (never repeating the
  /// immediately-prior pick).
  factory VoiceContent.pool(List<String> logicalKeys) =>
      VoiceContent._(logicalKeys);

  final List<String> keys;
}

/// A bundle of pools shared by a whole modality (rep-based vs time-based
/// exercises) so individual [VoiceScript]s don't retype them.
class ScriptBundle {
  const ScriptBundle({
    required this.count,
    required this.hustle,
    required this.praise,
  });

  final List<String> count;
  final List<String> hustle;
  final List<String> praise;
}

/// The one place repetitive lines live. Referenced by [VoiceScript]s and
/// [VoiceDefaults] — never retyped.
class VoiceLib {
  const VoiceLib._();

  // Universal (modality-independent) ------------------------------------

  static const List<String> praise = [
    'common.good_1',
    'common.good_2',
    'common.good_3',
  ];

  /// Standout reps (D8) — biased toward on a high `formScore`.
  static const List<String> praiseBig = [
    'common.great_1',
    'common.great_2',
  ];

  // Rep-based family ------------------------------------------------------

  /// Reuses today's already-recorded numeral count assets ('1'..'12' →
  /// common/count_1.mp3 etc., see `generic_exercise_voice_assets.dart`)
  /// rather than inventing a parallel `common.count.N` namespace that
  /// would need re-recording identical audio under new names.
  static const List<String> countReps = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
  ];

  static const List<String> hustleReps = [
    'common.one_more_rep',
    'common.push',
  ];

  // Time / hold family ------------------------------------------------------

  static const List<String> countTime = [
    'common.time.30s',
    'common.time.15s',
    'common.time.5s',
  ];

  static const List<String> hustleHold = [
    'common.hold_15s',
    'common.keep_going',
  ];

  /// key -> variations, for `VoiceContent.key`'s auto-variation lookup.
  /// Neither `common.good` nor `common.great` are ever sent to the sink
  /// directly — `VoiceCoach` always expands a key with registered
  /// variations to one of its pool members first.
  static const Map<String, List<String>> variations = {
    'common.good': praise,
    'common.great': praiseBig,
  };
}

/// Modality bundles (SAME FILE as `VoiceLib`, per the locked constraint).
class VoiceDefaults {
  const VoiceDefaults._();

  static const ScriptBundle repBased = ScriptBundle(
    count: VoiceLib.countReps,
    hustle: VoiceLib.hustleReps,
    praise: VoiceLib.praise,
  );

  static const ScriptBundle timeBased = ScriptBundle(
    count: VoiceLib.countTime,
    hustle: VoiceLib.hustleHold,
    praise: VoiceLib.praise,
  );
}

/// A per-exercise footprint: "which bundle + my faults [+ my phase cues]."
/// Built from a [ScriptBundle] via [VoiceScript.from]; any pool can be
/// overridden by name.
class VoiceScript {
  const VoiceScript({
    required this.slug,
    this.faultIds = const [],
    this.softCuePools = const {},
    this.reminderPools = const {},
    required this.praisePool,
    required this.hustlePool,
    this.hustleFinalPool = const [],
    required this.countPool,
    this.phaseCues = const {},
    this.repStartPhaseKeys = const {},
    this.effortPhaseKeys = const {},
  });

  factory VoiceScript.from(
    ScriptBundle bundle, {
    required String slug,
    List<String> faultIds = const [],
    Map<String, List<String>> softCuePools = const {},
    Map<String, List<String>> reminderPools = const {},
    List<String>? praisePool,
    List<String>? hustlePool,
    List<String>? hustleFinalPool,
    List<String>? countPool,
    Map<String, String> phaseCues = const {},
    Set<String> repStartPhaseKeys = const {},
    Set<String> effortPhaseKeys = const {},
  }) {
    return VoiceScript(
      slug: slug,
      faultIds: faultIds,
      softCuePools: softCuePools,
      reminderPools: reminderPools,
      praisePool: praisePool ?? bundle.praise,
      hustlePool: hustlePool ?? bundle.hustle,
      hustleFinalPool: hustleFinalPool ?? const [],
      countPool: countPool ?? bundle.count,
      phaseCues: phaseCues,
      repStartPhaseKeys: repStartPhaseKeys,
      effortPhaseKeys: effortPhaseKeys,
    );
  }

  final String slug;
  final List<String> faultIds;
  final Map<String, List<String>> softCuePools;
  final Map<String, List<String>> reminderPools;
  final List<String> praisePool;
  final List<String> hustlePool;
  final List<String> hustleFinalPool;
  final List<String> countPool;

  bool get hasSoftCues => softCuePools.isNotEmpty;

  List<String> softPoolFor(String id) => softCuePools[id] ?? const [];

  List<String> reminderPoolFor(String id) => reminderPools[id] ?? const [];

  /// phaseKey -> logical key. The squat/surya escape hatch for movement
  /// cues that aren't rep-outcome cues (e.g. "Xuống" / "Giữ" / "Đứng lên").
  final Map<String, String> phaseCues;

  /// Phase keys where a new rep attempt commits. Empty means this script never
  /// fires next-rep reminders.
  final Set<String> repStartPhaseKeys;

  /// Phase keys where the exercise's force phase is underway. Empty means
  /// this script never arms hustle.
  final Set<String> effortPhaseKeys;

  /// Unchanged from today's `GenericExerciseVoiceScript.faultKey` /
  /// `SquatVoiceCoach` fault-line convention: `<slug>.<faultId>`.
  String faultKey(String id) => '$slug.$id';

  /// Reminder convention: `<slug>.<faultId>_reminder`.
  String reminderKey(String id) => '$slug.${id}_reminder';

  /// The per-set intro pair (setup instruction) — same `<slug>.<id>` keys the
  /// legacy generic coach spoke, so they resolve to the already-recorded
  /// `glute_bridge.setup_position` / `glute_bridge.active_intro` assets.
  String get setupPositionKey => '$slug.setup_position';
  String get activeIntroKey => '$slug.active_intro';
}
