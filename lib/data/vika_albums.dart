import 'package:flutter/material.dart';

import '../widgets/library/library_card.dart';

@immutable
class VikaAlbum {
  const VikaAlbum({
    required this.id,
    required this.vietnameseTitle,
    required this.vietnameseSubtitle,
    required this.level,
    required this.minutes,
    required this.icon,
    required this.exerciseIds,
  });

  final String id;
  final String vietnameseTitle;
  final String vietnameseSubtitle;
  final String level;
  final int minutes;
  final IconData icon;
  final List<String> exerciseIds;

  String get cardMeta => '${exerciseIds.length} bài · ~$minutes phút';

  LibraryCardData toCardData() {
    return LibraryCardData(
      kind: LibraryCardKind.album,
      title: vietnameseTitle,
      duration: '${exerciseIds.length} bài',
      detail: '~$minutes phút',
      hasAi: true,
      icon: icon,
      albumId: id,
      sequenceExerciseIds: exerciseIds,
      episodeMeta: cardMeta,
    );
  }
}

const List<VikaAlbum> vikaAlbums = [
  VikaAlbum(
    id: 'wake',
    vietnameseTitle: 'Tỉnh dậy cùng cơ thể',
    vietnameseSubtitle: 'Đánh thức cơ thể cho ngày mới.',
    level: 'Dễ',
    minutes: 6,
    icon: Icons.wb_twilight_rounded,
    exerciseIds: [
      'glute_bridge',
      'bird_dog',
      'jumping_jack',
      'high_plank',
    ],
  ),
  VikaAlbum(
    id: 'desk',
    vietnameseTitle: 'Reset bàn làm việc',
    vietnameseSubtitle: 'Nhanh giữa giờ, không cần thay đồ.',
    level: 'Dễ–TB',
    minutes: 5,
    icon: Icons.chair_rounded,
    exerciseIds: [
      'standing_knee_to_elbow',
      'jumping_jack',
      'squat',
      'lunge',
    ],
  ),
  VikaAlbum(
    id: 'evening',
    vietnameseTitle: 'Buông một ngày',
    vietnameseSubtitle: 'Giãn nhẹ để dễ vào giấc ngủ.',
    level: 'Người mới',
    minutes: 8,
    icon: Icons.nightlight_round,
    exerciseIds: [
      'seated_forward_fold',
      'butterfly',
      'sphinx',
      'cobra',
    ],
  ),
  VikaAlbum(
    id: 'core',
    vietnameseTitle: 'Cốt lõi vững',
    vietnameseSubtitle: 'Core kiểu McGill, an toàn cho lưng.',
    level: 'TB',
    minutes: 7,
    icon: Icons.center_focus_strong_rounded,
    exerciseIds: [
      'dead_bug',
      'bird_dog',
      'mcgill_curlup',
      'plank',
    ],
  ),
  VikaAlbum(
    id: 'legs',
    vietnameseTitle: 'Chân khỏe mông săn',
    vietnameseSubtitle: 'Nền tảng cho thân dưới.',
    level: 'TB',
    minutes: 8,
    icon: Icons.directions_walk_rounded,
    exerciseIds: [
      'squat',
      'lunge',
      'glute_bridge',
      'walking_lunge',
    ],
  ),
  VikaAlbum(
    id: 'upper',
    vietnameseTitle: 'Thân trên chắc',
    vietnameseSubtitle: 'Ngực, vai, tay sau.',
    level: 'TB',
    minutes: 7,
    icon: Icons.fitness_center_rounded,
    exerciseIds: [
      'push_up',
      'plank_up_down',
      'tricep_dip',
      'plank_shoulder_tap',
    ],
  ),
  VikaAlbum(
    id: 'energy',
    vietnameseTitle: 'Đốt năng lượng',
    vietnameseSubtitle: 'Tăng nhịp tim, đổ mồ hôi nhanh.',
    level: 'TB–Khó',
    minutes: 6,
    icon: Icons.bolt_rounded,
    exerciseIds: [
      'jumping_jack',
      'mountain_climber',
      'jump_squat',
      'step_back_burpee',
    ],
  ),
  VikaAlbum(
    id: 'back',
    vietnameseTitle: 'Lưng khỏe mỗi ngày',
    vietnameseSubtitle: 'Cho lưng sau giờ ngồi lâu.',
    level: 'Dễ–TB',
    minutes: 8,
    icon: Icons.healing_rounded,
    exerciseIds: [
      'bird_dog',
      'dead_bug',
      'glute_bridge',
      'superman',
      'sphinx',
    ],
  ),
  VikaAlbum(
    id: 'beginner',
    vietnameseTitle: 'Người mới bắt đầu',
    vietnameseSubtitle: 'Cơ bản, nhịp chậm, form đúng trước.',
    level: 'Dễ',
    minutes: 6,
    icon: Icons.flag_rounded,
    exerciseIds: [
      'glute_bridge',
      'wall_pushup',
      'squat',
      'high_plank',
      'dead_bug',
    ],
  ),
  VikaAlbum(
    id: 'mobility',
    vietnameseTitle: 'Linh hoạt & giãn cơ',
    vietnameseSubtitle: 'Mở hông, giãn gân kheo, thả cột sống.',
    level: 'Người mới–TB',
    minutes: 9,
    icon: Icons.self_improvement_rounded,
    exerciseIds: [
      'butterfly',
      'seated_forward_fold',
      'warrior_one',
      'sphinx',
      'cobra',
    ],
  ),
];

final List<LibraryCardData> vikaAlbumCards = [
  for (final album in vikaAlbums) album.toCardData(),
];

VikaAlbum? vikaAlbumById(String id) {
  for (final album in vikaAlbums) {
    if (album.id == id) return album;
  }
  return null;
}
