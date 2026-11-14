# EV6 wireless charging pad on the steering wheel star button

A head unit mod for the Kia EV6 that lets the steering wheel star button switch the wireless phone charging pad on and off. One press, no menu.

It is one [HMG-API](https://github.com/Open-HMG/HMG-API) mod, `qipad-star`.

**Current version: 2.0.0** ([download](https://github.com/amc2002/hmgapi-qipad-star/releases/latest)). Tested on a 2023 Kia EV6 GT-Line AWD (US) with HMG-API 1.1.0-beta.1: a short press of the steering wheel star switches the pad, and only while the star is set to "Qi pad on/off" in the car's Setup > Button menu.

How it works: [docs/design.md](docs/design.md). Every test on the car: [docs/research.md](docs/research.md). Building and releasing: [docs/maintaining.md](docs/maintaining.md).

## Why

With wireless Android Auto the phone sits on the charging pad for the whole drive, and the pad charges it the whole time. The phone gets hot enough that Android Auto turns off 3D buildings and says the phone needs to cool down. With the pad switched off in the car's menu the phone is fine. The car only offers that switch several taps deep in its vehicle settings, so the pad is in practice always on or always off. The goal is to leave it off and turn it on with the star button when the phone is low.

Just a toggle. No timer, no automation.

## Car and software

- 2023 Kia EV6 GT-Line AWD, US market
- Head unit software `CV_E.USA.S5W_M.V015.012.260507` (`ro.build.product` = `CVEV.USA.0000.V015.012.260507`), Gen5W, Android 4.4
- [NEMESIS](https://github.com/xwtk/hmg_nemesis) installed on the head unit (HMG-API runs on top of it)
- [HMG-API](https://github.com/Open-HMG/HMG-API) installed on the head unit (tested with 1.1.0-beta.1)

The method numbers in this project were read from this build's own framework files. Another build must be checked again before anything is sent to the car.

## What is known

The pad switch in the car's menu is one call on the head unit's user-settings service, `com.hkmc.micom.usm`:

| Purpose | Method | Transaction code |
|---|---|---|
| Set the front pad | `setConvenience_WirelessChargingSystemFront(int)` | 130 |
| Read the front pad | `getConvenience_WirelessChargingSystemFront()` | 465 |

The value is 1 for off and 2 for on, confirmed by reading the getter from a root shell while the screen showed off, and by one write of 2 from a root shell that flipped the toggle on the screen to ON. The settings app, the framework and the service all carry that method by name, and the head unit log shows the car's micom frame leaving within 10 ms of the call. Details, evidence and the validation of the numbers are in [docs/research.md](docs/research.md).

## How it works

The mod has two parts, installed together:

1. **A choice in the car's star button list.** Through HMG-API's `provides.star_key` the mod adds "Qi pad on/off" to the car's own lists in Setup > Button. The choice itself does nothing: on a press HMG-API sends a broadcast that nothing receives. It gives the star a setting of its own. HMG-API shows the choice in the steering wheel star's list and in the head unit star's list; the listener only acts on the steering wheel star, so for the head unit star the choice does nothing.
2. **A listener.** HMG-API runs it as a root service of the mod. It watches the head unit's raw button input. On a short press of the steering wheel star (key code 43 on the main input device) it reads the car's saved star choice (the system property `persist.sys.key.swrccustom`). Only if that is this mod's choice (`hmgapi.star.qipad-star.toggle`) does it read the pad state with the getter and write the other value with the setter. With any other star setting the pad is left alone and the star does what that setting says. A long press is left to the car, and the dash star is ignored.

Full design: [docs/design.md](docs/design.md).

History: up to version 1.0 this was a NEMESIS package of its own, `qipad.star`, that did not use HMG-API. It switched the pad on every short press, whatever the star was set to, and the star had to be set to Phone Projection so that the car's own action stayed out of the way. HMG-API was two days old when that route was chosen (2026-11-02). Since version 2.0.0 (2026-11-13) the project requires HMG-API and is one mod.

## Install and set up

HMG-API has to be on the head unit already: see [Installing HMG-API](https://github.com/Open-HMG/HMG-API/wiki/Installing-HMG-API).

1. Download `qipad-star-2.0.0.zip` from the [latest release](https://github.com/amc2002/hmgapi-qipad-star/releases/latest) and put it in a folder `HMGAPI/updates/` at the top of a USB stick. Do not unzip it. (The same file is in `install-sticks/hmgapi-qipad-star-2.0.0/`, already inside an `HMGAPI` folder, with a `README.txt` of the steps.)
2. In the car: HMG-API app > Check USB updates > **Install** (or **Update**, if an older version of the mod is installed). On a first install HMG-API asks to confirm the author key, which should be `e3264f78-8e52-846d-8ed6-28e59cd5f68a`.
3. Go back, press Apply if it asks, take the stick out, and press Restart unit.
4. **Set the steering wheel star to Qi pad on/off:** Setup > Button > steering wheel star > **Qi pad on/off**.
5. Short-press the wheel star: the pad switches. With any other star setting the pad is left alone.

If the old NEMESIS package is still on the head unit, uninstall it before step 1: NEMESIS Manager > Packages > Qi Pad Star Button > Uninstall (the entry with the id `qipad.star`). As long as its listener is there, the mod's listener waits and does nothing.

If the pad does not switch: HMG-API app > Mods > Qi Pad Star Button, and scroll to Log. The listener's last lines are under "service stard" and say what it is doing.

The `README.txt` in the stick folder has the same steps in full.

To remove it: first set the wheel star to another choice. Then, in the HMG-API app, press the mod's Remove button, confirm, apply, and restart the head unit. If the star is still on "Qi pad on/off" when the mod is removed, HMG-API sets it to None at the next restart, and with None every press opens the car's button setup screen.

NEMESIS Manager lists the mod as well, with the id `hmgapi.qipad-star`: HMG-API puts every mod it installs there. It is one mod, shown in two places.

### The earlier NEMESIS package

Up to version 1.0 this project was a NEMESIS package of its own, `qipad.star`, that worked without HMG-API. It is retired and is not part of this repository; [docs/design.md](docs/design.md), section 11, tells its story. If it is still on a head unit, uninstall it before installing the mod.

## What is in this repository

| Folder | Contents |
|---|---|
| `docs/` | The design, the research record with every test on the car, and the notes for maintainers |
| `hmgapi-mod/qipad-star/` | The mod: `mod.json` and the service script `svc/stard.sh` |
| `src/` | The listener (`StarDaemon.java`), built into the mod as `lib/stard.jar` |
| `test/` | The listener's checks (`StarDaemonTest.java`) |
| `install-sticks/` | Built install sticks, ready to copy to a USB stick |
| `tools/make-hmgapi-mod/` | The build script that compiles the listener and signs and packs the mod with HMG-API's mod SDK, and its checks (`test.sh`) |
| `tools/capture-stick/` | Read-only USB kit that records the head unit log while the setting is flipped on the screen, and copies the framework files needed to look up the method numbers |
| `tools/read-stick/` | Read-only USB kit that asks the service for the current pad value |
| `tools/write-stick/` | USB kit that makes exactly one write (the other value), reads it back, and saves a short log |
| `tools/aidl-codes/` | Small Python reader that prints transaction codes from a head unit's own framework file |
| `tools/star-capture/` | Steps for recording the star buttons with Launchpad's port kit (the kit itself is downloaded from its releases) |
| `tools/getevent-stick/` | Read-only USB kit that tested whether `getevent` passes presses through without delay (it does not) |

The kits in `tools/` (capture, read, write, getevent) are NEMESIS run scripts: two files at the root of a FAT32 or exFAT stick, approved on screen, run as root. Apart from the write kit's single service call they only write to the stick. Each folder has its own README with the in-car steps.

## Rules this project follows

- Nothing here sends its own messages on the car's network. The toggle calls the same head unit service the car's own settings screen calls.
- No firmware files, raw head unit logs or signing keys are ever committed. The head unit log contains the car's GPS position. The findings go in the repository, the files do not.
- Every number is derived from the car's own files and checked against numbers other projects have published for the same build.
- Getter first, then one write, parked, then confirm on the screen. Never guess a transaction number against a live service.

## Credits

- [HMG-API](https://github.com/Open-HMG/HMG-API) (Open-HMG, started by VysseCodes): the mod runs on it. It adds the star-list choice, runs the listener as the mod's service, and its mod SDK signs the package. Its documentation of the car's star-button menu informed the research.
- [NEMESIS](https://github.com/xwtk/hmg_nemesis) by xwtk: the root channel and the USB run-script mechanism.
- [hkmc-coldstart-heat](https://github.com/eclipseempire/hkmc-coldstart-heat) by eclipseempire: the discovery recipe and the capture template this project's capture stick is adapted from, and the published USM codes used to validate the parser.
- [gen5w-preconditioning](https://github.com/paytondevs/gen5w-preconditioning) by paytondevs (Launchpad / Precondition): the USB kit layout the sticks here follow, the port kit used to measure the star button, and the idea of a root service reading button input. No code is copied; this project's listener is written from scratch.

## License

AGPL-3.0. See [LICENSE](LICENSE).

This is an unofficial project with no connection to Hyundai, Kia, Genesis or HKMC. You are responsible for anything you send to your car.
