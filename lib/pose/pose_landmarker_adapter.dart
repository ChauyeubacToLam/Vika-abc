import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseLandmarkerAdapter {
  static Pose? fromChannelData(Map<String, dynamic> data) {
    final rawLandmarks = data['landmarks'];
    if (rawLandmarks is! List || rawLandmarks.isEmpty) {
      return null;
    }

    final imageWidth = (data['imageWidth'] as num?)?.toDouble();
    final imageHeight = (data['imageHeight'] as num?)?.toDouble();
    if (imageWidth == null || imageHeight == null) {
      return null;
    }

    final landmarkMap = <PoseLandmarkType, PoseLandmark>{};

    for (final rawLandmark in rawLandmarks) {
      final landmark = Map<String, dynamic>.from(rawLandmark as Map);
      final typeIndex = landmark['type'] as int? ?? -1;
      if (typeIndex < 0 || typeIndex >= PoseLandmarkType.values.length) {
        continue;
      }

      final type = PoseLandmarkType.values[typeIndex];
      landmarkMap[type] = PoseLandmark(
        type: type,
        x: (landmark['x'] as num).toDouble() * imageWidth,
        y: (landmark['y'] as num).toDouble() * imageHeight,
        z: (landmark['z'] as num).toDouble(),
        likelihood: (landmark['likelihood'] as num?)?.toDouble() ?? 0,
      );
    }

    if (landmarkMap.isEmpty) {
      return null;
    }

    return Pose(landmarks: landmarkMap);
  }

  static Size? imageSizeFromChannelData(Map<String, dynamic> data) {
    final width = data['imageWidth'] as num?;
    final height = data['imageHeight'] as num?;
    if (width == null || height == null) {
      return null;
    }

    return Size(width.toDouble(), height.toDouble());
  }

  static InputImage? inputImageFromChannelData(Map<String, dynamic> data) {
    final frameBytes = _frameBytesFromChannelData(data);
    final frameWidth = data['frameWidth'] as num?;
    final frameHeight = data['frameHeight'] as num?;
    if (frameBytes == null || frameWidth == null || frameHeight == null) {
      return null;
    }

    return InputImage.fromBytes(
      bytes: frameBytes,
      metadata: InputImageMetadata(
        size: Size(frameWidth.toDouble(), frameHeight.toDouble()),
        rotation: inputImageRotationFromChannelData(data),
        format: InputImageFormat.nv21,
        bytesPerRow: frameWidth.toInt(),
      ),
    );
  }

  static InputImageRotation inputImageRotationFromChannelData(
    Map<String, dynamic> data,
  ) {
    switch (data['rotationDegrees'] as int? ?? 0) {
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

  static CameraLensDirection lensDirectionFromChannelData(
    Map<String, dynamic> data,
  ) {
    return data['isFrontCamera'] == true
        ? CameraLensDirection.front
        : CameraLensDirection.back;
  }

  static Uint8List? _frameBytesFromChannelData(Map<String, dynamic> data) {
    final rawBytes = data['frameBytes'];
    if (rawBytes is Uint8List) {
      return rawBytes;
    }
    if (rawBytes is List) {
      return Uint8List.fromList(rawBytes.cast<int>());
    }
    return null;
  }
}
