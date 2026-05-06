import 'package:flutter/foundation.dart';

enum MetricStatus { pass, near, fault }

abstract interface class DebugMetricSource {
  String get name;
  Map<String, dynamic> get debugData;
  double? get value;
  ThresholdBand? get threshold;
  MetricStatus get status;
  String? get nameVi;
  bool get devOnly;
}

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

enum DebugMode { off, user, dev }

extension DebugModeCodec on DebugMode {
  String get storageValue => name;

  static DebugMode fromStorage(String? value) {
    return switch (value) {
      'user' => DebugMode.user,
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
      return settingsValue == DebugMode.user ? DebugMode.user : DebugMode.off;
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

class MetricSample {
  final double value;
  final MetricStatus status;

  const MetricSample(this.value, this.status);
}

class StatusTransition {
  final MetricStatus from;
  final MetricStatus to;
  final double value;
  final int frameTimestampMs;

  const StatusTransition(
    this.from,
    this.to,
    this.value,
    this.frameTimestampMs,
  );
}
