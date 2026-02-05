/* =========================================================================
   Debouncer class 
    ========================================================================= */

class Debouncer {
  int currentFrame = 0;
  int? requiredFrames;
  bool isActive = false;

  Debouncer({this.requiredFrames = 5}); // Default to 5 frames

  bool update(bool condition) {
    if (condition) {
      currentFrame++;
      if (currentFrame >= (requiredFrames ?? 5)) {
        isActive = true;
      }
    } else {
      currentFrame = 0;
      isActive = false;
    }
    return isActive;
  }

  void reset() {
    currentFrame = 0;
    isActive = false;
  }
}
