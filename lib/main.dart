// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'exercise/exercise_base.dart';
import 'models/exercise_definition.dart';
import 'screens/exercise/exercise_launch_args.dart';
import 'screens/exercise/exercise_experience_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding/v5/v5_onboarding_navigator.dart';
import 'screens/plan_retest_screen.dart';
import 'screens/weekly_check_in_screen.dart';
import 'services/recommendation/recommendation_service.dart';
import 'theme/typography.dart';
import 'theme/vf_theme.dart';
import 'utils/orientation_lock.dart';

/* =========================================================================
   APP ENTRY POINT
   ========================================================================= */

List<CameraDescription> _cameras = const <CameraDescription>[];
bool _hasCompletedOnboarding = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appConfig = await _loadAppConfig();

  await Supabase.initialize(
    url: appConfig.supabaseUrl,
    anonKey: appConfig.supabaseAnonKey,
  );

  await OrientationLock.portraitOnly();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  _cameras = await availableCameras();
  _hasCompletedOnboarding = await isOnboardingComplete();
  runApp(const VikaApp());
}

class _AppConfig {
  const _AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
}

Future<_AppConfig> _loadAppConfig() async {
  const defineSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const defineSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final env = await _loadBundledDotEnv();
  final supabaseUrl = _firstNonEmpty(
    defineSupabaseUrl,
    env['SUPABASE_URL'],
  );
  final supabaseAnonKey = _firstNonEmpty(
    defineSupabaseAnonKey,
    env['SUPABASE_ANON_KEY'],
  );

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw StateError(
      'Missing Supabase config. Provide SUPABASE_URL and '
      'SUPABASE_ANON_KEY in .env or with --dart-define.',
    );
  }

  return _AppConfig(
    supabaseUrl: supabaseUrl,
    supabaseAnonKey: supabaseAnonKey,
  );
}

Future<Map<String, String>> _loadBundledDotEnv() async {
  try {
    final raw = await rootBundle.loadString('.env');
    final values = <String, String>{};
    for (final rawLine in raw.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      values[key] = _stripEnvQuotes(value);
    }
    return values;
  } catch (_) {
    return const {};
  }
}

String _stripEnvQuotes(String value) {
  if (value.length < 2) return value;
  final first = value[0];
  final last = value[value.length - 1];
  if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

String? _firstNonEmpty(String? first, String? second) {
  final a = first?.trim();
  if (a != null && a.isNotEmpty) return a;
  final b = second?.trim();
  if (b != null && b.isNotEmpty) return b;
  return null;
}

// Add this at the top level of the file for easy access everywhere
final supabase = Supabase.instance.client;

Future<bool> _readStoredOnboardingCompletion() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_complete') ?? false;
}

Future<bool> isOnboardingComplete() async {
  final user = supabase.auth.currentUser;
  if (user == null) return false;

  try {
    final data = await supabase
        .from('profiles')
        .select('onboarding_complete')
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      // Profile row missing — user was deleted server-side. Clear stale
      // local flag and sign out so onboarding starts fresh.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('onboarding_complete');
      await supabase.auth.signOut();
      return false;
    }
    return data['onboarding_complete'] as bool? ?? false;
  } catch (_) {
    return await _readStoredOnboardingCompletion();
  }
}

/* =========================================================================
   UI REP LOG — For debug panel display only. Not the data pipeline.
   ========================================================================= */

enum _AppEntryState { onboarding, home, loading }

class UIRepLog {
  final int repNumber;
  final bool correctForm;
  final Map<String, Map<String, String>> faults;
  final String? tempo;
  final double? descentDuration;
  final double? ascentDuration;
  final double? bottomHold;
  final DateTime timestamp;

  UIRepLog({
    required this.repNumber,
    required this.correctForm,
    required this.faults,
    this.tempo,
    this.descentDuration,
    this.ascentDuration,
    this.bottomHold,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  List<String> get allFaultMessages {
    final msgs = <String>[];
    for (final phaseMap in faults.values) {
      msgs.addAll(phaseMap.values);
    }
    return msgs;
  }

  @override
  String toString() => 'Rep $repNumber: ${correctForm ? "GOOD" : "BAD"} | '
      'Tempo: ${tempo ?? "N/A"} | '
      'Faults: ${allFaultMessages.isEmpty ? "None" : allFaultMessages.join(", ")}';
}

/* =========================================================================
   APP
   ========================================================================= */

class VikaApp extends StatelessWidget {
  const VikaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vika',
      debugShowCheckedModeBanner: false,
      theme: VFTheme.lightTheme,
      builder: (context, child) => ScrollConfiguration(
        behavior: const VFScrollBehavior(),
        // Clamp the user's text scale to [0.9, 1.3]. Respects accessibility
        // settings within reason; prevents 2× scales from breaking the
        // tight Premium Ivory layouts. See lib/theme/typography.dart.
        child: VikaType.clampTextScaler(context, child),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            final args = settings.arguments;
            final overrideComplete = args is Map<String, dynamic>
                ? args['onboardingComplete'] as bool?
                : null;
            return MaterialPageRoute(
              builder: (_) => AppEntryGate(
                initialOnboardingComplete:
                    overrideComplete ?? _hasCompletedOnboarding,
              ),
            );
          case '/onboarding':
            return MaterialPageRoute(
              builder: (_) => const V5OnboardingNavigator(),
            );
          case '/exercise':
            final args = settings.arguments;
            final launchArgs = args is ExerciseLaunchArgs
                ? args
                : ExerciseLaunchArgs(
                    definition: args as ExerciseDefinition,
                  );
            return MaterialPageRoute(
              builder: (_) => ExerciseExperienceScreen(
                definition: launchArgs.definition,
                catalogExerciseId: launchArgs.catalogExerciseId,
                prescription: launchArgs.prescription,
                recommendationId: launchArgs.recommendationId,
                weekNumber: launchArgs.weekNumber,
                sessionIndex: launchArgs.sessionIndex,
                slotName: launchArgs.slotName,
                sequence: launchArgs.sequence,
                sequenceIndex: launchArgs.sequenceIndex,
              ),
            );
          case '/weekly-check-in':
            final args = settings.arguments as WeeklyCheckInLaunchArgs;
            return MaterialPageRoute(
              builder: (_) => WeeklyCheckInScreen(args: args),
            );
          case '/plan-retest':
            final args = settings.arguments as PlanRetestLaunchArgs;
            return MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => PlanRetestScreen(args: args),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => AppEntryGate(
                initialOnboardingComplete: _hasCompletedOnboarding,
              ),
            );
        }
      },
    );
  }
}

class AppEntryGate extends StatefulWidget {
  const AppEntryGate({
    super.key,
    required this.initialOnboardingComplete,
  });

  final bool initialOnboardingComplete;

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  StreamSubscription<AuthState>? _authSubscription;
  late _AppEntryState _entryState;
  bool _ensuredPlanForSession = false;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    _entryState = _initialEntryState();
    _authSubscription = supabase.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
    );
    _resolveEntryState();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  _AppEntryState _initialEntryState() {
    return widget.initialOnboardingComplete
        ? _AppEntryState.home
        : _AppEntryState.onboarding;
  }

  Future<void> _resolveEntryState() async {
    await _quietResolveEntryState();
  }

  void _handleAuthStateChange(AuthState data) {
    switch (data.event.name) {
      case 'signedIn':
      case 'initialSession':
      case 'passwordRecovery':
      case 'userUpdated':
      case 'mfaChallengeVerified':
        // If the user is mid-onboarding, do NOT flash to loading and
        // rebuild the navigator — that disposes its State and resets the
        // PageController back to S01. The signup screen has its own auth
        // listener that advances the page in place. Only swap to home
        // if onboarding is actually complete.
        _quietResolveEntryState();
        break;
      case 'signedOut':
      case 'userDeleted':
        _setEntryState(_AppEntryState.onboarding);
        break;
      case 'tokenRefreshed':
        break;
      default:
        _quietResolveEntryState();
    }
  }

  /// Re-resolves the entry state without flashing through `loading`. Stays
  /// in the current state if no transition is required — preserves the
  /// V5OnboardingNavigator's State (PageController + OnboardingData) when
  /// the signup screen completes auth mid-flow.
  Future<void> _quietResolveEntryState() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      if (_entryState != _AppEntryState.onboarding) {
        _setEntryState(_AppEntryState.onboarding);
      }
      return;
    }

    final complete = await isOnboardingComplete();
    if (complete) {
      _ensurePlanForSignedInUser();
    }
    final target = complete ? _AppEntryState.home : _AppEntryState.onboarding;
    if (target != _entryState) {
      _setEntryState(target);
    }
  }

  void _setEntryState(_AppEntryState state) {
    if (!mounted) {
      return;
    }

    setState(() => _entryState = state);
  }

  void _ensurePlanForSignedInUser() {
    if (_ensuredPlanForSession) return;
    _ensuredPlanForSession = true;
    unawaited(
      RecommendationService().ensurePlanForCurrentUser(trigger: 'onboarding'),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_entryState) {
      case _AppEntryState.onboarding:
        return const V5OnboardingNavigator();
      case _AppEntryState.home:
        return const MainShell();
      case _AppEntryState.loading:
        return const _AuthLoadingScreen();
    }
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: VFTheme.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: const AlwaysStoppedAnimation<Color>(VFTheme.jade),
                  backgroundColor: VFTheme.jadeMist,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Đang đồng bộ tài khoản...',
                style: VFTheme.textStyle(
                  context,
                  size: 13,
                  weight: FontWeight.w600,
                  color: VFTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================================================================
   EXERCISE SCREEN — Generic, works with any ExerciseBase subclass.
   ========================================================================= */

class ExerciseScreen extends StatefulWidget {
  final ExerciseDefinition definition;

  const ExerciseScreen({super.key, required this.definition});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ── Shorthand ──
  ExerciseDefinition get _definition => widget.definition;

  // ── Camera ──
  CameraController? _cameraController;
  int _cameraIndex = -1;
  bool _isCameraReady = false;
  CameraLensDirection _currentLensDirection = CameraLensDirection.front;

  // ── ML Kit ──
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.accurate,
      mode: PoseDetectionMode.stream,
    ),
  );
  bool _isDetecting = false;

  // ── Exercise (generic) ──
  late ExerciseBase _exercise;
  int _repCount = 0;
  Map<String, String> _feedback = {};
  List<dynamic>? _result;

  // ── Drawing overlay ──
  Pose? _detectedPose;
  Size _imageSize = Size.zero;
  InputImageRotation _imageRotation = InputImageRotation.rotation0deg;

  // ── UI toggles ──
  bool _showDebug = false;
  bool _showRepLog = false;
  bool _didShowSetupSheet = false;

  // ── Camera UX state ──
  PermissionStatus? _cameraPermissionStatus;
  String? _cameraErrorMessage;
  bool _isInitializingCamera = false;

  // ── UI refresh throttling ──
  int _lastUiRefreshAtMs = 0;
  static const int _MIN_UI_REFRESH_INTERVAL_MS = 50;

  // ── FPS ──
  int _frameCount = 0;
  DateTime _lastFpsTime = DateTime.now();
  double _fps = 0;

  // ── UI Rep Logging (for debug panel only) ──
  final List<UIRepLog> _repLogs = [];
  int _lastLoggedRep = 0;

  // ── After-rep banner ──
  String? _repBannerText;
  bool _repBannerGood = true;
  late final AnimationController _bannerController;
  late final Animation<double> _bannerAnimation;

  // ── State logging ──
  String _lastLoggedState = '';
  String _lastLoggedPhaseState = '';

  // ── Completion guard ──
  bool _didComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _exercise = _definition.createExercise();

    _bannerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _bannerAnimation = CurvedAnimation(
      parent: _bannerController,
      curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
      reverseCurve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    );
    _bannerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _bannerController.reverse();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showSetupSheet();
    });

    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector.close();
    _exercise.disposeDetectors();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _isCameraReady = false;
      _cameraController = null;
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  /* -----------------------------------------------------------------------
     CAMERA INIT
     ----------------------------------------------------------------------- */
  Future<void> _initCamera({int retryCount = 0}) async {
    if (mounted) {
      setState(() {
        _isInitializingCamera = true;
        _cameraErrorMessage = null;
      });
    }

    final status = await Permission.camera.request();
    _cameraPermissionStatus = status;
    if (!status.isGranted) {
      debugPrint('[Vika] Camera permission not granted: $status');
      if (mounted) {
        setState(() {
          _isInitializingCamera = false;
          _isCameraReady = false;
          _cameraErrorMessage = status.isPermanentlyDenied
              ? 'Quyền camera đã bị chặn. Hãy mở lại trong cài đặt.'
              : 'Ứng dụng cần quyền camera để theo dõi bài tập.';
        });
      }
      return;
    }

    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
      } catch (_) {}
      _cameraController = null;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (_cameras.isEmpty) {
      debugPrint('[Vika] No cameras available');
      if (mounted) {
        setState(() {
          _isInitializingCamera = false;
          _isCameraReady = false;
          _cameraErrorMessage = 'Không tìm thấy camera trên thiết bị này.';
        });
      }
      return;
    }

    final camerasToTry = <int>[];
    final preferredIdx = _cameras.indexWhere(
      (cam) => cam.lensDirection == _currentLensDirection,
    );
    if (preferredIdx != -1) camerasToTry.add(preferredIdx);
    for (int i = 0; i < _cameras.length; i++) {
      if (!camerasToTry.contains(i)) camerasToTry.add(i);
    }

    for (final idx in camerasToTry) {
      final camera = _cameras[idx];
      debugPrint(
        '[Vika] Trying camera $idx: ${camera.lensDirection} (${camera.name})',
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      try {
        await controller.initialize();
        if (!mounted) {
          controller.dispose();
          return;
        }
        _cameraController = controller;
        _cameraIndex = idx;
        _currentLensDirection = camera.lensDirection;
        _isCameraReady = true;
        await controller.startImageStream(_processCameraImage);
        debugPrint('[Vika] Camera $idx initialized successfully');
        if (mounted) {
          setState(() {
            _isInitializingCamera = false;
            _cameraErrorMessage = null;
          });
        }
        return;
      } catch (e) {
        debugPrint('[Vika] Camera $idx init error: $e');
        try {
          await controller.dispose();
        } catch (_) {}
      }
    }

    if (retryCount < 3 && mounted) {
      final delay = Duration(seconds: 1 + retryCount);
      debugPrint(
          '[Vika] Camera open failed, retrying in ${delay.inSeconds}s (attempt ${retryCount + 1}/3)');
      await Future.delayed(delay);
      if (mounted) return _initCamera(retryCount: retryCount + 1);
    }

    debugPrint('[Vika] Camera open failed after all retries');
    if (mounted) {
      setState(() {
        _isInitializingCamera = false;
        _isCameraReady = false;
        _cameraErrorMessage =
            'Không thể khởi động camera. Hãy thử lại hoặc đổi camera.';
      });
    }
  }

  /* -----------------------------------------------------------------------
     CAMERA TOGGLE
     ----------------------------------------------------------------------- */
  Future<void> _toggleCamera() async {
    final newDirection = _currentLensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    final newIndex = _cameras.indexWhere(
      (cam) => cam.lensDirection == newDirection,
    );
    if (newIndex == -1) return;

    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();

    setState(() {
      _isCameraReady = false;
      _cameraIndex = newIndex;
      _currentLensDirection = newDirection;
      _detectedPose = null;
    });

    final camera = _cameras[_cameraIndex];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      await _cameraController!.startImageStream(_processCameraImage);
      setState(() {
        _isCameraReady = true;
        _cameraErrorMessage = null;
      });
    } catch (e) {
      debugPrint('[Vika] Camera toggle error: $e');
      if (mounted) {
        setState(() {
          _cameraErrorMessage = 'Không thể chuyển camera. Hãy thử lại.';
        });
      }
    }
  }

  /* -----------------------------------------------------------------------
     POSE PIPELINE
     ----------------------------------------------------------------------- */
  void _processCameraImage(CameraImage cameraImage) {
    if (_isDetecting) return;
    _isDetecting = true;
    _detectPose(cameraImage).then((_) => _isDetecting = false);
  }

  Future<void> _detectPose(CameraImage cameraImage) async {
    try {
      final inputImage = _buildInputImage(cameraImage);
      if (inputImage == null) return;

      await _exercise.runPersonDetection(inputImage);
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        final pose = poses.first;
        _detectedPose = pose;
        _result = _exercise.processPose(pose.landmarks);

        if (_result != null) {
          if (_exercise.exerciseState == ExerciseState.completed) {
            _repCount = _exercise.repCount;
            _feedback = {'Result': 'Hoàn thành! $_repCount reps'};
            _logSetComplete();
            _popWithLogger();
          } else if (_result!.length == 2) {
            final prevRepCount = _repCount;
            _repCount = _result![0] as int;
            _feedback = Map<String, String>.from(_result![1] as Map);
            if (_repCount > prevRepCount) {
              _logRepCompletion();
            }
          }
        }

        _logStateChanges();
      } else {
        _detectedPose = null;
        _feedback = _exercise.processNoPoseFrame();
      }

      // FPS
      _frameCount++;
      final now = DateTime.now();
      final elapsed = now.difference(_lastFpsTime).inMilliseconds;
      if (elapsed >= 1000) {
        _fps = _frameCount * 1000.0 / elapsed;
        _frameCount = 0;
        _lastFpsTime = now;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (mounted &&
          nowMs - _lastUiRefreshAtMs >= _MIN_UI_REFRESH_INTERVAL_MS) {
        _lastUiRefreshAtMs = nowMs;
        setState(() {});
      }
    } catch (e) {
      debugPrint('[Vika] Detection error: $e');
    }
  }

  /* -----------------------------------------------------------------------
     COMPLETION — Pop with logger after short delay
     ----------------------------------------------------------------------- */
  void _popWithLogger() {
    if (_didComplete) return;
    _didComplete = true;

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context, {'logger': _exercise.logger});
      }
    });
  }

  /* -----------------------------------------------------------------------
     LOGGING (UI debug panel only)
     ----------------------------------------------------------------------- */
  void _logStateChanges() {
    final exState = _exercise.exerciseState.toString().split('.').last;
    final phaseState = _exercise.currentPhaseKey;
    if (exState != _lastLoggedState) {
      debugPrint('[Vika][State] Exercise: $_lastLoggedState -> $exState');
      _lastLoggedState = exState;
    }
    if (phaseState != _lastLoggedPhaseState) {
      debugPrint(
        '[Vika][State] ${_exercise.exerciseName}: $_lastLoggedPhaseState -> $phaseState',
      );
      _lastLoggedPhaseState = phaseState;
    }
  }

  void _logRepCompletion() {
    if (_repCount <= _lastLoggedRep) return;
    _lastLoggedRep = _repCount;

    final d = _exercise.debugData;

    // Extract tempo info
    String? tempo;
    final descent = d['descentDur'];
    final ascent = d['ascentDur'];
    if (descent != null && descent != '-') {
      tempo = '\u2193${descent}s';
      if (ascent != null && ascent != '-') {
        tempo = '\u2193${descent}s \u2191${ascent}s';
      }
    }
    if (tempo == null) {
      final holdTime = d['holdTime'];
      if (holdTime != null && holdTime != '0.0') {
        tempo = '\u23F1${holdTime}s';
      }
    }

    final faultMap = <String, Map<String, String>>{};
    if (_exercise.setFeedback.isNotEmpty) {
      final lastEntry = _exercise.setFeedback.last;
      for (final entry in lastEntry.entries) {
        for (final phaseEntry in entry.value.entries) {
          faultMap[phaseEntry.key] = Map<String, String>.from(phaseEntry.value);
        }
      }
    }

    final wasGoodRep =
        _feedback['Result'] == 'Good Rep!' || _feedback['Result'] == 'Tốt lắm!';

    final log = UIRepLog(
      repNumber: _repCount,
      correctForm: wasGoodRep,
      faults: faultMap,
      tempo: tempo,
      descentDuration: double.tryParse(d['descentDur'] ?? ''),
      ascentDuration: double.tryParse(d['ascentDur'] ?? ''),
      bottomHold: double.tryParse(d['bottomHold'] ?? d['holdTime'] ?? ''),
    );
    _repLogs.add(log);

    debugPrint('[Vika][Rep] $log');
    debugPrint(
      '[Vika][Feedback] ${_feedback.entries.map((e) => '${e.key}: ${e.value}').join(' | ')}',
    );

    _repBannerGood = log.correctForm;
    final parts = <String>[];
    parts.add(log.correctForm ? 'Tốt lắm!' : 'Sửa tư thế');
    if (tempo != null) parts.add(tempo);
    _repBannerText = parts.join('  ');
    _bannerController.forward(from: 0.0);
  }

  void _logSetComplete() {
    if (_repLogs.isEmpty) return;
    final goodReps = _repLogs.where((r) => r.correctForm).length;
    final badReps = _repLogs.where((r) => !r.correctForm).length;
    debugPrint('');
    debugPrint('============================================');
    debugPrint(
      '[Vika][SET COMPLETE] ${_exercise.exerciseName} — $_repCount reps total',
    );
    debugPrint('[Vika][SET] Good: $goodReps | Bad: $badReps');
    debugPrint('--------------------------------------------');
    for (final log in _repLogs) {
      final status = log.correctForm ? 'OK' : 'BAD';
      final faultStr = log.allFaultMessages.isEmpty
          ? 'No issues'
          : log.allFaultMessages.join(', ');
      debugPrint(
        '[Vika][SET] Rep ${log.repNumber} [$status] '
        'Tempo: ${log.tempo ?? "N/A"} | $faultStr',
      );
    }
    debugPrint('============================================');
    debugPrint('');
  }

  Future<void> _showSetupSheet({bool force = false}) async {
    if (!mounted) return;
    if (_didShowSetupSheet && !force) return;
    _didShowSetupSheet = true;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D1228),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _definition.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _definition.icon,
                        color: _definition.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _definition.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _definition.subtitle,
                            style: TextStyle(
                              color: _definition.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _definition.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSetupRow(
                    Icons.cameraswitch_outlined, _definition.cameraHint),
                const SizedBox(height: 8),
                _buildSetupRow(
                    Icons.crop_free_outlined, _definition.framingHint),
                const SizedBox(height: 14),
                if (_definition.safetyWarning != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.health_and_safety,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _definition.safetyWarning!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                ..._definition.setupTips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: _definition.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _definition.primaryColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Bắt đầu'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSetupRow(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _definition.primaryColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* -----------------------------------------------------------------------
     INPUT IMAGE
     ----------------------------------------------------------------------- */
  InputImage? _buildInputImage(CameraImage image) {
    final camera = _cameras[_cameraIndex];
    final rotation = _rotationFromSensor(camera.sensorOrientation);
    _imageRotation = rotation;

    if (rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg) {
      _imageSize = Size(image.height.toDouble(), image.width.toDouble());
    } else {
      _imageSize = Size(image.width.toDouble(), image.height.toDouble());
    }

    final format =
        Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888;

    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  InputImageRotation _rotationFromSensor(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Size get _legacyPreviewRenderSize {
    if (_imageSize != Size.zero) {
      return _imageSize;
    }

    final previewSize = _cameraController?.value.previewSize;
    if (previewSize != null) {
      if (previewSize.width > previewSize.height) {
        return Size(previewSize.height, previewSize.width);
      }
      return previewSize;
    }

    return const Size(480, 640);
  }

  /* =======================================================================
     BUILD
     ======================================================================= */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C1A),
      body: SafeArea(
        child: !_hasCameraPermission
            ? _buildPermissionView()
            : !_isCameraReady
                ? _buildLoadingView()
                : _buildCameraView(context),
      ),
    );
  }

  bool get _hasCameraPermission => _cameraPermissionStatus?.isGranted ?? true;

  /* ── LOADING ── */
  Widget _buildLoadingView() {
    if (_cameraErrorMessage != null && !_isInitializingCamera) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                size: 48,
                color: _definition.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                _cameraErrorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _initCamera,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(
                _definition.primaryColor.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isInitializingCamera
                ? 'Đang khởi động camera...'
                : 'Đang chờ camera sẵn sàng...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionView() {
    final status = _cameraPermissionStatus;
    final permanentlyDenied = status?.isPermanentlyDenied ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 54,
              color: _definition.primaryColor,
            ),
            const SizedBox(height: 18),
            const Text(
              'Cần quyền camera',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _cameraErrorMessage ??
                  'Hãy cấp quyền camera để AI theo dõi bài tập của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: permanentlyDenied ? openAppSettings : _initCamera,
              child: Text(permanentlyDenied ? 'Mở cài đặt' : 'Cấp quyền'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }

  /* ── MAIN LAYOUT ── */
  Widget _buildCameraView(BuildContext context) {
    final controller = _cameraController!;
    final isCompleted = _exercise.exerciseState == ExerciseState.completed;

    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Stack(
            children: [
              _buildCameraStack(controller),
              _buildRepBanner(),
              Positioned(bottom: 12, right: 12, child: _buildRepCountOverlay()),
              if (_repLogs.isNotEmpty)
                Positioned(bottom: 12, left: 12, child: _buildRepDots()),
              _buildCoachingOverlay(),
            ],
          ),
        ),
        _buildInstructionsBar(),
        _buildFeedbackCards(),
        _buildBottomBar(),
        if (_showDebug) _buildDebugPanel(),
        if (_showRepLog || isCompleted) _buildRepLogPanel(),
      ],
    );
  }

  /* ── TOP BAR ── */
  Widget _buildTopBar() {
    final accent = _definition.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(color: Color(0xFF080C1A)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accent.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(_definition.icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _definition.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
              Text(
                _definition.subtitle,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _toggleCamera,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                _currentLensDirection == CameraLensDirection.back
                    ? Icons.camera_front
                    : Icons.camera_rear,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showSetupSheet(force: true),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: _buildStatePill()),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_fps.toStringAsFixed(0)} fps',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ── STATE PILL ── */
  Widget _buildStatePill() {
    final exerciseState = _exercise.exerciseState;

    Color color;
    String text;
    IconData icon;

    switch (exerciseState) {
      case ExerciseState.notActivated:
        color = const Color(0xFFFF9800);
        final progress = _exercise.activationProgress;
        if (progress != null && progress > 0) {
          final remaining = ((1.0 - progress) * 3.0).toStringAsFixed(0);
          text = 'Giữ yên... ${remaining}s';
          icon = Icons.timer_outlined;
        } else {
          text = 'Vào tư thế để bắt đầu';
          icon = Icons.accessibility_new;
        }
        break;
      case ExerciseState.activated:
        final phaseKey = _exercise.currentPhaseKey;
        color = _definition.phaseColors[phaseKey] ?? _definition.primaryColor;
        text = _exercise.currentPhaseLabel;
        icon = Icons.directions_run;
        break;
      case ExerciseState.completed:
        color = const Color(0xFF00E676);
        text = 'Hoàn thành!';
        icon = Icons.emoji_events;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /* ── CAMERA + SKELETON ── */
  Widget _buildCameraStack(CameraController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = Size(constraints.maxWidth, constraints.maxHeight);
        final framingColor = _exercise.isPaused
            ? const Color(0xFFFF5252)
            : _definition.primaryColor;
        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _legacyPreviewRenderSize.width,
                    height: _legacyPreviewRenderSize.height,
                    child: CameraPreview(controller),
                  ),
                ),
              ),
            ),
            if (_detectedPose != null)
              RepaintBoundary(
                child: CustomPaint(
                  size: previewSize,
                  painter: PosePainter(
                    pose: _detectedPose!,
                    imageSize: _imageSize,
                    widgetSize: previewSize,
                    rotation: _imageRotation,
                    lensDirection: controller.description.lensDirection,
                    debugData: _exercise.debugData,
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 70, 28, 90),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: framingColor.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                      stops: const [0.0, 0.12, 0.72, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              left: 12,
              right: 12,
              child: _buildFramingGuideCard(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFramingGuideCard() {
    final showSystemMessage = _feedback['System'];
    final guidance = showSystemMessage ??
        (_exercise.exerciseState == ExerciseState.notActivated
            ? _definition.framingHint
            : _definition.cameraHint);
    final color =
        _exercise.isPaused ? const Color(0xFFFF5252) : _definition.primaryColor;

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Icon(Icons.center_focus_strong, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                guidance,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ── REP COUNT OVERLAY ── */
  Widget _buildRepCountOverlay() {
    final isActive = _exercise.exerciseState == ExerciseState.activated ||
        _exercise.exerciseState == ExerciseState.completed;
    final accent = _definition.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$_repCount',
            style: TextStyle(
              color: isActive ? accent : Colors.white60,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _definition.id == 'plank' ? 'HOLDS' : 'REPS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                if (_exercise.exerciseState == ExerciseState.activated)
                  Text(
                    _exercise.correctForm ? '✓ TỐT' : '✗ SỬA',
                    style: TextStyle(
                      color: _exercise.correctForm
                          ? const Color(0xFF00E676)
                          : const Color(0xFFFF5252),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ── REP DOTS ── */
  Widget _buildRepDots() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _repLogs.map((log) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: log.correctForm
                    ? const Color(0xFF00E676)
                    : const Color(0xFFFF5252),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /* ── AFTER-REP BANNER ── */
  Widget _buildRepBanner() {
    if (_repBannerText == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _bannerAnimation,
      builder: (context, child) {
        if (_bannerAnimation.value <= 0.01) return const SizedBox.shrink();
        return Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: _bannerAnimation.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -24 * (1.0 - _bannerAnimation.value)),
              child: Center(child: child),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _repBannerGood
                ? [
                    const Color(0xFF00E676).withValues(alpha: 0.92),
                    const Color(0xFF00C853).withValues(alpha: 0.92),
                  ]
                : [
                    const Color(0xFFFF5252).withValues(alpha: 0.92),
                    const Color(0xFFD50000).withValues(alpha: 0.92),
                  ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (_repBannerGood
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFF5252))
                  .withValues(alpha: 0.35),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _repBannerGood
                  ? Icons.check_circle_rounded
                  : Icons.warning_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _repBannerText!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ── INSTRUCTIONS BAR ── */
  Widget _buildInstructionsBar() {
    final phaseKey = _exercise.currentPhaseKey;
    final phaseInstr = _exercise.resultIssues.instructions[phaseKey];
    if (phaseInstr == null || phaseInstr.isEmpty)
      return const SizedBox.shrink();

    final statusText = phaseInstr['Status'];
    if (statusText == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF0D1228),
      child: _buildStatusBadge(statusText),
    );
  }

  Widget _buildStatusBadge(String statusText) {
    final isHold = statusText.startsWith('Hold') ||
        statusText.startsWith('Giữ') ||
        statusText.contains('!');

    final holdProgress = isHold
        ? (_exercise.debugData['bottomHoldProgress'] as double? ??
            _exercise.debugData['holdProgress'] as double? ??
            0.0)
        : null;

    final phaseKey = _exercise.currentPhaseKey;
    final color = _definition.phaseColors[phaseKey] ?? _definition.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (holdProgress != null && holdProgress > 0) ...[
            SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(
                painter: _ArcCountdownPainter(
                  progress: holdProgress,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 7),
          ] else ...[
            Icon(_statusIcon(statusText), color: color, size: 14),
            const SizedBox(width: 6),
          ],
          Text(
            statusText,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /* ── COACHING OVERLAY ── */
  Widget _buildCoachingOverlay() {
    final phaseKey = _exercise.currentPhaseKey;
    final phaseInstr = _exercise.resultIssues.instructions[phaseKey];

    if (phaseInstr == null || phaseInstr.isEmpty) {
      return const SizedBox.shrink();
    }

    final coachingEntries =
        phaseInstr.entries.where((e) => e.key != 'Status').toList();
    if (coachingEntries.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 60,
      right: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: coachingEntries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    color: Color(0xFFFFB74D),
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        color: Color(0xFFFFB74D),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _statusIcon(String status) {
    if (status.contains('Xuống') || status.contains('Down'))
      return Icons.arrow_downward_rounded;
    if (status.contains('Giữ') ||
        status.contains('Hold') ||
        status.contains('Bottom')) return Icons.pause_circle_outline;
    if (status.contains('Đứng lên') ||
        status.contains('Push') ||
        status.contains('Up')) return Icons.arrow_upward_rounded;
    if (status.contains('Nghỉ') || status.contains('Rest'))
      return Icons.bedtime_outlined;
    if (status.contains('Chuẩn bị') || status.contains('Setup'))
      return Icons.accessibility_new;
    return Icons.info_outline;
  }

  /* ── FEEDBACK CARDS ── */
  Widget _buildFeedbackCards() {
    if (_feedback.isEmpty) return const SizedBox(height: 2);

    final liveEntries =
        _feedback.entries.where((e) => e.key != 'Result').toList();
    if (liveEntries.isEmpty) return const SizedBox(height: 2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const Color(0xFF0A0F20),
      child: Wrap(
        spacing: 6,
        runSpacing: 5,
        children: liveEntries.map((entry) {
          final severity = _feedbackSeverity(entry.value);
          final color = _severityColor(severity);
          final icon = _severityIcon(severity);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 13),
                const SizedBox(width: 5),
                Text(
                  entry.key,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  entry.value,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  int _feedbackSeverity(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('good') ||
        lower.contains('deep') ||
        lower.contains('tốt') ||
        lower.contains('push')) return 0;
    if (value.contains('!') ||
        lower.contains('lifting') ||
        lower.contains("don't") ||
        lower.contains('sửa') ||
        lower.contains('fix') ||
        lower.contains('cần')) return 2;
    return 1;
  }

  Color _severityColor(int severity) {
    switch (severity) {
      case 0:
        return const Color(0xFF00E676);
      case 2:
        return const Color(0xFFFF5252);
      default:
        return const Color(0xFFFFD600);
    }
  }

  IconData _severityIcon(int severity) {
    switch (severity) {
      case 0:
        return Icons.check_circle_outline;
      case 2:
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  /* ── BOTTOM BAR ── */
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF080C1A),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildMiniInfo(
            Icons.videocam_outlined,
            _exercise.cameraFacing.toString().split('.').last.toUpperCase(),
          ),
          const SizedBox(width: 8),
          if (_exercise.exerciseState == ExerciseState.activated)
            _buildMiniInfo(
              _exercise.correctForm
                  ? Icons.verified_outlined
                  : Icons.warning_amber_rounded,
              _exercise.correctForm ? 'Tư thế tốt' : 'Sửa tư thế',
              color: _exercise.correctForm
                  ? const Color(0xFF00E676)
                  : const Color(0xFFFF5252),
            ),
          const Spacer(),
          _buildToggleButton(
            icon: Icons.format_list_numbered,
            label: 'Log',
            isActive: _showRepLog,
            onTap: () => setState(() => _showRepLog = !_showRepLog),
          ),
          const SizedBox(width: 6),
          _buildToggleButton(
            icon: Icons.bug_report_outlined,
            label: 'Debug',
            isActive: _showDebug,
            onTap: () => setState(() => _showDebug = !_showDebug),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(IconData icon, String text, {Color? color}) {
    final c = color ?? Colors.white.withValues(alpha: 0.35);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: c, size: 13),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final accent = _definition.primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? accent.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? accent : Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive ? accent : Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ── DEBUG PANEL ── */
  Widget _buildDebugPanel() {
    final d = _exercise.debugData;
    if (d.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        color: const Color(0xFF060A16),
        child: Text(
          'Waiting for pose data...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.2),
            fontSize: 10,
          ),
        ),
      );
    }

    const colorPalette = [
      Color(0xFF00E5FF),
      Color(0xFFFFD600),
      Color(0xFF7C4DFF),
      Color(0xFF607D8B),
      Color(0xFF00BCD4),
      Color(0xFFFF9800),
      Color(0xFF4CAF50),
      Color(0xFF29B6F6),
      Color(0xFFAB47BC),
      Color(0xFFFF6D00),
      Color(0xFF00E676),
      Color(0xFFFF5252),
      Color(0xFF5C6BC0),
      Color(0xFF26A69A),
    ];

    final entries = d.entries.toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: const Color(0xFF060A16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.terminal,
                size: 11,
                color: _definition.primaryColor.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Text(
                'DEBUG — ${_exercise.exerciseName.toUpperCase()}',
                style: TextStyle(
                  color: _definition.primaryColor.withValues(alpha: 0.4),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: entries.asMap().entries.map((indexed) {
              final entry = indexed.value;
              final color = colorPalette[indexed.key % colorPalette.length];
              final value = entry.value is double
                  ? (entry.value as double).toStringAsFixed(2)
                  : '${entry.value}';
              return _debugChip(entry.key, value, color);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _debugChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                color: color.withValues(alpha: 0.45),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ── REP LOG PANEL ── */
  Widget _buildRepLogPanel() {
    if (_repLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF060A16),
        child: Text(
          'Chưa có lượt ${_exercise.exerciseName.toLowerCase()} nào.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 11,
          ),
        ),
      );
    }

    final goodCount = _repLogs.where((r) => r.correctForm).length;
    final badCount = _repLogs.where((r) => !r.correctForm).length;
    final isSetComplete = _exercise.exerciseState == ExerciseState.completed;

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      color: const Color(0xFF060A16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(
                  isSetComplete ? Icons.emoji_events : Icons.analytics_outlined,
                  size: 14,
                  color: isSetComplete
                      ? const Color(0xFFFFD600)
                      : _definition.primaryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  isSetComplete ? 'KẾT QUẢ BÀI TẬP' : 'LỊCH SỬ REP',
                  style: TextStyle(
                    color: isSetComplete
                        ? const Color(0xFFFFD600)
                        : _definition.primaryColor.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                _buildMiniStat('$goodCount', 'tốt', const Color(0xFF00E676)),
                const SizedBox(width: 10),
                _buildMiniStat('$badCount', 'sửa', const Color(0xFFFF5252)),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              shrinkWrap: true,
              itemCount: _repLogs.length,
              itemBuilder: (context, index) =>
                  _buildRepLogCard(_repLogs[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String count, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRepLogCard(UIRepLog log) {
    final color =
        log.correctForm ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    final faults = log.allFaultMessages;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                '${log.repNumber}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      log.correctForm
                          ? Icons.check_circle
                          : Icons.cancel_rounded,
                      color: color,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      log.correctForm ? 'Tốt' : 'Cần sửa',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (log.tempo != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF29B6F6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          log.tempo!,
                          style: const TextStyle(
                            color: Color(0xFF29B6F6),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                  ],
                ),
                if (faults.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    faults.join(' · '),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================================================================
   ARC COUNTDOWN PAINTER
   ========================================================================= */

class _ArcCountdownPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ArcCountdownPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    if (progress >= 1.0) {
      canvas.drawCircle(center, 2.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ArcCountdownPainter old) =>
      old.progress != progress || old.color != color;
}

/* =========================================================================
   POSE PAINTER
   ========================================================================= */

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Size widgetSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;
  final Map<String, dynamic> debugData;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.widgetSize,
    required this.rotation,
    required this.lensDirection,
    this.debugData = const {},
  });

  static const List<List<PoseLandmarkType>> _bodyConnections = [
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel],
    [PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex],
    [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel],
    [PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex],
    [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex],
  ];

  static final Map<PoseLandmarkType, Color> _landmarkColors = {
    PoseLandmarkType.leftShoulder: Colors.cyanAccent,
    PoseLandmarkType.leftElbow: Colors.cyanAccent,
    PoseLandmarkType.leftWrist: Colors.cyanAccent,
    PoseLandmarkType.leftHip: Colors.cyanAccent,
    PoseLandmarkType.leftKnee: Colors.cyanAccent,
    PoseLandmarkType.leftAnkle: Colors.cyanAccent,
    PoseLandmarkType.leftHeel: Colors.cyanAccent,
    PoseLandmarkType.leftFootIndex: Colors.cyanAccent,
    PoseLandmarkType.rightShoulder: Colors.yellowAccent,
    PoseLandmarkType.rightElbow: Colors.yellowAccent,
    PoseLandmarkType.rightWrist: Colors.yellowAccent,
    PoseLandmarkType.rightHip: Colors.yellowAccent,
    PoseLandmarkType.rightKnee: Colors.yellowAccent,
    PoseLandmarkType.rightAnkle: Colors.yellowAccent,
    PoseLandmarkType.rightHeel: Colors.yellowAccent,
    PoseLandmarkType.rightFootIndex: Colors.yellowAccent,
    PoseLandmarkType.nose: Colors.white,
    PoseLandmarkType.leftEye: Colors.white70,
    PoseLandmarkType.rightEye: Colors.white70,
    PoseLandmarkType.leftEar: Colors.white54,
    PoseLandmarkType.rightEar: Colors.white54,
    PoseLandmarkType.leftMouth: Colors.white54,
    PoseLandmarkType.rightMouth: Colors.white54,
    PoseLandmarkType.leftEyeInner: Colors.white54,
    PoseLandmarkType.leftEyeOuter: Colors.white54,
    PoseLandmarkType.rightEyeInner: Colors.white54,
    PoseLandmarkType.rightEyeOuter: Colors.white54,
    PoseLandmarkType.leftPinky: Colors.cyanAccent,
    PoseLandmarkType.rightPinky: Colors.yellowAccent,
    PoseLandmarkType.leftIndex: Colors.cyanAccent,
    PoseLandmarkType.rightIndex: Colors.yellowAccent,
    PoseLandmarkType.leftThumb: Colors.cyanAccent,
    PoseLandmarkType.rightThumb: Colors.yellowAccent,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final landmarks = pose.landmarks;
    if (landmarks.isEmpty) return;

    final double imageW = imageSize.width;
    final double imageH = imageSize.height;
    final double canvasW = size.width;
    final double canvasH = size.height;

    final double imageAspect = imageW / imageH;
    final double canvasAspect = canvasW / canvasH;

    double previewW, previewH, offsetX, offsetY;
    if (imageAspect > canvasAspect) {
      previewW = canvasW;
      previewH = canvasW / imageAspect;
      offsetX = 0;
      offsetY = (canvasH - previewH) / 2;
    } else {
      previewH = canvasH;
      previewW = canvasH * imageAspect;
      offsetX = (canvasW - previewW) / 2;
      offsetY = 0;
    }

    final double scaleX = previewW / imageW;
    final double scaleY = previewH / imageH;

    Offset transformPoint(PoseLandmark lm) {
      double x = lm.x;
      double y = lm.y;

      if (Platform.isAndroid) {
        switch (rotation) {
          case InputImageRotation.rotation90deg:
            x = lm.x;
            y = lm.y;
            break;
          case InputImageRotation.rotation270deg:
            // For front camera, ML Kit already returns upright landmarks.
            // Minor mirroring is handled by the lensDirection check below.
            x = lm.x;
            y = lm.y;
            break;
          default:
            break;
        }
      }

      if (lensDirection == CameraLensDirection.front) {
        x = imageW - x;
      }

      return Offset(x * scaleX + offsetX, y * scaleY + offsetY);
    }

    for (final connection in _bodyConnections) {
      final lm1 = landmarks[connection[0]];
      final lm2 = landmarks[connection[1]];
      if (lm1 == null || lm2 == null) continue;
      if (lm1.likelihood < 0.5 || lm2.likelihood < 0.5) continue;

      final p1 = transformPoint(lm1);
      final p2 = transformPoint(lm2);

      final avgConf = (lm1.likelihood + lm2.likelihood) / 2;
      final lineColor = avgConf > 0.8
          ? Colors.greenAccent.withValues(alpha: 0.65)
          : Colors.orangeAccent.withValues(alpha: 0.45);

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final entry in landmarks.entries) {
      final lm = entry.value;
      if (lm.likelihood < 0.5) continue;

      final point = transformPoint(lm);
      final color = _landmarkColors[entry.key] ?? Colors.white;

      canvas.drawCircle(
        point,
        5.5,
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        3.5,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }

    _drawAngleLabels(canvas, landmarks, transformPoint);
  }

  void _drawAngleLabels(
    Canvas canvas,
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    Offset Function(PoseLandmark) transformPoint,
  ) {
    final knee = landmarks[PoseLandmarkType.leftKnee] ??
        landmarks[PoseLandmarkType.rightKnee];
    if (knee != null && knee.likelihood > 0.92) {
      final kneePos = transformPoint(knee);
      final kneeAngle = debugData['kneeAngle'];
      if (kneeAngle != null) {
        _drawLabel(
            canvas, kneePos + const Offset(12, -8), '$kneeAngle°', Colors.cyan);
      }
    }

    final elbow = landmarks[PoseLandmarkType.leftElbow] ??
        landmarks[PoseLandmarkType.rightElbow];
    if (elbow != null && elbow.likelihood > 0.5) {
      final elbowAngle = debugData['elbowAngle'];
      if (elbowAngle != null) {
        final elbowPos = transformPoint(elbow);
        _drawLabel(canvas, elbowPos + const Offset(12, -8), '$elbowAngle°',
            const Color(0xFFE040FB));
      }
    }

    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ??
        landmarks[PoseLandmarkType.rightShoulder];
    if (shoulder != null && shoulder.likelihood > 0.5) {
      final shoulderPos = transformPoint(shoulder);
      final trunkLean = debugData['trunkLean'];
      final backAngle = debugData['backAngle'];
      final trunkDev = debugData['trunkDev'];
      if (trunkLean != null) {
        _drawLabel(canvas, shoulderPos + const Offset(12, -8), '$trunkLean',
            Colors.orange);
      } else if (trunkDev != null) {
        _drawLabel(canvas, shoulderPos + const Offset(12, -8), '$trunkDev',
            Colors.orange);
      } else if (backAngle != null) {
        _drawLabel(canvas, shoulderPos + const Offset(12, -8), '$backAngle°',
            Colors.orange);
      }
    }

    final ear = landmarks[PoseLandmarkType.leftEar] ??
        landmarks[PoseLandmarkType.rightEar];
    if (ear != null && ear.likelihood > 0.5) {
      final neckAngle = debugData['neckAngle'];
      if (neckAngle != null) {
        final earPos = transformPoint(ear);
        _drawLabel(canvas, earPos + const Offset(12, -8), '$neckAngle°',
            const Color(0xFF4CAF50));
      }
    }
  }

  void _drawLabel(Canvas canvas, Offset position, String text, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 4),
            Shadow(color: Colors.black, blurRadius: 8),
          ],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        position.dx - 2,
        position.dy - 2,
        textPainter.width + 4,
        textPainter.height + 4,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(bgRect, Paint()..color = Colors.black54);
    textPainter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.widgetSize != widgetSize ||
        oldDelegate.rotation != rotation ||
        oldDelegate.lensDirection != lensDirection ||
        !mapEquals(oldDelegate.debugData, debugData);
  }
}
