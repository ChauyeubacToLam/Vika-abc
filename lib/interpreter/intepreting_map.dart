class IssueDefinition {
  final int priority;
  final List<String> questions;

  // NEW fields from NASM table
  final List<String> overactive; // muscles to stretch/inhibit
  final List<String> underactive; // muscles to activate/strengthen
  final List<String> correctives; // exercise IDs for corrective program
  final String bodyRegion; // 'ankle', 'hip', 'core', 'shoulder'

  const IssueDefinition({
    required this.priority,
    required this.questions,
    this.overactive = const [],
    this.underactive = const [],
    this.correctives = const [],
    this.bodyRegion = '',
  });
}

final interpretingMap = {
  'ankle_mobility': IssueDefinition(
    priority: 0,
    questions: ['Bạn có hay bị đau mắt cá chân khi ngồi xổm không?'],
    overactive: ['soleus', 'gastrocnemius'],
    underactive: ['anterior_tibialis'],
    correctives: ['wall_calf_stretch', 'seated_toe_raise'],
    bodyRegion: 'ankle',
  ),
  'limited_mobility': IssueDefinition(
    priority: 1,
    questions: ['Bạn có cảm thấy khó ngồi xổm sâu không?'],
    overactive: [],
    underactive: [],
    correctives: ['bodyweight_squat_to_box', 'hip_flexor_stretch'],
    bodyRegion: 'hip',
  ),
  'ankle_mobility_restriction': IssueDefinition(
    priority: 0,
    questions: [
      'Bạn có cảm thấy bắp chân căng hoặc gót chân nhấc lên khi squat không? Đây là điều thường gặp ở người ngồi nhiều.',
    ],
    overactive: ['soleus', 'gastrocnemius', 'hip_flexor_complex'],
    underactive: ['anterior_tibialis', 'gluteus_maximus', 'erector_spinae'],
    correctives: [
      'wall_calf_stretch',
      'kneeling_hip_flexor_stretch',
      'floor_glute_bridge',
      'wall_squat'
    ],
    bodyRegion: 'ankle',
  ),
  'hip_flexor_overactivity': IssueDefinition(
    priority: 1,
    questions: [
      'Bạn có cảm thấy phải gập người về trước rất nhiều để squat sâu không? Điều này khá phổ biến khi ngồi nhiều giờ mỗi ngày.',
    ],
    overactive: ['hip_flexor_complex', 'abdominal_complex'],
    underactive: ['gluteus_maximus', 'erector_spinae', 'core_stabilizers'],
    correctives: [
      'kneeling_hip_flexor_stretch',
      'floor_glute_bridge',
      'bird_dog'
    ],
    bodyRegion: 'hip',
  ),
};
