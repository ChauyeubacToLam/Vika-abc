import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseOverlayPainter extends CustomPainter {
  const PoseOverlayPainter({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
    this.debugData = const {},
  });

  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;
  final Map<String, dynamic> debugData;

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

    for (final connection in _bodyConnections) {
      final start = landmarks[connection[0]];
      final end = landmarks[connection[1]];
      if (start == null || end == null) continue;
      if (start.likelihood < 0.5 || end.likelihood < 0.5) continue;

      final averageConfidence = (start.likelihood + end.likelihood) / 2;
      final lineColor = averageConfidence > 0.8
          ? Colors.greenAccent.withValues(alpha: 0.68)
          : Colors.orangeAccent.withValues(alpha: 0.48);

      canvas.drawLine(
        transformPoint(start),
        transformPoint(end),
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final entry in landmarks.entries) {
      if (entry.value.likelihood < 0.5) continue;
      final point = transformPoint(entry.value);
      final color = _landmarkColors[entry.key] ?? Colors.white;

      canvas.drawCircle(
        point,
        5.5,
        Paint()
          ..color = color.withValues(alpha: 0.24)
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

    _drawMetricLabels(canvas, landmarks, transformPoint);
  }

  void _drawMetricLabels(
    Canvas canvas,
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    Offset Function(PoseLandmark) transformPoint,
  ) {
    final knee = landmarks[PoseLandmarkType.leftKnee] ??
        landmarks[PoseLandmarkType.rightKnee];
    final elbow = landmarks[PoseLandmarkType.leftElbow] ??
        landmarks[PoseLandmarkType.rightElbow];
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ??
        landmarks[PoseLandmarkType.rightShoulder];
    final ear = landmarks[PoseLandmarkType.leftEar] ??
        landmarks[PoseLandmarkType.rightEar];
    final heel = landmarks[PoseLandmarkType.leftHeel] ??
        landmarks[PoseLandmarkType.rightHeel];
    final hip = landmarks[PoseLandmarkType.leftHip] ??
        landmarks[PoseLandmarkType.rightHip];

    final kneeAngle =
        _readDouble(debugData['kneeAngle'] ?? debugData['minKneeAngle']);
    if (knee != null && knee.likelihood > 0.7 && kneeAngle != null) {
      _drawLabel(
        canvas,
        transformPoint(knee) + const Offset(12, -8),
        '${kneeAngle.toStringAsFixed(0)}°',
        Colors.cyanAccent,
      );
    }

    final elbowAngle = _readDouble(debugData['elbowAngle']);
    if (elbow != null && elbow.likelihood > 0.7 && elbowAngle != null) {
      _drawLabel(
        canvas,
        transformPoint(elbow) + const Offset(12, -8),
        '${elbowAngle.toStringAsFixed(0)}°',
        const Color(0xFFE040FB),
      );
    }

    final trunkLean =
        _readDouble(debugData['trunkLean'] ?? debugData['maxTrunkLean']);
    final trunkDeviation = _readDouble(debugData['trunkDev']);
    final backAngle = _readDouble(debugData['backAngle']);
    if (shoulder != null && shoulder.likelihood > 0.7) {
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
          transformPoint(shoulder) + const Offset(12, -8),
          shoulderText,
          Colors.orangeAccent,
        );
      }
    }

    final neckAngle = _readDouble(debugData['neckAngle']);
    if (ear != null && ear.likelihood > 0.7 && neckAngle != null) {
      _drawLabel(
        canvas,
        transformPoint(ear) + const Offset(12, -8),
        '${neckAngle.toStringAsFixed(0)}°',
        const Color(0xFF4CAF50),
      );
    }

    final heelNorm = _readDouble(debugData['heelNorm']);
    if (heel != null && heel.likelihood > 0.7 && heelNorm != null) {
      _drawLabel(
        canvas,
        transformPoint(heel) + const Offset(12, -22),
        'gót ${(heelNorm * 100).toStringAsFixed(0)}%',
        const Color(0xFFFF8A80),
      );
    }

    final syncRatio =
        _readDouble(debugData['syncRatio'] ?? debugData['peakSyncRatio']);
    if (hip != null && hip.likelihood > 0.7 && syncRatio != null) {
      _drawLabel(
        canvas,
        transformPoint(hip) + const Offset(12, 10),
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
        !mapEquals(oldDelegate.debugData, debugData);
  }
}
