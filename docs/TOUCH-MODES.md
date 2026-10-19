# Layout editing and forgiving touch

The previous pure-gamepad redesign is checkpointed at `5fe6af8`.

## Layout editor

Tap the sliders icon beside Connect. Switch between **Move** and **Resize**:

- Drag a control to reposition it.
- In Resize, drag right/up to enlarge or left/down to shrink.
- The control menu can select a covered control, make it smaller/larger, or reset it.
- Save applies and persists changes. Cancel discards the draft. Reset all restores defaults in the draft.

Edits use normalized safe-area centers and relative sizes so they survive screen
size changes. Controls remain at least 44 points and inside the safe area,
with the top toolbar reserved. Custom controls can overlap; the control menu
allows selecting them again. In gameplay smaller targets take priority at
shared borders. Avoid overlapping controls that you need simultaneously.
Editing sends no control presses and releases previously held inputs.

## Standard and Forgiving

Tap **Standard** to enable **Forgiving**; tap again to return. The setting persists.
The user selected nearby snapping plus floating sticks after reviewing the options.

Standard retains the existing fixed stick centers and hit testing. Forgiving adds:

- Direct hits take priority. Every remaining touch on the gamepad surface goes
  to the nearest gameplay target edge, with no maximum snap distance. This
  includes space above shoulders/triggers, below L3/R3, beside the pad, and
  outside the safe-area rectangle used to position the controls. System gestures
  and toolbar buttons still handle the touches that iOS/SwiftUI delivers to them.
- Home, Start, and Select keep their original direct targets; misses around them
  are assigned to gameplay controls instead of expanding the menu targets.
- Face-button sliding requires the new button to be at least 8 points closer
  than the current one, reducing changes due to thumb jitter. Held gameplay
  buttons use their enlarged nearest-target regions too, with 8 points of
  tolerance at the boundary. They release outside that region or on finger lift.
- Each stick starts neutral at its finger's initial landing point, and remains
  centered there until release. The visual stick follows that origin. Ownership
  prevents a second finger from taking over a held stick.
- Mode changes release all controls. Existing touch feedback applies in both modes.

The 8-point hysteresis is an engineering choice, not a value established by a
study of this app. Snapping cannot infer which of two neighboring buttons was intended.
No input is delayed to guess intent, and no button is held after finger release.

## Research and alternatives

Sources reviewed on October 17, 2026:

1. [Moonlight Android's controller modes](https://github.com/moonlight-stream/moonlight-android/blob/master/app/src/main/java/com/limelight/binding/input/virtual_controller/VirtualController.java)
   and [element touch handling](https://github.com/moonlight-stream/moonlight-android/blob/master/app/src/main/java/com/limelight/binding/input/virtual_controller/VirtualControllerElement.java)
   separate active play, moving, and resizing; returning to active saves the profile.
   This app follows that interaction pattern with explicit Save/Cancel.
2. [PPSSPP control settings](https://www.ppsspp.org/docs/settings/controls/) offer
   movable controls, an auto-centering analog stick, haptic feedback, and keeping
   the first button pressed while sliding onto another. Moving targets closer to
   natural thumb positions and using touch-down as a stick origin address missed
   placement directly. Its gliding option is useful for button combinations but
   can cause an unwanted held action, so this app does not enable it.
3. [Grossman and Balakrishnan, Bubble Cursor (CHI 2005)](https://www.dgp.toronto.edu/papers/tgrossman_CHI2005.pdf)
   adapt the activation area to nearby targets so one target is selectable. Their
   experiments concern pointer acquisition, not eyes-free multi-touch gamepads.
   Nearest-target snapping here is an adaptation of that idea, not a
   reproduction or a claim of equivalent measured benefits.
4. [Valve touch menus](https://partner.steamgames.com/doc/features/steam_controller/touch_menus)
   offer radial/grid selection and several activation styles, including release.
   A large directional face-button zone is a possible future mode, but would
   change button combinations and slide behavior; release activation would also
   delay immediate gamepad presses. It is not implemented.

Other practical options to evaluate later: a temporary display of expanded hit
regions for tuning, thumb-position calibration, and distinct short haptic cues
when crossing between face buttons. These are proposals, not current features.
Calibration would require a deliberate setup exercise; learning silently during
gameplay would have no reliable intended-button labels.

Start by testing the chosen mode in the same emulator used for the working
baseline. Compare missed presses, wrong-button presses, and accidental camera
movement. Adjust the layout first, then evaluate whether the target regions and
floating stick travel need individual settings.
