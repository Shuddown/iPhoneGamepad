# Touch-controller layout references

The gamepad screen was redesigned after inspecting these open-source projects:

1. [Moonlight iOS — OnScreenControls.m](https://github.com/moonlight-stream/moonlight-ios/blob/master/Limelight/Input/OnScreenControls.m),
   particularly `setupComplexControls`. It places the D-pad/face buttons at the
   outer edges, thumbsticks lower and inward, and shoulder controls above them.
2. [PPSSPP — GamepadEmu.cpp](https://github.com/hrydgard/ppsspp/blob/master/UI/GamepadEmu.cpp),
   particularly `InitPadLayout`. It separates the action-button diamond from
   the analog sticks, adapts to screen dimensions, and keeps controls away from
   the iOS home-indicator area.

This app uses a new implementation of those familiar placement conventions,
with its own UIKit drawing and touch ownership. No source code, images, or
control artwork from those projects was copied.

The chosen layout is landscape in both directions. It has fixed, non-scrolling
thumb zones, larger shoulder pads, 44-point minimum targets, safe-area insets,
a continuous eight-way D-pad, and independently tracked simultaneous touches.
Select/Start are central; L3/R3 sit below the outer groups so they do not overlap
the sticks on smaller iPhones. Opening connection settings neutralizes inputs.
