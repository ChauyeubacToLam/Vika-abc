import 'dart:math' as math;

import 'frame_snapshot.dart';

enum ChangeState {
  increasing,
  decreasing,
  stable,
}

class FrameBuffer {
  /// Stored frames form the current analysis window.
  ///
  /// Peak/travel/elapsed helpers read this entire window, so callers that need
  /// per-rep values must call [clear] at rep boundaries or pass [maxLength] for
  /// rolling-window behavior.
  FrameBuffer({this.maxLength});

  final int? maxLength;
  List<FrameSnapshot> frameBuffer = [];

  void addFrame(FrameSnapshot frame) {
    frameBuffer.add(frame);
    final limit = maxLength;
    if (limit != null && limit > 0 && frameBuffer.length > limit) {
      frameBuffer.removeRange(0, frameBuffer.length - limit);
    }
  }

  void clear() {
    frameBuffer.clear();
  }

  ChangeState getChange(String key, double gate) {
    if (frameBuffer.length < 2) {
      return ChangeState.stable;
    }
    final prevFrame = frameBuffer[frameBuffer.length - 2];
    final currFrame = frameBuffer.last;
    final prevAngle = prevFrame.log[key];
    final currAngle = currFrame.log[key];
    if (prevAngle == null || currAngle == null) {
      return ChangeState.stable;
    }
    if (currAngle > prevAngle + gate) {
      return ChangeState.increasing;
    } else if (currAngle < prevAngle - gate) {
      return ChangeState.decreasing;
    } else {
      return ChangeState.stable;
    }
  }

  FrameSnapshot? getPeakMax(String key) {
    if (frameBuffer.isEmpty) {
      return null;
    }
    FrameSnapshot peakFrame = frameBuffer.first;
    for (int i = 1; i < frameBuffer.length; i++) {
      if (frameBuffer[i].log[key] == null || peakFrame.log[key] == null) {
        continue;
      }
      if (frameBuffer[i].log[key]! > peakFrame.log[key]!) {
        peakFrame = frameBuffer[i];
      }
    }
    return peakFrame;
  }

  FrameSnapshot? getPeakMin(String key) {
    if (frameBuffer.isEmpty) {
      return null;
    }
    FrameSnapshot peakFrame = frameBuffer.first;
    for (int i = 1; i < frameBuffer.length; i++) {
      if (frameBuffer[i].log[key] == null || peakFrame.log[key] == null) {
        continue;
      }
      if (frameBuffer[i].log[key]! < peakFrame.log[key]!) {
        peakFrame = frameBuffer[i];
      }
    }
    return peakFrame;
  }

  double getTravel(String key) {
    final maxValue = getPeakMax(key)?.log[key];
    final minValue = getPeakMin(key)?.log[key];
    if (maxValue == null || minValue == null) return 0.0;
    return (maxValue - minValue).abs();
  }

  double getMaxAbs(String key) {
    var result = 0.0;
    for (final frame in frameBuffer) {
      final value = frame.log[key];
      if (value == null) continue;
      result = math.max(result, value.abs());
    }
    return result;
  }

  double getMaxAbsFromBaseline(String key, double? baseline) {
    if (baseline == null) return 0.0;
    var result = 0.0;
    for (final frame in frameBuffer) {
      final value = frame.log[key];
      if (value == null) continue;
      result = math.max(result, (value - baseline).abs());
    }
    return result;
  }

  int getElapseTime() {
    if (frameBuffer.isEmpty) {
      return 0;
    }
    return (frameBuffer.last.timeStamp - frameBuffer.first.timeStamp);
  }
}
