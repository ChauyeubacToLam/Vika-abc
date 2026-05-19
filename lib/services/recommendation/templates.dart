import 'models/slot.dart';
import 'models/template.dart';

const _foundationPhaseNames = ['Nền tảng', 'Phát triển'];
const _deloadName = 'Phục hồi';

const _homeBaseSlots = [
  Slot(
    name: 'lower_body_strength',
    acceptedBodyRegions: ['lower_body', 'full_body'],
    acceptedMuscleGroups: ['quads', 'glutes', 'hamstrings'],
    difficultyRange: (min: 1, max: 3),
  ),
  Slot(
    name: 'upper_body_push',
    acceptedBodyRegions: ['upper_body', 'full_body'],
    acceptedMuscleGroups: ['chest', 'shoulders', 'triceps'],
    difficultyRange: (min: 1, max: 3),
  ),
  Slot(
    name: 'core_stability',
    acceptedBodyRegions: ['core', 'full_body'],
    acceptedMuscleGroups: ['core', 'abs', 'obliques'],
    difficultyRange: (min: 1, max: 3),
  ),
  Slot(
    name: 'posterior_chain',
    acceptedBodyRegions: ['lower_body', 'core', 'full_body'],
    acceptedMuscleGroups: ['glutes', 'hamstrings', 'lower_back', 'core'],
    difficultyRange: (min: 1, max: 3),
  ),
];

const _yogaBaseSlots = [
  Slot(
    name: 'standing_foundation',
    acceptedBodyRegions: ['lower_body', 'full_body'],
    acceptedMuscleGroups: ['quads', 'glutes', 'hips'],
    difficultyRange: (min: 1, max: 3),
  ),
  Slot(
    name: 'spine_mobility',
    acceptedBodyRegions: ['core', 'upper_body', 'full_body'],
    acceptedMuscleGroups: ['spine', 'back', 'core'],
    difficultyRange: (min: 1, max: 3),
  ),
  Slot(
    name: 'hip_mobility',
    acceptedBodyRegions: ['lower_body', 'core', 'full_body'],
    acceptedMuscleGroups: ['hips', 'hamstrings', 'glutes'],
    difficultyRange: (min: 1, max: 3),
  ),
  Slot(
    name: 'breath_core',
    acceptedBodyRegions: ['core', 'full_body'],
    acceptedMuscleGroups: ['core', 'back', 'shoulders'],
    difficultyRange: (min: 1, max: 3),
  ),
];

const launchTemplates = <String, Template>{
  'home_health': Template(
    key: 'home_health',
    fork: 'home',
    goal: 'health',
    vietnameseName: 'Tập tại nhà - Khỏe hơn',
    slots: _homeBaseSlots,
    phaseNames: _foundationPhaseNames,
    deloadName: _deloadName,
    numPhases: 2,
    weeksPerPhase: 3,
    includeDeloadAtEnd: true,
    defaultRestSecondsRep: 60,
    defaultRestSecondsHold: 35,
  ),
  'home_body': Template(
    key: 'home_body',
    fork: 'home',
    goal: 'body',
    vietnameseName: 'Tập tại nhà - Gọn dáng',
    slots: _homeBaseSlots,
    phaseNames: _foundationPhaseNames,
    deloadName: _deloadName,
    numPhases: 2,
    weeksPerPhase: 3,
    includeDeloadAtEnd: true,
    defaultRestSecondsRep: 55,
    defaultRestSecondsHold: 30,
  ),
  'home_strength': Template(
    key: 'home_strength',
    fork: 'home',
    goal: 'strength',
    vietnameseName: 'Tập tại nhà - Mạnh hơn',
    slots: _homeBaseSlots,
    phaseNames: _foundationPhaseNames,
    deloadName: _deloadName,
    numPhases: 2,
    weeksPerPhase: 3,
    includeDeloadAtEnd: true,
    defaultRestSecondsRep: 75,
    defaultRestSecondsHold: 45,
  ),
  'home_flexible': Template(
    key: 'home_flexible',
    fork: 'home',
    goal: 'flexible',
    vietnameseName: 'Tập tại nhà - Linh hoạt hơn',
    slots: _homeBaseSlots,
    phaseNames: _foundationPhaseNames,
    deloadName: _deloadName,
    numPhases: 2,
    weeksPerPhase: 3,
    includeDeloadAtEnd: true,
    defaultRestSecondsRep: 60,
    defaultRestSecondsHold: 35,
  ),
  'yoga_health': Template(
    key: 'yoga_health',
    fork: 'yoga',
    goal: 'health',
    vietnameseName: 'Yoga - Khỏe hơn',
    slots: _yogaBaseSlots,
    phaseNames: _foundationPhaseNames,
    deloadName: _deloadName,
    numPhases: 2,
    weeksPerPhase: 3,
    includeDeloadAtEnd: true,
    defaultRestSecondsRep: 60,
    defaultRestSecondsHold: 30,
  ),
  'yoga_body': Template(
    key: 'yoga_body',
    fork: 'yoga',
    goal: 'body',
    vietnameseName: 'Yoga - Gọn dáng',
    slots: _yogaBaseSlots,
    phaseNames: _foundationPhaseNames,
    deloadName: _deloadName,
    numPhases: 2,
    weeksPerPhase: 3,
    includeDeloadAtEnd: true,
    defaultRestSecondsRep: 55,
    defaultRestSecondsHold: 30,
  ),
  'yoga_strength': Template(
    key: 'yoga_strength',
    fork: 'yoga',
    goal: 'strength',
    vietnameseName: 'Yoga - Mạnh và vững',
    slots: _yogaBaseSlots,
    phaseNames: _foundationPhaseNames,
    deloadName: _deloadName,
    numPhases: 2,
    weeksPerPhase: 3,
    includeDeloadAtEnd: true,
    defaultRestSecondsRep: 70,
    defaultRestSecondsHold: 45,
  ),
  'yoga_flexible': Template(
    key: 'yoga_flexible',
    fork: 'yoga',
    goal: 'flexible',
    vietnameseName: 'Yoga - Linh hoạt hơn',
    slots: _yogaBaseSlots,
    phaseNames: _foundationPhaseNames,
    deloadName: _deloadName,
    numPhases: 2,
    weeksPerPhase: 3,
    includeDeloadAtEnd: true,
    defaultRestSecondsRep: 55,
    defaultRestSecondsHold: 25,
  ),
};

Template templateFor({
  required String? fork,
  required String? goal,
}) {
  final normalizedFork = switch (fork) {
    'yoga' => 'yoga',
    _ => 'home',
  };
  final normalizedGoal = switch (goal) {
    'body' => 'body',
    'strength' => 'strength',
    'flexible' => 'flexible',
    _ => 'health',
  };

  return launchTemplates['${normalizedFork}_$normalizedGoal'] ??
      launchTemplates['home_health']!;
}
