import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vika/screens/onboarding/onboarding_data.dart';
import 'package:vika/screens/onboarding/v5/screens/s01_welcome.dart';
import 'package:vika/screens/onboarding/v5/screens/s02_mirror.dart';
import 'package:vika/screens/onboarding/v5/screens/s03_barrier.dart';
import 'package:vika/screens/onboarding/v5/screens/s03_goal.dart';
import 'package:vika/screens/onboarding/v5/screens/s04_pain_check.dart';
import 'package:vika/screens/onboarding/v5/screens/s04_resolution.dart';
import 'package:vika/screens/onboarding/v5/screens/s05_fork.dart';
import 'package:vika/screens/onboarding/v5/screens/s06_trust.dart';
import 'package:vika/screens/onboarding/v5/screens/s07_assessment_intro.dart';
import 'package:vika/screens/onboarding/v5/screens/s08_analyzing.dart';
import 'package:vika/screens/onboarding/v5/screens/s09_phase1.dart';
import 'package:vika/screens/onboarding/v5/screens/s10_level_issue.dart';
import 'package:vika/screens/onboarding/v5/screens/s11_body_info.dart';
import 'package:vika/screens/onboarding/v5/screens/s12_schedule.dart';
import 'package:vika/screens/onboarding/v5/screens/s13_signup.dart';
import 'package:vika/screens/onboarding/v5/screens/s15_journey.dart';
import 'package:vika/screens/onboarding/v5/screens/s16_closer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://frjtlfzbvdgwgzegfzxh.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJpc3MiOiJmcmp0bGZ6YnZkZ3dnemVnZnp4aCIsInJlZiI6ImZy'
          'anRsZnpidmRnd2d6ZWdmenhoIiwicm9sZSI6ImFub24iLCJpYXQi'
          'OjE3NzU4Mjk2NjUsImV4cCI6MjA5MTQwNTY2NX0.'
          'Eprv5NtWbZqigYPZdOEeRIyvYVxp0l2hmbXXyEdh8nI',
    );
  });

  final sizes = <Size>[
    const Size(390, 844),
    const Size(375, 667),
    const Size(320, 568),
  ];

  for (final size in sizes) {
    testWidgets('v5 onboarding screens fit at ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final screen in _screens()) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: screen),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1600));

        final exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: '${screen.runtimeType} overflowed at $size',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1600));
    });
  }
}

List<Widget> _screens() {
  final data = OnboardingData()
    ..problemResonance = ['form_uncertainty']
    ..goal = 'health'
    ..duration = '<6m'
    ..painAreas = ['back']
    ..fork = 'yoga'
    ..level = 'beginner'
    ..age = 30
    ..gender = 'male'
    ..heightCm = 170
    ..weightKg = 65
    ..scheduleSessions = ['T2_afternoon', 'T4_afternoon', 'T6_afternoon'];

  void noop() {}

  return [
    S01Welcome(onNext: noop),
    S02Mirror(data: data, onNext: noop, onBack: noop),
    S03Barrier(onNext: noop, onBack: noop),
    S04Resolution(onNext: noop, onBack: noop),
    S03Goal(data: data, onNext: noop, onBack: noop),
    S04PainCheck(data: data, onNext: noop, onBack: noop),
    S05Fork(data: data, onNext: noop, onBack: noop),
    S06Trust(onNext: noop, onBack: noop),
    S07AssessmentIntro(data: data, onNext: noop, onSkip: noop, onBack: noop),
    S08Analyzing(data: data, active: false, onNext: noop, onBack: noop),
    S09Phase1(data: data, onNext: noop, onBack: noop),
    S10LevelIssue(data: data, onNext: noop, onBack: noop),
    S11BodyInfo(data: data, onNext: noop, onBack: noop),
    S12Schedule(data: data, onNext: noop, onBack: noop),
    S13Signup(data: data, onNext: noop, onBack: noop),
    S15Journey(data: data, onNext: noop, onBack: noop),
    S16Closer(data: data, onComplete: () async {}, onBack: noop),
  ];
}
