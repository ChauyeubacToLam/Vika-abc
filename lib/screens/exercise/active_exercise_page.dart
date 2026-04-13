import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../exercise/exercise_base.dart';
import '../../pose/pose_landmarker_adapter.dart';
import '../../pose/pose_landmarker_channel.dart';
import '../../exercise/squat/metrics/heel_rise_metric.dart';
import '../../exercise/squat/metrics/hip_shoulder_sync.dart';
import '../../exercise/squat/metrics/tempo_metric.dart';
import '../../exercise/squat/metrics/trunk_lean_metric.dart';
import '../../exercise/squat/squat.dart';
import '../../models/exercise_definition.dart';
import '../../utils/exercise_logger.dart';
import '../onboarding/vf_theme.dart';
import 'widgets/form_score_arc.dart';
import 'widgets/metric_chip.dart';
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
  bool _showReference = true;
  bool _showDebug = false;
  String? _cameraErrorMessage;
  Map<String, String> _feedback = {};
  Pose? _detectedPose;
  Size _imageSize = Size.zero;
  InputImageRotation _imageRotation = InputImageRotation.rotation0deg;
  late final AnimationController _pulseController;
  late final AnimationController _voiceController;
  _PoseRuntime _runtime = _PoseRuntime.nativeMediaPipe;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _voiceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _initCamera();
  }

  @override
  void dispose() {
    final landmarkSubscription = _landmarkSubscription;
    _landmarkSubscription = null;
    unawaited(landmarkSubscription?.cancel() ?? Future<void>.value());
    unawaited(_disposeFallbackCamera());
    unawaited(_poseChannel.dispose());
    _poseDetector.close();
    unawaited(widget.exercise.disposeDetectors());
    _pulseController.dispose();
    _voiceController.dispose();
    super.dispose();
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isCameraReady = false;
          _textureId = null;
          _cameraErrorMessage =
              'Không thể khởi động camera. Hãy thử lại hoặc đổi camera.';
        });
      }
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
      if (inputImage != null) {
        await widget.exercise.runPersonDetection(inputImage);
      }

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
        widget.exercise.exerciseState == ExerciseState.activated &&
        result.length == 2 &&
        result[1] is Map) {
      _feedback = Map<String, String>.from(result[1] as Map);
      return;
    }

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
      '[VinaFit] Falling back to Flutter camera + ML Kit: ${nativeErrorMessage ?? "unknown native init error"}',
    );
    await _poseChannel.dispose();
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
      } catch (_) {
        await controller.dispose();
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
      ResolutionPreset.medium,
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

      await widget.exercise.runPersonDetection(inputImage);
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        _handlePose(poses.first);
      } else {
        _detectedPose = null;
        _feedback = widget.exercise.processNoPoseFrame();
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
              Icon(icon, size: 52, color: VF.jadeGlow),
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
                  child: VFButton(
                    label: actionLabel,
                    onTap: onAction,
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
    final translatedSystem = _translatedSystemMessage;
    final coachMessage = _coachMessage;
    final showSetPill = _showSetPill;
    final activeState =
        widget.exercise.exerciseState == ExerciseState.activated &&
            !widget.exercise.isPaused;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: Center(
              child: _runtime == _PoseRuntime.nativeMediaPipe
                  ? Texture(textureId: _textureId!)
                  : (_cameraController != null
                      ? CameraPreview(_cameraController!)
                      : const SizedBox.shrink()),
            ),
          ),
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
                        style: SkeletonStyle.constellation),
                  );
                },
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.24),
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.58),
                  ],
                  stops: const [0, 0.22, 0.58, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 96, 22, 110),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: widget.exercise.isPaused
                          ? VF.coral.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.18),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  _FrostedIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: widget.onBack,
                  ),
                  Expanded(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: showSetPill
                            ? KeyedSubtree(
                                key: const ValueKey('set-pill'),
                                child: _FrostedPill(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Hi\u1ec7p ',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.42,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '${widget.currentSet}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        TextSpan(
                                          text: ' / ${widget.totalSets}',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.32,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox(key: ValueKey('set-pill-empty')),
                      ),
                    ),
                  ),
                  _FrostedIconButton(
                    icon: Icons.bug_report_outlined,
                    active: _showDebug,
                    onTap: () => setState(() => _showDebug = !_showDebug),
                  ),
                  const SizedBox(width: 10),
                  _FrostedIconButton(
                    icon: _currentLens == CameraLensDirection.back
                        ? Icons.camera_front_rounded
                        : Icons.camera_rear_rounded,
                    onTap: _toggleCamera,
                  ),
                ],
              ),
            ),
          ),
          if (_showReference && activeState)
            Positioned(
              top: media.padding.top + 82,
              right: 16,
              child: _ReferenceCard(
                exerciseName: widget.definition.name,
                onClose: () => setState(() => _showReference = false),
              ),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: overlayState == _LiveOverlayState.active
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
          if (translatedSystem != null &&
              overlayState != _LiveOverlayState.active)
            Positioned(
              left: 20,
              right: 20,
              bottom: activeState ? 214 : media.padding.bottom + 18,
              child: SystemBanner(
                message: translatedSystem,
                mode: _bannerModeFor(overlayState),
              ),
            ),
          if (_showDebug)
            Positioned(
              left: 16,
              right: 16,
              bottom: activeState
                  ? media.padding.bottom + 212
                  : media.padding.bottom + 104,
              child: _buildDebugPanel(),
            ),
          if (activeState)
            Positioned(
              left: 16,
              right: 16,
              bottom: media.padding.bottom + 20,
              child: _buildActiveHud(coachMessage),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveHud(String coachMessage) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 62,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _metricTiles.asMap().entries.map((entry) {
                final index = entry.key;
                final metric = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == _metricTiles.length - 1 ? 0 : 8,
                  ),
                  child: SizedBox(
                    width: 112,
                    child: MetricChip(
                      label: metric.label,
                      value: metric.value,
                      state: metric.state,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FormScoreArc(
              progress: widget.totalReps == 0
                  ? 0
                  : widget.exercise.repCount / widget.totalReps,
              size: 72,
              color: VF.jadeGlow,
              trackColor: Colors.white.withValues(alpha: 0.08),
              strokeWidth: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${widget.exercise.repCount}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    '/${widget.totalReps}',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.34),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.08, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        key: ValueKey<String>(coachMessage),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: VF.jadeGlow,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'HLV AI',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: VF.jadeGlow.withValues(alpha: 0.62),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            coachMessage,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.80),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _voiceController,
          builder: (context, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(5, (index) {
                    final phase = (_voiceController.value + (index * 0.12)) % 1;
                    final height =
                        6 + (phase < 0.5 ? phase * 16 : (1 - phase) * 16);
                    return Padding(
                      padding: EdgeInsets.only(right: index == 4 ? 0 : 2),
                      child: Container(
                        width: 3,
                        height: height,
                        decoration: BoxDecoration(
                          color: VF.jadeGlow.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Text(
                  'Giọng nói đang bật',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  _LiveOverlayState get _overlayState {
    if (widget.exercise.isPaused) {
      return _LiveOverlayState.paused;
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
    final system = _translatedSystemMessage ?? '';
    if (_isSafetyMessage(system)) {
      return _LiveOverlayState.warn;
    }
    if (_isScanningMessage(system)) {
      return _LiveOverlayState.scan;
    }
    return _LiveOverlayState.position;
  }

  bool get _showSetPill {
    final isCountingDown = widget.exercise.activationProgress != null;
    final isActive = widget.exercise.exerciseState == ExerciseState.activated;
    return !isCountingDown && !isActive && _detectedPose == null;
  }

  SystemBannerMode _bannerModeFor(_LiveOverlayState state) {
    switch (state) {
      case _LiveOverlayState.scan:
        return SystemBannerMode.scan;
      case _LiveOverlayState.warn:
        return SystemBannerMode.warn;
      case _LiveOverlayState.paused:
        return SystemBannerMode.pause;
      case _LiveOverlayState.position:
      case _LiveOverlayState.hold:
      case _LiveOverlayState.active:
        return SystemBannerMode.info;
    }
  }

  bool _isScanningMessage(String message) => message.contains('Đang tìm người');

  bool _isSafetyMessage(String message) {
    return message.contains('Quay nghiêng') ||
        message.contains('ánh sáng') ||
        message.contains('Giữ toàn thân') ||
        message.contains('theo dõi tốt hơn');
  }

  String? get _translatedSystemMessage {
    final raw = _feedback['System'];
    if (raw == null || raw.isEmpty) {
      return null;
    }
    if (raw.contains('Please turn to the side')) {
      return 'Quay nghiêng người để AI theo dõi tốt hơn';
    }
    if (raw.contains('Body not fully visible')) {
      return 'Giữ toàn thân trong khung hình';
    }
    if (raw.contains('Adjust lighting/position')) {
      return 'Điều chỉnh ánh sáng hoặc vị trí để AI nhận rõ hơn';
    }
    if (raw.contains('⚸')) {
      return 'Tạm dừng. Quay lại khung hình để tiếp tục';
    }
    return raw.replaceAll('⚸ ', '');
  }

  Map<String, String>? get _currentPhaseInstructions {
    return widget
        .exercise.resultIssues.instructions[widget.exercise.currentPhaseKey];
  }

  String? get _currentPhaseStatus => _currentPhaseInstructions?['Status'];

  _BottomHoldCue? get _bottomHoldCue {
    if (!widget.definition.id.startsWith('squat')) {
      return null;
    }
    if (widget.exercise.exerciseState != ExerciseState.activated) {
      return null;
    }

    final status = _currentPhaseStatus;
    if (status == null || status.isEmpty) {
      return null;
    }

    final isHolding = status.contains('Hold!');
    final isRelease = status.contains('Push Up Now!');
    if (!isHolding && !isRelease) {
      return null;
    }

    final progress =
        (_readDebugNumber(widget.exercise.debugData['bottomHoldProgress']) ??
                0.0)
            .clamp(0.0, 1.0)
            .toDouble();

    return _BottomHoldCue(
      progress: isRelease ? 1.0 : progress,
      remaining: _extractDurationSeconds(status),
      readyToPush: isRelease,
    );
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

  List<_MetricTileData> get _metricTiles {
    if (widget.definition.id.startsWith('squat')) {
      return _buildLiveSquatMetricTiles();
    }

    final feedback = Map<String, String>.from(_feedback)
      ..remove('System')
      ..remove('Result');

    final preferredKeys = <String>['Depth', 'Back', 'Tempo'];
    final tiles = <_MetricTileData>[];

    for (final key in preferredKeys) {
      final value = feedback[key];
      if (value != null) {
        tiles.add(_metricFrom(key, value));
      }
    }

    for (final entry in feedback.entries) {
      if (tiles.length >= 4) {
        break;
      }
      if (preferredKeys.contains(entry.key)) {
        continue;
      }
      tiles.add(_metricFrom(entry.key, entry.value));
    }

    while (tiles.length < 4) {
      tiles.add(
        const _MetricTileData(
          label: 'DỮ LIỆU',
          value: '—',
          state: MetricChipState.neutral,
        ),
      );
    }

    return tiles.take(4).toList();
  }

  _MetricTileData _metricFrom(String key, String value) {
    final translatedValue = _translateFeedbackValue(key, value);
    final label = switch (key) {
      'Depth' => 'ĐỘ SÂU',
      'Back' => 'LƯNG',
      'Tempo' => 'NHỊP',
      'Feet' => 'CHÂN',
      _ => key.toUpperCase(),
    };
    final normalizedValue = value.toLowerCase();
    final good = normalizedValue.contains('good') ||
        normalizedValue.contains('deep squat');

    return _MetricTileData(
      label: label,
      value: translatedValue,
      state: good ? MetricChipState.good : MetricChipState.warning,
    );
  }

  // ignore: unused_element
  List<_MetricTileData> _buildSquatMetricTiles() {
    final debug = widget.exercise.debugData;
    final depthAngle =
        _readDebugNumber(debug['kneeAngle'] ?? debug['minKneeAngle']);
    final heelNorm = _readDebugNumber(debug['heelNorm']);
    final trunkLean =
        _readDebugNumber(debug['trunkLean'] ?? debug['maxTrunkLean']);
    final descent = _readDebugNumber(debug['descentDur']);
    final ascent = _readDebugNumber(debug['ascentDur']);
    final hold = _readDebugNumber(debug['bottomHold']);
    final syncRatio =
        _readDebugNumber(debug['syncRatio'] ?? debug['peakSyncRatio']);

    return [
      _MetricTileData(
        label: 'ĐỘ SÂU',
        value: depthAngle == null
            ? _fallbackMetricValue('Depth', '—')
            : '${depthAngle.toStringAsFixed(0)}°',
        state: depthAngle == null
            ? MetricChipState.neutral
            : (depthAngle >= SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[0] &&
                    depthAngle <= SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1]
                ? MetricChipState.good
                : MetricChipState.warning),
      ),
      _MetricTileData(
        label: 'GÓT CHÂN',
        value: heelNorm == null
            ? _fallbackMetricValue('Feet', '—')
            : '${(heelNorm * 100).toStringAsFixed(0)}%',
        state: heelNorm == null
            ? MetricChipState.neutral
            : (heelNorm < HeelRiseConfig.LIFT_THRESHOLD
                ? MetricChipState.good
                : MetricChipState.warning),
      ),
      _MetricTileData(
        label: 'LƯNG',
        value: trunkLean == null
            ? _fallbackMetricValue('Back', '—')
            : '${trunkLean.toStringAsFixed(0)}°',
        state: trunkLean == null
            ? MetricChipState.neutral
            : (trunkLean >= TrunkLeanConfig.GOOD_LEAN_RANGE[0] &&
                    trunkLean <= TrunkLeanConfig.GOOD_LEAN_RANGE[1]
                ? MetricChipState.good
                : MetricChipState.warning),
      ),
      _MetricTileData(
        label: 'NHỊP',
        value: _tempoValue(
          descent: descent,
          ascent: ascent,
          hold: hold,
          fallback: _fallbackMetricValue('Tempo', '—'),
        ),
        state: descent == null && hold == null && _feedback['Tempo'] == null
            ? MetricChipState.neutral
            : (_tempoGood(
                descent: descent,
                hold: hold,
                fallbackFeedback: _feedback['Tempo'],
              )
                ? MetricChipState.good
                : MetricChipState.warning),
      ),
      _MetricTileData(
        label: 'ĐỒNG BỘ',
        value: syncRatio == null
            ? _fallbackMetricValue('Sync', '—')
            : '${syncRatio.toStringAsFixed(2)}x',
        state: syncRatio == null
            ? MetricChipState.neutral
            : (syncRatio <= HipShoulderSyncConfig.RATIO_GOOD_MAX
                ? MetricChipState.good
                : MetricChipState.warning),
      ),
    ];
  }

  String _fallbackMetricValue(String key, String fallback) {
    final raw = _feedback[key];
    if (raw == null || raw.isEmpty) return fallback;
    return _translateFeedbackValue(key, raw);
  }

  List<_MetricTileData> _buildLiveSquatMetricTiles() {
    final debug = widget.exercise.debugData;
    final depthAngle =
        _readDebugNumber(debug['kneeAngle'] ?? debug['minKneeAngle']);
    final heelNorm = _readDebugNumber(debug['heelNorm']);
    final trunkLean =
        _readDebugNumber(debug['trunkLean'] ?? debug['maxTrunkLean']);
    final descent = _readDebugNumber(debug['descentDur']);
    final ascent = _readDebugNumber(debug['ascentDur']);
    final hold = _readDebugNumber(debug['bottomHold']);
    final syncRatio =
        _readDebugNumber(debug['syncRatio'] ?? debug['peakSyncRatio']);

    return [
      _buildLiveSquatMetricTile(
        metric: _SquatMetric.depth,
        label: 'ĐỘ SÂU',
        activeValue:
            depthAngle == null ? '—' : '${depthAngle.toStringAsFixed(0)}°',
        hasValue: depthAngle != null,
        state: _liveSquatMetricState(_SquatMetric.depth),
      ),
      _buildLiveSquatMetricTile(
        metric: _SquatMetric.heel,
        label: 'GÓT CHÂN',
        activeValue:
            heelNorm == null ? '—' : '${(heelNorm * 100).toStringAsFixed(0)}%',
        hasValue: heelNorm != null,
        state: _liveSquatMetricState(_SquatMetric.heel),
      ),
      _buildLiveSquatMetricTile(
        metric: _SquatMetric.trunk,
        label: 'LƯNG',
        activeValue:
            trunkLean == null ? '—' : '${trunkLean.toStringAsFixed(0)}°',
        hasValue: trunkLean != null,
        state: _liveSquatMetricState(_SquatMetric.trunk),
      ),
      _buildLiveSquatMetricTile(
        metric: _SquatMetric.tempo,
        label: 'NHỊP',
        activeValue: _tempoValue(
          descent: descent,
          ascent: ascent,
          hold: hold,
          fallback: '—',
        ),
        hasValue: descent != null || hold != null || _feedback['Tempo'] != null,
        state: _liveSquatMetricState(_SquatMetric.tempo),
      ),
      _buildLiveSquatMetricTile(
        metric: _SquatMetric.sync,
        label: 'ĐỒNG BỘ',
        activeValue:
            syncRatio == null ? '—' : '${syncRatio.toStringAsFixed(2)}x',
        hasValue: syncRatio != null,
        state: _liveSquatMetricState(_SquatMetric.sync),
      ),
    ];
  }

  _MetricTileData _buildLiveSquatMetricTile({
    required _SquatMetric metric,
    required String label,
    required String activeValue,
    required bool hasValue,
    required MetricChipState state,
  }) {
    final active = _isSquatMetricActive(metric);
    return _MetricTileData(
      label: label,
      value: active && hasValue ? activeValue : '—',
      state: !active || !hasValue ? MetricChipState.neutral : state,
    );
  }

  MetricChipState _liveSquatMetricState(_SquatMetric metric) {
    if (!_isSquatMetricActive(metric)) {
      return MetricChipState.neutral;
    }

    final feedbackKey = switch (metric) {
      _SquatMetric.depth => 'Depth',
      _SquatMetric.heel => 'Feet',
      _SquatMetric.trunk => 'Back',
      _SquatMetric.tempo => 'Tempo',
      _SquatMetric.sync => 'Sync',
    };
    final feedback = _feedback[feedbackKey];
    if (feedback == null || feedback.isEmpty) {
      return MetricChipState.neutral;
    }

    final normalized = feedback.toLowerCase();
    final isFaulting = switch (metric) {
      _SquatMetric.depth => normalized.contains('go lower'),
      _SquatMetric.heel => normalized.contains('lifting'),
      _SquatMetric.trunk =>
        normalized.contains('chest up') || normalized.contains("don't lean"),
      _SquatMetric.tempo =>
        normalized.contains('dropping') || normalized.contains('not pausing'),
      _SquatMetric.sync => normalized.contains('drive chest up') ||
          normalized.contains('keep chest up'),
    };

    return isFaulting ? MetricChipState.warning : MetricChipState.neutral;
  }

  bool _isSquatMetricActive(_SquatMetric metric) {
    if (widget.exercise.exerciseState != ExerciseState.activated ||
        widget.exercise.isPaused) {
      return false;
    }

    final phase = widget.exercise.currentPhaseKey;
    return switch (metric) {
      _SquatMetric.depth => phase == 'descending' || phase == 'bottom',
      _SquatMetric.heel ||
      _SquatMetric.trunk =>
        phase == 'descending' || phase == 'bottom' || phase == 'ascending',
      _SquatMetric.tempo => phase == 'bottom' || phase == 'ascending',
      _SquatMetric.sync => phase == 'ascending',
    };
  }

  double? _readDebugNumber(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  String _tempoValue({
    required double? descent,
    required double? ascent,
    required double? hold,
    required String fallback,
  }) {
    if (descent != null && ascent != null) {
      return '${descent.toStringAsFixed(1)}/${ascent.toStringAsFixed(1)}s';
    }
    if (descent != null) {
      return '${descent.toStringAsFixed(1)}s';
    }
    if (hold != null) {
      return 'giữ ${hold.toStringAsFixed(1)}s';
    }
    return fallback;
  }

  bool _tempoGood({
    required double? descent,
    required double? hold,
    required String? fallbackFeedback,
  }) {
    if (descent != null) {
      final goodDescent = descent >= TempoConfig.DESCENT_MIN_GOOD;
      final goodHold = hold == null || hold >= TempoConfig.BOTTOM_HOLD_MIN;
      return goodDescent && goodHold;
    }
    if (fallbackFeedback == null) return false;
    if (fallbackFeedback.contains('Good')) return true;
    return _translateFeedbackValue('Tempo', fallbackFeedback).contains('Ổn');
  }

  String _translateFeedbackValue(String key, String value) {
    switch ('$key::$value') {
      case 'Depth::Good Depth':
      case 'Depth::Deep Squat!':
        return 'Chuẩn';
      case 'Depth::Go Lower':
        return 'Hạ thấp hơn';
      case 'Back::Good back':
        return 'Tốt';
      case 'Back::Chest up!':
        return 'Giữ ngực mở';
      case "Back::Don't lean back!":
        return 'Đừng ngả ra sau';
      case 'Feet::Heels lifting':
        return 'Gót đang nhấc';
      case 'Feet::Good Heels':
        return 'Ổn';
      case 'Tempo::Good tempo':
        return 'Ổn';
      case 'Tempo::Not pausing at bottom!':
        return 'Giữ đáy lâu hơn';
      default:
        if (value.contains('Dropping')) {
          return 'Xuống chậm hơn';
        }
        if (value.contains('Good')) {
          return 'Tốt';
        }
        return value;
    }
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
    if (value.contains('Hold!')) {
      return seconds == null
          ? 'Giữ đáy rồi đẩy lên.'
          : 'Giữ đáy ${seconds.toStringAsFixed(1)} giây rồi đẩy lên.';
    }
    if (value.contains('Push Up Now!')) {
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

  Widget _buildDebugPanel() {
    final debugEntries = widget.exercise.debugData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          constraints: const BoxConstraints(maxHeight: 148),
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
                            color: VF.jadeGlow.withValues(alpha: 0.74),
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
}

enum _PoseRuntime {
  nativeMediaPipe,
  mlKitFallback,
}

enum _LiveOverlayState { scan, warn, position, hold, paused, active }

class _MetricTileData {
  const _MetricTileData({
    required this.label,
    required this.value,
    MetricChipState? state,
    bool? good,
  }) : state = state ??
            (good == null
                ? MetricChipState.neutral
                : (good ? MetricChipState.good : MetricChipState.warning));

  final String label;
  final String value;
  final MetricChipState state;
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
        if (holdCue != null) {
          final cue = holdCue!;
          final color = cue.readyToPush ? VF.jadeGlow : VF.amber;
          return AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) {
              final scale =
                  cue.readyToPush ? 1 + (pulseController.value * 0.04) : 1.0;
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: FormScoreArc(
              progress: cue.progress,
              size: 136,
              color: color,
              trackColor: Colors.white.withValues(alpha: 0.10),
              strokeWidth: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cue.readyToPush
                        ? 'LÊN'
                        : cue.remaining?.toStringAsFixed(1) ?? 'GIỮ',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cue.readyToPush ? 'Đẩy lên ngay' : 'Giữ đáy',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final clamped = progress?.clamp(0.0, 1.0) ?? 0.0;
        final remainingSeconds =
            (ExerciseBase.HOLD_STILL_REQUIRED_DURATION.inMilliseconds *
                    (1 - clamped)) /
                1000;
        final remainingLabel = remainingSeconds <= 0
            ? '0.0'
            : (remainingSeconds < 1
                ? remainingSeconds.toStringAsFixed(1)
                : remainingSeconds.ceil().toString());
        return FormScoreArc(
          progress: clamped,
          size: 132,
          color: VF.jadeGlow,
          trackColor: Colors.white.withValues(alpha: 0.10),
          strokeWidth: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                remainingLabel,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              Text(
                'Giữ yên',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.34),
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

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({
    required this.exerciseName,
    required this.onClose,
  });

  final String exerciseName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 104,
          height: 144,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.36),
                      size: 34,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      exerciseName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Video mẫu',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrostedIconButton extends StatelessWidget {
  const _FrostedIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active
                  ? VF.jadeGlow.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? VF.jadeGlow.withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color:
                  active ? VF.jadeGlow : Colors.white.withValues(alpha: 0.74),
            ),
          ),
        ),
      ),
    );
  }
}

class _FrostedPill extends StatelessWidget {
  const _FrostedPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: child,
        ),
      ),
    );
  }
}

enum _SquatMetric { depth, heel, trunk, tempo, sync }
