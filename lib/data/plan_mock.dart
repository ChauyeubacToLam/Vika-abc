// Mock data for the Premium Ivory Plan screen, mirroring PHASE_WEEKS in the
// vika-main-app-ivory-v1.jsx prototype. All Vietnamese strings copied
// verbatim from the JSX. When the real backend lands, swap this for whatever
// service produces the same shape — the widgets only know about these models.

import 'package:flutter/foundation.dart';

/// Status for a single day cell in the week strip / done timeline.
enum DayStatus {
  done,
  rest,
  today,
  recheck,
  planned,
}

/// Status for a whole week — drives which layout WeekPage dispatches to.
enum WeekStatus {
  done,
  current,
  future,
}

/// Body region highlighted by BodyDiagram inside WeekFocusCard.
/// Only `hip` is used in this prototype; other values reserved for future
/// weeks (e.g. shoulder programs).
enum BodyRegion {
  none,
  hip,
}

@immutable
class PlanExercise {
  const PlanExercise({required this.name, required this.form});
  final String name;
  final int form;
}

@immutable
class PlanDay {
  const PlanDay({
    required this.weekday, // 'T2' / 'T3' / ... / 'CN'
    required this.date, // '21/4'
    required this.status,
    this.weekdayLong = '', // 'Thứ Hai' (only used in done timeline rows)
    this.title = '',
    this.duration = '',
    this.count = 0,
    this.form,
    this.coach,
    this.isBest = false,
    this.exercises = const [],
  });

  final String weekday;
  final String weekdayLong;
  final String date;
  final DayStatus status;
  final String title;
  final String duration;
  final int count;
  final int? form;
  final String? coach;
  final bool isBest;
  final List<PlanExercise> exercises;
}

@immutable
class PlanWeek {
  const PlanWeek({
    required this.num,
    required this.name,
    required this.dates,
    required this.status,
    required this.sessions,
    required this.completed,
    required this.bodyFocus,
    required this.focus,
    required this.days,
    this.body = BodyRegion.none,
    this.avgForm,
    this.recap,
    this.bestDay,
    this.coachLine,
    this.chapterLine,
    this.unlockNote,
  });

  final int num;
  final String name;
  final String dates;
  final WeekStatus status;
  final int sessions;
  final int completed;
  final String bodyFocus;
  final String focus;
  final BodyRegion body;
  final int? avgForm; // done weeks
  final String? recap; // done weeks
  final String? bestDay; // done weeks
  final String? coachLine; // current week
  final String? chapterLine; // future weeks
  final String? unlockNote; // future weeks
  final List<PlanDay> days;
}

/// Convenience: total counts across all weeks (for the page hero subtitle).
int planTotalSessions(List<PlanWeek> weeks) =>
    weeks.fold(0, (a, w) => a + w.sessions);

int planTotalCompleted(List<PlanWeek> weeks) =>
    weeks.fold(0, (a, w) => a + w.completed);

/// 4-week mock matching JSX exactly. Order: weeks 1+2 done, week 3 current,
/// week 4 future. Days within a week order T2 → CN.
const List<PlanWeek> phaseWeeksMock = [
  // ─── Week 1: Khởi đầu (done) ────────────────────────────────────────────
  PlanWeek(
    num: 1,
    name: 'Khởi đầu',
    dates: '21/4 – 27/4',
    status: WeekStatus.done,
    sessions: 3,
    completed: 3,
    bodyFocus: 'Làm quen',
    focus: 'Squat đến 90°',
    avgForm: 68,
    recap: 'Khởi đầu chuẩn. Squat cải thiện nhanh, '
        'cốt lõi cần thêm thời gian.',
    bestDay: 'T6',
    days: [
      PlanDay(
        weekday: 'T2',
        weekdayLong: 'Thứ Hai',
        date: '21/4',
        status: DayStatus.done,
        title: 'Toàn thân nhẹ',
        duration: '12 phút',
        count: 4,
        form: 64,
        coach: 'Plank fade sau rep 3 — cốt lõi cần thêm thời gian.',
        exercises: [
          PlanExercise(name: 'Squat', form: 72),
          PlanExercise(name: 'Push-up', form: 68),
          PlanExercise(name: 'Plank', form: 52),
          PlanExercise(name: 'Lunge', form: 64),
        ],
      ),
      PlanDay(weekday: 'T3', date: '22/4', status: DayStatus.rest),
      PlanDay(
        weekday: 'T4',
        weekdayLong: 'Thứ Tư',
        date: '23/4',
        status: DayStatus.done,
        title: 'Chân & Cốt lõi',
        duration: '14 phút',
        count: 4,
        form: 70,
        coach: 'Squat sâu hơn T2 4°. Glute bridge ổn định.',
        exercises: [
          PlanExercise(name: 'Squat', form: 76),
          PlanExercise(name: 'Glute bridge', form: 78),
          PlanExercise(name: 'Plank', form: 58),
          PlanExercise(name: 'Lunge', form: 68),
        ],
      ),
      PlanDay(weekday: 'T5', date: '24/4', status: DayStatus.rest),
      PlanDay(
        weekday: 'T6',
        weekdayLong: 'Thứ Sáu',
        date: '25/4',
        status: DayStatus.done,
        title: 'Toàn thân',
        duration: '15 phút',
        count: 4,
        form: 70,
        isBest: true,
        coach: 'Squat đạt 80% — đỉnh tuần. Cốt lõi đang lên đều.',
        exercises: [
          PlanExercise(name: 'Squat', form: 80),
          PlanExercise(name: 'Push-up', form: 72),
          PlanExercise(name: 'Plank', form: 62),
          PlanExercise(name: 'Curl-up', form: 66),
        ],
      ),
      PlanDay(weekday: 'T7', date: '26/4', status: DayStatus.rest),
      PlanDay(weekday: 'CN', date: '27/4', status: DayStatus.rest),
    ],
  ),

  // ─── Week 2: Củng cố (done) ─────────────────────────────────────────────
  PlanWeek(
    num: 2,
    name: 'Củng cố',
    dates: '28/4 – 4/5',
    status: WeekStatus.done,
    sessions: 3,
    completed: 3,
    bodyFocus: 'Cốt lõi',
    focus: 'Plank giữ 30s',
    avgForm: 74,
    recap: 'Tăng đều. Cốt lõi cuối cùng cũng lên — '
        'plank trên 70%.',
    bestDay: 'T4',
    days: [
      PlanDay(
        weekday: 'T2',
        weekdayLong: 'Thứ Hai',
        date: '28/4',
        status: DayStatus.done,
        title: 'Cốt lõi sâu',
        duration: '15 phút',
        count: 4,
        form: 72,
        coach: 'Plank lên 78% — tăng 26 điểm so với tuần 1.',
        exercises: [
          PlanExercise(name: 'Plank', form: 78),
          PlanExercise(name: 'Curl-up', form: 70),
          PlanExercise(name: 'Bird dog', form: 68),
          PlanExercise(name: 'Glute', form: 74),
        ],
      ),
      PlanDay(weekday: 'T3', date: '29/4', status: DayStatus.rest),
      PlanDay(
        weekday: 'T4',
        weekdayLong: 'Thứ Tư',
        date: '30/4',
        status: DayStatus.done,
        title: 'Chân & Mông',
        duration: '16 phút',
        count: 5,
        form: 78,
        isBest: true,
        coach: 'Glute bridge 84% — mạnh nhất. Squat depth chuẩn.',
        exercises: [
          PlanExercise(name: 'Squat', form: 82),
          PlanExercise(name: 'Lunge', form: 76),
          PlanExercise(name: 'Glute', form: 84),
          PlanExercise(name: 'Wall sit', form: 72),
          PlanExercise(name: 'Calf raise', form: 78),
        ],
      ),
      PlanDay(weekday: 'T5', date: '1/5', status: DayStatus.rest),
      PlanDay(
        weekday: 'T6',
        weekdayLong: 'Thứ Sáu',
        date: '2/5',
        status: DayStatus.done,
        title: 'Toàn thân',
        duration: '15 phút',
        count: 4,
        form: 73,
        coach: 'Đều và ổn. Plank giữ trên 70% rồi.',
        exercises: [
          PlanExercise(name: 'Squat', form: 78),
          PlanExercise(name: 'Push-up', form: 74),
          PlanExercise(name: 'Plank', form: 70),
          PlanExercise(name: 'Lunge', form: 72),
        ],
      ),
      PlanDay(weekday: 'T7', date: '3/5', status: DayStatus.rest),
      PlanDay(weekday: 'CN', date: '4/5', status: DayStatus.rest),
    ],
  ),

  // ─── Week 3: Đẩy mạnh (current) ─────────────────────────────────────────
  PlanWeek(
    num: 3,
    name: 'Đẩy mạnh',
    dates: '5/5 – 11/5',
    status: WeekStatus.current,
    sessions: 3,
    completed: 2,
    bodyFocus: 'Khớp háng',
    focus: 'Mở khớp · Glute',
    body: BodyRegion.hip,
    coachLine: 'Bốn tuần đã qua. Khớp háng giờ đáng được chú ý — '
        'squat sâu hơn 5cm bắt đầu từ đó.',
    days: [
      PlanDay(
        weekday: 'T2',
        date: '5/5',
        status: DayStatus.done,
        title: 'Toàn thân nhẹ',
        count: 4,
        form: 76,
      ),
      PlanDay(weekday: 'T3', date: '6/5', status: DayStatus.rest, title: 'Nghỉ'),
      PlanDay(
        weekday: 'T4',
        date: '7/5',
        status: DayStatus.done,
        title: 'Chân & Mông',
        count: 5,
        form: 82,
      ),
      PlanDay(weekday: 'T5', date: '8/5', status: DayStatus.rest, title: 'Nghỉ'),
      PlanDay(
        weekday: 'T6',
        date: '9/5',
        status: DayStatus.today,
        title: 'Toàn thân nhẹ',
        duration: '15 phút',
        count: 4,
      ),
      PlanDay(
        weekday: 'T7',
        date: '10/5',
        status: DayStatus.recheck,
        title: 'Đánh giá lại',
        count: 2,
      ),
      PlanDay(weekday: 'CN', date: '11/5', status: DayStatus.rest, title: 'Nghỉ'),
    ],
  ),

  // ─── Week 4: Đánh giá (future) ──────────────────────────────────────────
  PlanWeek(
    num: 4,
    name: 'Đánh giá',
    dates: '12/5 – 18/5',
    status: WeekStatus.future,
    sessions: 2,
    completed: 0,
    bodyFocus: 'Đo lại level',
    focus: 'Re-assessment',
    chapterLine: 'Đo lại mọi thứ. Lộ trình tuần kế '
        'sẽ định hình từ kết quả này.',
    unlockNote: 'Mở khoá sau khi Recheck T7 hoàn tất.',
    days: [
      PlanDay(weekday: 'T2', date: '12/5', status: DayStatus.rest, title: 'Nghỉ'),
      PlanDay(
        weekday: 'T3',
        date: '13/5',
        status: DayStatus.planned,
        title: 'Đánh giá nhẹ',
        count: 3,
      ),
      PlanDay(weekday: 'T4', date: '14/5', status: DayStatus.rest, title: 'Nghỉ'),
      PlanDay(weekday: 'T5', date: '15/5', status: DayStatus.rest, title: 'Nghỉ'),
      PlanDay(
        weekday: 'T6',
        date: '16/5',
        status: DayStatus.planned,
        title: 'Đánh giá đầy đủ',
        count: 4,
      ),
      PlanDay(weekday: 'T7', date: '17/5', status: DayStatus.rest, title: 'Nghỉ'),
      PlanDay(weekday: 'CN', date: '18/5', status: DayStatus.rest, title: 'Nghỉ'),
    ],
  ),
];
