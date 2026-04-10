import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum SkeletonStyle {
  constellation,
  classic,
  tetGold,
}

class _PoseConnection {
  const _PoseConnection(this.start, this.end, {required this.isCore});

  final PoseLandmarkType start;
  final PoseLandmarkType end;
  final bool isCore;
}

class PoseOverlayPainter extends CustomPainter {
  PoseOverlayPainter({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
    this.debugData = const {},
    this.style = SkeletonStyle.constellation,
  });

  static const Color jadeGlow = Color(0xFF2DD4A0);
  static const Color jadeBright = Color(0xFF5BFFB0);
  static const Color jade = Color(0xFF18594A);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFFFE9A3);
  static const Color goldDark = Color(0xFF8C6D1F);
  static const Color tetGreen = Color(0xFF0F2E20);

  static const double _minLikelihood = 0.5;
  static const double _coreDashLength = 3.0;
  static const double _coreGapLength = 6.0;
  static const double _limbDashLength = 2.0;
  static const double _limbGapLength = 8.0;
  static const double _tetCoreDashLength = 5.0;
  static const double _tetCoreGapLength = 8.0;
  static const double _tetLimbDashLength = 3.0;
  static const double _tetLimbGapLength = 8.0;

  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;
  final Map<String, dynamic> debugData;
  final SkeletonStyle style;

  final Paint _classicLinePaint = Paint()..strokeCap = StrokeCap.round;
  final Paint _classicOuterJointPaint = Paint()..style = PaintingStyle.fill;
  final Paint _classicInnerJointPaint = Paint()..style = PaintingStyle.fill;

  // ── Constellation paints (tuned for real camera feed) ──

  final Paint _constellationCoreLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.5
    ..color = jadeGlow.withValues(alpha: 0.55);

  final Paint _constellationLimbLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.0
    ..color = jadeGlow.withValues(alpha: 0.30);

  final Paint _majorOuterHaloPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = jadeGlow.withValues(alpha: 0.12);

  final Paint _majorInnerHaloPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = jadeGlow.withValues(alpha: 0.20);

  final Paint _majorCorePaint = Paint()
    ..style = PaintingStyle.fill
    ..color = jadeBright.withValues(alpha: 0.85);

  final Paint _flarePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.0
    ..color = jadeBright.withValues(alpha: 0.55);

  final Paint _headOuterHaloPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = jadeGlow.withValues(alpha: 0.15);

  final Paint _headCorePaint = Paint()
    ..style = PaintingStyle.fill
    ..color = jadeBright.withValues(alpha: 0.90);

  final Paint _minorJointPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = jadeGlow.withValues(alpha: 0.50);

  final Paint _wristPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = jadeGlow.withValues(alpha: 0.35);

  final Paint _neckPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = jadeGlow.withValues(alpha: 0.60);

  final Paint _tetLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.4
    ..color = gold.withValues(alpha: 0.6);

  final Paint _tetLimbLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.0
    ..color = gold.withValues(alpha: 0.4);

  final Paint _tetOuterGlowPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = gold.withValues(alpha: 0.06);

  final Paint _tetPetalFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = gold.withValues(alpha: 0.12);

  final Paint _tetPetalStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6
    ..color = gold.withValues(alpha: 0.7);

  final Paint _tetCenterPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = goldLight.withValues(alpha: 0.9);

  final Paint _tetCenterHighlightPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7);

  final Paint _tetMinorPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = gold.withValues(alpha: 0.4);

  final Paint _tetWristPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = gold.withValues(alpha: 0.25);

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

  static const List<_PoseConnection> _constellationConnections = [
    _PoseConnection(
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      isCore: true,
    ),
    _PoseConnection(
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
      isCore: true,
    ),
    _PoseConnection(
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      isCore: true,
    ),
    _PoseConnection(
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      isCore: true,
    ),
    _PoseConnection(
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
      isCore: true,
    ),
    _PoseConnection(
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
      isCore: true,
    ),
    _PoseConnection(
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.rightAnkle,
      isCore: true,
    ),
    _PoseConnection(
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      isCore: false,
    ),
    _PoseConnection(
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
      isCore: false,
    ),
    _PoseConnection(
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightElbow,
      isCore: false,
    ),
    _PoseConnection(
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightWrist,
      isCore: false,
    ),
    _PoseConnection(
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.leftHeel,
      isCore: false,
    ),
    _PoseConnection(
      PoseLandmarkType.leftHeel,
      PoseLandmarkType.leftFootIndex,
      isCore: false,
    ),
    _PoseConnection(
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.leftFootIndex,
      isCore: false,
    ),
    _PoseConnection(
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.rightHeel,
      isCore: false,
    ),
    _PoseConnection(
      PoseLandmarkType.rightHeel,
      PoseLandmarkType.rightFootIndex,
      isCore: false,
    ),
    _PoseConnection(
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.rightFootIndex,
      isCore: false,
    ),
  ];

  static const Set<PoseLandmarkType> _majorJointTypes = {
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.rightKnee,
    PoseLandmarkType.leftAnkle,
    PoseLandmarkType.rightAnkle,
  };

  static const Set<PoseLandmarkType> _elbowJointTypes = {
    PoseLandmarkType.leftElbow,
    PoseLandmarkType.rightElbow,
  };

  static const Set<PoseLandmarkType> _wristJointTypes = {
    PoseLandmarkType.leftWrist,
    PoseLandmarkType.rightWrist,
  };

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
    if (landmarks.isEmpty || imageSize == Size.zero) return;

    final imageW = imageSize.width;
    final imageH = imageSize.height;
    final canvasW = size.width;
    final canvasH = size.height;

    final imageAspect = imageW / imageH;
    final canvasAspect = canvasW / canvasH;

    double previewW;
    double previewH;
    double offsetX;
    double offsetY;

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

    final scaleX = previewW / imageW;
    final scaleY = previewH / imageH;

    Offset transformPoint(PoseLandmark landmark) {
      var x = landmark.x;
      var y = landmark.y;

      if (Platform.isAndroid) {
        switch (rotation) {
          case InputImageRotation.rotation90deg:
            x = landmark.x;
            y = landmark.y;
            break;
          case InputImageRotation.rotation270deg:
            x = imageW - landmark.x;
            y = imageH - landmark.y;
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

    final projectedPoints = <PoseLandmarkType, Offset>{};
    for (final entry in landmarks.entries) {
      if (entry.value.likelihood < _minLikelihood) continue;
      projectedPoints[entry.key] = transformPoint(entry.value);
    }

    switch (style) {
      case SkeletonStyle.constellation:
        _drawConstellationSkeleton(canvas, projectedPoints);
        break;
      case SkeletonStyle.classic:
        _drawClassicSkeleton(canvas, landmarks, projectedPoints);
        break;
      case SkeletonStyle.tetGold:
        _drawTetGoldSkeleton(canvas, projectedPoints);
        break;
    }

    _drawMetricLabels(canvas, projectedPoints);
  }

  void _drawClassicSkeleton(
    Canvas canvas,
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    Map<PoseLandmarkType, Offset> projectedPoints,
  ) {
    for (final connection in _bodyConnections) {
      final startLandmark = landmarks[connection[0]];
      final endLandmark = landmarks[connection[1]];
      if (startLandmark == null || endLandmark == null) continue;

      final start = projectedPoints[connection[0]];
      final end = projectedPoints[connection[1]];
      if (start == null || end == null) continue;

      final averageConfidence =
          (startLandmark.likelihood + endLandmark.likelihood) / 2;
      final lineColor = averageConfidence > 0.8
          ? Colors.greenAccent.withValues(alpha: 0.68)
          : Colors.orangeAccent.withValues(alpha: 0.48);

      _classicLinePaint
        ..color = lineColor
        ..strokeWidth = 2.5;
      canvas.drawLine(start, end, _classicLinePaint);
    }

    for (final entry in projectedPoints.entries) {
      final color = _landmarkColors[entry.key] ?? Colors.white;
      _classicOuterJointPaint.color = color.withValues(alpha: 0.24);
      _classicInnerJointPaint.color = color;

      canvas.drawCircle(entry.value, 5.5, _classicOuterJointPaint);
      canvas.drawCircle(entry.value, 3.5, _classicInnerJointPaint);
    }
  }

  void _drawConstellationSkeleton(
    Canvas canvas,
    Map<PoseLandmarkType, Offset> projectedPoints,
  ) {
    final neck = _resolveNeck(projectedPoints);
    final head = _resolveHead(projectedPoints);

    if (neck != null) {
      final leftShoulder = projectedPoints[PoseLandmarkType.leftShoulder];
      final rightShoulder = projectedPoints[PoseLandmarkType.rightShoulder];

      if (leftShoulder != null) {
        _drawDashedLine(
          canvas,
          neck,
          leftShoulder,
          _constellationCoreLinePaint,
          dashLength: _coreDashLength,
          gapLength: _coreGapLength,
        );
      }
      if (rightShoulder != null) {
        _drawDashedLine(
          canvas,
          neck,
          rightShoulder,
          _constellationCoreLinePaint,
          dashLength: _coreDashLength,
          gapLength: _coreGapLength,
        );
      }
    }

    for (final connection in _constellationConnections) {
      final start = projectedPoints[connection.start];
      final end = projectedPoints[connection.end];
      if (start == null || end == null) continue;

      _drawDashedLine(
        canvas,
        start,
        end,
        connection.isCore
            ? _constellationCoreLinePaint
            : _constellationLimbLinePaint,
        dashLength: connection.isCore ? _coreDashLength : _limbDashLength,
        gapLength: connection.isCore ? _coreGapLength : _limbGapLength,
      );
    }

    for (final jointType in _majorJointTypes) {
      final joint = projectedPoints[jointType];
      if (joint == null) continue;
      _drawMajorJoint(canvas, joint);
    }

    if (head != null) {
      _drawHeadJoint(canvas, head);
    }
    if (neck != null) {
      canvas.drawCircle(neck, 2.0, _neckPaint);
    }

    for (final jointType in _elbowJointTypes) {
      final joint = projectedPoints[jointType];
      if (joint == null) continue;
      canvas.drawCircle(joint, 1.5, _minorJointPaint);
    }

    for (final jointType in _wristJointTypes) {
      final joint = projectedPoints[jointType];
      if (joint == null) continue;
      canvas.drawCircle(joint, 1.5, _wristPaint);
    }
  }

  void _drawTetGoldSkeleton(
    Canvas canvas,
    Map<PoseLandmarkType, Offset> projectedPoints,
  ) {
    final neck = _resolveNeck(projectedPoints);
    final head = _resolveHead(projectedPoints);

    if (neck != null) {
      final leftShoulder = projectedPoints[PoseLandmarkType.leftShoulder];
      final rightShoulder = projectedPoints[PoseLandmarkType.rightShoulder];

      if (leftShoulder != null) {
        _drawDashedLine(
          canvas,
          neck,
          leftShoulder,
          _tetLinePaint,
          dashLength: _tetCoreDashLength,
          gapLength: _tetCoreGapLength,
        );
      }
      if (rightShoulder != null) {
        _drawDashedLine(
          canvas,
          neck,
          rightShoulder,
          _tetLinePaint,
          dashLength: _tetCoreDashLength,
          gapLength: _tetCoreGapLength,
        );
      }
    }

    for (final connection in _constellationConnections) {
      final start = projectedPoints[connection.start];
      final end = projectedPoints[connection.end];
      if (start == null || end == null) continue;

      _drawDashedLine(
        canvas,
        start,
        end,
        connection.isCore ? _tetLinePaint : _tetLimbLinePaint,
        dashLength: connection.isCore ? _tetCoreDashLength : _tetLimbDashLength,
        gapLength: connection.isCore ? _tetCoreGapLength : _tetLimbGapLength,
      );
    }

    for (final jointType in _majorJointTypes) {
      final joint = projectedPoints[jointType];
      if (joint == null) continue;
      _drawGoldLotus(canvas, joint, 8.0);
    }

    if (head != null) {
      _drawGoldLotus(canvas, head, 10.0);
    }
    if (neck != null) {
      canvas.drawCircle(neck, 2.0, _tetMinorPaint);
    }

    for (final jointType in _elbowJointTypes) {
      final joint = projectedPoints[jointType];
      if (joint == null) continue;
      canvas.drawCircle(joint, 2.0, _tetMinorPaint);
    }

    for (final jointType in _wristJointTypes) {
      final joint = projectedPoints[jointType];
      if (joint == null) continue;
      canvas.drawCircle(joint, 1.5, _tetWristPaint);
    }
  }

  void _drawMajorJoint(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 10.0, _majorOuterHaloPaint);
    canvas.drawCircle(center, 5.0, _majorInnerHaloPaint);
    canvas.drawCircle(center, 3.0, _majorCorePaint);
    canvas.drawLine(
      Offset(center.dx - 7, center.dy),
      Offset(center.dx + 7, center.dy),
      _flarePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 7),
      Offset(center.dx, center.dy + 7),
      _flarePaint,
    );
  }

  void _drawHeadJoint(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 8.0, _headOuterHaloPaint);
    canvas.drawCircle(center, 3.5, _headCorePaint);
  }

  void _drawGoldLotus(Canvas canvas, Offset center, double size) {
    canvas.drawCircle(center, size * 2, _tetOuterGlowPaint);

    for (var i = 0; i < 8; i++) {
      final angle = i * (math.pi / 4);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final petalRect = Rect.fromCenter(
        center: Offset(0, -size * 0.55),
        width: size * 0.4,
        height: size * 1.1,
      );
      canvas.drawOval(petalRect, _tetPetalFillPaint);
      canvas.drawOval(petalRect, _tetPetalStrokePaint);
      canvas.restore();
    }

    canvas.drawCircle(center, size * 0.22, _tetCenterPaint);
    canvas.drawCircle(center, size * 0.08, _tetCenterHighlightPaint);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final delta = end - start;
    final distance = delta.distance;
    if (distance <= 0) return;

    final direction = Offset(delta.dx / distance, delta.dy / distance);
    var cursor = 0.0;
    while (cursor < distance) {
      final dashEnd = math.min(cursor + dashLength, distance);
      canvas.drawLine(
        start + direction * cursor,
        start + direction * dashEnd,
        paint,
      );
      cursor += dashLength + gapLength;
    }
  }

  Offset? _resolveNeck(Map<PoseLandmarkType, Offset> projectedPoints) {
    final leftShoulder = projectedPoints[PoseLandmarkType.leftShoulder];
    final rightShoulder = projectedPoints[PoseLandmarkType.rightShoulder];
    if (leftShoulder == null || rightShoulder == null) return null;
    return Offset(
      (leftShoulder.dx + rightShoulder.dx) / 2,
      (leftShoulder.dy + rightShoulder.dy) / 2,
    );
  }

  Offset? _resolveHead(Map<PoseLandmarkType, Offset> projectedPoints) {
    final nose = projectedPoints[PoseLandmarkType.nose];
    if (nose != null) return nose;

    final leftEye = projectedPoints[PoseLandmarkType.leftEye];
    final rightEye = projectedPoints[PoseLandmarkType.rightEye];
    if (leftEye != null && rightEye != null) {
      return Offset(
        (leftEye.dx + rightEye.dx) / 2,
        (leftEye.dy + rightEye.dy) / 2,
      );
    }

    final leftEar = projectedPoints[PoseLandmarkType.leftEar];
    final rightEar = projectedPoints[PoseLandmarkType.rightEar];
    if (leftEar != null && rightEar != null) {
      return Offset(
        (leftEar.dx + rightEar.dx) / 2,
        (leftEar.dy + rightEar.dy) / 2,
      );
    }

    return null;
  }

  void _drawMetricLabels(
    Canvas canvas,
    Map<PoseLandmarkType, Offset> projectedPoints,
  ) {
    final knee = projectedPoints[PoseLandmarkType.leftKnee] ??
        projectedPoints[PoseLandmarkType.rightKnee];
    final elbow = projectedPoints[PoseLandmarkType.leftElbow] ??
        projectedPoints[PoseLandmarkType.rightElbow];
    final shoulder = projectedPoints[PoseLandmarkType.leftShoulder] ??
        projectedPoints[PoseLandmarkType.rightShoulder];
    final ear = projectedPoints[PoseLandmarkType.leftEar] ??
        projectedPoints[PoseLandmarkType.rightEar];
    final heel = projectedPoints[PoseLandmarkType.leftHeel] ??
        projectedPoints[PoseLandmarkType.rightHeel];
    final hip = projectedPoints[PoseLandmarkType.leftHip] ??
        projectedPoints[PoseLandmarkType.rightHip];

    final kneeAngle =
        _readDouble(debugData['kneeAngle'] ?? debugData['minKneeAngle']);
    if (knee != null && kneeAngle != null) {
      _drawLabel(
        canvas,
        knee + const Offset(12, -8),
        '${kneeAngle.toStringAsFixed(0)}°',
        Colors.cyanAccent,
      );
    }

    final elbowAngle = _readDouble(debugData['elbowAngle']);
    if (elbow != null && elbowAngle != null) {
      _drawLabel(
        canvas,
        elbow + const Offset(12, -8),
        '${elbowAngle.toStringAsFixed(0)}°',
        const Color(0xFFE040FB),
      );
    }

    final trunkLean =
        _readDouble(debugData['trunkLean'] ?? debugData['maxTrunkLean']);
    final trunkDeviation = _readDouble(debugData['trunkDev']);
    final backAngle = _readDouble(debugData['backAngle']);
    if (shoulder != null) {
      final shoulderText = trunkLean != null
          ? '${trunkLean.toStringAsFixed(0)}°'
          : trunkDeviation != null
              ? trunkDeviation.toStringAsFixed(0)
              : backAngle != null
                  ? '${backAngle.toStringAsFixed(0)}°'
                  : null;
      if (shoulderText != null) {
        _drawLabel(
          canvas,
          shoulder + const Offset(12, -8),
          shoulderText,
          Colors.orangeAccent,
        );
      }
    }

    final neckAngle = _readDouble(debugData['neckAngle']);
    if (ear != null && neckAngle != null) {
      _drawLabel(
        canvas,
        ear + const Offset(12, -8),
        '${neckAngle.toStringAsFixed(0)}°',
        const Color(0xFF4CAF50),
      );
    }

    final heelNorm = _readDouble(debugData['heelNorm']);
    if (heel != null && heelNorm != null) {
      _drawLabel(
        canvas,
        heel + const Offset(12, -22),
        'gót ${(heelNorm * 100).toStringAsFixed(0)}%',
        const Color(0xFFFF8A80),
      );
    }

    final syncRatio =
        _readDouble(debugData['syncRatio'] ?? debugData['peakSyncRatio']);
    if (hip != null && syncRatio != null) {
      _drawLabel(
        canvas,
        hip + const Offset(12, 10),
        'đồng bộ ${syncRatio.toStringAsFixed(2)}x',
        const Color(0xFFAED581),
      );
    }
  }

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  void _drawLabel(Canvas canvas, Offset position, String text, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 4),
            Shadow(color: Colors.black, blurRadius: 8),
          ],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final background = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        position.dx - 4,
        position.dy - 3,
        textPainter.width + 8,
        textPainter.height + 6,
      ),
      const Radius.circular(6),
    );

    canvas.drawRRect(
      background,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
    textPainter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.rotation != rotation ||
        oldDelegate.lensDirection != lensDirection ||
        oldDelegate.style != style ||
        !mapEquals(oldDelegate.debugData, debugData);
  }
}
