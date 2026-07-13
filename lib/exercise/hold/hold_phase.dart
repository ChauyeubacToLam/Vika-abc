// ignore_for_file: non_constant_identifier_names

enum HoldPhase { setup, holding, dropping, resting, reArming }

// Compatibility names for the voice adapter. Their values come from the enum,
// so phase production and validation cannot drift onto different spellings.
final String REP_COUNTED_HOLD_PHASE_SETUP = HoldPhase.setup.name;
final String REP_COUNTED_HOLD_PHASE_HOLDING = HoldPhase.holding.name;
final String REP_COUNTED_HOLD_PHASE_DROPPING = HoldPhase.dropping.name;
final String REP_COUNTED_HOLD_PHASE_RESTING = HoldPhase.resting.name;
final String REP_COUNTED_HOLD_PHASE_RE_ARMING = HoldPhase.reArming.name;
final Set<String> REP_COUNTED_HOLD_PHASE_KEYS =
    Set<String>.unmodifiable(HoldPhase.values.map((phase) => phase.name));
