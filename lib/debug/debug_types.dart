import 'package:flutter/foundation.dart';

enum MetricStatus { pass, near, fault }

class ThresholdBand {
  final double? warningAbove;
  final double? faultAbove;
  final double? warningBelow;
  final double? faultBelow;

  const ThresholdBand({
    this.warningAbove,
    this.faultAbove,
    this.warningBelow,
    this.faultBelow,
  });

  MetricStatus evaluate(double value) {
    if (faultAbove != null && value >= faultAbove!) return MetricStatus.fault;
    if (faultBelow != null && value <= faultBelow!) return MetricStatus.fault;
    if (warningAbove != null && value >= warningAbove!) {
      return MetricStatus.near;
    }
    if (warningBelow != null && value <= warningBelow!) {
      return MetricStatus.near;
    }
    return MetricStatus.pass;
  }
}

enum DebugMode { off, dev }

extension DebugModeCodec on DebugMode {
  String get storageValue => name;

  static DebugMode fromStorage(String? value) {
    return switch (value) {
      'dev' => DebugMode.dev,
      _ => DebugMode.off,
    };
  }
}

class DebugModeResolver {
  const DebugModeResolver._();

  static DebugMode resolve({
    required bool isStaff,
    required DebugMode settingsValue,
  }) {
    if (kReleaseMode && !isStaff) {
      return DebugMode.off;
    }
    return settingsValue;
  }
}

class LandmarkInput {
  final double x;
  final double y;
  final double z;
  final double visibility;
  final bool derived;

  const LandmarkInput({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
    this.derived = false,
  });
}

class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(this.x, this.y, this.z);
}
