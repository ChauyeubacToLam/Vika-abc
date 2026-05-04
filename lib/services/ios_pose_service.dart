import 'dart:async';
import 'package:flutter/services.dart';

class PosePoint {
  final int index;
  final double x;
  final double y;
  final double z;

  PosePoint({
    required this.index,
    required this.x,
    required this.y,
    required this.z,
  });

  factory PosePoint.fromMap(Map<dynamic, dynamic> map) {
    return PosePoint(
      index: map['index'] as int,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      z: (map['z'] as num).toDouble(),
    );
  }
}

class PoseFrame {
  final int timestamp;
  final bool poseDetected;
  final List<PosePoint> landmarks;

  PoseFrame({
    required this.timestamp,
    required this.poseDetected,
    required this.landmarks,
  });

  factory PoseFrame.fromMap(Map<dynamic, dynamic> map) {
    final raw = (map['landmarks'] as List<dynamic>? ?? const []);
    return PoseFrame(
      timestamp: map['timestamp'] as int? ?? 0,
      poseDetected: map['poseDetected'] as bool? ?? false,
      landmarks: raw
          .map((e) => PosePoint.fromMap(Map<dynamic, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class IOSPoseService {
  static const MethodChannel _methods = MethodChannel('com.vika.pose/methods');
  static const EventChannel _stream = EventChannel('com.vika.pose/stream');

  Future<void> initialize() async {
    await _methods.invokeMethod('initialize');
  }

  Future<void> start({String camera = 'front'}) async {
    await _methods.invokeMethod('start', {'camera': camera});
  }

  Future<void> stop() async {
    await _methods.invokeMethod('stop');
  }

  Stream<PoseFrame> poseStream() {
    return _stream.receiveBroadcastStream().map((event) {
      return PoseFrame.fromMap(Map<dynamic, dynamic>.from(event as Map));
    });
  }
}
