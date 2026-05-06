import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_metadata.dart';
import '../../debug/debug_panel.dart';
import '../../debug/debug_preferences.dart';
import '../../debug/debug_types.dart';
import '../../exercise/exercise_base.dart';
import '../../pose/pose_landmarker_adapter.dart';
import '../../pose/pose_landmarker_channel.dart';
import '../../models/exercise_definition.dart';
import '../../utils/exercise_logger.dart';
import '../../theme/vf_theme.dart';
import 'widgets/form_score_arc.dart';
import 'widgets/ivory_chrome.dart';
import 'widgets/pose_overlay_painter.dart';
import 'widgets/system_banner.dart';

class ActiveExercisePage extends StatefulWidget {
  const ActiveExercisePage({
    super.key,
    required this.definition,
    required this.exercise,
    required this.currentSet,
    required this.totalSets,
    required this.totalReps,
    required this.onSetComplete,
    required this.onBack,
  });

  final ExerciseDefinition definition;
  final ExerciseBase exercise;
  final int currentSet;
  final int totalSets;
  final int totalReps;
  final ValueChanged<ExerciseLogger> onSetComplete;
  final VoidCallback onBack;

  @override
  State<ActiveExercisePage> createState() => _ActiveExercisePageState();
}

class _ActiveExercisePageState extends State<ActiveExercisePage>
    with TickerProviderStateMixin {
  final PoseLandmarkerChannel _poseChannel = PoseLandmarkerChannel();
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.accurate,
      mode: PoseDetectionMode.stream,
    ),
  );

  StreamSubscription<Map<String, dynamic>>? _landmarkSubscription;
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = const [];
  int? _textureId;
  int _cameraIndex = -1;
  CameraLensDirection _currentLens = CameraLensDirection.back;
  PermissionStatus? _permissionStatus;
  bool _isInitializing = false;
  bool _isProcessingFrame = false;
  bool _isCameraReady = false;
  bool _didComplete = false;
  String? _cameraErrorMessage;
  Map<String, String> _feedback = {};
  Pose? _detectedPose;
  Size _imageSize = Size.zero;
  InputImageRotation _imageRotation = InputImageRotation.rotation0deg;
  late final AnimationController _pulseController;
  ExerciseVoiceCoach? _voiceCoach;

  // ─── Ivory v8 state ───
  int _setElapsedSeconds = 0;
  Timer? _setTimer;
  // TODO(form-score): Replace with real computed form score from ML pipeline
  static const int _hardcodedFormScore = 82;
  // TODO(chart): Replace with real sparkline data from primaryAngleForChart
  static const List<int> _hardcodedSparkData = [
    72,
    78,
    84,
    80,
    76,
    82,
    86,
    88,
    84,
    82
  ];
  // TODO(integration): Replace with real fault indices from RepLog.faults
  static const List<int> _hardcodedFaultIndices = [2];
  bool _isManualPause = false;
  _PoseRuntime _runtime = _PoseRuntime.nativeMediaPipe;
  DebugMode _settingsDebugMode = DebugMode.off;
  bool _isStaffUser = false;
  bool _debugPanelOpen = false;
  String? _expandedMetricId;
  int _debugBackTapCount = 0;
  DateTime? _debugFirstBackTap;
  Timer? _pendingStaffBackTimer;
  DateTime? _lastPersonDetectionAt;
  bool _personDetectionInFlight = false;
  static const Duration _personDetectionInterval = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _voiceCoach = widget.exercise.createVoiceCoach();
    _loadDebugMode();
    _startSetTimer();
    _initCamera();
  }

  @override
  void dispose() {
    _setTimer?.cancel();
    _pendingStaffBackTimer?.cancel();
    final landmarkSubscription = _landmarkSubscription;
    _landmarkSubscription = null;
    unawaited(landmarkSubscription?.cancel() ?? Future<void>.value());
    unawaited(_disposeFallbackCamera());
    unawaited(_poseChannel.dispose().catchError((_) {}));
    _poseDetector.close();
    unawaited(widget.exercise.disposeDetectors());
    _voiceCoach?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadDebugMode() async {
    final isStaff = await _loadStaffFlag();
    final mode = await DebugPreferences.loadMode();
    if (!mounted) return;
    _isStaffUser = isStaff;
    final resolved = _resolveDebugMode(mode);
    setState(() {
      _settingsDebugMode = mode;
      _isStaffUser = isStaff;
      _debugPanelOpen = resolved != DebugMode.off;
    });
  }

  DebugMode _resolveDebugMode(DebugMode settingsValue) {
    return DebugModeResolver.resolve(
      isStaff: _isStaffUser,
      settingsValue: settingsValue,
    );
  }

  Future<bool> _loadStaffFlag() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return false;

    try {
      final row = await client
          .from('profiles')
          .select('is_staff')
          .eq('id', user.id)
          .maybeSingle();
      final value = row?['is_staff'];
      if (value == true || value == 'true') {
        return true;
      }
    } catch (_) {
      // Keep the dev menu non-fatal if the column has not shipped yet.
    }

    final metadataValue = user.appMetadata['is_staff'];
    return metadataValue == true || metadataValue == 'true';
  }

  Future<void> _applyDebugMode(DebugMode mode) async {
    await DebugPreferences.saveMode(mode);
    if (!mounted) return;
    final resolved = _resolveDebugMode(mode);
    setState(() {
      _settingsDebugMode = mode;
      _debugPanelOpen = resolved != DebugMode.off;
      if (resolved == DebugMode.off) {
        _expandedMetricId = null;
      }
    });
  }

  void _handleBackChromeTap() {
    if (!_isStaffUser) {
      widget.onBack();
      return;
    }

    final openedMenu = _recordStaffBackTap();
    _pendingStaffBackTimer?.cancel();
    if (openedMenu) return;

    _pendingStaffBackTimer = Timer(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      _debugBackTapCount = 0;
      _debugFirstBackTap = null;
      widget.onBack();
    });
  }

  bool _recordStaffBackTap() {
    final now = DateTime.now();
    if (_debugFirstBackTap == null ||
        now.difference(_debugFirstBackTap!) > const Duration(seconds: 3)) {
      _debugFirstBackTap = now;
      _debugBackTapCount = 1;
    } else {
      _debugBackTapCount++;
    }

    if (_debugBackTapCount < 5) return false;

    _debugBackTapCount = 0;
    _debugFirstBackTap = null;
    _showDevModeSheet();
    return true;
  }

  void _showDevModeSheet() {
    if (!_isStaffUser) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            decoration: BoxDecoration(
              color: VikaIvory.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Debug mode',
                  style: TextStyle(
                    fontFamily: VikaIvory.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: VikaIvory.ink,
                  ),
                ),
                const SizedBox(height: 8),
                for (final mode in DebugMode.values)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_applyDebugMode(mode));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _settingsDebugMode == mode
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 20,
                            color: _settingsDebugMode == mode
                                ? VikaIvory.yellowDeep
                                : VikaIvory.inkFaint,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            switch (mode) {
                              DebugMode.off => 'Off',
                              DebugMode.user => 'User',
                              DebugMode.dev => 'Dev',
                            },
                            style: TextStyle(
                              fontFamily: VikaIvory.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: VikaIvory.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _initCamera() async {
    await _disposeFallbackCamera();
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _isCameraReady = false;
        _cameraErrorMessage = null;
        _textureId = null;
      });
    }

    final status = await Permission.camera.request();
    _permissionStatus = status;
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isCameraReady = false;
          _cameraErrorMessage = status.isPermanentlyDenied
              ? 'Quyền camera đang bị chặn. Hãy mở lại trong cài đặt.'
              : 'Cần quyền camera để AI theo dõi bài tập.';
        });
      }
      return;
    }

    try {
      _ensureLandmarkSubscription();
      final textureId = await _poseChannel.initialize(
        useFrontCamera: _currentLens == CameraLensDirection.front,
      );
      await _poseChannel.startDetection();
      if (!mounted) return;

      setState(() {
        _runtime = _PoseRuntime.nativeMediaPipe;
        _textureId = textureId;
        _isCameraReady = true;
        _isInitializing = false;
      });
    } on PlatformException catch (error) {
      if (_shouldUseMlKitFallback(error)) {
        await _startMlKitFallback(error.message);
        return;
      }
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isCameraReady = false;
          _textureId = null;
          _cameraErrorMessage = error.message ??
              'Khong the khoi dong MediaPipe tren thiet bi nay.';
        });
      }
    } on MissingPluginException catch (_) {
      // Native MediaPipe channel not implemented on this platform (e.g. iOS)
      // → fallback to Flutter camera + ML Kit
      await _startMlKitFallback('Native pose landmarker not available on iOS');
    } catch (_) {
      // Any other error → also try ML Kit fallback
      await _startMlKitFallback('Unknown camera init error');
    }
  }

  Future<void> _toggleCamera() async {
    final nextLens = _currentLens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _cameraErrorMessage = null;
      });
    }

    try {
      if (_runtime == _PoseRuntime.mlKitFallback) {
        await _switchMlKitCamera(nextLens);
        if (!mounted) return;
        setState(() {
          _isInitializing = false;
        });
        return;
      }

      await _poseChannel.switchCamera();
      if (!mounted) return;

      setState(() {
        _currentLens = nextLens;
        _isInitializing = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _cameraErrorMessage = 'Khong the chuyen camera. Hay thu lai.';
        });
      }
    }
  }

  void _ensureLandmarkSubscription() {
    if (_landmarkSubscription != null) {
      return;
    }

    _landmarkSubscription = _poseChannel.landmarkStream.listen(
      _handleLandmarkEvent,
      onError: _handleLandmarkStreamError,
    );
  }

  Future<void> _handleLandmarkEvent(Map<String, dynamic> data) async {
    if (_isProcessingFrame || _didComplete) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final inputImage = PoseLandmarkerAdapter.inputImageFromChannelData(data);
      _schedulePersonDetection(inputImage);

      _currentLens = PoseLandmarkerAdapter.lensDirectionFromChannelData(data);
      _imageRotation =
          PoseLandmarkerAdapter.inputImageRotationFromChannelData(data);
      _imageSize =
          PoseLandmarkerAdapter.imageSizeFromChannelData(data) ?? Size.zero;

      final pose = PoseLandmarkerAdapter.fromChannelData(data);
      if (pose != null) {
        _handlePose(pose);
      } else {
        _detectedPose = null;
        _feedback = widget.exercise.processNoPoseFrame();
        _processVoiceFrame(hasPose: false);
      }

      if (mounted) {
        setState(() {});
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _handlePoseResult(List<dynamic>? result) {
    if (result != null &&
        result.length == 2 &&
        result.first is int &&
        result[1] is Map) {
      _feedback = Map<String, String>.from(result[1] as Map);
      _processVoiceFrame(hasPose: true);
      return;
    }

    _processVoiceFrame(hasPose: _detectedPose != null);

    if (widget.exercise.exerciseState == ExerciseState.completed &&
        !_didComplete) {
      _didComplete = true;
      unawaited(_poseChannel.stopDetection());
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          widget.onSetComplete(widget.exercise.logger);
        }
      });
    }
  }

  void _handleLandmarkStreamError(Object error) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isInitializing = false;
      _isCameraReady = false;
      _cameraErrorMessage = 'Khong the nhan du lieu pose. Hay thu lai.';
    });
  }

  Future<void> _startMlKitFallback(String? nativeErrorMessage) async {
    debugPrint(
      '[Vika] Falling back to Flutter camera + ML Kit: ${nativeErrorMessage ?? "unknown native init error"}',
    );
    try {
      await _poseChannel.dispose();
    } catch (_) {}
    await _initMlKitCamera();
  }

  bool _shouldUseMlKitFallback(PlatformException error) {
    final message = (error.message ?? '').toLowerCase();
    return message.contains('mediapipe') ||
        message.contains('x86_64') ||
        message.contains('native library') ||
        message.contains('pose landmarker') ||
        message.contains('unsupported');
  }

  Future<void> _initMlKitCamera() async {
    await _disposeFallbackCamera();

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (!mounted) return;
      setState(() {
        _runtime = _PoseRuntime.mlKitFallback;
        _isInitializing = false;
        _isCameraReady = false;
        _cameraErrorMessage = 'Khong tim thay camera tren thiet bi nay.';
      });
      return;
    }

    _availableCameras = cameras;
    final camerasToTry = <int>[];
    final preferredIndex = cameras.indexWhere(
      (camera) => camera.lensDirection == _currentLens,
    );
    if (preferredIndex != -1) {
      camerasToTry.add(preferredIndex);
    }
    for (int index = 0; index < cameras.length; index++) {
      if (!camerasToTry.contains(index)) {
        camerasToTry.add(index);
      }
    }

    for (final index in camerasToTry) {
      final camera = cameras[index];
      debugPrint(
        '[Vika] Trying fallback camera ${camera.name} (${camera.lensDirection.name})',
      );
      final controller = CameraController(
        camera,
        // High = 1280x720, gives the widest 16:9 framing while staying within ML Kit's
        // performance envelope on iOS (the fallback path).
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      try {
        await controller.initialize().timeout(const Duration(seconds: 6));
        await controller.startImageStream(_processFallbackCameraImage);
        if (!mounted) {
          await controller.dispose();
          return;
        }

        setState(() {
          _runtime = _PoseRuntime.mlKitFallback;
          _cameraController = controller;
          _cameraIndex = index;
          _currentLens = camera.lensDirection;
          _textureId = null;
          _isCameraReady = true;
          _isInitializing = false;
          _cameraErrorMessage = null;
        });
        return;
      } catch (error) {
        debugPrint('[Vika] Fallback camera ${camera.name} failed: $error');
        try {
          await controller.dispose();
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _runtime = _PoseRuntime.mlKitFallback;
      _isInitializing = false;
      _isCameraReady = false;
      _cameraErrorMessage = 'Khong the khoi dong camera fallback. Hay thu lai.';
    });
  }

  Future<void> _switchMlKitCamera(CameraLensDirection nextLens) async {
    if (_availableCameras.isEmpty) {
      _availableCameras = await availableCameras();
    }
    final newIndex = _availableCameras.indexWhere(
      (camera) => camera.lensDirection == nextLens,
    );
    if (newIndex == -1) {
      throw StateError('Requested camera is not available.');
    }

    await _disposeFallbackCamera();

    final camera = _availableCameras[newIndex];
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await controller.initialize();
    await controller.startImageStream(_processFallbackCameraImage);
    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _cameraController = controller;
      _cameraIndex = newIndex;
      _currentLens = camera.lensDirection;
      _isCameraReady = true;
    });
  }

  Future<void> _disposeFallbackCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller == null) {
      return;
    }
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }

  void _processFallbackCameraImage(CameraImage cameraImage) {
    if (_isProcessingFrame || _didComplete) {
      return;
    }
    _isProcessingFrame = true;
    _detectPoseFromFallback(cameraImage).whenComplete(() {
      _isProcessingFrame = false;
    });
  }

  Future<void> _detectPoseFromFallback(CameraImage cameraImage) async {
    try {
      final inputImage = _buildInputImage(cameraImage);
      if (inputImage == null) {
        return;
      }

      _schedulePersonDetection(inputImage);
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        _handlePose(poses.first);
      } else {
        _detectedPose = null;
        _feedback = widget.exercise.processNoPoseFrame();
        _processVoiceFrame(hasPose: false);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCameraReady = false;
        _cameraErrorMessage = 'Khong the nhan du lieu pose. Hay thu lai.';
      });
    }
  }

  void _handlePose(Pose pose) {
    _detectedPose = pose;
    _handlePoseResult(widget.exercise.processPose(pose.landmarks));
  }

  void _schedulePersonDetection(InputImage? inputImage) {
    if (inputImage == null ||
        _personDetectionInFlight ||
        widget.exercise.exerciseState == ExerciseState.completed) {
      return;
    }

    final now = DateTime.now();
    final lastRun = _lastPersonDetectionAt;
    if (lastRun != null && now.difference(lastRun) < _personDetectionInterval) {
      return;
    }

    _lastPersonDetectionAt = now;
    _personDetectionInFlight = true;
    unawaited(
      widget.exercise
          .runPersonDetection(inputImage)
          .catchError((Object _) {})
          .whenComplete(() {
        _personDetectionInFlight = false;
      }),
    );
  }

  void _processVoiceFrame({required bool hasPose}) {
    final coach = _voiceCoach;
    if (coach == null) {
      return;
    }

    coach.processFrame(
      exercise: widget.exercise,
      repCount: widget.exercise.repCount,
      hasPose: hasPose,
      feedback: _feedback,
    );
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_cameraIndex < 0 || _cameraIndex >= _availableCameras.length) {
      return null;
    }

    final camera = _availableCameras[_cameraIndex];
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

  void _startSetTimer() {
    _setElapsedSeconds = 0;
    _setTimer?.cancel();
    _setTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.exercise.isPaused) return;
      if (widget.exercise.exerciseState != ExerciseState.activated) return;
      setState(() => _setElapsedSeconds++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final permissionGranted = _permissionStatus?.isGranted ?? true;
    if (!permissionGranted) {
      return _buildCameraFallback(
        icon: Icons.camera_alt_outlined,
        title: 'Cần quyền camera',
        subtitle: _cameraErrorMessage ??
            'Hãy cấp quyền camera để AI theo dõi bài tập của bạn.',
        actionLabel: _permissionStatus?.isPermanentlyDenied == true
            ? 'Mở cài đặt'
            : 'Cấp quyền',
        onAction: _permissionStatus?.isPermanentlyDenied == true
            ? openAppSettings
            : _initCamera,
      );
    }

    if (!_isCameraReady || _textureId == null) {
      final waitingForFallback =
          _runtime == _PoseRuntime.mlKitFallback && _cameraController == null;
      final nativeReady =
          _runtime == _PoseRuntime.nativeMediaPipe && _textureId != null;
      final fallbackReady =
          _runtime == _PoseRuntime.mlKitFallback && _cameraController != null;
      if (nativeReady || fallbackReady) {
        return _buildActiveLayout(context);
      }
      return _buildCameraFallback(
        icon: _cameraErrorMessage == null
            ? Icons.videocam_outlined
            : Icons.videocam_off_outlined,
        title: _cameraErrorMessage == null
            ? 'Đang chuẩn bị camera'
            : 'Camera chưa sẵn sàng',
        subtitle: _cameraErrorMessage ??
            (_isInitializing || waitingForFallback
                ? 'AI đang kết nối camera và chuẩn bị theo dõi form của bạn.'
                : 'Đang chờ camera sẵn sàng...'),
        actionLabel: _cameraErrorMessage == null ? null : 'Thử lại',
        onAction: _cameraErrorMessage == null ? null : _initCamera,
      );
    }

    return _buildActiveLayout(context);
  }

  Widget _buildCameraFallback({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      color: const Color(0xFF080C1A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: VFTheme.jadeGlow),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.68),
                  height: 1.5,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VFTheme.jade,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveLayout(BuildContext context) {
    final media = MediaQuery.of(context);
    final overlayState = _overlayState;
    final bottomHoldCue = _bottomHoldCue;
    final guidanceCopy = _currentGuidanceCopy;
    final coachMessage = _coachMessage;
    final activeState =
        widget.exercise.exerciseState == ExerciseState.activated &&
            !widget.exercise.isPaused;
    final trackedMetrics = widget.exercise.trackedDebugMetrics;
    final debugMode = trackedMetrics.isEmpty
        ? DebugMode.off
        : _resolveDebugMode(_settingsDebugMode);
    final debugEnabled = debugMode != DebugMode.off;
    final showDebugEntryBadge =
        trackedMetrics.isNotEmpty && (debugEnabled || _isStaffUser);
    final showDebugPanel = debugEnabled && _debugPanelOpen;

    // Derive ivory phase verb from squat state machine phases.
    // Standing = default resting position (not a "ready" state).
    final phaseKey = widget.exercise.currentPhaseKey;
    final isHoldPhase = bottomHoldCue != null;
    String phaseVerb;
    String phaseHint;
    switch (phaseKey) {
      case 'descending':
        phaseVerb = 'XUỐNG';
        phaseHint = 'Hạ chậm, kiểm soát';
      case 'bottom':
        phaseVerb = 'GIỮ';
        phaseHint = 'Giữ đáy, ổn định';
      case 'ascending':
        phaseVerb = 'LÊN';
        phaseHint = 'Đẩy sàn xuống';
      default: // 'standing' or any other
        phaseVerb = 'XUỐNG';
        phaseHint = 'Bắt đầu hạ người';
    }

    // TODO(caption): Wire mid-rep fault detection caption here
    final showCaption = activeState &&
        coachMessage.isNotEmpty &&
        !showDebugPanel &&
        guidanceCopy == null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Camera preview ──
          RepaintBoundary(
            child: ColoredBox(
              color: Colors.black,
              child: ClipRect(
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: _previewRenderSize.width,
                      height: _previewRenderSize.height,
                      child: _runtime == _PoseRuntime.nativeMediaPipe
                          ? Texture(textureId: _textureId!)
                          : (_cameraController != null
                              ? CameraPreview(_cameraController!)
                              : const SizedBox.shrink()),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Layer 2: Skeleton overlay (unchanged — jade colors preserved) ──
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (_detectedPose == null || _imageSize == Size.zero) {
                    return const SizedBox.shrink();
                  }
                  return CustomPaint(
                    size: constraints.biggest,
                    painter: PoseOverlayPainter(
                        pose: _detectedPose!,
                        imageSize: _imageSize,
                        rotation: _imageRotation,
                        lensDirection: _currentLens,
                        debugData: widget.exercise.debugData,
                        style: SkeletonStyle.vikaCream),
                  );
                },
              ),
            ),
          ),

          // ── Layer 3: Top scrim — anchors the status bar + top chrome
          // row against the camera scene. Fades to transparent by ~140 px
          // so the live body area stays bright.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromRGBO(15, 11, 9, 0.78),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Layer 4: Bottom scrim — anchors the phase verb + rep
          // counter. Stronger alpha than the top scrim because the bottom
          // carries more glass-on-bright-scene text and a wider safe-area.
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color.fromRGBO(15, 11, 9, 0.92),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Layer 4: Top chrome left (back + HIỆP pill) ──
          Positioned(
            top: media.padding.top + 10,
            left: 16,
            child: IvoryTopChromeLeft(
              currentSet: widget.currentSet,
              totalSets: widget.totalSets,
              setSeconds: _setElapsedSeconds,
              onBack: _handleBackChromeTap,
            ),
          ),

          // ── Layer 5: Top chrome right (form arc + flip + pause) ──
          // JSX v8: form arc lives inline with the icon buttons. The pulse pill
          // is the "minimal richness" alternative and is deliberately omitted —
          // we ship at the medium-richness default (form arc visible).
          Positioned(
            top: media.padding.top + 10,
            right: 16,
            child: IvoryTopChromeRight(
              // TODO(form-score): Replace _hardcodedFormScore with the real
              // computed form score from the ML pipeline (per-rep average or
              // rolling window).
              formScore: _hardcodedFormScore,
              onPause: () {
                _isManualPause = true;
                widget.exercise.manualPause();
                setState(() {});
              },
              onFlipCamera: _toggleCamera,
              debugBadge: showDebugEntryBadge
                  ? DebugIndicatorBadge(
                      mode: debugEnabled ? debugMode : DebugMode.dev,
                      panelOpen: debugEnabled && _debugPanelOpen,
                      onToggle: () {
                        if (!debugEnabled) {
                          _showDevModeSheet();
                          return;
                        }
                        setState(() {
                          _debugPanelOpen = !_debugPanelOpen;
                        });
                      },
                    )
                  : null,
            ),
          ),

          // ── Layer 6: Sparkline (below top-right chrome row) ──
          // JSX positions sparkline ~6px under the chrome row (top:112 with
          // chrome at top:64). In Flutter that maps to chrome top + chrome
          // height (44) + 4 ≈ media.padding.top + 58.
          if (activeState && !debugEnabled && guidanceCopy == null)
            Positioned(
              top: media.padding.top + 58,
              right: 16,
              // TODO(chart): Replace _hardcodedSparkData with the real rolling
              // 10s form-score history coming out of the ML pipeline.
              child: const IvoryFormScoreSparkline(data: _hardcodedSparkData),
            ),

          // ── Layer 7: PT reference loop (top-left, just below chrome row) ──
          // JSX places it at top:116 (16px below chrome bottom). chrome bottom
          // = media.padding.top + 10 + 36 = +46, so PT loop sits at +56.
          if (activeState &&
              !(debugEnabled && _debugPanelOpen) &&
              guidanceCopy == null)
            Positioned(
              top: media.padding.top + 56,
              left: 16,
              child: const IvoryPTReferenceLoop(),
            ),

          // ── Layer 8: Coach caption (center lower-third) ──
          if (showCaption)
            Positioned(
              left: 24,
              right: 24,
              bottom: media.padding.bottom + 156,
              child: IvoryCoachCaption(message: coachMessage),
            ),

          // ── Layer 9: Setup/safety guidance panel ──
          if (guidanceCopy != null && !widget.exercise.isPaused)
            Positioned(
              left: 20,
              right: 20,
              top: media.padding.top + 78,
              child: IgnorePointer(
                child: _SetupGuidancePanel(
                  copy: guidanceCopy,
                ),
              ),
            ),

          // ── Layer 10: Center overlay (scan/warn/position/hold) ──
          IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: overlayState == _LiveOverlayState.active ||
                      guidanceCopy != null
                  ? const SizedBox.shrink()
                  : Center(
                      key: ValueKey<_LiveOverlayState>(overlayState),
                      child: _CenterOverlay(
                        state: overlayState,
                        pulseController: _pulseController,
                        progress: widget.exercise.activationProgress,
                        holdCue: bottomHoldCue,
                      ),
                    ),
            ),
          ),

          // ── Layer 12: Bottom chrome (phase verb + rep counter) ──
          if (activeState && !showDebugPanel)
            Positioned(
              left: 24,
              right: 24,
              bottom: media.padding.bottom + 36,
              child: IvoryBottomChrome(
                phaseVerb: phaseVerb,
                phaseHint: phaseHint,
                repCount: widget.exercise.repCount,
                totalReps: widget.totalReps,
                isHoldPhase: isHoldPhase,
                holdProgress: bottomHoldCue?.progress,
                holdRemaining: bottomHoldCue?.remaining,
                // TODO(integration): Wire RepLog.faults into faultIndices
                faultIndices: _hardcodedFaultIndices,
              ),
            ),

          // ── Layer 13: Pause overlay ──
          if (widget.exercise.isPaused)
            Positioned.fill(
              child: IvoryPauseOverlay(
                isManualPause: _isManualPause,
                onResume: () {
                  _isManualPause = false;
                  widget.exercise.manualResume();
                  setState(() {});
                },
                onEnd: widget.onBack,
              ),
            ),

          // ── Layer 14: Debug/back escape chrome above blocking overlays ──
          if (widget.exercise.isPaused)
            Positioned(
              top: media.padding.top + 10,
              left: 16,
              child: IvoryTopChromeLeft(
                currentSet: widget.currentSet,
                totalSets: widget.totalSets,
                setSeconds: _setElapsedSeconds,
                onBack: widget.onBack,
              ),
            ),
          if (widget.exercise.isPaused && showDebugEntryBadge)
            Positioned(
              top: media.padding.top + 10,
              right: 16,
              child: DebugIndicatorBadge(
                mode: debugEnabled ? debugMode : DebugMode.dev,
                panelOpen: debugEnabled && _debugPanelOpen,
                onToggle: () {
                  if (!debugEnabled) {
                    _showDevModeSheet();
                    return;
                  }
                  setState(() {
                    _debugPanelOpen = !_debugPanelOpen;
                  });
                },
              ),
            ),

          // ── Layer 15: Debug panel ──
          if (showDebugPanel)
            Positioned(
              left: 12,
              right: 12,
              bottom: media.padding.bottom + 16,
              child: DebugPanel(
                mode: debugMode,
                metrics: trackedMetrics,
                expandedMetricId: _expandedMetricId,
                onToggleExpand: (metricId) {
                  setState(() {
                    _expandedMetricId =
                        _expandedMetricId == metricId ? null : metricId;
                  });
                },
                phaseLabel: debugMode == DebugMode.dev
                    ? widget.exercise.currentPhaseKey
                    : widget.exercise.currentPhaseLabel,
                repCount: widget.exercise.repCount,
                totalReps: widget.totalReps,
                setSeconds: _setElapsedSeconds,
                fps: widget.exercise.currentFps,
                frameTimestampMs: widget.exercise.frameTimestampMs,
                confidence: widget.exercise.personPresenceScore,
                footerLabel:
                    '${widget.exercise.exerciseName} · ${AppMetadata.displayVersion}',
                onMinimize: () {
                  setState(() => _debugPanelOpen = false);
                },
              ),
            ),
        ],
      ),
    );
  }

  _LiveOverlayState get _overlayState {
    if (widget.exercise.isPaused) {
      return _LiveOverlayState.paused;
    }

    final guidance = _currentGuidanceCopy;
    if (guidance != null) {
      return switch (guidance.mode) {
        SystemBannerMode.scan => _LiveOverlayState.scan,
        SystemBannerMode.warn => _LiveOverlayState.warn,
        SystemBannerMode.pause => _LiveOverlayState.paused,
        SystemBannerMode.info => _LiveOverlayState.position,
      };
    }

    if ((_feedback['System'] ?? '').isNotEmpty &&
        widget.exercise.exerciseState == ExerciseState.activated) {
      return _LiveOverlayState.position;
    }

    if (widget.exercise.exerciseState == ExerciseState.activated) {
      if (_bottomHoldCue != null) {
        return _LiveOverlayState.hold;
      }
      return _LiveOverlayState.active;
    }
    if (widget.exercise.activationProgress != null) {
      return _LiveOverlayState.hold;
    }
    return _LiveOverlayState.position;
  }

  _GuidanceCopy? get _currentGuidanceCopy {
    final raw = _feedback['System'];
    if (raw == null || raw.trim().isEmpty) return null;
    return _guidanceForSystemMessage(raw);
  }

  _GuidanceCopy? _guidanceForSystemMessage(String rawMessage) {
    final message = _translateSystemMessage(rawMessage);
    final normalized = message.toLowerCase();
    final rawNormalized = rawMessage.toLowerCase();

    if (normalized.contains('giữ yên')) {
      return null;
    }

    if (rawNormalized.contains('turn to the side') ||
        normalized.contains('quay ngang') ||
        normalized.contains('quay nghiêng') ||
        normalized.contains('quay sang bên')) {
      return const _GuidanceCopy(
        icon: Icons.screen_rotation_alt_rounded,
        title: 'Quay ngang người',
        body:
            'Đứng ngang với camera để AI thấy vai, hông, gối và cổ chân rõ hơn.',
        mode: SystemBannerMode.warn,
      );
    }
    if (normalized.contains('quay mặt')) {
      return const _GuidanceCopy(
        icon: Icons.center_focus_strong_rounded,
        title: 'Quay mặt về camera',
        body: 'Đứng đối diện camera để AI thấy hai bên cơ thể rõ hơn.',
        mode: SystemBannerMode.warn,
      );
    }
    if (rawNormalized.contains('adjust lighting') ||
        rawNormalized.contains('lighting') ||
        normalized.contains('ánh sáng') ||
        normalized.contains('hình ảnh không rõ')) {
      return const _GuidanceCopy(
        icon: Icons.light_mode_rounded,
        title: 'Tăng ánh sáng',
        body:
            'Đứng nơi sáng hơn hoặc tránh ngược sáng để AI nhận landmark ổn định.',
        mode: SystemBannerMode.warn,
      );
    }
    if (rawNormalized.contains('body not fully visible') ||
        normalized.contains('toàn thân') ||
        normalized.contains('phần trên cơ thể') ||
        normalized.contains('trong khung hình') ||
        normalized.contains('vai, hông') ||
        normalized.contains('vai, hông và gối')) {
      return const _GuidanceCopy(
        icon: Icons.fit_screen_rounded,
        title: 'Đưa toàn thân vào khung',
        body:
            'Lùi lại một chút hoặc hạ máy để thấy vai, hông, gối, cổ chân và bàn chân.',
        mode: SystemBannerMode.warn,
      );
    }
    if (normalized.contains('đang tìm người')) {
      return const _GuidanceCopy(
        icon: Icons.person_search_rounded,
        title: 'Đang tìm người',
        body: 'Đứng trong khung hình và giữ toàn thân rõ để bắt đầu theo dõi.',
        mode: SystemBannerMode.scan,
      );
    }
    if (normalized.contains('vào tư thế') ||
        normalized.contains('đứng trong khung') ||
        normalized.contains('bắt đầu')) {
      return _GuidanceCopy(
        icon: Icons.accessibility_new_rounded,
        title: 'Vào tư thế bắt đầu',
        body: message,
        mode: SystemBannerMode.info,
      );
    }

    return null;
  }

  String _translateSystemMessage(String raw) {
    if (raw.contains('Please turn to the side')) {
      return 'Quay ngang người để AI theo dõi tốt hơn';
    }
    if (raw.contains('Body not fully visible')) {
      return 'Giữ toàn thân trong khung hình';
    }
    if (raw.contains('Adjust lighting/position')) {
      return 'Điều chỉnh ánh sáng hoặc vị trí để AI nhận rõ hơn';
    }
    if (raw.contains('⏸') || raw.contains('⚸')) {
      return 'Tạm dừng. Quay lại khung hình để tiếp tục';
    }
    return raw.replaceAll('⚠️ ', '').replaceAll('⏸ ', '').replaceAll('⚸ ', '');
  }

  Map<String, String>? get _currentPhaseInstructions {
    return widget
        .exercise.resultIssues.instructions[widget.exercise.currentPhaseKey];
  }

  String? get _currentPhaseStatus => _currentPhaseInstructions?['Status'];

  _BottomHoldCue? get _bottomHoldCue {
    if (widget.exercise.exerciseState != ExerciseState.activated) {
      return null;
    }

    final status = _currentPhaseStatus;
    if (status == null || status.isEmpty) {
      return null;
    }

    final isHolding = _isHoldStatus(status);
    final isRelease = _isReleaseStatus(status);
    if (!isHolding && !isRelease) {
      return null;
    }

    final progress =
        (_readDebugNumber(widget.exercise.debugData['bottomHoldProgress']) ??
                _readDebugNumber(widget.exercise.debugData['holdProgress']) ??
                0.0)
            .clamp(0.0, 1.0)
            .toDouble();

    return _BottomHoldCue(
      progress: isRelease ? 1.0 : progress,
      remaining: _extractDurationSeconds(status),
      readyToPush: isRelease,
    );
  }

  bool _isHoldStatus(String value) =>
      value.contains('Hold') || value.contains('Giữ');

  bool _isReleaseStatus(String value) {
    return value.contains('Push Up Now!') ||
        value.contains('Push Up!') ||
        value.contains('Đứng lên') ||
        value.contains('Lên') ||
        value.contains('đẩy lên');
  }

  String get _coachMessage {
    final phaseInstructions = _currentPhaseInstructions;
    if (phaseInstructions != null) {
      for (final entry in phaseInstructions.entries) {
        if (entry.key == 'Status') {
          continue;
        }
        return _translateInstruction(entry.value);
      }
    }

    final status = _currentPhaseStatus;
    if (status != null && status.isNotEmpty) {
      return _translateStatus(status);
    }

    final result = _feedback['Result'];
    if (result != null && result.isNotEmpty) {
      return _translateResult(result);
    }
    return 'Giữ nhịp đều và kiểm soát toàn bộ chuyển động.';
  }

  double? _readDebugNumber(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  String _translateInstruction(String value) {
    if (value.contains('Keep chest up')) {
      return 'Mở ngực hơn ở rep tới để giữ thân trên vững.';
    }
    if (value.contains('Heels lifting')) {
      return 'Ấn gót xuống sàn để squat chắc hơn.';
    }
    if (value.contains('Dropped too fast')) {
      return 'Hạ chậm hơn để AI bắt trọn chuyển động.';
    }
    if (value.contains('pause')) {
      return 'Giữ đáy thêm một nhịp rồi mới đứng lên.';
    }
    if (value == 'Going Down...') {
      return 'Hạ người chậm và kiểm soát.';
    }
    if (value == 'Đứng lên') {
      return 'Đứng lên dứt khoát.';
    }
    if (value == 'Push Up!') {
      return 'Đứng lên mạnh nhưng vẫn giữ thân chắc.';
    }
    return value
        .replaceAll('Going Down...', 'Hạ người chậm xuống.')
        .replaceAll('Push Up Now!', 'Đứng lên dứt khoát.')
        .replaceAll('Hold!', 'Giữ vững.');
  }

  String _translateResult(String value) {
    if (value == 'Good Rep!' || value == 'Tốt lắm!') {
      return 'Rep đẹp. Giữ nhịp này.';
    }
    if (value == 'Fix Form') {
      return 'Điều chỉnh lại form ở rep tiếp theo.';
    }
    return value;
  }

  String _translateStatus(String value) {
    final seconds = _extractDurationSeconds(value);
    if (_isHoldStatus(value)) {
      return seconds == null
          ? 'Giữ đáy rồi đẩy lên.'
          : 'Giữ đáy ${seconds.toStringAsFixed(1)} giây rồi đẩy lên.';
    }
    if (_isReleaseStatus(value)) {
      return 'Đẩy lên ngay.';
    }
    if (value.contains('Push Up!')) {
      return 'Đứng lên dứt khoát.';
    }
    if (value.contains('Going Down...')) {
      return 'Hạ người xuống có kiểm soát.';
    }
    return _translateInstruction(value);
  }

  double? _extractDurationSeconds(String value) {
    final match = RegExp(r'(\d+(?:\.\d+)?)s').firstMatch(value);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(1)!);
  }

  // ignore: unused_element
  Widget _buildDebugPanel() {
    final debugEntries = widget.exercise.debugData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          constraints: const BoxConstraints(maxHeight: 320),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: debugEntries.isEmpty
              ? Text(
                  'Đang chờ dữ liệu pose...',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.42),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.terminal_rounded,
                            size: 12,
                            color: VFTheme.jadeGlow.withValues(alpha: 0.74),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Dữ liệu debug',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: debugEntries.map((entry) {
                          return _debugChip(
                            label: entry.key,
                            value: '${entry.value}',
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _debugChip({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'monospace'),
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Size get _previewRenderSize {
    if (_runtime == _PoseRuntime.mlKitFallback) {
      final previewSize = _cameraController?.value.previewSize;
      if (previewSize != null) {
        if (previewSize.width > previewSize.height) {
          return Size(previewSize.height, previewSize.width);
        }
        return previewSize;
      }
    }

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
}

enum _PoseRuntime {
  nativeMediaPipe,
  mlKitFallback,
}

enum _LiveOverlayState { scan, warn, position, hold, paused, active }

class _GuidanceCopy {
  const _GuidanceCopy({
    required this.icon,
    required this.title,
    required this.body,
    required this.mode,
  });

  final IconData icon;
  final String title;
  final String body;
  final SystemBannerMode mode;
}

class _BottomHoldCue {
  const _BottomHoldCue({
    required this.progress,
    required this.remaining,
    required this.readyToPush,
  });

  final double progress;
  final double? remaining;
  final bool readyToPush;
}

class _SetupGuidancePanel extends StatelessWidget {
  const _SetupGuidancePanel({
    required this.copy,
  });

  final _GuidanceCopy copy;

  @override
  Widget build(BuildContext context) {
    final accent = switch (copy.mode) {
      SystemBannerMode.warn => const Color(0xFFFFB4A8),
      SystemBannerMode.scan => const Color(0xCCFFFFFF),
      SystemBannerMode.pause => const Color(0xCCFFFFFF),
      SystemBannerMode.info => VikaIvory.yellow,
    };
    final background = switch (copy.mode) {
      SystemBannerMode.warn => const Color(0xD1150C09),
      SystemBannerMode.scan => const Color(0xC914100D),
      SystemBannerMode.pause => const Color(0xC914100D),
      SystemBannerMode.info => const Color(0xD1150C09),
    };
    final border = switch (copy.mode) {
      SystemBannerMode.warn => const Color(0x4DFFB4A8),
      SystemBannerMode.scan => const Color(0x22FFFFFF),
      SystemBannerMode.pause => const Color(0x22FFFFFF),
      SystemBannerMode.info => VikaIvory.yellowGlowWeak,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                ),
                child: Icon(copy.icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      copy.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: VikaIvory.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: VikaIvory.invInk,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      copy.body,
                      style: TextStyle(
                        fontFamily: VikaIvory.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: VikaIvory.invInkSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterOverlay extends StatelessWidget {
  const _CenterOverlay({
    required this.state,
    required this.pulseController,
    required this.progress,
    required this.holdCue,
  });

  final _LiveOverlayState state;
  final AnimationController pulseController;
  final double? progress;
  final _BottomHoldCue? holdCue;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _LiveOverlayState.scan:
        return AnimatedBuilder(
          animation: pulseController,
          builder: (context, _) {
            final scale = 1 + (pulseController.value * 0.05);
            return Transform.scale(
              scale: scale,
              child: _OverlayBubble(
                icon: Icons.accessibility_new_rounded,
                iconColor: Colors.white.withValues(alpha: 0.34),
                outlineColor: Colors.white.withValues(alpha: 0.10),
              ),
            );
          },
        );
      case _LiveOverlayState.warn:
        return const _OverlayBubble(
          icon: Icons.warning_amber_rounded,
          iconColor: Color(0xFFFFB4A8),
          fillColor: Color(0x16B84435),
          outlineColor: Color(0x3CB84435),
        );
      case _LiveOverlayState.position:
        return const _OverlayBubble(
          icon: Icons.accessibility_new_rounded,
          iconColor: Color(0x52FFFFFF),
          outlineColor: Color(0x1AFFFFFF),
        );
      case _LiveOverlayState.paused:
        return const _OverlayBubble(
          icon: Icons.pause_circle_outline_rounded,
          iconColor: Color(0x66FFFFFF),
          outlineColor: Color(0x1AFFFFFF),
        );
      case _LiveOverlayState.hold:
        // Mid-rep bottom hold is owned by IvoryBottomChrome — don't render
        // a duplicate centered ring during squat-bottom holds.
        if (holdCue != null) {
          return const SizedBox.shrink();
        }
        // Activation countdown (user holding still in starting position).
        // Ivory yellow with smooth interpolated progress + glowing dial.
        final clamped = progress?.clamp(0.0, 1.0) ?? 0.0;
        final remainingSeconds =
            (ExerciseBase.HOLD_STILL_REQUIRED_DURATION.inMilliseconds *
                    (1 - clamped)) /
                1000;
        final isReadyToStart = remainingSeconds <= 0;
        final remainingLabel = isReadyToStart
            ? 'Sẵn sàng'
            : (remainingSeconds < 1
                ? remainingSeconds.toStringAsFixed(1)
                : remainingSeconds.ceil().toString());
        return FormScoreArc(
          progress: clamped,
          size: 144,
          color: VikaIvory.yellow,
          trackColor: VikaIvory.glass12,
          strokeWidth: 5,
          glow: true,
          // Snappier than the default 900 ms — this is a live activation
          // gauge, not a one-shot reveal.
          duration: const Duration(milliseconds: 240),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                remainingLabel,
                style: TextStyle(
                  fontFamily: VikaIvory.fontFamily,
                  fontSize: isReadyToStart ? 22 : 38,
                  fontWeight: FontWeight.w800,
                  color: VikaIvory.yellow,
                  letterSpacing: isReadyToStart ? 0.1 : -1.6,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: VikaIvory.yellowGlow,
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isReadyToStart ? 'Bắt đầu tập' : 'Giữ yên',
                style: TextStyle(
                  fontFamily: VikaIvory.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: VikaIvory.invInkSoft,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        );
      case _LiveOverlayState.active:
        return const SizedBox.shrink();
    }
  }
}

class _OverlayBubble extends StatelessWidget {
  const _OverlayBubble({
    required this.icon,
    required this.iconColor,
    required this.outlineColor,
    this.fillColor = const Color(0x00000000),
  });

  final IconData icon;
  final Color iconColor;
  final Color outlineColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(color: outlineColor, width: 2),
      ),
      child: Icon(icon, size: 34, color: iconColor),
    );
  }
}
