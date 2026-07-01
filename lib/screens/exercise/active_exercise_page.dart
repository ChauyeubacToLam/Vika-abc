import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
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
import '../../services/analytics_service.dart';
import '../../utils/exercise_logger.dart';
import '../../utils/orientation_lock.dart';
import '../../utils/segmentation_channel.dart';
import '../../theme/vf_theme.dart';
import 'widgets/form_score_arc.dart';
import 'widgets/guidance_signage.dart';
import 'widgets/hold_hero_ring.dart';
import 'widgets/hybrid_hold_cue.dart';
import 'widgets/ivory_chrome.dart';
import 'widgets/rep_hero.dart';
import 'widgets/pose_overlay_painter.dart';
import 'widgets/rep_reward_layer.dart';
import 'widgets/system_banner.dart';

class ActiveExercisePage extends StatefulWidget {
  const ActiveExercisePage({
    super.key,
    required this.definition,
    required this.exercise,
    required this.currentSet,
    required this.totalSets,
    required this.totalReps,
    this.isTimeBased = false,
    required this.onSetComplete,
    required this.onBack,
  });

  final ExerciseDefinition definition;
  final ExerciseBase exercise;
  final int currentSet;
  final int totalSets;
  final int totalReps;
  final bool isTimeBased;
  final ValueChanged<ExerciseLogger> onSetComplete;
  final VoidCallback onBack;

  @override
  State<ActiveExercisePage> createState() => _ActiveExercisePageState();
}

class _ActiveExercisePageState extends State<ActiveExercisePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final PoseLandmarkerChannel _poseChannel = PoseLandmarkerChannel();
  final SegmentationChannel _segmentationChannel = SegmentationChannel();
  final NativeDeviceOrientationCommunicator _orientationCommunicator =
      NativeDeviceOrientationCommunicator();
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.accurate,
      mode: PoseDetectionMode.stream,
    ),
  );

  StreamSubscription<Map<String, dynamic>>? _landmarkSubscription;
  StreamSubscription<NativeDeviceOrientation>? _orientationSubscription;
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = const [];
  int? _textureId;
  int _cameraIndex = -1;
  CameraLensDirection _currentLens = CameraLensDirection.front;
  PermissionStatus? _permissionStatus;
  bool _isInitializing = false;
  bool _isProcessingFrame = false;
  bool _isCameraReady = false;
  bool _didComplete = false;
  bool _isDisposed = false;
  bool _isCompletingSet = false;
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

  // ─── Ambient reward (Hearthlight) ───
  // Drives the additive warm-light feedback layer. A clean rep blooms and
  // raises the hearth pool; a faulted rep is met with silence. There is no
  // real-time form score on this screen — the verdict is computed after the
  // set, never during.
  int _rewardRepSeen = 0; // highest repCount already evaluated for reward
  int _cleanRepCount = 0; // cumulative clean reps this set (drives pool level)
  int _rewardPulseId = 0; // bumps once per clean rep (fires a bloom)

  // Last non-null accrued hold seconds. The hold hero ring keeps showing the
  // frozen count when the exercise momentarily reports null (user dropped out
  // of the hold pose) instead of snapping back to zero.
  double _lastKnownHoldSeconds = 0;
  bool _isManualPause = false;
  _PoseRuntime _runtime = _PoseRuntime.nativeMediaPipe;
  DebugMode _settingsDebugMode = DebugMode.off;
  bool _isStaffUser = false;
  bool _debugPanelOpen = false;
  String? _expandedMetricId;
  int _debugBackTapCount = 0;
  DateTime? _debugFirstBackTap;
  Timer? _pendingStaffBackTimer;
  Timer? _setCompleteTimer;
  DateTime? _lastPersonDetectionAt;
  bool _personDetectionInFlight = false;
  bool _orientationPauseActive = false;
  bool _isLifecyclePaused = false;
  bool _resumeInitRequested = false;
  VikaImageOrientation _currentOrientation = VikaImageOrientation.portrait;
  VikaImageOrientation? _lastSentOrientation;
  bool? _lastSentOrientationFrontCamera;
  Future<void>? _pipelineShutdownFuture;
  Future<void>? _lifecyclePauseFuture;
  int _cameraInitGeneration = 0;
  int? _activeCameraInitGeneration;
  static const Duration _personDetectionInterval = Duration(milliseconds: 450);
  static const Duration _voiceCompletionTimeout = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Restrict allowed orientations to those the exercise supports. For
    // landscape-only exercises this forces iOS to rotate the Flutter surface
    // into landscape, so the orientation gate can detect that the user is in
    // a supported orientation and the rest of the UI lays out correctly.
    unawaited(
      OrientationLock.forSupported(widget.exercise.supportedOrientations),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _voiceCoach = widget.exercise.createVoiceCoach();
    _startOrientationListener();
    _loadDebugMode();
    _startSetTimer();
    _initCamera();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _didComplete = true;
    _isCompletingSet = true;
    WidgetsBinding.instance.removeObserver(this);
    _setTimer?.cancel();
    _pendingStaffBackTimer?.cancel();
    _setCompleteTimer?.cancel();
    unawaited(_orientationSubscription?.cancel() ?? Future<void>.value());
    _orientationSubscription = null;
    _poseDetector.close();
    _voiceCoach?.dispose();
    _voiceCoach = null;
    unawaited(OrientationLock.portraitOnly());
    unawaited(_shutdownPipelines());
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Window dimensions just changed (typically a rotation). Re-evaluate the
    // orientation gate so landscape-only exercises stop showing the
    // "rotate phone" guidance once the surface is actually landscape, even on
    // devices where the native_device_orientation sensor stream is slow or
    // does not fire after rotation.
    if (!ExerciseBase.kLandscapeRotationEnabled || _isDisposed) return;
    unawaited(_handleMetricsChange());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _handleLifecycleResumed();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _handleLifecyclePaused();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  bool get _setTeardownOwnsPipeline =>
      _isDisposed || _isCompletingSet || _didComplete;

  bool get _hasCameraPipelineWork =>
      _isInitializing ||
      _isCameraReady ||
      _textureId != null ||
      _cameraController != null ||
      _landmarkSubscription != null;

  bool get _pipelineReady =>
      _isCameraReady &&
      ((_runtime == _PoseRuntime.nativeMediaPipe && _textureId != null) ||
          (_runtime == _PoseRuntime.mlKitFallback &&
              _cameraController != null));

  bool _shouldAbortCameraInit(int generation) {
    return !mounted ||
        _setTeardownOwnsPipeline ||
        _isLifecyclePaused ||
        generation != _cameraInitGeneration;
  }

  void _handleLifecyclePaused() {
    if (_setTeardownOwnsPipeline) return;

    _isLifecyclePaused = true;
    _resumeInitRequested = false;
    _cameraInitGeneration++;
    _pipelineShutdownFuture = null;

    if (!_hasCameraPipelineWork && _lifecyclePauseFuture == null) {
      return;
    }

    final pauseFuture = _lifecyclePauseFuture ??= _pausePipelinesForLifecycle();
    unawaited(pauseFuture.whenComplete(() {
      if (identical(_lifecyclePauseFuture, pauseFuture)) {
        _lifecyclePauseFuture = null;
      }
    }));
  }

  void _handleLifecycleResumed() {
    if (_setTeardownOwnsPipeline) return;

    _isLifecyclePaused = false;
    unawaited(_resumePipelinesAfterLifecycle());
  }

  Future<void> _resumePipelinesAfterLifecycle() async {
    final pauseFuture = _lifecyclePauseFuture;
    if (pauseFuture != null) {
      await pauseFuture;
    }

    if (!mounted || _setTeardownOwnsPipeline || _isLifecyclePaused) {
      return;
    }
    if (_pipelineReady) {
      return;
    }
    if (_isInitializing) {
      _resumeInitRequested = true;
      return;
    }

    await _initCamera();
  }

  Future<void> _pausePipelinesForLifecycle() async {
    try {
      final landmarkSubscription = _landmarkSubscription;
      _landmarkSubscription = null;
      try {
        await landmarkSubscription?.cancel();
      } catch (_) {}

      await _stopAndDisposePoseChannel();
      await _disposeFallbackCamera();
    } finally {
      _pipelineShutdownFuture = null;
      _lastSentOrientation = null;
      _lastSentOrientationFrontCamera = null;
      _isProcessingFrame = false;

      if (!_isDisposed) {
        if (mounted) {
          setState(() {
            _isCameraReady = false;
            _textureId = null;
          });
        } else {
          _isCameraReady = false;
          _textureId = null;
        }
      }
    }
  }

  Future<void> _handleMetricsChange() async {
    if (_isDisposed) return;
    // Re-read the native sensor so _currentOrientation tracks the device side
    // (landscapeLeft vs landscapeRight) once it eventually reports — and so
    // the camera receives the correct orientation. The gate inside
    // _applyDeviceOrientation also falls back to the surface size when the
    // sensor is still stuck on portrait.
    try {
      final nativeOrientation =
          await _orientationCommunicator.orientation(useSensor: true);
      if (_isDisposed) return;
      await _applyDeviceOrientation(
        VikaImageOrientation.fromNative(nativeOrientation),
      );
    } catch (_) {
      if (_isDisposed) return;
      await _applyDeviceOrientation(_currentOrientation);
    }
  }

  Future<void> _stopAndDisposePoseChannel() async {
    try {
      await _poseChannel.stopDetection();
    } catch (_) {}
    try {
      await _poseChannel.dispose();
    } catch (_) {}
  }

  Future<void> _shutdownPipelines() {
    return _pipelineShutdownFuture ??= _shutdownPipelinesOnce();
  }

  Future<void> _shutdownPipelinesOnce() async {
    _setTimer?.cancel();
    _pendingStaffBackTimer?.cancel();

    final orientationSubscription = _orientationSubscription;
    _orientationSubscription = null;
    try {
      await orientationSubscription?.cancel();
    } catch (_) {}

    final landmarkSubscription = _landmarkSubscription;
    _landmarkSubscription = null;
    try {
      await landmarkSubscription?.cancel();
    } catch (_) {}

    try {
      await widget.exercise.disposeDetectors();
    } catch (_) {}
    await _stopAndDisposePoseChannel();
    await _disposeFallbackCamera();
  }

  Future<void> _loadDebugMode() async {
    final isStaff = await _loadStaffFlag();
    final mode = await DebugPreferences.loadMode();
    if (!mounted) return;
    _isStaffUser = isStaff;
    final resolved = _resolveDebugMode(mode);
    widget.exercise.debugMode = resolved;
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

  bool get _isFrontCamera => _currentLens == CameraLensDirection.front;

  void _startOrientationListener() {
    if (!ExerciseBase.kLandscapeRotationEnabled) {
      return;
    }

    // Use the sensor for left/right landscape side. The gate below resolves this
    // against Flutter's actual surface size so logic cannot stay portrait after
    // the UI has rotated.
    _orientationSubscription = _orientationCommunicator
        .onOrientationChanged(useSensor: true)
        .listen(_handleNativeOrientation);
  }

  Future<void> _refreshCurrentOrientation() async {
    if (!ExerciseBase.kLandscapeRotationEnabled) {
      return;
    }

    // Hard-cap the sensor read at 1.5s. On iOS, asking
    // NativeDeviceOrientationCommunicator with useSensor:true spins up
    // CMMotionManager which (per system console) reads
    // /private/var/Managed Preferences/mobile/com.apple.CoreMotion.plist.
    // On some iPhones that read can stall (managed-prefs sandbox check)
    // and never returns. Without the timeout, _initCamera() never
    // proceeds and the user sits forever on "Đang khởi động camera".
    try {
      final nativeOrientation = await _orientationCommunicator
          .orientation(useSensor: true)
          .timeout(const Duration(milliseconds: 1500));
      _setCurrentOrientation(
          VikaImageOrientation.fromNative(nativeOrientation));
    } catch (_) {
      // Sensor read failed or timed out — default to portrait. The
      // orientation stream subscription (_orientationSubscription) will
      // still fire async updates once CMMotionManager warms up.
      _setCurrentOrientation(VikaImageOrientation.portrait);
    }
  }

  void _handleNativeOrientation(NativeDeviceOrientation nativeOrientation) {
    final newOrientation = VikaImageOrientation.fromNative(nativeOrientation);
    unawaited(_applyDeviceOrientation(newOrientation));
  }

  Future<void> _applyDeviceOrientation(
    VikaImageOrientation newOrientation,
  ) async {
    if (_isDisposed) return;

    final wasGated = _orientationPauseActive;
    final changed = newOrientation != _currentOrientation;
    if (changed) {
      _setCurrentOrientation(newOrientation);
      if (_isCurrentOrientationSupported) {
        await _sendOrientationToNative();
      }
    }

    final blocked = _syncOrientationGate();
    final gateChanged = wasGated != _orientationPauseActive;
    if (!_isDisposed && mounted && (changed || blocked || gateChanged)) {
      setState(() {});
    }
  }

  void _setCurrentOrientation(VikaImageOrientation orientation) {
    _currentOrientation = orientation;
  }

  // The Flutter window is locked to portraitUp; the page rotates manually via
  // `RotatedBox`. So the session orientation is just the latest sensor
  // reading — there's no surface-vs-sensor reconciliation to do.
  VikaImageOrientation get _sessionOrientation => _currentOrientation;

  bool get _isCurrentOrientationSupported {
    if (!ExerciseBase.kLandscapeRotationEnabled) {
      return true;
    }
    return widget.exercise.supportedOrientations.contains(_sessionOrientation);
  }

  bool get _orientationGateActive =>
      ExerciseBase.kLandscapeRotationEnabled && !_isCurrentOrientationSupported;

  String get _orientationFeedbackCode {
    final wantsLandscape = !widget.exercise.supportedOrientations
        .contains(VikaImageOrientation.portrait);
    return wantsLandscape
        ? 'wrong_orientation_landscape'
        : 'wrong_orientation_portrait';
  }

  bool _isOrientationFeedback(String? value) {
    return value == 'wrong_orientation_landscape' ||
        value == 'wrong_orientation_portrait';
  }

  bool _syncOrientationGate() {
    if (!ExerciseBase.kLandscapeRotationEnabled) {
      return false;
    }

    if (!_isCurrentOrientationSupported) {
      widget.exercise.resultIssues.feedback['System'] =
          _orientationFeedbackCode;
      _feedback =
          Map<String, String>.from(widget.exercise.resultIssues.feedback);
      if (!_orientationPauseActive) {
        widget.exercise.manualPause();
        _orientationPauseActive = true;
      }
      return true;
    }

    if (_isOrientationFeedback(
        widget.exercise.resultIssues.feedback['System'])) {
      widget.exercise.resultIssues.feedback.remove('System');
    }
    if (_isOrientationFeedback(_feedback['System'])) {
      _feedback.remove('System');
    }

    if (_orientationPauseActive) {
      _orientationPauseActive = false;
      if (!_isManualPause) {
        widget.exercise.manualResume();
      }
    }
    unawaited(_sendOrientationToNative());
    return false;
  }

  int get _cameraSceneQuarterTurns {
    final orientation = _sessionOrientation;
    if (!ExerciseBase.kLandscapeRotationEnabled ||
        _runtime != _PoseRuntime.nativeMediaPipe ||
        !Platform.isAndroid ||
        !orientation.isLandscape) {
      return 0;
    }

    return orientation.androidNativeCameraSceneQuarterTurns;
  }

  Widget _orientCameraScene(Widget child) {
    final quarterTurns = _cameraSceneQuarterTurns;
    if (quarterTurns == 0) {
      return child;
    }
    return RotatedBox(
      quarterTurns: quarterTurns,
      child: child,
    );
  }

  Future<void> _sendOrientationToNative() async {
    if (!ExerciseBase.kLandscapeRotationEnabled ||
        !_isCurrentOrientationSupported) {
      return;
    }

    final orientation = _sessionOrientation;
    if (_lastSentOrientation == orientation &&
        _lastSentOrientationFrontCamera == _isFrontCamera) {
      return;
    }

    _lastSentOrientation = orientation;
    _lastSentOrientationFrontCamera = _isFrontCamera;

    final updates = <Future<void>>[
      _segmentationChannel
          .setOrientation(
            orientation: orientation,
            isFrontCamera: _isFrontCamera,
          )
          .catchError((Object _) {}),
    ];

    if (_runtime == _PoseRuntime.nativeMediaPipe) {
      updates.add(
        _poseChannel
            .setOrientation(
              orientation: orientation,
              isFrontCamera: _isFrontCamera,
            )
            .catchError((Object _) {}),
      );
    }

    await Future.wait(updates);
  }

  Future<void> _applyDebugMode(DebugMode mode) async {
    await DebugPreferences.saveMode(mode);
    if (!mounted) return;
    final resolved = _resolveDebugMode(mode);
    widget.exercise.debugMode = resolved;
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
      _requestExit();
      return;
    }

    final openedMenu = _recordStaffBackTap();
    _pendingStaffBackTimer?.cancel();
    if (openedMenu) return;

    _pendingStaffBackTimer = Timer(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      _debugBackTapCount = 0;
      _debugFirstBackTap = null;
      _requestExit();
    });
  }

  /// Whether the user is mid-set with progress an accidental back would discard.
  /// Scoped to the genuinely-active window: the exercise has activated or at
  /// least one rep is logged, and the set is not already finishing/torn down.
  bool get _isSetInProgress {
    if (_isCompletingSet || _didComplete) return false;
    final state = widget.exercise.exerciseState;
    if (state == ExerciseState.completed) return false;
    return state == ExerciseState.activated || widget.exercise.repCount > 0;
  }

  /// Single exit gate for both back affordances. While a set is in progress the
  /// confirm dialog stands between the user and a lost set; otherwise (intro,
  /// post-completion) back is instant. Mirrors the PopScope canPop condition so
  /// the chrome back arrow and the system back behave identically.
  void _requestExit() {
    if (_isSetInProgress) {
      unawaited(_confirmExitDuringActiveSet());
    } else {
      widget.onBack();
    }
  }

  /// Shown when the system back / back-gesture is invoked mid-set. Only exits
  /// on explicit confirmation; the default (barrier dismiss / "Tiếp tục") keeps
  /// the session running. Uses the existing exit path (widget.onBack).
  Future<void> _confirmExitDuringActiveSet() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: VikaIvory.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Thoát buổi tập?',
                  style: TextStyle(
                    fontFamily: VikaIvory.fontFamily,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: VikaIvory.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tiến độ hiệp này sẽ không được lưu. Cố thêm chút nữa nhé!',
                  style: TextStyle(
                    fontFamily: VikaIvory.fontFamily,
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: VikaIvory.inkSoft,
                  ),
                ),
                const SizedBox(height: 22),
                // Primary, encouraging action: keep the session going.
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: VikaIvory.ink,
                      foregroundColor: VikaIvory.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Tiếp tục',
                      style: TextStyle(
                        fontFamily: VikaIvory.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // De-emphasised exit.
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    'Thoát',
                    style: TextStyle(
                      fontFamily: VikaIvory.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: VikaIvory.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (shouldExit == true && mounted) {
      // Lifecycle boundary: the user confirmed leaving mid-set, discarding the
      // in-progress set. Both the chrome back arrow and the system / predictive
      // back gesture (PopScope) funnel through this confirm path. No-op without
      // consent; exercise_id only.
      unawaited(
        AnalyticsService.instance.capture(
          'exercise_abandoned',
          props: {'exercise_id': widget.definition.id},
        ),
      );
      widget.onBack();
    }
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

  // ─── Reviewer tracking-demo shortcut (squat only) ───
  //
  Future<void> _initCamera() async {
    if (_setTeardownOwnsPipeline || _isLifecyclePaused || _isInitializing) {
      return;
    }

    final initGeneration = _cameraInitGeneration;
    _activeCameraInitGeneration = initGeneration;
    _resumeInitRequested = false;
    _isInitializing = true;
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _isCameraReady = false;
        _cameraErrorMessage = null;
        _textureId = null;
      });
    }

    try {
      await _refreshCurrentOrientation();
      if (_shouldAbortCameraInit(initGeneration)) return;
      _syncOrientationGate();
      await _disposeFallbackCamera();
      if (_shouldAbortCameraInit(initGeneration)) return;

      final status = await Permission.camera.request();
      if (_shouldAbortCameraInit(initGeneration)) return;
      _permissionStatus = status;
      if (!status.isGranted) {
        if (!_isDisposed && mounted) {
          setState(() {
            _isInitializing = false;
            _isCameraReady = false;
            _cameraErrorMessage = status.isPermanentlyDenied
                ? 'Quyền camera chưa được bật. Hãy mở lại trong cài đặt.'
                : 'AI cần camera để theo dõi bài tập.';
          });
        }
        return;
      }

      try {
        _ensureLandmarkSubscription();
        // Hard-timeout the native init so a hung PoseLandmarkerService
        // (completion handler never called, deadlocked Swift queue)
        // doesn't strand the UI on "Đang khởi động camera" forever. After
        // 8 seconds we throw and surface a real error with a Retry button.
        //
        // ML Kit fallback intentionally NOT triggered here on real devices
        // (iPhone/Android). It's for simulator/emulator only — see
        // _shouldUseMlKitFallback() which gates on specific error strings
        // ("x86_64", "native library", etc.) emitted by emulator builds.
        final textureId = await _poseChannel
            .initialize(
              useFrontCamera: _isFrontCamera,
              initialOrientation: _isCurrentOrientationSupported
                  ? _sessionOrientation
                  : VikaImageOrientation.portrait,
              isFrontCamera: _isFrontCamera,
            )
            .timeout(const Duration(seconds: 8));
        if (_shouldAbortCameraInit(initGeneration)) {
          await _stopAndDisposePoseChannel();
          return;
        }
        await _poseChannel.startDetection().timeout(const Duration(seconds: 4));
        if (_shouldAbortCameraInit(initGeneration)) {
          await _stopAndDisposePoseChannel();
          return;
        }

        setState(() {
          _runtime = _PoseRuntime.nativeMediaPipe;
          _textureId = textureId;
          _isCameraReady = true;
          _isInitializing = false;
        });
      } on TimeoutException catch (_) {
        // Native side never responded. Surface an error so the user can
        // retry — don't auto-fallback to ML Kit on real device.
        if (_shouldAbortCameraInit(initGeneration)) return;
        debugPrint('[Vika] Native pose init timed out after 8s.');
        try {
          await _poseChannel.dispose();
        } catch (_) {}
        if (!_isDisposed && mounted) {
          setState(() {
            _isInitializing = false;
            _isCameraReady = false;
            _textureId = null;
            _cameraErrorMessage = 'Camera khoi dong qua lau. Hay thu lai.';
          });
        }
      } on PlatformException catch (error) {
        if (_shouldAbortCameraInit(initGeneration)) return;
        if (_shouldUseMlKitFallback(error)) {
          // Emulator-only path. _shouldUseMlKitFallback gates on error
          // strings emitted by simulator builds where the native MediaPipe
          // dylib isn't shipped (x86_64, missing native library).
          await _startMlKitFallback(error.message);
          return;
        }
        if (!_isDisposed && mounted) {
          setState(() {
            _isInitializing = false;
            _isCameraReady = false;
            _textureId = null;
            _cameraErrorMessage = error.message ??
                'Khong the khoi dong MediaPipe tren thiet bi nay.';
          });
        }
      } on MissingPluginException catch (_) {
        // Native MediaPipe channel not implemented for this build target
        // (typically simulator without native pods). Use ML Kit fallback —
        // emulator path only.
        if (_shouldAbortCameraInit(initGeneration)) return;
        await _startMlKitFallback('Native pose landmarker not registered');
      } catch (_) {
        // Any other error — surface to the user with retry instead of
        // silently swapping engines on a real device.
        if (_shouldAbortCameraInit(initGeneration)) return;
        try {
          await _poseChannel.dispose();
        } catch (_) {}
        if (!_isDisposed && mounted) {
          setState(() {
            _isInitializing = false;
            _isCameraReady = false;
            _textureId = null;
            _cameraErrorMessage = 'Loi khi khoi dong camera. Hay thu lai.';
          });
        }
      }
    } finally {
      if (_activeCameraInitGeneration == initGeneration) {
        _activeCameraInitGeneration = null;
        if (_isInitializing) {
          if (!_isDisposed && mounted) {
            setState(() {
              _isInitializing = false;
            });
          } else {
            _isInitializing = false;
          }
        }
      }

      if (_resumeInitRequested &&
          !_isInitializing &&
          !_isLifecyclePaused &&
          !_setTeardownOwnsPipeline &&
          mounted) {
        _resumeInitRequested = false;
        unawaited(_initCamera());
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_setTeardownOwnsPipeline || _isLifecyclePaused) return;
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
        await _sendOrientationToNative();
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
      await _sendOrientationToNative();
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
    if (_isDisposed ||
        _isCompletingSet ||
        _didComplete ||
        _isLifecyclePaused ||
        (_isProcessingFrame && !ExerciseBase.kDiagnosticMode)) {
      return;
    }

    if (!ExerciseBase.kDiagnosticMode) {
      _isProcessingFrame = true;
    }

    try {
      if (_isDisposed || _isLifecyclePaused) return;
      _schedulePersonDetection();

      _currentLens = PoseLandmarkerAdapter.lensDirectionFromChannelData(data);
      _imageRotation =
          PoseLandmarkerAdapter.inputImageRotationFromChannelData(data);
      _imageSize =
          PoseLandmarkerAdapter.imageSizeFromChannelData(data) ?? Size.zero;
      if (ExerciseBase.kDiagnosticMode) {
        widget.exercise.debugData['nativeRotDeg'] =
            data['rotationDegrees'] ?? '-';
        widget.exercise.debugData['nativeRotMs'] =
            data['rotationDurationMs'] ?? '-';
        widget.exercise.debugData['nativeOrientation'] =
            data['orientation'] ?? 'cameraX';
      }

      final pose = PoseLandmarkerAdapter.fromChannelData(data);
      if (_syncOrientationGate()) {
        _detectedPose = pose;
        _processVoiceFrame(hasPose: pose != null);
        if (!_isDisposed && mounted) {
          setState(() {});
        }
        return;
      }

      if (pose != null) {
        _handlePose(pose);
      } else {
        if (_isDisposed) return;
        _detectedPose = null;
        _feedback = widget.exercise.processNoPoseFrame();
        _processVoiceFrame(hasPose: false);
      }

      if (!_isDisposed && mounted) {
        setState(() {});
      }
    } finally {
      if (!ExerciseBase.kDiagnosticMode) {
        _isProcessingFrame = false;
      }
    }
  }

  void _handlePoseResult(List<dynamic>? result) {
    if (_isDisposed) {
      return;
    }

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
      _scheduleSetCompletion();
    }
  }

  void _scheduleSetCompletion() {
    if (_didComplete || _isCompletingSet || _isDisposed) {
      return;
    }

    _didComplete = true;
    _isCompletingSet = true;
    _setCompleteTimer?.cancel();
    unawaited(_poseChannel.stopDetection().catchError((Object _) {}));

    // Let the final rep verdict and completion cue drain before the parent
    // swaps this active page out of the tree.
    _setCompleteTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_finishSetAndNotifyParent());
    });
  }

  Future<void> _finishSetAndNotifyParent() async {
    if (_isDisposed) return;
    final voiceCoach = _voiceCoach;
    if (voiceCoach != null) {
      await voiceCoach.waitUntilIdle(timeout: _voiceCompletionTimeout);
    }
    if (_isDisposed) return;
    await _shutdownPipelines();
    _voiceCoach?.dispose();
    _voiceCoach = null;

    if (_isDisposed || !mounted) return;
    widget.onSetComplete(widget.exercise.logger);
  }

  void _handleLandmarkStreamError(Object error) {
    if (_setTeardownOwnsPipeline || _isLifecyclePaused || !mounted) {
      return;
    }

    setState(() {
      _isInitializing = false;
      _isCameraReady = false;
      _cameraErrorMessage = 'Khong the nhan du lieu pose. Hay thu lai.';
    });
  }

  Future<void> _startMlKitFallback(String? nativeErrorMessage) async {
    if (_setTeardownOwnsPipeline || _isLifecyclePaused) return;
    debugPrint(
      '[Vika] Falling back to Flutter camera + ML Kit: ${nativeErrorMessage ?? "unknown native init error"}',
    );
    try {
      await _poseChannel.dispose();
    } catch (_) {}
    if (_setTeardownOwnsPipeline || _isLifecyclePaused || !mounted) return;
    await _initMlKitCamera();
  }

  bool _shouldUseMlKitFallback(PlatformException error) {
    // ML Kit is for simulator/emulator only — real iPhones and Android phones
    // must use the native MediaPipe Pose Landmarker. We only swap engines
    // when the native error matches one of the emulator-specific signals
    // emitted by:
    //   • Android x86_64 emulator: ensureRuntimeSupport() throws
    //     "is not available on x86_64 Android emulators"
    //   • Android emulator missing native lib: "libmediapipe_tasks_vision_jni"
    //   • iOS simulator: handled separately via MissingPluginException
    // Any other PlatformException (model load failure, GPU init, etc.) on a
    // real device surfaces a retry UI instead of silently falling back to a
    // less accurate engine.
    final message = (error.message ?? '').toLowerCase();
    return message.contains('x86_64 android emulators') ||
        message.contains('libmediapipe_tasks_vision_jni');
  }

  Future<void> _initMlKitCamera() async {
    if (_setTeardownOwnsPipeline || _isLifecyclePaused) return;
    await _disposeFallbackCamera();
    if (_setTeardownOwnsPipeline || _isLifecyclePaused || !mounted) return;

    final cameras = await availableCameras();
    if (_setTeardownOwnsPipeline || _isLifecyclePaused || !mounted) return;
    if (cameras.isEmpty) {
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
        // Match the native path's 720p-class preview quality when fallback is
        // needed on simulator/emulator builds.
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      try {
        await controller.initialize().timeout(const Duration(seconds: 6));
        if (_setTeardownOwnsPipeline || _isLifecyclePaused || !mounted) {
          await controller.dispose();
          return;
        }
        await controller.startImageStream(_processFallbackCameraImage);
        if (_setTeardownOwnsPipeline || _isLifecyclePaused || !mounted) {
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
        await _sendOrientationToNative();
        return;
      } catch (error) {
        debugPrint('[Vika] Fallback camera ${camera.name} failed: $error');
        try {
          await controller.dispose();
        } catch (_) {}
      }
    }

    if (_setTeardownOwnsPipeline || _isLifecyclePaused || !mounted) return;
    setState(() {
      _runtime = _PoseRuntime.mlKitFallback;
      _isInitializing = false;
      _isCameraReady = false;
      _cameraErrorMessage = 'Khong the khoi dong camera fallback. Hay thu lai.';
    });
  }

  Future<void> _switchMlKitCamera(CameraLensDirection nextLens) async {
    if (_setTeardownOwnsPipeline || _isLifecyclePaused) return;
    if (_availableCameras.isEmpty) {
      _availableCameras = await availableCameras();
    }
    if (_setTeardownOwnsPipeline || _isLifecyclePaused || !mounted) return;
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
    if (_setTeardownOwnsPipeline || _isLifecyclePaused || !mounted) {
      await controller.dispose();
      return;
    }
    await controller.startImageStream(_processFallbackCameraImage);
    if (_setTeardownOwnsPipeline || _isLifecyclePaused || !mounted) {
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
    if (_isDisposed ||
        _isCompletingSet ||
        _didComplete ||
        _isLifecyclePaused ||
        (_isProcessingFrame && !ExerciseBase.kDiagnosticMode)) {
      return;
    }
    if (!ExerciseBase.kDiagnosticMode) {
      _isProcessingFrame = true;
    }
    _detectPoseFromFallback(cameraImage).whenComplete(() {
      if (!ExerciseBase.kDiagnosticMode) {
        _isProcessingFrame = false;
      }
    });
  }

  Future<void> _detectPoseFromFallback(CameraImage cameraImage) async {
    if (_setTeardownOwnsPipeline || _isLifecyclePaused) return;
    try {
      final inputImage = _buildInputImage(cameraImage);
      if (inputImage == null) {
        return;
      }

      _schedulePersonDetection(inputImage);
      final poses = await _poseDetector.processImage(inputImage);
      if (_setTeardownOwnsPipeline || _isLifecyclePaused || !mounted) return;

      if (_syncOrientationGate()) {
        _detectedPose = poses.isNotEmpty ? poses.first : null;
        _processVoiceFrame(hasPose: poses.isNotEmpty);
        if (!_isDisposed && mounted) {
          setState(() {});
        }
        return;
      }

      if (poses.isNotEmpty) {
        _handlePose(poses.first);
      } else {
        if (_isDisposed || _isLifecyclePaused) return;
        _detectedPose = null;
        _feedback = widget.exercise.processNoPoseFrame();
        _processVoiceFrame(hasPose: false);
      }

      if (!_isDisposed && !_isLifecyclePaused && mounted) {
        setState(() {});
      }
    } catch (_) {
      if (_setTeardownOwnsPipeline || _isLifecyclePaused || !mounted) return;
      setState(() {
        _isCameraReady = false;
        _cameraErrorMessage = 'Khong the nhan du lieu pose. Hay thu lai.';
      });
    }
  }

  void _handlePose(Pose pose) {
    if (_isDisposed || _isLifecyclePaused) {
      return;
    }

    _detectedPose = pose;
    _handlePoseResult(
      widget.exercise.processPose(
        pose.landmarks,
        imageSize: _imageSize == Size.zero ? null : _imageSize,
      ),
    );
    _maybeEmitRepReward();
  }

  /// Feeds the ambient Hearthlight reward layer off real rep completions.
  ///
  /// A clean rep accumulates and fires a bloom; a faulted rep is met with
  /// silence (the pool holds, nothing flashes). The per-rep clean/faulted
  /// verdict comes straight from the interpreter via [ExerciseLogger.repLogs] —
  /// faulted reps still increment the rep count but never trigger a reward.
  void _maybeEmitRepReward() {
    final reps = widget.exercise.repCount;
    if (reps <= _rewardRepSeen) {
      _rewardRepSeen = reps; // tolerate a counter reset between sets
      return;
    }
    final logs = widget.exercise.logger.repLogs;
    for (var n = _rewardRepSeen + 1; n <= reps; n++) {
      if (_repWasClean(logs, n)) {
        _cleanRepCount++;
        _rewardPulseId++;
      }
    }
    _rewardRepSeen = reps;
  }

  bool _repWasClean(List<RepLog> logs, int repNumber) {
    for (final log in logs) {
      if (log.repNumber == repNumber) return log.correctForm;
    }
    // A counted rep without a matching log shouldn't happen; stay silent rather
    // than risk rewarding a rep we can't confirm was clean.
    return false;
  }

  void _schedulePersonDetection([InputImage? inputImage]) {
    if (_isDisposed ||
        _isCompletingSet ||
        _personDetectionInFlight ||
        _isLifecyclePaused ||
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
        if (_isDisposed) return;
        _personDetectionInFlight = false;
      }),
    );
  }

  void _processVoiceFrame({required bool hasPose}) {
    if (_isDisposed || _isLifecyclePaused) {
      return;
    }

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
    // The ML Kit fallback path only fires when native MediaPipe fails to
    // initialize (e.g. x86_64 simulators). The Android formula combines
    // sensor mount angle with device rotation; iOS ML Kit does not have
    // first-class landscape support in this fallback and uses sensor
    // orientation only — acceptable since iOS simulator cameras don't run
    // a real preview and physical iPhones use the native MediaPipe path.
    final rotation = ExerciseBase.kLandscapeRotationEnabled &&
            Platform.isAndroid
        ? _imageRotationFromVikaOrientation(
            orientation: _sessionOrientation,
            sensorOrientation: camera.sensorOrientation,
            isFrontCamera: camera.lensDirection == CameraLensDirection.front,
          )
        : _rotationFromSensor(camera.sensorOrientation);
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
    return _rotationFromDegrees(sensorOrientation);
  }

  InputImageRotation _imageRotationFromVikaOrientation({
    required VikaImageOrientation orientation,
    required int sensorOrientation,
    required bool isFrontCamera,
  }) {
    // ML Kit's Android formula requires both device rotation and the camera
    // sensor mount angle; device orientation alone is not enough on 90/270 sensors.
    final deviceRotationDegrees = orientation.androidSurfaceRotationDegrees;
    final rotationDegrees = isFrontCamera
        ? (sensorOrientation + deviceRotationDegrees) % 360
        : (sensorOrientation - deviceRotationDegrees + 360) % 360;
    return _rotationFromDegrees(rotationDegrees);
  }

  InputImageRotation _rotationFromDegrees(int rotationDegrees) {
    switch (rotationDegrees % 360) {
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
      if (_isDisposed || _isCompletingSet) return;
      if (widget.exercise.isPaused) return;
      if (widget.exercise.exerciseState != ExerciseState.activated) return;
      setState(() => _setElapsedSeconds++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final permissionGranted = _permissionStatus?.isGranted ?? true;
    final Widget inner;
    if (!permissionGranted) {
      inner = _buildCameraFallback(
        icon: Icons.camera_alt_outlined,
        title: 'Cần quyền truy cập camera',
        subtitle: _cameraErrorMessage ??
            'Cấp quyền camera để AI có thể theo dõi form.',
        actionLabel: _permissionStatus?.isPermanentlyDenied == true
            ? 'Mở Cài đặt'
            : 'Cấp quyền',
        onAction: _permissionStatus?.isPermanentlyDenied == true
            ? openAppSettings
            : _initCamera,
      );
    } else if (!_isCameraReady || _textureId == null) {
      final waitingForFallback =
          _runtime == _PoseRuntime.mlKitFallback && _cameraController == null;
      final nativeReady =
          _runtime == _PoseRuntime.nativeMediaPipe && _textureId != null;
      final fallbackReady =
          _runtime == _PoseRuntime.mlKitFallback && _cameraController != null;
      if (nativeReady || fallbackReady) {
        inner = _buildActiveLayout(context);
      } else {
        inner = _buildCameraFallback(
          icon: _cameraErrorMessage == null
              ? Icons.videocam_outlined
              : Icons.videocam_off_outlined,
          title: _cameraErrorMessage == null
              ? 'Đang khởi động camera'
              : 'Camera chưa sẵn sàng',
          subtitle: _cameraErrorMessage ??
              (_isInitializing || waitingForFallback
                  ? 'AI đang kết nối camera để theo dõi form của bạn.'
                  : 'Đang chờ camera khởi động…'),
          actionLabel: _cameraErrorMessage == null ? null : 'Thử lại',
          onAction: _cameraErrorMessage == null ? null : _initCamera,
        );
      }
    } else {
      inner = _buildActiveLayout(context);
    }

    // Manually rotate the entire page to match the device sensor. The OS is
    // locked to portraitUp (see OrientationLock); this RotatedBox is the
    // single rotation point — it wraps the chrome, the camera Texture, and
    // the skeleton overlay as one unit, so they always stay in sync. The
    // native camera buffer is rotated server-side to match the same sensor
    // reading (see PoseLandmarkerService.applyOrientation), so the image
    // inside the rotated UI is already upright for the user's view.
    final Widget content;
    if (!ExerciseBase.kLandscapeRotationEnabled) {
      content = inner;
    } else {
      content = RotatedBox(
        quarterTurns: _currentOrientation.uiQuarterTurns,
        child: inner,
      );
    }

    // Guard accidental Android back / back-gesture while a set is in progress.
    // PopScope blocks only the route-level pop (system / predictive back); the
    // confirm path exits imperatively via widget.onBack. It lives only in the
    // active phase, so the intro and summary screens keep their instant back.
    return PopScope(
      canPop: !_isSetInProgress,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_confirmExitDuringActiveSet());
      },
      child: content,
    );
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
    final orientationGuidanceActive =
        _orientationPauseActive && guidanceCopy != null;
    final coachMessage = _coachMessage;
    final activeState =
        widget.exercise.exerciseState == ExerciseState.activated &&
            !widget.exercise.isPaused;
    final trackedMetrics = widget.exercise.trackedDebugMetrics;
    final debugMode = trackedMetrics.isEmpty
        ? DebugMode.off
        : _resolveDebugMode(_settingsDebugMode);
    final debugEnabled = debugMode != DebugMode.off;
    widget.exercise.debugMode = debugMode;
    final showDebugEntryBadge =
        trackedMetrics.isNotEmpty && (debugEnabled || _isStaffUser);
    final showDebugPanel = debugEnabled && _debugPanelOpen;
    final previewFit = _previewFit;

    // The persistent phase verb (XUỐNG/LÊN) and phase hint are gone in v9:
    // they duplicated the user's own proprioception and were illegible from
    // 2.5 m anyway. Direction is now the quiet chevron stream's job; the
    // bottom zone belongs to the rep hero alone.

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
          _orientCameraScene(
            RepaintBoundary(
              child: ColoredBox(
                color: Colors.black,
                child: ClipRect(
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: previewFit,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: _previewRenderSize.width,
                        height: _previewRenderSize.height,
                        child: _buildPreviewSurface(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Layer 2: Skeleton overlay (unchanged — jade colors preserved) ──
          Positioned.fill(
            child: _orientCameraScene(
              IgnorePointer(
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
                          fit: previewFit,
                          // Native texture preview and native pose landmarks
                          // are produced from the same oriented frame. The old
                          // Flutter camera fallback still needs front-camera
                          // mirroring to match CameraPreview.
                          mirrorHorizontally:
                              _runtime == _PoseRuntime.mlKitFallback &&
                                  _currentLens == CameraLensDirection.front,
                          debugData: widget.exercise.debugData,
                          debugLabelsEnabled: debugEnabled,
                          style: SkeletonStyle.vikaCream),
                    );
                  },
                ),
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

          // ── Layer 4.5: Ambient reward (Hearthlight) ──
          // Additive warm-light feedback for clean reps. Sits above the camera
          // + scrims but below the chrome, and is bottom/edge anchored +
          // transparent through the center, so the live body and the jade
          // skeleton stay fully visible. Always mounted (even when paused) so
          // the accumulated hearth pool persists across the whole set.
          Positioned.fill(
            child: RepRewardLayer(
              cleanReps: _cleanRepCount,
              totalReps: widget.totalReps,
              pulseId: _rewardPulseId,
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

          // ── Layer 5: Top chrome right (flip + pause) ──
          // No live form score lives here — real-time feedback on this screen
          // is encouragement and safety only, never a verdict the user performs
          // under. The form verdict is computed after the set.
          Positioned(
            top: media.padding.top + 10,
            right: 16,
            child: IvoryTopChromeRight(
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

          // ── Layer 7: PT reference loop (top-left, just below chrome row) ──
          // JSX places it at top:116 (16px below chrome bottom). chrome bottom
          // = media.padding.top + 10 + 36 = +46, so PT loop sits at +56.
          if (activeState &&
              !(debugEnabled && _debugPanelOpen) &&
              guidanceCopy == null)
            Positioned(
              top: media.padding.top + 56,
              left: 16,
              child: IvoryPTReferenceLoop(
                videoAsset: widget.definition.videoAsset,
              ),
            ),

          // ── Layer 8: Coach caption (upper third, timed) ──
          // High enough to clear the center hold ring / hybrid cue and far
          // from the bottom rep hero; the caption times its own ~2s life.
          if (showCaption)
            Positioned(
              left: 24,
              right: 24,
              top: media.padding.top + 64,
              child: IvoryCoachCaption(message: coachMessage),
            ),

          // ── Layer 9: Setup/safety guidance — signage, not paragraphs ──
          // Glyph-first, animated directionally, upper-center of the screen
          // so it never hides the user's own body in the mirror.
          if (guidanceCopy != null && !widget.exercise.isPaused)
            Align(
              alignment: const Alignment(0, -0.45),
              child: IgnorePointer(
                child: GuidanceSignage(
                  icon: guidanceCopy.icon,
                  kind: guidanceCopy.kind,
                  title: guidanceCopy.title,
                  body: guidanceCopy.body,
                  mode: guidanceCopy.mode,
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
                      child: _CenterOverlay(
                        state: overlayState,
                        pulseController: _pulseController,
                        progress: widget.exercise.activationProgress,
                        holdCue: bottomHoldCue,
                      ),
                    ),
            ),
          ),

          // ── Layer 11: Hold hero ring (category 1 — time-based holds) ──
          // The centerpiece for hold exercises: one large transparent ring
          // center-screen. Flowing vs frozen is derived from the accrued
          // seconds advancing or not — see HoldHeroRing.
          if (widget.isTimeBased && activeState && guidanceCopy == null)
            Center(
              child: HoldHeroRing(
                seconds: _liveHoldRingSeconds,
                targetSeconds: widget.exercise.liveHoldTargetSeconds ??
                    widget.totalReps.toDouble(),
              ),
            ),

          // ── Layer 11.5: Hybrid bottom-hold cue (category 2b) ──
          // A compact mid-rep checkpoint, structurally distinct from the
          // category-1 ring: counts DOWN, much smaller, lives 1–3 seconds.
          // "LÊN!" is deliberately the loudest visual beat — hesitating
          // loaded at the bottom is a safety problem.
          if (!widget.isTimeBased && !showDebugPanel)
            IgnorePointer(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    );
                  },
                  child: (activeState &&
                          bottomHoldCue != null &&
                          guidanceCopy == null)
                      ? HybridHoldCue(
                          // Stable key: hold → release must update the same
                          // widget so the release pop animates, not crossfade.
                          key: const ValueKey<String>('hybrid-hold-cue'),
                          remainingSeconds: bottomHoldCue.remaining,
                          readyToPush: bottomHoldCue.readyToPush,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),

          // ── Layer 12: Rep hero (category 2 — bottom-center) ──
          // The one number a rep-based user glances for. No fault marking —
          // feedback during the set is additive only; the form verdict is
          // computed after the set, never during.
          if (!widget.isTimeBased && activeState && !showDebugPanel)
            Positioned(
              left: 24,
              right: 24,
              bottom: media.padding.bottom + 28,
              child: Center(
                child: IvoryRepHero(
                  repCount: widget.exercise.repCount,
                  totalReps: widget.totalReps,
                ),
              ),
            ),

          // ── Layer 13: Pause overlay ──
          if (widget.exercise.isPaused)
            Positioned.fill(
              child: IvoryPauseOverlay(
                isManualPause: _isManualPause,
                onResume: () {
                  if (_orientationGateActive) {
                    _syncOrientationGate();
                    setState(() {});
                    return;
                  }
                  _isManualPause = false;
                  widget.exercise.manualResume();
                  setState(() {});
                },
                onEnd: widget.onBack,
              ),
            ),

          // Orientation guidance riding above the pause overlay — compact
          // pill so it never collides with the centered pause card.
          if (orientationGuidanceActive)
            Positioned(
              left: 20,
              right: 20,
              top: media.padding.top + 78,
              child: IgnorePointer(
                child: Center(
                  child: GuidanceSignage(
                    icon: guidanceCopy.icon,
                    kind: guidanceCopy.kind,
                    title: guidanceCopy.title,
                    body: guidanceCopy.body,
                    mode: guidanceCopy.mode,
                    compact: true,
                  ),
                ),
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

    if (normalized.contains('đứng yên')) {
      return null;
    }

    if (rawNormalized.contains('wrong_orientation_landscape')) {
      return const _GuidanceCopy(
        icon: Icons.screen_rotation_alt_rounded,
        kind: GuidanceGlyphKind.rotate,
        title: 'Xoay ngang máy',
        body: 'Bài này cần điẹn thoại nằm ngang để AI thấy rõ toàn thân bạn.',
        mode: SystemBannerMode.warn,
      );
    }
    if (rawNormalized.contains('wrong_orientation_portrait')) {
      return const _GuidanceCopy(
        icon: Icons.screen_rotation_alt_rounded,
        kind: GuidanceGlyphKind.rotate,
        title: 'Xoay dọc máy',
        body: 'Bài này cần màn hình dọc.',
        mode: SystemBannerMode.warn,
      );
    }
    if (rawNormalized.contains('turn to the side') ||
        normalized.contains('quay ngang') ||
        normalized.contains('quay nghiêng') ||
        normalized.contains('quay sang bên')) {
      return const _GuidanceCopy(
        icon: Icons.accessibility_new_rounded,
        kind: GuidanceGlyphKind.turnSide,
        title: 'Đứng nghiêng người',
        body:
            'Đứng nghiêng người với camera để AI thấy rõ vai, hông, gối và mắt cá.',
        mode: SystemBannerMode.warn,
      );
    }
    if (normalized.contains('quay mặt')) {
      return const _GuidanceCopy(
        icon: Icons.center_focus_strong_rounded,
        kind: GuidanceGlyphKind.faceCamera,
        title: 'Hướng về camera',
        body: 'Đứng đối diện camera để AI thấy cả hai bên người rõ hơn.',
        mode: SystemBannerMode.warn,
      );
    }
    if (rawNormalized.contains('adjust lighting') ||
        rawNormalized.contains('lighting') ||
        normalized.contains('ánh sáng') ||
        normalized.contains('hình ảnh không rõ')) {
      return const _GuidanceCopy(
        icon: Icons.light_mode_rounded,
        kind: GuidanceGlyphKind.light,
        title: 'Thêm ánh sáng',
        body:
            'Đứng chỗ sáng hơn hoặc tránh ngược sáng để AI nhận diện ổn định hơn.',
        mode: SystemBannerMode.warn,
      );
    }
    if (normalized.contains('đang tìm người')) {
      return const _GuidanceCopy(
        icon: Icons.person_search_rounded,
        kind: GuidanceGlyphKind.search,
        title: 'Đang tìm người',
        body: 'Đứng trong khung hình để bắt đầu.',
        mode: SystemBannerMode.scan,
      );
    }
    if (normalized.contains('tạm dừng') ||
        normalized.contains('quay lại khung hình')) {
      return const _GuidanceCopy(
        icon: Icons.pause_circle_filled_rounded,
        kind: GuidanceGlyphKind.still,
        title: 'Tạm dừng',
        body: 'Đứng trong khung hình để tiếp tục.',
        mode: SystemBannerMode.pause,
      );
    }
    if (normalized.contains('phần trên cơ thể')) {
      return const _GuidanceCopy(
        icon: Icons.accessibility_new_rounded,
        kind: GuidanceGlyphKind.stepBack,
        title: 'Lùi lại chút',
        body: 'Lùi lại một chút để thấy rõ vai, khuỷu tay và hông.',
        mode: SystemBannerMode.warn,
      );
    }
    if (rawNormalized.contains('body not fully visible') ||
        normalized.contains('toàn thân')) {
      return const _GuidanceCopy(
        icon: Icons.accessibility_new_rounded,
        kind: GuidanceGlyphKind.stepBack,
        title: 'Lùi lại',
        body: 'Lùi lại hoặc hạ điện thoại để thấy từ vai đến bàn chân.',
        mode: SystemBannerMode.warn,
      );
    }
    if (normalized.contains('trong khung hình') ||
        normalized.contains('vai, hông') ||
        normalized.contains('vai, hông và gối')) {
      return const _GuidanceCopy(
        icon: Icons.fit_screen_rounded,
        kind: GuidanceGlyphKind.stepBack,
        title: 'Chỉnh khung hình',
        body: 'Lùi lại hoặc chỉnh góc điện thoại để AI nhìn rõ hơn.',
        mode: SystemBannerMode.warn,
      );
    }
    if (normalized.contains('vào tư thế') ||
        normalized.contains('đứng trong khung') ||
        normalized.contains('bắt đầu')) {
      return _GuidanceCopy(
        icon: Icons.accessibility_new_rounded,
        kind: GuidanceGlyphKind.faceCamera,
        title: 'Vào vị trí',
        body: message,
        mode: SystemBannerMode.info,
      );
    }

    return null;
  }

  String _translateSystemMessage(String raw) {
    if (raw.contains('Please turn to the side')) {
      return 'Quay ngang người với camera để AI theo dõi tốt hơn';
    }
    if (raw.contains('Body not fully visible')) {
      return 'Lùi lại, giữ toàn thân vào khung';
    }
    if (raw.contains('Adjust lighting/position')) {
      return 'Di chuyển ra chỗ sáng hơn để AI nhận diện tốt hơn';
    }
    if (raw.contains('⏸') || raw.contains('⚸')) {
      return 'Tạm dừng. đứng trong  khung ảnh để tiếp tục';
    }
    return raw.replaceAll('⚠️ ', '').replaceAll('⏸ ', '').replaceAll('⚸ ', '');
  }

  /// Accrued correct seconds for the hold hero ring. Holds the last known
  /// value when the exercise reports null (user out of the hold pose) so the
  /// numeral freezes in place instead of resetting.
  double get _liveHoldRingSeconds {
    final live = widget.exercise.liveHoldSeconds;
    if (live != null) {
      _lastKnownHoldSeconds = live;
    }
    return _lastKnownHoldSeconds;
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

    final liveSeconds = widget.exercise.liveHoldSeconds;
    final targetSeconds = widget.exercise.liveHoldTargetSeconds;
    if (liveSeconds != null && targetSeconds != null && targetSeconds > 0) {
      return _BottomHoldCue(
        progress: (liveSeconds / targetSeconds).clamp(0.0, 1.0),
        remaining: (targetSeconds - liveSeconds).clamp(0.0, targetSeconds),
        readyToPush: liveSeconds >= targetSeconds,
      );
    }

    // Time-based exercises expose their real timer through liveHoldSeconds.
    // Outside the actual hold phase, do not synthesize a squat-style timer
    // from status copy.
    if (widget.isTimeBased) return null;

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
    return 'Giữ nhịp đều, kiểm soát chuyển động.';
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
      return 'Rep tiếp theo, mở ngực ra để thân trên thẳng hơn.';
    }
    if (value.contains('Heels lifting')) {
      return 'Ép gót chân xuống sàn để đứng chắc hơn.';
    }
    if (value.contains('Dropped too fast')) {
      return 'Hạ chậm hơn một chút để AI theo dõi tốt hơn.';
    }
    if (value.contains('pause')) {
      return 'Giữ ở đáy thêm một nhịp rồi đứng lên.';
    }
    if (value == 'Going Down...') {
      return 'Hạ người xuống thật chậm.';
    }
    if (value == 'Đứng lên') {
      return 'Đứng lên dứt khoát.';
    }
    if (value == 'Push Up!') {
      return 'Đứng mạnh lên, giữ người thẳng.';
    }
    return value
        .replaceAll('Going Down...', 'Hạ người chậm xuống.')
        .replaceAll('Push Up Now!', 'Đứng lên dứt khoát.')
        .replaceAll('Hold!', 'Giữ vững.');
  }

  String _translateResult(String value) {
    if (value == 'Good Rep!' || value == 'Tốt lắm!') {
      return 'Tập chuẩn lắm. Giữ nhịp này.';
    }
    if (value == 'Fix Form') {
      return 'Rep tiếp theo chú ý form hơn nhé.';
    }
    return value;
  }

  String _translateStatus(String value) {
    final seconds = _extractDurationSeconds(value);
    if (_isHoldStatus(value)) {
      return seconds == null
          ? 'Giữ ở đáy, rồi đẩy lên.'
          : 'Giữ ở đáy ${seconds.toStringAsFixed(1)} giây, rồi đẩy lên.';
    }
    if (_isReleaseStatus(value)) {
      return 'Đẩy lên luôn.';
    }
    if (value.contains('Push Up!')) {
      return 'Đứng lên dứt khoát.';
    }
    if (value.contains('Going Down...')) {
      return 'Hạ người xuống chậm có kiểm soát.';
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

  Widget _buildPreviewSurface() {
    if (_runtime == _PoseRuntime.nativeMediaPipe) {
      // Native pipeline now rotates the AVCapture buffer to match the device
      // orientation (see PoseLandmarkerService.captureVideoOrientation), so
      // the texture is already correctly oriented. Displaying it directly
      // avoids the double-rotation that previously made the preview appear
      // 90° off in landscape.
      return Texture(textureId: _textureId!);
    }

    if (_cameraController != null) {
      return CameraPreview(_cameraController!);
    }
    return const SizedBox.shrink();
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

    if (_runtime == _PoseRuntime.nativeMediaPipe &&
        ExerciseBase.kLandscapeRotationEnabled &&
        _sessionOrientation.isLandscape) {
      return const Size(1280, 720);
    }

    final previewSize = _cameraController?.value.previewSize;
    if (previewSize != null) {
      if (previewSize.width > previewSize.height) {
        return Size(previewSize.height, previewSize.width);
      }
      return previewSize;
    }

    return const Size(720, 1280);
  }

  // Setup hard constraint: the live camera must fill the whole exercise
  // surface. Native min-zoom plus 720p capture keep the visible scene as wide
  // and sharp as possible within this no-letterbox presentation.
  BoxFit get _previewFit => BoxFit.cover;
}

enum _PoseRuntime {
  nativeMediaPipe,
  mlKitFallback,
}

enum _LiveOverlayState { scan, warn, position, hold, paused, active }

class _GuidanceCopy {
  const _GuidanceCopy({
    required this.icon,
    required this.kind,
    required this.title,
    required this.body,
    required this.mode,
  });

  final IconData icon;

  /// How the signage glyph animates — directional where meaningful.
  final GuidanceGlyphKind kind;

  /// At most ~3 words: the instruction itself, readable from 2.5 m mid-motion.
  final String title;

  /// Near-view detail, rendered small under the title.
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
        // Mid-rep bottom hold is owned by the HybridHoldCue layer — don't
        // render a duplicate centered element during squat-bottom holds.
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
        // Live activation gauge on a solid warm-dark backing disc.
        //
        // Why this layered chrome:
        //   1. FormScoreArc — yellow progress ring that traces around
        //      the outside; readable on ANY background regardless of
        //      camera content.
        //   2. Outer breathing pulse — wider yellow halo that gently
        //      breathes (driven by the existing pulseController) to
        //      pull the eye from across the room.
        //   3. Warm-dark backing disc at 0.95 alpha + yellow border —
        //      solid fill, no BackdropFilter (workstream H): at this
        //      alpha the camera barely reads through, so blurring it
        //      first bought nothing but GPU time.
        //   4. Numeral with brand yellow glow + crisp dark text stroke
        //      so the edge stays sharp even where backing alpha fades.
        return AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            // Subtle breathing 0.96 → 1.04 over a full pulse cycle.
            final breathe = 1.0 + (pulseController.value * 0.06) - 0.03;
            final haloAlpha = 0.35 + (pulseController.value * 0.25);
            return Transform.scale(
              scale: breathe,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Wider breathing yellow halo — pulls attention from
                  // far away. Sits OUTSIDE the form score arc.
                  IgnorePointer(
                    child: Container(
                      width: 184,
                      height: 184,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                VikaIvory.yellow.withValues(alpha: haloAlpha),
                            blurRadius: 44,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  FormScoreArc(
                    progress: clamped,
                    size: 156,
                    color: VikaIvory.yellow,
                    trackColor: VikaIvory.glass12,
                    strokeWidth: 6,
                    glow: true,
                    duration: const Duration(milliseconds: 240),
                    child: Container(
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: VikaIvory.heroBg.withValues(alpha: 0.95),
                        border: Border.all(
                          color: VikaIvory.yellow.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: VikaIvory.heroBg.withValues(alpha: 0.55),
                            blurRadius: 24,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // FittedBox so the numeral never overflows
                          // on small screens or with large system
                          // text scaling.
                          SizedBox(
                            height: isReadyToStart ? 28 : 56,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                remainingLabel,
                                style: TextStyle(
                                  fontFamily: VikaIvory.fontFamily,
                                  fontSize: isReadyToStart ? 22 : 48,
                                  fontWeight: FontWeight.w800,
                                  color: VikaIvory.yellow,
                                  letterSpacing: isReadyToStart ? 0.1 : -2.2,
                                  height: 1,
                                  shadows: [
                                    Shadow(
                                      color: VikaIvory.yellowGlow,
                                      blurRadius: 14,
                                    ),
                                    Shadow(
                                      color: VikaIvory.heroBg
                                          .withValues(alpha: 0.85),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isReadyToStart ? 'Bắt đầu' : 'Giữ yên',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: VikaIvory.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: VikaIvory.invInk,
                              letterSpacing: 1.0,
                              shadows: [
                                Shadow(
                                  color:
                                      VikaIvory.heroBg.withValues(alpha: 0.7),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
    // Sized for the 2.5 m viewing distance — the bubble is a gross state
    // marker, not a detail element.
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(color: outlineColor, width: 2.5),
      ),
      child: Icon(icon, size: 48, color: iconColor),
    );
  }
}
