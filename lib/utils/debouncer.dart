/* =========================================================================
   Debouncer class 
    ========================================================================= */

class Debouncer {
  int currentFrame = 0;
  int requiredFrames;
  bool isActive = false;

  Debouncer({this.requiredFrames = 5}); // Default to 5 frames

  bool update(bool condition) {
    if (condition) {
      currentFrame++;
      if (currentFrame >= requiredFrames) {
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

/* =========================================================================
   StickyDebouncer class 
   For binary toggle states (like left/right) where BOTH directions 
   need debouncing. Requires N consecutive frames in the NEW direction 
   before switching state.
   ========================================================================= */

class StickyDebouncer {
  int consecutiveFrames = 0;
  int requiredFrames;
  bool currentState;

  StickyDebouncer({this.requiredFrames = 5, this.currentState = true});

  bool update(bool newCondition) {
    if (newCondition == currentState) {
      // Same state, reset the counter
      consecutiveFrames = 0;
    } else {
      // Different state, increment counter
      consecutiveFrames++;
      if (consecutiveFrames >= requiredFrames) {
        // Enough consecutive frames in new direction, switch state
        currentState = newCondition;
        consecutiveFrames = 0;
      }
    }
    return currentState;
  }

  void reset() {
    consecutiveFrames = 0;
  }
}
