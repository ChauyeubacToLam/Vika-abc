// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';
import 'dart:math' as math;
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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  _cameras = await availableCameras();
  runApp(const VinaFitApp());
}

/* =========================================================================
   REP LOG
   ========================================================================= */

class RepLog {
  final int repNumber;
  final bool correctForm;
  final Map<String, Map<String, String>> faults;
  final String? tempo;
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
   APP
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
        scaffoldBackgroundColor: const Color(0xFF080C1A),
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

  // ── FPS ──
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
            if (_repCount > prevRepCount) {
              _logRepCompletion();
            }
          }
        }

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
     LOGGING
     ----------------------------------------------------------------------- */
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

  void _logRepCompletion() {
    if (_repCount <= _lastLoggedRep) return;
    _lastLoggedRep = _repCount;

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

    final faultMap = <String, Map<String, String>>{};
    if (_squat.setFeedback.isNotEmpty) {
      final lastEntry = _squat.setFeedback.last;
      for (final entry in lastEntry.entries) {
        for (final phaseEntry in entry.value.entries) {
          faultMap[phaseEntry.key] = Map<String, String>.from(phaseEntry.value);
        }
      }
    }

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

    debugPrint('[VinaFit][Rep] $log');
    debugPrint(
        '[VinaFit][Feedback] ${_feedback.entries.map((e) => '${e.key}: ${e.value}').join(' | ')}');

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

  /* =======================================================================
     BUILD
     ======================================================================= */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C1A),
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
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(
                  Colors.cyanAccent.withValues(alpha: 0.8)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Đang khởi động camera...',
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

  /* ── MAIN LAYOUT ── */
  Widget _buildCameraView(BuildContext context) {
    final controller = _cameraController!;
    final isCompleted = _squat.exerciseState == ExerciseState.completed;

    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Stack(
            children: [
              _buildCameraStack(controller),
              _buildRepBanner(),
              Positioned(
                bottom: 12,
                right: 12,
                child: _buildRepCountOverlay(),
              ),
              if (_repLogs.isNotEmpty)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: _buildRepDots(),
                ),
              // Floating coaching chips (right side of camera)
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF080C1A),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Icon(Icons.fitness_center,
                color: Color(0xFF00E5FF), size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VINAFIT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
              Text(
                'Phân tích Squat',
                style: TextStyle(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildStatePill(),
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
    final exerciseState = _squat.exerciseState;
    final sqState = _squat.squatState;

    Color color;
    String text;
    IconData icon;

    switch (exerciseState) {
      case ExerciseState.notActivated:
        color = const Color(0xFFFF9800);
        text = 'Gật đầu để bắt đầu';
        icon = Icons.accessibility_new;
        break;
      case ExerciseState.activated:
        color = _sqStateColor(sqState);
        text = _sqStateLabel(sqState);
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
        return 'Đứng thẳng';
      case SquatState.descending:
        return 'Xuống';
      case SquatState.bottom:
        return 'Giữ';
      case SquatState.ascending:
        return 'Đứng lên';
    }
  }

  /* ── CAMERA + SKELETON ── */
  Widget _buildCameraStack(CameraController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
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
            // Subtle vignette
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
          ],
        );
      },
    );
  }

  /* ── REP COUNT OVERLAY ── */
  Widget _buildRepCountOverlay() {
    final isActive = _squat.exerciseState == ExerciseState.activated ||
        _squat.exerciseState == ExerciseState.completed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$_repCount',
            style: TextStyle(
              color: isActive ? const Color(0xFF00E5FF) : Colors.white60,
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
                  'REPS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                if (_squat.exerciseState == ExerciseState.activated)
                  Text(
                    _squat.correctForm ? '✓ TỐT' : '✗ SỬA',
                    style: TextStyle(
                      color: _squat.correctForm
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

  /* ── INSTRUCTIONS BAR (Status badge only — coaching moved to camera overlay) ── */
  Widget _buildInstructionsBar() {
    // Read instructions for the current squat phase
    final phaseKey = _squat.squatState.toString().split('.').last;
    final phaseInstr = _squat.resultIssues.instructions[phaseKey];
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

  /* ── STATUS BADGE (with arc countdown for Hold phase) ── */
  Widget _buildStatusBadge(String statusText) {
    final isHold = statusText.startsWith('Hold') ||
        statusText.startsWith('Giữ') ||
        statusText.contains('!') && _squat.squatState == SquatState.bottom;

    final progress = isHold
        ? (_squat.debugData['bottomHoldProgress'] as double? ?? 0.0)
        : null;

    final color = _statusColor(statusText);

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
          if (progress != null) ...[
            // Circular countdown arc
            SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(
                painter: _ArcCountdownPainter(
                  progress: progress,
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

  Widget _buildCoachingChip(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF9800).withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.tips_and_updates_outlined,
            color: Color(0xFFFFB74D),
            size: 12,
          ),
          const SizedBox(width: 5),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFFFFB74D),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /* ── FLOATING COACHING CHIPS (right side of camera view) ── */
  /// Shows coaching instructions from previous rep as floating pills
  /// on the camera view. Like a PT standing beside you whispering tips.
  /// Only visible during standing phase (before next rep starts).
  Widget _buildCoachingOverlay() {
    // Collect coaching entries for the current phase (exclude Status)
    final phaseKey = _squat.squatState.toString().split('.').last;
    final phaseInstr = _squat.resultIssues.instructions[phaseKey];

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

  Color _statusColor(String status) {
    if (status.contains('Xuống') || status.contains('Down'))
      return const Color(0xFFFFD600);
    if (status.contains('Giữ') ||
        status.contains('Hold') ||
        status.contains('Bottom')) return const Color(0xFFFF6D00);
    if (status.contains('Đứng lên') ||
        status.contains('Push') ||
        status.contains('Up')) return const Color(0xFF00B0FF);
    return Colors.white70;
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
              border:
                  Border.all(color: color.withValues(alpha: 0.25), width: 1),
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
        lower.contains('fix')) return 2;
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
            _squat.cameraFacing.toString().split('.').last.toUpperCase(),
          ),
          const SizedBox(width: 8),
          if (_squat.exerciseState == ExerciseState.activated)
            _buildMiniInfo(
              _squat.correctForm
                  ? Icons.verified_outlined
                  : Icons.warning_amber_rounded,
              _squat.correctForm ? 'Tư thế tốt' : 'Sửa tư thế',
              color: _squat.correctForm
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive
                  ? const Color(0xFF00E5FF)
                  : Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? const Color(0xFF00E5FF)
                    : Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ── DEBUG PANEL ── */
  Widget _buildDebugPanel() {
    final d = _squat.debugData;
    if (d.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        color: const Color(0xFF060A16),
        child: Text(
          'Waiting for pose data...',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2), fontSize: 10),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: const Color(0xFF060A16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal,
                  size: 11,
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Text(
                'DEBUG',
                style: TextStyle(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
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
            children: [
              _debugChip(
                  'State', d['exerciseState'] ?? '?', const Color(0xFF00E5FF)),
              _debugChip(
                  'Squat', d['squatState'] ?? '?', const Color(0xFFFFD600)),
              _debugChip(
                  'Facing', d['cameraFacing'] ?? '?', const Color(0xFF7C4DFF)),
              _debugChip(
                  'Scale', d['scaleFactor'] ?? '?', const Color(0xFF607D8B)),
              _debugChip('Knee∠', '${d['kneeAngle'] ?? '?'}°',
                  const Color(0xFF00BCD4)),
              // _debugChip(
              //     'Trunk',
              //     '${d['trunkLean'] ?? '?'} ${d['trunkLeanDir'] ?? ''}',
              //     const Color(0xFFFF9800)),
              // _debugChip(
              //     'Descent', d['descentDur'] ?? '-', const Color(0xFF29B6F6)),
              // _debugChip(
              //     'Ascent', d['ascentDur'] ?? '-', const Color(0xFF4FC3F7)),
              // _debugChip(
              //     'BtmHold', d['bottomHold'] ?? '-', const Color(0xFFFF6D00)),
              // _debugChip('D:A', d['ratio'] ?? '-', const Color(0xFFAB47BC)),
              // _debugChip(
              //   'Form',
              //   d['correctForm'] ?? '?',
              //   d['correctForm'] == 'true'
              //       ? const Color(0xFF00E676)
              //       : const Color(0xFFFF5252),
              _debugChip(
                  "Hip speed", d['hipSpeed'] ?? '?', const Color(0xFF00E5FF)),
              _debugChip("Shoulder Speed", d['shoulderSpeed'] ?? '?',
                  const Color(0xFFFFD600)),
              _debugChip(
                  "Sync Ratio", d['syncRatio'] ?? '?', const Color(0xFF4CAF50)),
              _debugChip("Peak Sync Ratio", d['peakSyncRatio'] ?? '?',
                  const Color(0xFF00E5FF)),
              // ),
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
          'Chưa có lượt squat nào.',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25), fontSize: 11),
        ),
      );
    }

    final goodCount = _repLogs.where((r) => r.correctForm).length;
    final badCount = _repLogs.where((r) => !r.correctForm).length;
    final isSetComplete = _squat.exerciseState == ExerciseState.completed;

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
                      : const Color(0xFF00E5FF).withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  isSetComplete ? 'KẾT QUẢ BÀI TẬP' : 'LỊCH SỬ REP',
                  style: TextStyle(
                    color: isSetComplete
                        ? const Color(0xFFFFD600)
                        : const Color(0xFF00E5FF).withValues(alpha: 0.5),
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
              color: color, fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
              color: color.withValues(alpha: 0.55),
              fontSize: 10,
              fontWeight: FontWeight.w600),
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
                    color: color, fontSize: 12, fontWeight: FontWeight.w800),
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
                          fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (log.tempo != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
   Draws a circular progress arc for the bottom hold countdown.
   ========================================================================= */

class _ArcCountdownPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color color;

  const _ArcCountdownPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Progress arc — starts at top (−π/2), sweeps clockwise
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

    // Center dot when complete
    if (progress >= 1.0) {
      canvas.drawCircle(
        center,
        2.5,
        Paint()..color = color,
      );
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
            x = imageW - lm.x;
            y = imageH - lm.y;
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

    // Draw skeleton lines
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

    // Draw landmark dots
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
    if (knee != null && knee.likelihood > 0.5) {
      final kneePos = transformPoint(knee);
      final kneeAngle = debugData['kneeAngle'];
      if (kneeAngle != null) {
        _drawLabel(
            canvas, kneePos + const Offset(12, -8), '$kneeAngle°', Colors.cyan);
      }
    }

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
  bool shouldRepaint(covariant PosePainter oldDelegate) => true;
}
