# Design: star button toggles the wireless charging pad

How the mod works, as of version 2.0.1, followed by the history of the NEMESIS package it replaced (section 11). The test record is in [research.md](research.md).

## 1. What it does

A short press of the steering wheel star button switches the front wireless charging pad to the other state: off to on, on to off. That is all.

- It does so only while the car's own setting for that star (Setup > Button) is **Qi pad on/off**, a choice this mod adds to the list. With any other setting the star does what that setting says and the pad is left alone.
- A long press is left to the car and does not touch the pad.
- The dash (head unit) star button is ignored. The choice shows in its list too, where it does nothing.
- No timer, no automation, no settings page, nothing shown on screen. The pad's indicator light, the phone's charging sign and the setting in the car's menu show the new state.

## 2. Facts it is built on

Measured on the car, head unit software `CVEV.USA.0000.V015.012.260507`:

| Fact | Value |
|---|---|
| Read the pad | `service call com.hkmc.micom.usm 465` answers 1 (off) or 2 (on) |
| Set the pad | `service call com.hkmc.micom.usm 130 i32 <1 or 2>` |
| After a write | The read shows the new value once the car confirms it, within 250 ms |
| Wheel star | key code 43 on input device `daudio_wp_daudioplus_cvev_us` (event1) |
| Dash star | key code 20 on the same device |
| Short press | key down, then key up 110 to 280 ms later |
| Long press | key down, then key up about 1.5 s later |

From HMG-API's source at version 1.1.0-beta.1 (paths are in the HMG-API repository):

| Fact | Where |
|---|---|
| A mod adds a choice to the star lists with `provides.star_key`: an `id`, a `title`, and either an `activity` or a `broadcast` | `core/runtime/java/hmgapi/hook/Mods.java` |
| A broadcast choice is always offered, in the steering wheel star's list and the head unit star's list. On a press HMG-API sends the broadcast; nothing has to receive it | `core/runtime/java/hmgapi/hook/StarKey.java` |
| The car keeps the wheel star's choice in the system property `persist.sys.key.swrccustom`. A mod's choice is saved as `hmgapi.star.<mod id>.<choice id>` | `StarKey.java`, `Mods.java` |
| A mod can declare a service: a script or a jar, run by HMG-API's daemon (hmgapid) as root, started once Android is up, restarted if it stops, stopped when the mod is turned off | `core/runtime/java/hmgapi/engine/ModRuntime.java`, `core/hmgapid/hmgapid.c` |
| A script service runs as `sh <mod folder>/<script>` with `HMGAPI_MOD_DIR` set to the mod's folder. Its output goes to `/data/hmgapi/logs/<mod>/<service>.log` | `hmgapid.c` |
| A package has to be signed. The mod's UUID comes from the author key, and an update is accepted only from the same key | `core/runtime/java/hmgapi/engine/Signing.java`, `Packages.java` |
| Star choices are read when the head unit starts. A star left on a removed mod's choice goes back to None at the next start | `Mods.java`, `StarKey.java` |
| The picture beside a star choice is the icon of the choice's activity. A broadcast choice gets Android's default app picture | `StarKey.java` |

Confirmed on the car on 2026-11-13: the mod installs, the choice shows in the steering wheel star's list, HMG-API runs the service, and the pad switches only with the choice selected.

## 3. How it works

One HMG-API mod, `qipad-star`, with three files:

| File | What it is |
|---|---|
| `mod.json` | The star choice, the service, and what the mod is for |
| `svc/stard.sh` | The service script HMG-API runs |
| `lib/stard.jar` | The listener, compiled from `src/qipad/star/StarDaemon.java` |

```json
{
  "id": "qipad-star",
  "name": "Qi Pad Star Button",
  "version": "2.0.1",
  "hmgapi": ">=1.0.0",
  "authors": ["amc2002"],
  "license": "AGPL-3.0",
  "description": "A short press of the steering wheel star switches the front wireless charging pad, while the star is set to \"Qi pad on/off\" in Setup > Button. This mod adds that choice and runs the listener.",
  "repo": "https://github.com/amc2002/hmgapi-qipad-star",
  "system": { "product": ["CVEV.USA.0000.V015.012.260507"] },
  "nemesis_conflicts": ["qipad.star"],
  "provides": {
    "star_key": [
      { "id": "toggle", "title": "Qi pad on/off", "broadcast": "qipad.star.action.STAR" }
    ]
  },
  "services": [
    { "name": "stard", "script": "svc/stard.sh", "user": "root", "start": "android", "restart": true }
  ]
}
```

**The star choice.** With "Qi pad on/off" selected, a press makes the car send its saved choice, HMG-API sends the broadcast `qipad.star.action.STAR`, and nothing receives it. The choice gives the star a setting of its own, so that no other function of the car runs on the press.

**The listener.** It reads the raw button input, the same way Precondition (Launchpad) watches the TUNE knob, and decides on each short press.

```text
head unit start
 └─ HMG-API starts the mod's service svc/stard.sh as root (and restarts it if it stops)
     ├─ check: this is build CVEV.USA.0000.V015.012.260507, otherwise log it and stay idle
     ├─ wait for Android and for the settings service com.hkmc.micom.usm
     ├─ wait while the listener of the old NEMESIS package is still installed
     └─ start the listener lib/stard.jar (Java, run through app_process)
          ├─ find the input device named daudio_wp_daudioplus_cvev_us
          └─ read its key events
               key 43 down  → note the time
               key 43 up    → within 800 ms of the down:
                                read the saved star choice (getprop persist.sys.key.swrccustom)
                                not hmgapi.star.qipad-star.toggle → log it, leave the pad alone
                                otherwise → toggle, unless the last toggle was under 2 s ago
                              later: ignore (that was a long press)
               anything else → ignore

toggle
 ├─ read the pad (465)
 ├─ 1 → write 2;  2 → write 1;  anything else → write nothing, log it
 ├─ read again every 250 ms, up to 3 s, until the new value shows; log the result
 └─ ignore further presses for 2 seconds
```

The star choice is read at every press, so a change in Setup > Button counts from the next press without a restart.

Why the listener is Java and not a shell script: Android's `getevent` tool holds its output back in a buffer when it writes to a file or a pipe, so a script would not see presses as they happen ([research.md](research.md), "getevent test").

## 4. Safety points

- **It only ever writes 1 or 2**, and only after reading a 1 or a 2. An unexpected reading means no write.
- **It only acts with its own choice selected.** Any other saved choice, an empty value or a failed read leaves the pad alone, and the log says what was read.
- **The build check.** The numbers 130 and 465 are only verified for one software build. HMG-API refuses the mod on any other (`system.product`), and the script checks the build itself: on another build it logs "not starting" and does nothing until the numbers have been checked again.
- **The 2-second pause** after a toggle stops a double press from switching the pad on and straight back off.
- **It listens without taking the button away from the car.** Reading input events is read-only: Android and the car still receive every press.
- **No messages of its own on the car's network.** It calls the same service the car's settings screen calls.
- **It does not run next to the old NEMESIS package**, whose listener switches the pad on every press. While that listener's file (`/data/nemesis/apps/qipad.star/lib/stard.jar`) exists, the script logs that the old package has to be uninstalled and waits. The mod also names the package in `nemesis_conflicts`.

## 5. The package

| Field | Value |
|---|---|
| `id` | `qipad-star` |
| `name` | Qi Pad Star Button |
| `version` | 2.0.1 |
| `hmgapi` | `>=1.0.0` (star choices and script services exist since 1.0.0; tested with 1.1.0-beta.1) |
| `system.product` | `CVEV.USA.0000.V015.012.260507` |
| Author key UUID | `e3264f78-8e52-846d-8ed6-28e59cd5f68a` |

The package is a zip holding `mod.json`, `svc/stard.sh`, `lib/stard.jar`, and HMG-API's `META-HMGAPI/manifest.json` and `META-HMGAPI/signature`. The signing key is not in the repository. Every version has to be signed with the same key: HMG-API takes an update only from the key the installed version was signed with.

- Log: `/data/hmgapi/logs/qipad-star/stard.log` on the head unit, one line per start and one per short press. No positions. The HMG-API app shows its last 40 lines on the mod's page, in the Log section under "service stard".
- NEMESIS Manager lists the mod too, with the id `hmgapi.qipad-star`. HMG-API puts every mod it installs there; it is one mod, shown in two places.
- The mod changes no file on the head unit outside its own folder.

## 6. Building

```bash
tools/make-hmgapi-mod/build-hmgapi-mod.sh <sdk dir> <key file>
```

`<sdk dir>` is HMG-API's unpacked mod SDK, `<key file>` the author key. The script compiles `src/` for Java 8, converts it to the head unit's dex format with `dx`, signs a copy of the mod with the SDK's signing tool, zips it, and checks the zip the way HMG-API will. The result is a ready-to-copy stick folder in `dist/hmgapi-qipad-star-<version>/`. What it needs is listed at the top of the script and in [maintaining.md](maintaining.md).

`tools/make-hmgapi-mod/test.sh` checks the listener's decision about the star choice, `mod.json`, the service script, the README, and, given the SDK, a full build with a throwaway key, including HMG-API's own engine reading the finished stick on the build machine.

## 7. Install, update, remove

Install: put `qipad-star-<version>.zip` in `HMGAPI/updates/` on a USB stick. HMG-API app > Check USB updates > Install, and confirm the author key. Go back, apply if it asks, restart the head unit. Then Setup > Button > steering wheel star > Qi pad on/off.

Update: the same, with Update in place of Install. A star that was on Qi pad on/off stays on it. Restart the head unit afterwards.

If the old NEMESIS package is still installed, uninstall it first (NEMESIS Manager > Packages > Qi Pad Star Button > Uninstall).

Remove: set the wheel star to another choice first. Then remove the mod in the HMG-API app, apply and restart. If the star is still on the mod's choice when the mod is removed or turned off, HMG-API sets it to None at the next start, and with None every press opens the car's button setup screen.

## 8. What has been tested

| Test | Result |
|---|---|
| The listener as a NEMESIS package, versions 0.1.0 to 0.2.1 | 2026-11-03, on the car: presses and holds told apart, the dash star ignored, every short press switched the pad, with and without Android Auto |
| The star choice (mod 1.0.0, choice only) | 2026-11-13, on the car: the choice shows in the steering wheel star's list and can be selected |
| Mod 2.0.0, off the car | The listener's decision cases; a full build; HMG-API's engine reads the stick as a new mod, as an update over 1.0.0, and refuses it on another build |
| Mod 2.0.0, on the car | 2026-11-13: the pad switches on a short press with Qi pad on/off selected, and does not with another choice selected |
| Mod 2.0.1 | Off the car only. The same listener and service script as 2.0.0; `mod.json` gains `authors` and `repo`, which HMG-API's community catalogue asks for |

Not yet recorded: the first press after the car has been off overnight, after the head unit sleeps and wakes, and a long press with the choice selected.

## 9. Not covered

- The rear pad, if any trim has one. Only the front pad's setter is verified.
- Other head unit builds and other cars. Each needs the transaction numbers, the key code and the saved-choice property checked again.
- Any automatic behavior (temperature, battery level, timers). Ruled out on purpose.
- An on-screen message when the pad switches. HMG-API offers the car's own pop-up to mods; left out so far.
- A picture of its own beside the choice in the star list. HMG-API takes that picture from the choice's activity, so a broadcast choice shows Android's default one, and there is no day and night version for star choices.

## 10. Approaches considered for the mod

1. **The existing service script as an HMG-API script service (chosen).** Everything that ran under NEMESIS runs the same way under HMG-API, and the build check and the waits stay in a script that had already run on the car.
2. **A jar service.** HMG-API would start the listener itself. The build check would have to be rewritten in Java, and that check is what keeps the pad numbers from being used on another software version.
3. **Toggle on the choice's own broadcast**, through a small app and a root script. The pad could then only switch with the choice selected, by construction. It replaces the tested listener and adds seconds between press and switch.
4. **Two pieces**: the NEMESIS package for the listener and an HMG-API mod for the star choice. Tried for a day (section 11). Two things to install and keep in step.

## 11. History: the NEMESIS package (versions up to 1.0)

The project began on 2026-11-02 as a NEMESIS package of its own, `qipad.star`. HMG-API could already add choices to the star lists, but it was two days old, its installers were untested on a car without adb, and its first issues included an install failure on this firmware. So the first route was a Launchpad-style root service that reads the button directly.

**How it worked.** One NEMESIS service package: `svc/stard.sh` (the same script as now, started by NEMESIS) and `lib/stard.jar` (the same listener, without the check of the star choice). It switched the pad on every short press of the wheel star, whatever the star was set to.

**The star setting it needed.** The car insists on some function for the star button. With None, every press, short or long, opens the star-button setup screen. The setting used was **Phone Projection**: with Android Auto on screen a press of it shows nothing, so the car's own action stayed out of the way. One side effect: the first press after Android Auto connects briefly switches the audio to Bluetooth Audio and back.

| Field | Value |
|---|---|
| `id` | `qipad.star` |
| `name` | Qi Pad Star Button |
| `type` | `service` (`name=stard`, `kind=sh`, `uid=root`, `mode=restart`) |
| `os` | `CVEV.USA.0000.V015.012.260507` |
| Versions | 0.1.0 (dry run: logs, never writes), 0.2.0, 0.2.1, 1.0 |
| Log | `/data/nemesis/logs/qipad.star/stard.log` |

| Step | Result |
|---|---|
| getevent test stick | 2026-11-03: failed (buffered output), so the listener is Java |
| Dry-run install (0.1.0) | 2026-11-03: presses logged, hold and dash star ignored, nothing written |
| Live install (0.2.0, then 0.2.1) | 2026-11-03: every short press switched the pad, a hold did not, with and without Android Auto. 0.2.0 logged a false mismatch on every press because it read the pad back before the car had confirmed the write; 0.2.1 reads again every 250 ms |
| 1.0 | Built 2026-11-07: the same service, plus a README and a store description inside the package |

**Why it changed.** By 2026-11-13 HMG-API was on the car. First, an HMG-API mod added the "Qi pad on/off" choice next to the package (mod 1.0.0: the choice and nothing else), so the star no longer had to be on Phone Projection. That showed the remaining flaw: the listener switched the pad whatever the star was set to. The listener then got its check of the saved choice. And because two pieces had to be installed and kept in step, the listener moved into the mod as its service: one mod, version 2.0.0.

The package is not part of this repository. Do not run it next to the mod.
