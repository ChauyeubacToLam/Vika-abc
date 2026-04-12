import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/exercise_definition.dart';
import 'screens/exercise/exercise_experience_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'theme/vf_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const VinaFitApp());
}

class VinaFitApp extends StatelessWidget {
  const VinaFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VinaFit',
      debugShowCheckedModeBanner: false,
      theme: VFTheme.lightTheme,
      builder: (context, child) => ScrollConfiguration(
        behavior: const VFScrollBehavior(),
        child: child ?? const SizedBox.shrink(),
      ),
      routes: {
        '/': (_) => const MainShell(),
        '/onboarding': (_) => const OnboardingScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/exercise') {
          final definition = settings.arguments as ExerciseDefinition;
          return MaterialPageRoute(
            builder: (_) => ExerciseExperienceScreen(definition: definition),
          );
        }

        return MaterialPageRoute(builder: (_) => const MainShell());
      },
    );
  }
}
