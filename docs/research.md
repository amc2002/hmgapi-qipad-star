# Research record

The dated record of everything learned and tested in this project, in the order it happened. Earlier entries are kept as they were written, so some plans in them were later changed; the later entries say so. Everything was measured on one car: a 2023 Kia EV6 GT-Line AWD (US) with head unit software `CV_E.USA.S5W_M.V015.012.260507`, `ro.build.product` = `CVEV.USA.0000.V015.012.260507`, device `wp_daudioplus_cvev_us`, SDK 19, `ro.build.version.incremental` = `eng.vmadmin.20260507.095323`.

## 1. The question

The wireless phone charging pad can be switched on and off in the head unit's vehicle settings. Which head unit call does that, and what are its transaction codes, so a mod can make the same call from a button?

## 2. Method

The recipe is the one documented in [hkmc-coldstart-heat/EXTENDING.md](https://github.com/eclipseempire/hkmc-coldstart-heat/blob/main/EXTENDING.md):

1. Capture the head unit log while the factory control is operated.
2. Find the service and method the log names.
3. Read the method's transaction code from the car's own `automotive.odex`, and confirm the service side exists in `automotive-service.odex`.
4. Call the getter first, then make one write while parked, and confirm on the screen. (Both done; see section 5.)

Step 1 used `tools/capture-stick/`, a NEMESIS run script adapted from the cold-start package's `research/probe-template/`. Two changes: it refuses to run unless it is on a USB volume (the template falls back to internal storage), and it saves the whole log instead of filtering on the car (the head unit's toolbox may lack `grep`).

## 3. Capture (2026-11-02)

The pad setting was opened on screen, the stick inserted and approved, and the setting flipped five times inside the 50 second window.

The first attempt produced nothing because the car was turned off before the script finished. The head unit has to stay on until the success dialog.

Each flip produced the same three-step pattern in the log (process 619 is `system_server`, process 172 is the micom daemon):

```
V/USMService(  619): [SND] FUNC : [USM_Convenience_SET_ETC_C_REQ(0x110f)]
D/MicomD  (  172): send_data: c => m : ff 92 11 01 11 0f 00 03 06 01 67
V/USMService(  619): [RCV] FUNC : [USM_Convenience_SET_ETC_M_RESP(0x910f)]
V/USMService(  619): -  Convenience_WirelessChargingSystemFront: 1
V/USMService(  619): -  Convenience_WirelessChargingSystemRear: 250
```

The frame's value byte alternated `01` and `02` across the five flips (`... 06 01 67` and `... 06 02 64`), and the response dump showed `Convenience_WirelessChargingSystemFront` as 1, 2, 1, 2, 1 in that order. The rear field read 250 throughout, which is read as "not fitted" (several other unfitted options in the same dump also read 250).

The foreground app during the flips was `com.android.vehiclesettings` (activity `VehicleSetting`). After each change, every process holding a `USMManager` received `onConvenienceEtcReceived()` with the new value.

## 4. Method names and transaction codes

The AIDL stub `com.hkmc.usm.IUSMService$Stub` in this build's `automotive.odex` has 656 transaction constants. The ones for the pad:

| Method | Code | Signature |
|---|---|---|
| `setConvenience_WirelessChargingSystemFront` | **130** | `(int) -> void` |
| `getConvenience_WirelessChargingSystemFront` | **465** | `() -> int` |
| `setConvenience_WirelessChargingSystemRear` | 131 | `(int) -> void` |
| `getConvenience_WirelessChargingSystemRear` | 466 | `() -> int` |

The service is registered as `com.hkmc.micom.usm` (entry 40 in `service list` on this build).

### How the numbers were read and checked

The constants were read with a small purpose-written DEX reader (static field values of the stub class). Before trusting it, four codes already published for this firmware were read from the same file and compared:

| Method | Read here | Published |
|---|---|---|
| `setFrontSeatHeatDrvStep` | 213 | 213 (cold-start heat, HMG-API) |
| `setFrontSeatHeatAstStep` | 214 | 214 (cold-start heat, HMG-API) |
| `setSWRC_SteeringwheelWarmerSet` | 212 | 212 (cold-start heat) |
| `setRearSeatHeatLeftStep` | 186 | 186 (cold-start heat) |

All four match. The published tool for this job, `tools/dexodex.py` in the cold-start repository, does the same thing and can be used as an independent cross-check.

### The chain by name, in the car's own files

- `HKMC_VehicleSetting.odex` (the settings app) references `USMManager.setConvenience_WirelessChargingSystemFront(int)` and the matching getter.
- `automotive.odex` has the `USMManager` wrapper, the `IUSMService` interface, the stub and the proxy, all with the same method.
- `automotive-service.odex` has `USMService.setConvenience_WirelessChargingSystemFront(int)` and the getter, in the same class as the `sendPacket` methods.

Not done: disassembling the service method down to its `sendPacket` call. The log already shows the `0x110f` frame leaving 10 ms after the call, with the value byte matching the setting, so the observed behavior covers that step.

### File identity

MD5 of the copied framework files matched the values HMG-API records for the US EV6 260507 in its `maps/kia/ev6/usa/260507/car.json`: `automotive.odex` `efbfceed274a0b58d092e89aeaa8c66e`, `automotive-service.odex` `33a30843e149a3d604ecc6957fd25d46`. The copies are complete and this head unit matches HMG-API's hook map.

## 5. Open items

1. **Which value is "on": resolved 2026-11-02.** `tools/read-stick/` ran on the car with the setting showing OFF on the screen. Getter 465 answered `Result: Parcel(00000000 00000001 ...)` twice, getter 466 (rear) answered 250 twice. So **1 = off, 2 = on**. (The capture therefore started with the pad on.) This was also the first confirmation that the getter answers a root shell without an exception.
2. **One write while parked: done 2026-11-02, worked.** `tools/write-stick/` ran with the setting screen open and showing OFF. Getter 465 read 1; the script sent `service call com.hkmc.micom.usm 130 i32 2`; the reply was a clean empty parcel; two seconds later the getter read 2. The toggle on the screen flipped to ON almost immediately, and was then switched back off by hand. The head unit log around the write shows the identical chain the settings screen produces: `USM_Convenience_SET_ETC_C_REQ(0x110f)`, the micom frame `ff 92 11 01 11 0f 00 03 06 02 64`, the `0x910f` response, every `USMManager` listener notified, and the dump reading `Convenience_WirelessChargingSystemFront: 2`. **The command half is settled: `com.hkmc.micom.usm` transaction 130 with 1 (off) or 2 (on); getter 465.**
3. The button half: see section 6. Resolved with a root service reading raw input, not with HMG-API. (From 2026-11-13 the project is an HMG-API mod: see the end of section 6.)

## 6. The button half (what was found)

The first bullets record what was learned about HMG-API before the route was chosen. The route taken, and every test of it, follow from "Decision (2026-11-02)" on.

- HMG-API adds rows to the car's own star-button lists by hooking the `ButtonSettings` app (`CustomButtonSetting` for the head unit star, `CustomButtonSettingSWRC` for the steering wheel star). A row needs an `activity` or a `broadcast` to fire. Source: `core/runtime/java/hmgapi/hook/StarKey.java` and `Mods.java` in the HMG-API repository.
- HMG-API's hook map for `kia/ev6/usa/260507` has every `buttonsettings.*` point found, and its README says buttons were tested on a 2023 US EV6 on this build (beta 1 test session).
- A mod can also bind the steering wheel star directly (`"key": "wheel_custom"`, press `hold`), leaving the short press to the choice made in the car's menu.
- Without HMG-API, the stock list cannot be extended: `ButtonSettings` builds it from hard-coded entries and skips unknown ones. A plain NEMESIS package could at most catch the stock "None" broadcast (`com.mobis.intent.action.SWRC_CUSTOM_SHORTCUT`), which is untested.

### Decision (2026-11-02)

The route chosen was a Launchpad-style package of our own instead of HMG-API. Reasons recorded at the time: HMG-API had existed for two days (repository created 2026-10-31, beta 5), its README said the installers were untested on a car without adb, and its first issues included an install failure on firmware 260507 and a report of wireless Android Auto lost in the Leafia-to-HMG-API transition. Launchpad's trigger mechanism was already proven on this car.

Changed 2026-11-13: with HMG-API on the car by then, the project became an HMG-API mod. See "The move to HMG-API" at the end of this section.

Launchpad (paytondevs/gen5w-preconditioning) has no license file and its README does not state one, so its daemon code is not copied here. The daemon for this project is written fresh from the public Linux input-event format.

Open before the design: (a) does the wheel star reach the head unit as a raw key event, on which device and with which code (the head unit lists three input devices: `telechips keypad`, `daudio_wp_daudioplus_cvev_us`, `daudio_wp_daudioplus_cvev_us_can`); (b) what the car does on a long press of the wheel star. Launchpad's read-only port kit (`Launchpad-port-kit-usb.zip`, 1.4.1) records every key on every input device for 30 seconds and is the planned instrument.

### Evidence from another car (Launchpad issue #36, 2026-10-31)

On a 2023 Ioniq 5 Limited (US, `NEEV23.USA.0000.V016.010.260903`), Launchpad's port kit was run while a star button was held. The kit logged key `code=20` on the head unit's main input device `daudio_wp_daudioplus_neev23_us` (15 presses, 14 holds) and marked it `likely_knob`. Changing `KEY_CODE=17` to `KEY_CODE=20` in Launchpad's `knob.conf` made holding the star open Launchpad. The issue does not say which star button (wheel or dash panel) was pressed; the main input device is where the panel's TUNE key also arrives. The maintainer's reply concerned the TUNE paddle, which can be pushed in. Source: https://github.com/paytondevs/gen5w-preconditioning/issues/36

What it establishes for this project: at least one star button on a Gen5W unit is an ordinary raw key event that a Launchpad-style daemon can act on, the port kit reports it, and a hold on it did not visibly interfere with the car on that unit. The EV6 has two star buttons (steering wheel and dash panel; HMG-API maps both `wheel_custom` and `custom` on this build), so the capture here presses each in its own phase.

### Star capture (2026-11-03)

Instrument: Launchpad's port kit 2.0.0 (`Launchpad-port-kit-usb.zip` from the Precondition 2.0.0 release), run as a NEMESIS script on NEMESIS 1.16.4. Before the run both star buttons were set to None in Setup > Button.

The first run (01:18 head unit time) was cut off between the `[interfaces]` and `[key_capture]` sections, so it recorded no keys. The kit writes captured keys only at the very end, after a long interface dump: the stick has to stay in until the success dialog. The second run (01:25) completed (`probe_complete=yes`, exit 0).

The head unit now lists five input devices, not three: `telechips keypad` (event0), `daudio_wp_daudioplus_cvev_us` (event1), `daudio_wp_daudioplus_cvev_us_can` (event2), `daudio_wp_daudioplus_cvev_us_knob` (event3), `fts_ts` (event4, touchscreen). The kit listened on all five.

All 26 key events came from `daudio_wp_daudioplus_cvev_us` (event1, the same device where TUNE is key 17). None from the CAN device, the knob device or the touchscreen.

| Time (ms) | Code | What |
|---|---|---|
| 5364 to 11054 | 43 | 5 short presses |
| 13536 to 16323 | 20 | 3 short presses |
| 17579 to 19115 | 20 | 1 hold, 1536 ms |
| 21542 to 23976 | 43 | 3 short presses |
| 24652 to 26286 | 43 | 1 hold, 1634 ms |

Which code is which button: the wheel star was pressed first, then the dash (console) star, then the wheel star again. That matches the three blocks (43, 20, 43), so **code 43 = steering wheel star, code 20 = dash star**. The first on-car test of the daemon confirms it again.

How presses and holds arrive: a short press is key down (value 1) then key up (value 0) 130 to 250 ms later. A hold is the same pair further apart. There is no separate hold code and no autorepeat (value 2). Both holds ended at about 1.5 to 1.6 s although the button was held longer, which suggests the car releases the key when it recognises a long press (inference, not proven).

What a long press does: on both stars, with the button set to None, a long press opens the car's star-button selection screen in Setup > Button. The car keeps the long press for itself.

Correction (2026-11-03, getevent test): with the wheel star set to None, a **short** press also opens that selection screen. Setting the star to None does not make a short press do nothing; the car treats None as "not set up yet" and offers the menu. The design's assumption that None leaves the short press free is wrong. Chosen assignment (2026-11-03): Reject/End Call and Phone Projection were tried on the wheel star with wireless Android Auto running and no call; neither showed anything on screen. **Phone Projection** chosen, because Reject/End Call would also end any active call (including, possibly, a call placed by the car's own emergency system; not checked). Not yet tried: a press with Android Auto disconnected. Full option list on this build: Cancel Route, Weather, Bluetooth Audio, Sports, Driver Assistance Settings, Voice memo Start/Stop, Utility Mode, Reroute, Phone, Calendar, Reject/End Call, Phone Projection, Privacy Mode, Change Handsfree Calling Device, Home, Display On/Off, Quiet Mode, EV, HD Radio Data, Kia Connect, MAP, Radio/Media On/Off, Wi-Fi Hotspot, None.

Consequences for the design: trigger on a short press of code 43 on event1 only; act on the key up, and only when it comes within a short limit (about 800 ms) of the key down, so a hold opens the car's setup screen and leaves the pad alone. The car's setting for the wheel star stays on None so a short press does nothing else.

The head unit ran NEMESIS 1.16.4 at the time of the capture.

### getevent test (2026-11-03)

Stick `tools/getevent-stick/` run at 01:59 head unit time. `getevent` exists (`/system/bin/getevent -> toolbox`). The main input device was found by name as `/dev/input/event1`. `getevent -t /dev/input/event1` ran in the background for 20 seconds, writing to a file on the stick, while the wheel star was pressed three times. The file stayed at 0 bytes every second, and was still empty after `getevent` was stopped. `getevent` wrote nothing to its error file.

Reading: the presses are known to reach event1 (the port kit read them there the same night), so the likely cause is that `getevent` holds its output in a buffer when it writes to a file or pipe, and loses it when stopped. Three presses make roughly 500 to 600 bytes of output, less than one buffer. Either way, a shell script cannot rely on `getevent` streaming presses as they happen. Per docs/design.md, the service falls back to option B: a small Java program run through `app_process`, which reads event1 directly.

### Dry-run install, qipad.star 0.1.0 (2026-11-03)

Installed from the dry-run stick (0.1.0) on NEMESIS 1.16.4. Wheel star set to Phone Projection. `stard.log`:

| Time | Action | Service logged |
|---|---|---|
| 02:20:36 | install | start, `daudio_wp_daudioplus_cvev_us` = event1, key 43, DRY RUN |
| 02:21:42 | wheel star, short | 253 ms, pad OFF(1), would write 2 |
| 02:21:44 | wheel star, short | 272 ms, pad OFF(1), would write 2 |
| 02:21:47 | wheel star, hold | hold of 1570 ms ignored |
| between | dash star, short | nothing (as intended) |
| 02:21:57 | wheel star, short | 199 ms, pad OFF(1), would write 2 |
| 02:22:13 | wheel star, short, Android Auto disconnected | 221 ms, pad OFF(1), would write 2 |

Confirms on the car: the service starts by itself after install, app_process runs the dex, key 43 on event1 is the wheel star, presses and holds are told apart, the dash star is ignored, getter 465 is read correctly from Java. The hold again ended at about 1.5 s. Nothing was written.

### Live install, qipad.star 0.2.0 (2026-11-03)

Installed over 0.1.0. The wireless charging setting was watched on screen: each short press of the wheel star flipped it, four times in a row (OFF, ON, OFF, ON, OFF). `stard.log`:

```text
02:27:50 start ... LIVE (writes)
02:27:58 press (138 ms): pad OFF(1) -> wrote 2 -> reads OFF(1)  MISMATCH. reply: Result: Parcel(00000000    '....')
02:28:26 press (116 ms): pad ON(2) -> wrote 1 -> reads ON(2)  MISMATCH. reply: Result: Parcel(00000000    '....')
02:28:31 press (167 ms): pad OFF(1) -> wrote 2 -> reads OFF(1)  MISMATCH. reply: Result: Parcel(00000000    '....')
02:28:40 press (201 ms): pad ON(2) -> wrote 1 -> reads ON(2)  MISMATCH. reply: Result: Parcel(00000000    '....')
```

Every write was accepted and took effect (the screen flipped, and each next press read the value just written). The "MISMATCH" is a timing artefact: getter 465 still returns the old value immediately after setter 130, and returns the new one only once the car has confirmed it. The write stick had slept 2 s before reading back for this reason. Fixed in 0.2.1: the service re-reads every 250 ms for up to 3 s and reports how long it took.

### Live install, qipad.star 0.2.1 (2026-11-03)

Installed over 0.2.0. 12 short presses between 02:36 and 02:39, each logged as `wrote N -> reads N after 250 ms` (no mismatch; the car confirms within the first 250 ms re-read). One hold of 1465 ms ignored; the car's setup screen opened and the pad stayed as it was. With Android Auto disconnected, a short press still switches the pad.

Side effect, from the car's own Phone Projection action on the star, not from the service: with Android Auto running, the **first** press after it connects briefly switches the audio to Bluetooth Audio and then straight back to Android Auto. Later presses show nothing. This was accepted for that version. If it ever matters, Reject/End Call showed nothing at all, at the cost of ending any active call.

### The move to HMG-API (2026-11-13)

- **HMG-API on the car.** By 2026-11-13 the test car ran HMG-API 1.1.0-beta.1, with its wireless CarPlay and Android Auto mod. The reasons of 2026-11-02 against using it no longer held.
- **A star choice of its own (mod 1.0.0).** An HMG-API mod, `qipad-star`, that was only a `mod.json` added a "Qi pad on/off" choice to the star lists through `provides.star_key`, as a broadcast entry that nothing receives. It was installed on the car that day, next to the NEMESIS package. The choice showed in the steering wheel star's list and could be selected. In that list it shows Android's default app picture: HMG-API takes a star choice's picture from its activity, and a broadcast choice has none.
- **Finding.** The NEMESIS package's listener reads the raw key, so the pad switched whatever the star was set to. It should switch only with "Qi pad on/off" selected.
- **The listener's check.** On each short press the listener now reads the system property `persist.sys.key.swrccustom` and goes on to the toggle only if the value is `hmgapi.star.qipad-star.toggle`. Both the property and the value come from HMG-API's source (v1.1.0-beta.1, `StarKey.java` and `Mods.java`). The check was first built into a NEMESIS package 1.1 that was never installed. Checked off the car: the 15 cases of the decision function; the compiled listener accepts six arguments and refuses five.
- **Toolchain check.** The unchanged 1.0 source, rebuilt on a Windows PC with a portable Temurin JDK 17.0.21+9 and dalvik-dx 9.0.0_r3, gave a package whose text files are byte-identical to those of the 1.0 stick built earlier and whose `classes.dex` has the same size.
- **One mod (2.0.0).** The listener moved into the HMG-API mod: HMG-API runs `svc/stard.sh` as a root script service of the mod, and the script starts the same listener (docs/design.md). The NEMESIS package is retired. Checked off the car with HMG-API's own engine from the 1.1.0-beta.1 mod SDK, run on a PC in desktop mode with the product set to this car's build: it reads the stick as a new mod, with only the warning that the author is not on its trusted list; with mod 1.0.0 installed it reads the stick as an update; installed into an empty test folder it writes the service line `qipad-star stard root android yes script svc/stard.sh -` for its daemon; `plan` lists `service qipad-star/stard as root, at android, restarted if it stops`; with another build string it refuses the stick. (On Windows that engine stopped with a rename error when it had to overwrite an existing state file. In an empty folder it did not. Not looked into further.)
- **Review of 2.0.0, off the car.** A second pair of eyes found nothing against the code. Checked there: the stick's `classes.dex` is byte-identical to a rebuild from the committed source; the service line passes the daemon's own validity check (`svc_valid` in `core/hmgapid/hmgapid.c`); the SDK's script check passes `svc/stard.sh`; and, with the listener driven on a PC by made-up key events and a stand-in `getprop`: with the star on None the pad was left alone and not read, a matching press went on to the pad read, a press inside the pause was ignored, a 1.5 s hold was ignored without asking for the star choice, and with no `getprop` at all the pad was left alone. What cannot be checked off the car: Dalvik with the service's own data folder; whether the daemon passes `BOOTCLASSPATH` on (the script reads `/init.environ.rc` if not); the real value of `persist.sys.key.swrccustom`; whether NEMESIS's uninstall removes the old listener's jar; SELinux under the daemon; and mksh itself (the script was run under bash).
- **Mod 2.0.0 on the car (2026-11-13).** A fresh install: the NEMESIS package and mod 1.0.0 had been removed first. Result: the pad switches on a short press of the wheel star with "Qi pad on/off" selected, and does not with another choice selected. So HMG-API starts the mod's service on this head unit, the listener's check of the saved star choice works there, and the wait for the old package's listener did not hold it up. Not yet recorded: the first press after the car has been off overnight, and a long press with the choice selected.

## 7. Notes for anyone repeating this

- Keep the car on until the stick's success dialog appears. Turning the car off ends the script.
- The head unit log contains the car's GPS position (theme scheduler lines). Do not post raw logs.
- The copied `.odex` files are Kia firmware. Keep them off the internet.
- The head unit shell is `mksh` with Android 4.4's toolbox. The capture and read scripts avoid `grep`, `awk` and `sed`.
- Values in this family of settings are small enums, not booleans. Seat heat on this platform uses 2 for off, while the pad uses 1 for off and 2 for on. Read the enum back before assuming; the first guess here was the wrong way round.
