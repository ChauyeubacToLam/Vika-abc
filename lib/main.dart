import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// IMPORT YOUR LOGIC FILES
import 'exercise/squat.dart';
import 'exercise/exercise_base.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error: ${e.code}\n${e.description}');
  }
  runApp(const MaterialApp(home: VinaFitApp()));
}

class VinaFitApp extends StatefulWidget {
  const VinaFitApp({Key? key}) : super(key: key);

  @override
  State<VinaFitApp> createState() => _VinaFitAppState();
}

class _VinaFitAppState extends State<VinaFitApp> {
  CameraController? _controller;
  PoseDetector? _poseDetector;
  bool _isBusy = false;

  // --- VINAFIT LOGIC ENGINE ---
  final Squat _squatLogic = Squat();

  // --- UI STATE ---
  Map<String, String> _feedbackMap = {};
  String _repCount = "0";
  String _statusMessage = "Initializing...";
  Color _statusColor = Colors.grey;

  // Summary State
  bool _isWorkoutComplete = false;
  List<Map<String, dynamic>> _summaryData = [];

  CustomPainter? _customPainter;

  @override
  void initState() {
    super.initState();
    // 1. SETUP POSE DETECTOR (Accurate Model is CRITICAL for Z-axis)
    _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
            mode: PoseDetectionMode.stream,
            model: PoseDetectionModel.accurate));
    _initializeCamera();
  }

  void _initializeCamera() async {
    if (cameras.isEmpty) return;

    // 2. SETUP CAMERA
    // Medium Resolution (480p/720p) is the sweet spot for performance vs accuracy
    var camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      _controller!.startImageStream(_processCameraImage);
      setState(() {});
    } catch (e) {
      print("Camera Init Error: $e");
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy || _isWorkoutComplete) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isEmpty) {
        if (mounted) {
          setState(() {
            _customPainter = null;
            _statusMessage = "No User Detected";
            _statusColor = Colors.orange;
          });
        }
        return;
      }

      // --- RUN LOGIC ---
      final pose = poses.first;
      final result = _squatLogic.processPose(pose.landmarks);

      if (mounted) {
        setState(() {
          // 1. Check for Completion
          if (_squatLogic.exerciseState == ExerciseState.completed) {
            _isWorkoutComplete = true;
            _summaryData = result as List<Map<String, dynamic>>;
            _customPainter = null;
            return;
          }

          // 2. Active State Update
          if (result != null) {
            _repCount = result[0].toString();
            _feedbackMap = result[1] as Map<String, String>;

            // Extract System Status for the top bar
            if (_feedbackMap.containsKey("System")) {
              _statusMessage = _feedbackMap["System"]!;
              _statusColor = Colors.blueAccent;
              _feedbackMap.remove("System"); // Don't show system msg in cards
            } else if (_feedbackMap.containsKey("Result")) {
              _statusMessage = _feedbackMap["Result"]!;
              _statusColor = _statusMessage.contains("Good")
                  ? Colors.green
                  : Colors.orange;
              _feedbackMap.remove("Result");
            } else {
              _statusMessage = "Active";
              _statusColor = Colors.green;
            }
          }

          // 3. Update Painter
          _customPainter = PosePainter(
            pose: pose,
            absoluteImageSize:
                Size(image.width.toDouble(), image.height.toDouble()),
            rotation: inputImage.metadata?.rotation ??
                InputImageRotation.rotation0deg,
            cameraLensDirection: _controller!.description.lensDirection,
          );
        });
      }
    } catch (e) {
      print("Logic Error: $e");
    } finally {
      _isBusy = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. SHOW SUMMARY SCREEN IF DONE
    if (_isWorkoutComplete) {
      return _buildSummaryScreen();
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator()));
    }

    // 2. CAMERA LAYOUT (Cover Mode)
    final Size size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A. Camera Feed
          Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(_controller!)),
          ),

          // B. Skeleton Overlay
          if (_customPainter != null)
            Transform.scale(
              scale: scale,
              child: CustomPaint(painter: _customPainter),
            ),

          // C. Top Status Bar (Glassmorphism)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4))
                  ]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _statusMessage.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.0),
                  ),
                ],
              ),
            ),
          ),

          // D. Main HUD (Rep Counter & Feedback)
          Positioned(
            top: 120,
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rep Counter (Big & Bold)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24, width: 1)),
                      child: Column(
                        children: [
                          const Text("REPS",
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          Text(_repCount,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(), // Pushes feedback to the bottom

                // Feedback Cards
                ..._feedbackMap.entries.map((entry) {
                  bool isError = entry.value.toLowerCase().contains("too") ||
                      entry.value.toLowerCase().contains("don't") ||
                      entry.value.toLowerCase().contains("go lower") ||
                      entry.value.toLowerCase().contains("lifted");

                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: isError
                            ? Colors.redAccent.withOpacity(0.9)
                            : Colors.green.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ]),
                    child: Row(
                      children: [
                        Icon(
                            isError
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                            color: Colors.white,
                            size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.key.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                              Text(entry.value,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SUMMARY SCREEN ---
  Widget _buildSummaryScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text("Workout Summary"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _summaryData.length,
        itemBuilder: (context, index) {
          final repData = _summaryData[index];
          final Map faults = repData.values.first as Map;
          final bool isGood = faults.isEmpty;
          final int repNum = index + 1;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isGood ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  "Rep $repNum",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                subtitle: Text(
                  isGood ? "Perfect Form" : "${faults.length} Issues Detected",
                  style: const TextStyle(color: Colors.white70),
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.black26,
                  child: Icon(isGood ? Icons.star : Icons.priority_high,
                      color: Colors.white),
                ),
                children: faults.isEmpty
                    ? []
                    : faults.entries.map<Widget>((phaseEntry) {
                        String phase = phaseEntry.key;
                        Map errors = phaseEntry.value;
                        return Container(
                          color: Colors.black12,
                          child: ListTile(
                            title: Text(phase,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: errors.entries
                                  .map((e) => Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline,
                                                size: 14,
                                                color: Colors.white70),
                                            const SizedBox(width: 6),
                                            Text("${e.key}: ${e.value}",
                                                style: const TextStyle(
                                                    color: Colors.white)),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        );
                      }).toList(),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Restart logic
          setState(() {
            _isWorkoutComplete = false;
            _repCount = "0";
            _summaryData.clear();
          });
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const VinaFitApp()));
        },
        label: const Text("Start New Set"),
        icon: const Icon(Icons.refresh),
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- CAMERA HELPER ---
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      final camera = _controller!.description;
      final rotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg;
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }
}

// --- 3D SKELETON PAINTER (HIGH PRECISION) ---
class PosePainter extends CustomPainter {
  final Pose pose;
  final Size absoluteImageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  PosePainter({
    required this.pose,
    required this.absoluteImageSize,
    required this.rotation,
    required this.cameraLensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Define Paint Styles
    final paintLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap =
          StrokeCap.round; // Rounds the ends of lines for smoother look

    final paintJointBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white;

    final paintJointFill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withOpacity(0.6); // Semi-transparent center

    // 2. Define Connections
    final List<List<PoseLandmarkType>> connections = [
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    ];

    // 3. Draw Connections with Z-Axis Depth Color
    for (final connection in connections) {
      final start = connection[0];
      final end = connection[1];
      final p1 = pose.landmarks[start];
      final p2 = pose.landmarks[end];

      if (p1 != null &&
          p2 != null &&
          p1.likelihood > 0.6 &&
          p2.likelihood > 0.6) {
        // Calculate depth color based on the average Z of the two points
        double avgZ = (p1.z + p2.z) / 2;
        paintLine.color = getDepthColor(avgZ);

        canvas.drawLine(
            Offset(translateX(p1.x, rotation, size, absoluteImageSize),
                translateY(p1.y, rotation, size, absoluteImageSize)),
            Offset(translateX(p2.x, rotation, size, absoluteImageSize),
                translateY(p2.y, rotation, size, absoluteImageSize)),
            paintLine);
      }
    }

    // 4. Draw Precision Joints (Bullseye Look)
    pose.landmarks.forEach((_, landmark) {
      if (landmark.likelihood > 0.6) {
        final center = Offset(
            translateX(landmark.x, rotation, size, absoluteImageSize),
            translateY(landmark.y, rotation, size, absoluteImageSize));

        // Draw Outer White Ring
        canvas.drawCircle(center, 5.0, paintJointBorder);
        // Draw Inner Depth-Colored Fill
        paintJointFill.color = getDepthColor(landmark.z);
        canvas.drawCircle(center, 3.0, paintJointFill);
      }
    });
  }

  // Helper: Convert Z-value (Depth) to Color
  // Z < 0: Close (Red)
  // Z > 0: Far (Blue)
  // Z range is roughly -300 to +300 for full body
  Color getDepthColor(double z) {
    // Normalize Z to range -1.0 to 1.0 (assuming max depth ~300)
    double normalized = (z / 300.0).clamp(-1.0, 1.0);

    if (normalized < 0) {
      // Coming towards camera -> Lerp to RED
      return Color.lerp(Colors.white, Colors.redAccent, normalized.abs())!;
    } else {
      // Going away -> Lerp to BLUE
      return Color.lerp(Colors.white, Colors.blueAccent, normalized)!;
    }
  }

  // Coordinate Translation Helpers
  double translateX(double x, InputImageRotation rotation, Size size,
      Size absoluteImageSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return x *
            size.width /
            (Platform.isIOS
                ? absoluteImageSize.width
                : absoluteImageSize.height);
      default:
        // Mirror logic for front camera
        if (cameraLensDirection == CameraLensDirection.front) {
          return size.width - (x * size.width / absoluteImageSize.width);
        }
        return x * size.width / absoluteImageSize.width;
    }
  }

  double translateY(double y, InputImageRotation rotation, Size size,
      Size absoluteImageSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y *
            size.height /
            (Platform.isIOS
                ? absoluteImageSize.height
                : absoluteImageSize.width);
      default:
        return y * size.height / absoluteImageSize.height;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
