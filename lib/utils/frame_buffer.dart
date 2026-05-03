import 'frame_snapshot.dart';

enum AngleChangeState {
  increasing,
  decreasing,
  stable,
}

const double ANGLE_GATE = 0.5;

class FrameBuffer {
  List<FrameSnapshot> frameBuffer = [];

  void addFrame(FrameSnapshot frame) {
    frameBuffer.add(frame);
  }

  void clear() {
    frameBuffer.clear();
  }

  AngleChangeState getAngleChange(String angleName) {
    if (frameBuffer.length < 2) {
      return AngleChangeState.stable;
    }
    final prevFrame = frameBuffer[frameBuffer.length - 2];
    final currFrame = frameBuffer.last;
    final prevAngle = prevFrame.log[angleName];
    final currAngle = currFrame.log[angleName];
    if (prevAngle == null || currAngle == null) {
      return AngleChangeState.stable;
    }
    if (currAngle > prevAngle + ANGLE_GATE) {
      return AngleChangeState.increasing;
    } else if (currAngle < prevAngle - ANGLE_GATE) {
      return AngleChangeState.decreasing;
    } else {
      return AngleChangeState.stable;
    }
  }

  FrameSnapshot? getPeakMax(String angleName) {
    if (frameBuffer.isEmpty) {
      return null;
    }
    FrameSnapshot peakFrame = frameBuffer.first;
    for (int i = 1; i < frameBuffer.length; i++) {
      if (frameBuffer[i].log[angleName] == null ||
          peakFrame.log[angleName] == null) {
        continue;
      }
      if (frameBuffer[i].log[angleName]! > peakFrame.log[angleName]!) {
        peakFrame = frameBuffer[i];
      }
    }
    return peakFrame;
  }

  FrameSnapshot? getPeakMin(String angleName) {
    if (frameBuffer.isEmpty) {
      return null;
    }
    FrameSnapshot peakFrame = frameBuffer.first;
    for (int i = 1; i < frameBuffer.length; i++) {
      if (frameBuffer[i].log[angleName] == null ||
          peakFrame.log[angleName] == null) {
        continue;
      }
      if (frameBuffer[i].log[angleName]! < peakFrame.log[angleName]!) {
        peakFrame = frameBuffer[i];
      }
    }
    return peakFrame;
  }

  int getElapseTime() {
    if (frameBuffer.isEmpty) {
      return 0;
    }
    return (frameBuffer.last.timeStamp - frameBuffer.first.timeStamp);
  }
}
