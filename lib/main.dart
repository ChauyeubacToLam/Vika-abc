// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'exercise/exercise_base.dart';
import 'exercise/squat/squat.dart';

/* =========================================================================
   APP ENTRY POINT
   ========================================================================= */

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Transparent status bar for edge-to-edge feel
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  _cameras = await availableCameras();
  runApp(const VinaFitApp());
}

/* =========================================================================
   REP LOG — Per-rep data store for history + after-set summary
   ========================================================================= */

class RepLog {
  final int repNumber;
  final bool correctForm;
  final Map<String, Map<String, String>> faults; // phase → {type: message}
  final String? tempo; // "↓1.2s ↑0.8s"
  final double? descentDuration;
  final double? ascentDuration;
  final double? bottomHold;
  final DateTime timestamp;

  RepLog({
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
   APP THEME
   ========================================================================= */

class VinaFitApp extends StatelessWidget {
  const VinaFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VinaFit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        colorSchemeSeed: const Color(0xFF00E5FF),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const ExerciseScreen(),
    );
  }
}

/* =========================================================================
   EXERCISE SCREEN
   ========================================================================= */

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ── Camera ──
  CameraController? _cameraController;
  int _cameraIndex = -1;
  bool _isCameraReady = false;

  // ── ML Kit ──
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.accurate,
      mode: PoseDetectionMode.stream,
    ),
  );
  bool _isDetecting = false;

  // ── Exercise ──
  final Squat _squat = Squat();
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

  // ── FPS counter ──
  int _frameCount = 0;
  DateTime _lastFpsTime = DateTime.now();
  double _fps = 0;

  // ── Rep Logging ──
  final List<RepLog> _repLogs = [];
  int _lastLoggedRep = 0;

  // ── After-rep banner ──
  String? _repBannerText;
  bool _repBannerGood = true;
  late final AnimationController _bannerController;
  late final Animation<double> _bannerAnimation;

  // ── State logging ──
  String _lastLoggedState = '';
  String _lastLoggedSquatState = '';

  /* ----------------------------------------------------------------------- */

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _poseDetector.close();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  /* -----------------------------------------------------------------------
     CAMERA INIT
     ----------------------------------------------------------------------- */
  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    _cameraIndex = _cameras
        .indexWhere((cam) => cam.lensDirection == CameraLensDirection.back);
    if (_cameraIndex == -1) _cameraIndex = 0;

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
      _isCameraReady = true;
      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('[VinaFit] Camera init error: $e');
    }

    if (mounted) setState(() {});
  }

  /* -----------------------------------------------------------------------
     IMAGE → POSE PIPELINE (with logging)
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

      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        final pose = poses.first;
        _detectedPose = pose;

        _result = _squat.processPose(pose.landmarks);

        if (_result != null) {
          if (_squat.exerciseState == ExerciseState.completed) {
            _repCount = _squat.repCount;
            _feedback = {'Result': 'Set Complete! $_repCount reps'};
            _logSetComplete();
          } else if (_result!.length == 2) {
            final prevRepCount = _repCount;
            _repCount = _result![0] as int;
            _feedback = Map<String, String>.from(_result![1] as Map);

            // Log rep completion when rep count increments
            if (_repCount > prevRepCount) {
              _logRepCompletion();
            }
          }
        }

        // Log state changes
        _logStateChanges();
      } else {
        _detectedPose = null;
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

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[VinaFit] Detection error: $e');
    }
  }

  /* -----------------------------------------------------------------------
     LOGGING SYSTEM
     ----------------------------------------------------------------------- */

  /// Log state transitions to console
  void _logStateChanges() {
    final exState = _squat.exerciseState.toString().split('.').last;
    final sqState = _squat.squatState.toString().split('.').last;

    if (exState != _lastLoggedState) {
      debugPrint('[VinaFit][State] Exercise: $_lastLoggedState -> $exState');
      _lastLoggedState = exState;
    }
    if (sqState != _lastLoggedSquatState) {
      debugPrint('[VinaFit][State] Squat: $_lastLoggedSquatState -> $sqState');
      _lastLoggedSquatState = sqState;
    }
  }

  /// Log each completed rep with full details
  void _logRepCompletion() {
    if (_repCount <= _lastLoggedRep) return;
    _lastLoggedRep = _repCount;

    // Build tempo string
    String? tempo;
    final d = _squat.debugData;
    final descent = d['descentDur'];
    final ascent = d['ascentDur'];
    if (descent != null && descent != '-') {
      tempo = '\u2193${descent}s';
      if (ascent != null && ascent != '-') {
        tempo = '\u2193${descent}s \u2191${ascent}s';
      }
    }

    // Build fault map from setFeedback
    final faultMap = <String, Map<String, String>>{};
    if (_squat.setFeedback.isNotEmpty) {
      final lastEntry = _squat.setFeedback.last;
      // lastEntry is Map<bool, Map<String, Map<String, String>>>
      for (final entry in lastEntry.entries) {
        for (final phaseEntry in entry.value.entries) {
          faultMap[phaseEntry.key] = Map<String, String>.from(phaseEntry.value);
        }
      }
    }

    // Read correctForm from feedback Result — _squat.correctForm is already
    // reset to true by the time this runs.
    final wasGoodRep = _feedback['Result'] == 'Good Rep!';

    final log = RepLog(
      repNumber: _repCount,
      correctForm: wasGoodRep,
      faults: faultMap,
      tempo: tempo,
      descentDuration: double.tryParse(d['descentDur'] ?? ''),
      ascentDuration: double.tryParse(d['ascentDur'] ?? ''),
      bottomHold: double.tryParse(d['bottomHold'] ?? ''),
    );
    _repLogs.add(log);

    // Console log
    debugPrint('[VinaFit][Rep] $log');
    debugPrint(
        '[VinaFit][Feedback] ${_feedback.entries.map((e) => '${e.key}: ${e.value}').join(' | ')}');

    // Show after-rep banner
    _repBannerGood = log.correctForm;
    final parts = <String>[];
    parts.add(log.correctForm ? 'Good Rep!' : 'Fix Form');
    if (tempo != null) parts.add(tempo);
    _repBannerText = parts.join('  ');
    _bannerController.forward(from: 0.0);
  }

  /// Log set summary when exercise completes
  void _logSetComplete() {
    if (_repLogs.isEmpty) return;

    final goodReps = _repLogs.where((r) => r.correctForm).length;
    final badReps = _repLogs.where((r) => !r.correctForm).length;

    debugPrint('');
    debugPrint('============================================');
    debugPrint('[VinaFit][SET COMPLETE] $_repCount reps total');
    debugPrint('[VinaFit][SET] Good: $goodReps | Bad: $badReps');
    debugPrint('--------------------------------------------');
    for (final log in _repLogs) {
      final status = log.correctForm ? 'OK' : 'BAD';
      final faultStr = log.allFaultMessages.isEmpty
          ? 'No issues'
          : log.allFaultMessages.join(', ');
      debugPrint('[VinaFit][SET] Rep ${log.repNumber} [$status] '
          'Tempo: ${log.tempo ?? "N/A"} | $faultStr');
    }
    debugPrint('============================================');
    debugPrint('');
  }

  /* -----------------------------------------------------------------------
     BUILD InputImage FROM CameraImage
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

  /* =======================================================================
     BUILD UI — Modern dark theme with glassmorphism accents
     ======================================================================= */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child:
            !_isCameraReady ? _buildLoadingView() : _buildCameraView(context),
      ),
    );
  }

  /* ── LOADING ── */
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                  Colors.cyanAccent.withValues(alpha: 0.8)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Initializing Camera...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /* ── MAIN LAYOUT ── */
  Widget _buildCameraView(BuildContext context) {
    final controller = _cameraController!;
    final isCompleted = _squat.exerciseState == ExerciseState.completed;

    return Column(
      children: [
        _buildTopBar(),

        // Camera + overlays
        Expanded(
          child: Stack(
            children: [
              _buildCameraStack(controller),

              // After-rep banner (animated slide-in)
              _buildRepBanner(),

              // Big rep counter overlay (bottom-right of camera)
              Positioned(
                bottom: 12,
                right: 12,
                child: _buildRepCountOverlay(),
              ),

              // Rep history dots (bottom-left of camera)
              if (_repLogs.isNotEmpty)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: _buildRepDots(),
                ),
            ],
          ),
        ),

        // Coaching instructions (status + tempo reminders)
        _buildInstructionsBar(),

        // Live feedback cards
        _buildFeedbackCards(),

        // Bottom controls bar
        _buildBottomBar(),

        // Expandable panels
        if (_showDebug) _buildDebugPanel(),
        if (_showRepLog || isCompleted) _buildRepLogPanel(),
      ],
    );
  }

  /* ── TOP BAR (glassmorphism) ── */
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0A0E21),
            const Color(0xFF0A0E21).withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Row(
        children: [
          // App logo / title
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center,
                color: Colors.cyanAccent, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VINAFIT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
              Text(
                'Squat Analysis',
                style: TextStyle(
                  color: Colors.cyanAccent.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const Spacer(),

          // State pill
          _buildStatePill(),

          const SizedBox(width: 8),

          // FPS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_fps.toStringAsFixed(0)} fps',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ── STATE PILL ── */
  Widget _buildStatePill() {
    final exerciseState = _squat.exerciseState;
    final sqState = _squat.squatState;

    Color color;
    String text;
    IconData icon;

    switch (exerciseState) {
      case ExerciseState.notActivated:
        color = const Color(0xFFFF9800);
        text = 'Nod to Start';
        icon = Icons.accessibility_new;
        break;
      case ExerciseState.activated:
        color = _sqStateColor(sqState);
        text = _sqStateLabel(sqState);
        icon = Icons.directions_run;
        break;
      case ExerciseState.completed:
        color = const Color(0xFF00E676);
        text = 'Set Done!';
        icon = Icons.emoji_events;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _sqStateColor(SquatState s) {
    switch (s) {
      case SquatState.standing:
        return const Color(0xFF00E676);
      case SquatState.descending:
        return const Color(0xFFFFD600);
      case SquatState.bottom:
        return const Color(0xFFFF6D00);
      case SquatState.ascending:
        return const Color(0xFF00B0FF);
    }
  }

  String _sqStateLabel(SquatState s) {
    switch (s) {
      case SquatState.standing:
        return 'Standing';
      case SquatState.descending:
        return 'Going Down';
      case SquatState.bottom:
        return 'At Bottom';
      case SquatState.ascending:
        return 'Pushing Up';
    }
  }

  /* ── CAMERA + SKELETON STACK ── */
  Widget _buildCameraStack(CameraController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = Size(constraints.maxWidth, constraints.maxHeight);

        return ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: CameraPreview(controller)),

              if (_detectedPose != null)
                CustomPaint(
                  size: previewSize,
                  painter: PosePainter(
                    pose: _detectedPose!,
                    imageSize: _imageSize,
                    widgetSize: previewSize,
                    rotation: _imageRotation,
                    lensDirection: controller.description.lensDirection,
                    debugData: _squat.debugData,
                  ),
                ),

              // Gradient vignette overlay for better text readability
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                        stops: const [0.0, 0.15, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /* ── REP COUNT OVERLAY (big number, bottom-right of camera) ── */
  Widget _buildRepCountOverlay() {
    final isActive = _squat.exerciseState == ExerciseState.activated ||
        _squat.exerciseState == ExerciseState.completed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_repCount',
            style: TextStyle(
              color: isActive ? Colors.cyanAccent : Colors.white60,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REPS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              if (_squat.exerciseState == ExerciseState.activated)
                Text(
                  _squat.correctForm ? 'GOOD' : 'FIX',
                  style: TextStyle(
                    color: _squat.correctForm
                        ? const Color(0xFF00E676)
                        : const Color(0xFFFF5252),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /* ── REP DOTS (visual history strip) ── */
  Widget _buildRepDots() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _repLogs.map((log) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: log.correctForm
                    ? const Color(0xFF00E676)
                    : const Color(0xFFFF5252),
                boxShadow: [
                  BoxShadow(
                    color: (log.correctForm
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF5252))
                        .withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /* ── AFTER-REP BANNER (animated) ── */
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
              offset: Offset(0, -30 * (1.0 - _bannerAnimation.value)),
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
                    const Color(0xFF00E676).withValues(alpha: 0.9),
                    const Color(0xFF00C853).withValues(alpha: 0.9)
                  ]
                : [
                    const Color(0xFFFF5252).withValues(alpha: 0.9),
                    const Color(0xFFD50000).withValues(alpha: 0.9)
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (_repBannerGood
                      ? const Color(0xFF00E676)
                      : const Color(0xFFFF5252))
                  .withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 2,
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
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              _repBannerText!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ── COACHING INSTRUCTIONS BAR (status + tempo reminders) ── */
  Widget _buildInstructionsBar() {
    final instr = _squat.instructions;
    if (instr.isEmpty) return const SizedBox.shrink();

    // Separate status from coaching reminders
    final statusText = instr['Status'];
    final coachingEntries =
        instr.entries.where((e) => e.key != 'Status').toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0D1228),
            const Color(0xFF131A3A),
          ],
        ),
      ),
      child: Row(
        children: [
          // Status badge (Going Down / Hold Bottom / Push Up)
          if (statusText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _statusColor(statusText).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _statusColor(statusText).withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _statusIcon(statusText),
                    color: _statusColor(statusText),
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: _statusColor(statusText),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Coaching reminders from tempo (e.g. "Go down slower this time")
          if (coachingEntries.isNotEmpty) ...[
            if (statusText != null) const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: coachingEntries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFF9800).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                const Color(0xFFFF9800).withValues(alpha: 0.3),
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
                            const SizedBox(width: 5),
                            Text(
                              entry.value,
                              style: const TextStyle(
                                color: Color(0xFFFFB74D),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    if (status.contains('Down')) return const Color(0xFFFFD600);
    if (status.contains('Hold') || status.contains('Bottom'))
      return const Color(0xFFFF6D00);
    if (status.contains('Push') || status.contains('Up'))
      return const Color(0xFF00B0FF);
    return Colors.white70;
  }

  IconData _statusIcon(String status) {
    if (status.contains('Down')) return Icons.arrow_downward_rounded;
    if (status.contains('Hold') || status.contains('Bottom'))
      return Icons.pause_circle_outline;
    if (status.contains('Push') || status.contains('Up'))
      return Icons.arrow_upward_rounded;
    return Icons.info_outline;
  }

  /* ── LIVE FEEDBACK CARDS ── */
  Widget _buildFeedbackCards() {
    if (_feedback.isEmpty) return const SizedBox(height: 2);

    // Filter out "System" for separate display, and "Result" for banner
    final liveEntries =
        _feedback.entries.where((e) => e.key != 'Result').toList();

    if (liveEntries.isEmpty) return const SizedBox(height: 2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1228),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: liveEntries.map((entry) {
            final severity = _feedbackSeverity(entry.value);
            final color = _severityColor(severity);
            final icon = _severityIcon(severity);

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: color.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      entry.key,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
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
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  int _feedbackSeverity(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('good') ||
        lower.contains('deep') ||
        lower.contains('push')) return 0; // Good
    if (value.contains('!') ||
        lower.contains('lifting') ||
        lower.contains("don't") ||
        lower.contains('fix')) return 2; // Error
    return 1; // Neutral / warning
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1228),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Camera facing
          _buildMiniInfo(
            Icons.videocam_outlined,
            _squat.cameraFacing.toString().split('.').last.toUpperCase(),
          ),
          const SizedBox(width: 8),

          // Form status
          if (_squat.exerciseState == ExerciseState.activated)
            _buildMiniInfo(
              _squat.correctForm
                  ? Icons.verified_outlined
                  : Icons.warning_amber_rounded,
              _squat.correctForm ? 'Good Form' : 'Fix Form',
              color: _squat.correctForm
                  ? const Color(0xFF00E676)
                  : const Color(0xFFFF5252),
            ),

          const Spacer(),

          // Rep log toggle
          _buildToggleButton(
            icon: Icons.format_list_numbered,
            label: 'Log',
            isActive: _showRepLog,
            onTap: () => setState(() => _showRepLog = !_showRepLog),
          ),
          const SizedBox(width: 6),

          // Debug toggle
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
    final c = color ?? Colors.white.withValues(alpha: 0.4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: c, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.cyanAccent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? Colors.cyanAccent.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? Colors.cyanAccent
                  : Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.cyanAccent
                    : Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ── DEBUG PANEL (organized by category) ── */
  Widget _buildDebugPanel() {
    final d = _squat.debugData;
    if (d.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        color: const Color(0xFF080B18),
        child: Text(
          'Waiting for pose data...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 11,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF080B18),
        border: Border(
          top: BorderSide(
              color: Colors.cyanAccent.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.terminal,
                  size: 12, color: Colors.cyanAccent.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text(
                'DEBUG',
                style: TextStyle(
                  color: Colors.cyanAccent.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _debugChip(
                  'State', d['exerciseState'] ?? '?', const Color(0xFF00E5FF)),
              _debugChip(
                  'Squat', d['squatState'] ?? '?', const Color(0xFFFFD600)),
              _debugChip(
                  'Facing', d['cameraFacing'] ?? '?', const Color(0xFF7C4DFF)),
              _debugChip(
                  'Scale', d['scaleFactor'] ?? '?', const Color(0xFF607D8B)),
              _debugChip('Knee\u2220', '${d['kneeAngle'] ?? '?'}\u00B0',
                  const Color(0xFF00BCD4)),
              _debugChip(
                  'Trunk',
                  '${d['trunkLean'] ?? '?'} ${d['trunkLeanDir'] ?? ''}',
                  const Color(0xFFFF9800)),
              _debugChip(
                  'Descent', d['descentDur'] ?? '-', const Color(0xFF29B6F6)),
              _debugChip(
                  'Ascent', d['ascentDur'] ?? '-', const Color(0xFF4FC3F7)),
              _debugChip(
                  'BtmHold', d['bottomHold'] ?? '-', const Color(0xFFFF6D00)),
              _debugChip(
                  'D:A Ratio', d['ratio'] ?? '-', const Color(0xFFAB47BC)),
              _debugChip(
                'Form',
                d['correctForm'] ?? '?',
                d['correctForm'] == 'true'
                    ? const Color(0xFF00E676)
                    : const Color(0xFFFF5252),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _debugChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                color: color.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ── REP LOG / SET SUMMARY PANEL ── */
  Widget _buildRepLogPanel() {
    if (_repLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF080B18),
        child: Text(
          'No reps completed yet.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 12,
          ),
        ),
      );
    }

    final goodCount = _repLogs.where((r) => r.correctForm).length;
    final badCount = _repLogs.where((r) => !r.correctForm).length;
    final isSetComplete = _squat.exerciseState == ExerciseState.completed;

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: const Color(0xFF080B18),
        border: Border(
          top: BorderSide(
            color: (isSetComplete ? const Color(0xFF00E676) : Colors.cyanAccent)
                .withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(
                  isSetComplete ? Icons.emoji_events : Icons.analytics,
                  size: 16,
                  color: isSetComplete
                      ? const Color(0xFFFFD600)
                      : Colors.cyanAccent.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  isSetComplete ? 'SET SUMMARY' : 'REP LOG',
                  style: TextStyle(
                    color: isSetComplete
                        ? const Color(0xFFFFD600)
                        : Colors.cyanAccent.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                _buildMiniStat('$goodCount', 'good', const Color(0xFF00E676)),
                const SizedBox(width: 10),
                _buildMiniStat('$badCount', 'fix', const Color(0xFFFF5252)),
              ],
            ),
          ),

          // Rep list
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              shrinkWrap: true,
              itemCount: _repLogs.length,
              itemBuilder: (context, index) {
                final log = _repLogs[index];
                return _buildRepLogCard(log);
              },
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
            color: color.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRepLogCard(RepLog log) {
    final color =
        log.correctForm ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    final faults = log.allFaultMessages;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Rep number badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(
                '${log.repNumber}',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Details
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
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      log.correctForm ? 'Good Rep' : 'Issues Found',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (log.tempo != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF29B6F6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          log.tempo!,
                          style: const TextStyle(
                            color: Color(0xFF29B6F6),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (faults.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    faults.join(' \u2022 '),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
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
   POSE PAINTER — Accurate Skeleton Overlay
   ========================================================================= */

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize; // Effective image size (after rotation swap)
  final Size widgetSize; // The canvas/widget size
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

  /* Fixed body skeleton connections */
  static const List<List<PoseLandmarkType>> _bodyConnections = [
    // Torso
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    // Left arm
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    // Right arm
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    // Left leg
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel],
    [PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex],
    [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex],
    // Right leg
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel],
    [PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex],
    [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex],
  ];

  /* Map of body part colors for visual clarity */
  static final Map<PoseLandmarkType, Color> _landmarkColors = {
    // Left side → cyan
    PoseLandmarkType.leftShoulder: Colors.cyanAccent,
    PoseLandmarkType.leftElbow: Colors.cyanAccent,
    PoseLandmarkType.leftWrist: Colors.cyanAccent,
    PoseLandmarkType.leftHip: Colors.cyanAccent,
    PoseLandmarkType.leftKnee: Colors.cyanAccent,
    PoseLandmarkType.leftAnkle: Colors.cyanAccent,
    PoseLandmarkType.leftHeel: Colors.cyanAccent,
    PoseLandmarkType.leftFootIndex: Colors.cyanAccent,
    // Right side → yellow
    PoseLandmarkType.rightShoulder: Colors.yellowAccent,
    PoseLandmarkType.rightElbow: Colors.yellowAccent,
    PoseLandmarkType.rightWrist: Colors.yellowAccent,
    PoseLandmarkType.rightHip: Colors.yellowAccent,
    PoseLandmarkType.rightKnee: Colors.yellowAccent,
    PoseLandmarkType.rightAnkle: Colors.yellowAccent,
    PoseLandmarkType.rightHeel: Colors.yellowAccent,
    PoseLandmarkType.rightFootIndex: Colors.yellowAccent,
    // Head → white
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

    /* ── Coordinate transformation ──
       ML Kit returns coordinates in the image space.
       On Android with rotation90, the effective coordinate space is
       (imageHeight × imageWidth). We scale to the widget/canvas size.
       
       The CameraPreview widget may not fill the canvas exactly (aspect ratio
       mismatch), so we compute the actual preview rect within the canvas and
       offset our drawing accordingly.
    */
    final double imageW = imageSize.width;
    final double imageH = imageSize.height;
    final double canvasW = size.width;
    final double canvasH = size.height;

    // Compute the area the camera preview occupies (aspect-fit centered)
    final double imageAspect = imageW / imageH;
    final double canvasAspect = canvasW / canvasH;

    double previewW, previewH, offsetX, offsetY;
    if (imageAspect > canvasAspect) {
      // Image is wider → pillarbox (black bars top/bottom)
      previewW = canvasW;
      previewH = canvasW / imageAspect;
      offsetX = 0;
      offsetY = (canvasH - previewH) / 2;
    } else {
      // Image is taller → letterbox (black bars left/right)
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

      // On Android, ML Kit with rotation90 returns coords in
      // the rotated coordinate space. Scale directly.
      // On iOS the coords are in the original space.
      if (Platform.isAndroid) {
        switch (rotation) {
          case InputImageRotation.rotation90deg:
            x = lm.x;
            y = lm.y;
            break;
          case InputImageRotation.rotation270deg:
            x = imageW - lm.x;
            y = imageH - lm.y;
            break;
          default:
            break;
        }
      }

      // Front camera mirror
      if (lensDirection == CameraLensDirection.front) {
        x = imageW - x;
      }

      return Offset(x * scaleX + offsetX, y * scaleY + offsetY);
    }

    /* ── Draw skeleton lines ── */
    for (final connection in _bodyConnections) {
      final lm1 = landmarks[connection[0]];
      final lm2 = landmarks[connection[1]];
      if (lm1 == null || lm2 == null) continue;
      if (lm1.likelihood < 0.5 || lm2.likelihood < 0.5) continue;

      final p1 = transformPoint(lm1);
      final p2 = transformPoint(lm2);

      // Determine line color based on confidence
      final avgConf = (lm1.likelihood + lm2.likelihood) / 2;
      final lineColor = avgConf > 0.8
          ? Colors.greenAccent.withValues(alpha: 0.7)
          : Colors.orangeAccent.withValues(alpha: 0.5);

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = lineColor
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
    }

    /* ── Draw landmark dots ── */
    for (final entry in landmarks.entries) {
      final lm = entry.value;
      if (lm.likelihood < 0.5) continue;

      final point = transformPoint(lm);
      final color = _landmarkColors[entry.key] ?? Colors.white;

      // Outer glow
      canvas.drawCircle(
        point,
        6,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill,
      );
      // Inner dot
      canvas.drawCircle(
        point,
        4,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }

    /* ── Draw angle labels at key joints ── */
    _drawAngleLabels(canvas, landmarks, transformPoint);
  }

  /* Draw angle values next to key joints for debugging */
  void _drawAngleLabels(
    Canvas canvas,
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    Offset Function(PoseLandmark) transformPoint,
  ) {
    // Knee angle
    final knee = landmarks[PoseLandmarkType.leftKnee] ??
        landmarks[PoseLandmarkType.rightKnee];
    if (knee != null && knee.likelihood > 0.5) {
      final kneePos = transformPoint(knee);
      final kneeAngle = debugData['kneeAngle'];
      if (kneeAngle != null) {
        _drawLabel(
            canvas, kneePos + const Offset(12, -8), '$kneeAngle°', Colors.cyan);
      }
    }

    // Trunk lean (at shoulder)
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ??
        landmarks[PoseLandmarkType.rightShoulder];
    if (shoulder != null && shoulder.likelihood > 0.5) {
      final shoulderPos = transformPoint(shoulder);
      final trunkLean = debugData['trunkLean'];
      if (trunkLean != null) {
        _drawLabel(canvas, shoulderPos + const Offset(12, -8), '$trunkLean',
            Colors.orange);
      }
    }
  }

  void _drawLabel(Canvas canvas, Offset position, String text, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
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

    // Background rect
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        position.dx - 2,
        position.dy - 2,
        textPainter.width + 4,
        textPainter.height + 4,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      bgRect,
      Paint()..color = Colors.black54,
    );

    textPainter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) => true;
}
