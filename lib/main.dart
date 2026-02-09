// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'exercise/exercise_base.dart';
import 'exercise/squat.dart';

/* =========================================================================
   APP ENTRY POINT
   ========================================================================= */

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait so coordinate math stays consistent
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  _cameras = await availableCameras();
  runApp(const VinaFitApp());
}

class VinaFitApp extends StatelessWidget {
  const VinaFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VinaFit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const ExerciseScreen(),
    );
  }
}

/* =========================================================================
   EXERCISE SCREEN — Camera + Pose + Overlay
   ========================================================================= */

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with WidgetsBindingObserver {
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

  // ── Debug toggle ──
  bool _showDebug = true;

  // ── FPS counter ──
  int _frameCount = 0;
  DateTime _lastFpsTime = DateTime.now();
  double _fps = 0;

  /* ----------------------------------------------------------------------- */

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _poseDetector.close();
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

    // Prefer back camera (side-view usage).
    // Fall back to first available.
    _cameraIndex = _cameras
        .indexWhere((cam) => cam.lensDirection == CameraLensDirection.back);
    if (_cameraIndex == -1) _cameraIndex = 0;

    final camera = _cameras[_cameraIndex];

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium, // 480×640 — good balance
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      _isCameraReady = true;

      // Start processing frames
      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }

    if (mounted) setState(() {});
  }

  /* -----------------------------------------------------------------------
     IMAGE → POSE PIPELINE
     ----------------------------------------------------------------------- */
  void _processCameraImage(CameraImage cameraImage) {
    if (_isDetecting) return;
    _isDetecting = true;

    _detectPose(cameraImage).then((_) {
      _isDetecting = false;
    });
  }

  Future<void> _detectPose(CameraImage cameraImage) async {
    try {
      final inputImage = _buildInputImage(cameraImage);
      if (inputImage == null) return;

      // Run ML Kit
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        final pose = poses.first;
        _detectedPose = pose;

        // Feed into exercise logic
        _result = _squat.processPose(pose.landmarks);

        if (_result != null && _result!.length == 2) {
          _repCount = _result![0] as int;
          _feedback = Map<String, String>.from(_result![1] as Map);
        }
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
      debugPrint('Detection error: $e');
    }
  }

  /* -----------------------------------------------------------------------
     BUILD InputImage FROM CameraImage
     ----------------------------------------------------------------------- */
  InputImage? _buildInputImage(CameraImage image) {
    final camera = _cameras[_cameraIndex];
    final rotation = _rotationFromSensor(camera.sensorOrientation);
    _imageRotation = rotation;

    // On Android with rotation 90/270, the effective display size swaps w/h
    if (rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg) {
      _imageSize = Size(image.height.toDouble(), image.width.toDouble());
    } else {
      _imageSize = Size(image.width.toDouble(), image.height.toDouble());
    }

    final format =
        Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888;

    // Concatenate all planes into a single byte buffer
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

  /* -----------------------------------------------------------------------
     BUILD UI
     ----------------------------------------------------------------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child:
            !_isCameraReady ? _buildLoadingView() : _buildCameraView(context),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Starting camera…', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildCameraView(BuildContext context) {
    final controller = _cameraController!;

    return Column(
      children: [
        // ── Top bar ──
        _buildTopBar(),

        // ── Camera + Skeleton overlay ──
        Expanded(child: _buildCameraStack(controller)),

        // ── Status bar: Rep count + State ──
        _buildStatusBar(),

        // ── Feedback chips ──
        _buildFeedbackRow(),

        // ── Debug panel (toggleable) ──
        if (_showDebug) _buildDebugPanel(),
      ],
    );
  }

  /* ── TOP BAR ── */
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.black54,
      child: Row(
        children: [
          const Icon(Icons.fitness_center, color: Colors.tealAccent, size: 22),
          const SizedBox(width: 8),
          const Text(
            'VinaFit — Squat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // FPS badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_fps.toStringAsFixed(0)} fps',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          // Debug toggle
          IconButton(
            icon: Icon(
              _showDebug ? Icons.bug_report : Icons.bug_report_outlined,
              color: _showDebug ? Colors.tealAccent : Colors.white54,
            ),
            iconSize: 22,
            onPressed: () => setState(() => _showDebug = !_showDebug),
            tooltip: 'Toggle debug panel',
          ),
        ],
      ),
    );
  }

  /* ── CAMERA + SKELETON STACK ── */
  Widget _buildCameraStack(CameraController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = Size(constraints.maxWidth, constraints.maxHeight);

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview — fill entire area
              Center(child: CameraPreview(controller)),

              // Skeleton overlay — drawn on top
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

              // State indicator overlay (top-left of camera)
              Positioned(
                top: 8,
                left: 8,
                child: _buildStateOverlay(),
              ),
            ],
          ),
        );
      },
    );
  }

  /* ── STATE OVERLAY (on camera view) ── */
  Widget _buildStateOverlay() {
    final exerciseState = _squat.exerciseState;
    final sqState = _squat.squatState;

    Color stateColor;
    String stateText;
    IconData stateIcon;

    switch (exerciseState) {
      case ExerciseState.notActivated:
        stateColor = Colors.orange;
        stateText = 'Nod to Start';
        stateIcon = Icons.accessibility_new;
        break;
      case ExerciseState.activated:
        stateColor = _sqStateColor(sqState);
        stateText = _sqStateLabel(sqState);
        stateIcon = Icons.directions_run;
        break;
      case ExerciseState.completed:
        stateColor = Colors.blue;
        stateText = 'Set Complete!';
        stateIcon = Icons.check_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: stateColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stateIcon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            stateText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _sqStateColor(SquatState s) {
    switch (s) {
      case SquatState.standing:
        return Colors.green;
      case SquatState.descending:
        return Colors.amber;
      case SquatState.bottom:
        return Colors.deepOrange;
      case SquatState.ascending:
        return Colors.lightBlue;
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

  /* ── STATUS BAR ── */
  Widget _buildStatusBar() {
    final isActive = _squat.exerciseState == ExerciseState.activated;
    final formOk = _squat.correctForm;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black87,
      child: Row(
        children: [
          // Rep counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.repeat, color: Colors.tealAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$_repCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'reps',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Form indicator
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: formOk
                    ? Colors.green.withOpacity(0.25)
                    : Colors.red.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: formOk
                        ? Colors.greenAccent.withOpacity(0.5)
                        : Colors.redAccent.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(
                    formOk ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: formOk ? Colors.greenAccent : Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formOk ? 'Good Form' : 'Fix Form',
                    style: TextStyle(
                      color: formOk ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Camera facing badge
          _buildBadge(
            'Cam: ${_squat.cameraFacing.toString().split('.').last}',
            Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
    );
  }

  /* ── FEEDBACK ROW ── */
  Widget _buildFeedbackRow() {
    if (_feedback.isEmpty) return const SizedBox(height: 4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.black87,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _feedback.entries.map((entry) {
            final isGood = entry.value.toLowerCase().contains('good') ||
                entry.value.contains('Deep') ||
                entry.value.contains('Push');
            final isWarning = entry.value.contains('!') ||
                entry.value.contains('lifting') ||
                entry.value.contains('Lower') ||
                entry.value.contains("Don't");

            Color chipColor = Colors.teal;
            if (isWarning)
              chipColor = Colors.red.shade700;
            else if (isGood)
              chipColor = Colors.green.shade700;
            else
              chipColor = Colors.amber.shade800;

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Chip(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                backgroundColor: chipColor.withOpacity(0.85),
                label: Text(
                  '${entry.key}: ${entry.value}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            );
          }).toList(),
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
        color: Colors.black.withOpacity(0.9),
        child: const Text(
          'Debug: waiting for pose data…',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black.withOpacity(0.92),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _debugChip('State', d['exerciseState'] ?? '?', Colors.teal),
          _debugChip('Squat', d['squatState'] ?? '?', Colors.amber),
          _debugChip('Knee∠', '${d['kneeAngle'] ?? '?'}°', Colors.cyan),
          _debugChip(
              'Trunk',
              '${d['trunkLean'] ?? '?'} ${d['trunkLeanDir'] ?? ''}',
              Colors.orange),
          _debugChip(
              'BackClk', '${d['backClockAngle'] ?? '?'}°', Colors.purple),
          _debugChip('HeelDist', d['heelDist'] ?? '?', Colors.pink),
          _debugChip('HeelNorm', d['heelNorm'] ?? '?', Colors.pink.shade300),
          _debugChip('Scale', d['scaleFactor'] ?? '?', Colors.blueGrey),
          // ─── Facing Detection Debug ───
          _debugChip('Facing', d['cameraFacing'] ?? '?', Colors.indigo),
          _debugChip('L.x', d['leftS_x'] ?? '?', Colors.lime),
          _debugChip('R.x', d['rightS_x'] ?? '?', Colors.lime),
          _debugChip('ShWidth', d['shoulderWidth'] ?? '?', Colors.lightGreen),
          _debugChip('TorsoH', d['torsoHeight'] ?? '?', Colors.lightGreen),
          _debugChip('Ratio', d['facingRatio'] ?? '?', Colors.yellow),
          _debugChip('FrontTh', '>${d['frontThresh'] ?? '?'}', Colors.grey),
          _debugChip('SideTh', '<${d['sideThresh'] ?? '?'}', Colors.grey),
          // ─────────────────────────────
          _debugChip('Form', d['correctForm'] ?? '?',
              d['correctForm'] == 'true' ? Colors.green : Colors.red),
        ],
      ),
    );
  }

  Widget _debugChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
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
          ? Colors.greenAccent.withOpacity(0.7)
          : Colors.orangeAccent.withOpacity(0.5);

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
          ..color = color.withOpacity(0.3)
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
