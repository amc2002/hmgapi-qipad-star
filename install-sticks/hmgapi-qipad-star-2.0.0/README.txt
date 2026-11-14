Qi Pad Star Button
HMG-API mod qipad-star 2.0.0

WHAT THIS IS
  One HMG-API mod. A short press of the steering wheel star switches the front wireless
  charging pad on or off, while the star is set to "Qi pad on/off" in the car's
  Setup > Button menu. The mod adds that choice to the star lists and runs the listener
  that switches the pad. With any other star setting the pad is left alone. A long press
  is left to the car.

  The choice is for the steering wheel star. It also shows in the head unit star's list,
  where it does nothing: the listener only acts on the steering wheel star.

  For head unit software CVEV.USA.0000.V015.012.260507 with HMG-API 1.0.0 or newer.

  Mod UUID: e3264f78-8e52-846d-8ed6-28e59cd5f68a
  HMG-API shows this as the "author key" when it asks whether to install the mod.

INSTALL
  1. Copy the HMGAPI folder that is next to this file to the top of a USB stick, so the
     stick holds HMGAPI/updates/qipad-star-2.0.0.zip. Do not unzip the file.
  2. In the car: HMG-API app > Check USB updates. In the row for this mod, press Install.
  3. A box asks "Install Qi Pad Star Button?" and says the author is not on HMG-API's
     trusted author list. The author key it shows should be the Mod UUID above.
     Press Install.
  4. When it says Installed, go back. If it asks "Apply these changes?", press Apply.
     It may say "Nothing to change" instead.
  5. Take the stick out, then press Restart unit in the HMG-API app and confirm.
  6. Setup > Button > steering wheel star > Qi pad on/off.
  7. Short-press the steering wheel star: the pad switches.

  If an older version of this mod is installed, the button in step 2 is Update and there
  is no author key box. A star that was on Qi pad on/off stays on it.

IF THE OLD NEMESIS PACKAGE IS STILL ON THE HEAD UNIT
  Before step 1: NEMESIS Manager > Packages > Qi Pad Star Button > Uninstall. That is the
  entry with the id qipad.star. (An entry "Star-list choice for Qi Pad Star Button" is
  this mod's older version. Leave it: the update replaces it.)
  As long as the old package's listener is on the head unit, this mod's listener waits
  and does nothing, and says so in its log.

IF THE PAD DOES NOT SWITCH
  HMG-API app > Mods > Qi Pad Star Button, and scroll to Log. Under "service stard" are
  the listener's last lines. They say what it is doing:
  - "the old NEMESIS package qipad.star is still installed": see the section above.
  - "wheel star is set to ..., not Qi pad on/off": the star is on another choice (step 6).
  - "head unit build is ...": this mod is not for that software version.
  - nothing under "service stard": restart the head unit and look again.
  The full log is /data/hmgapi/logs/qipad-star/stard.log on the head unit.

IN NEMESIS MANAGER
  NEMESIS Manager > Packages lists this mod as well, with the id hmgapi.qipad-star.
  HMG-API puts every mod it installs there. It is one mod, shown in two places.

REMOVE
  1. First set the steering wheel star to another choice (Setup > Button).
  2. HMG-API app > Mods > Qi Pad Star Button > Remove Qi Pad Star Button, and confirm.
     Then press Apply changes (it may say "Nothing to change").
  3. Press Restart unit and confirm.
  If the star is still on "Qi pad on/off" when the mod is removed or turned off, HMG-API
  sets it to None at the next restart. With None, every press opens the button setup screen.
