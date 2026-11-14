# Maintaining this project

What it takes to build, check, release and carry on with the mod. How the mod works is in [design.md](design.md); every test on a car is in [research.md](research.md).

## What you need

- A Gen5W head unit with [NEMESIS](https://github.com/xwtk/hmg_nemesis) and [HMG-API](https://github.com/Open-HMG/HMG-API), ideally a US Kia EV6 on software `CVEV.USA.0000.V015.012.260507`. Another build needs the work under "Another software build" below.
- To build:
  - A JDK (`javac`, `java`) and Python 3.
  - HMG-API's mod SDK: `hmgapi-mod-sdk-<version>.zip`, attached to each HMG-API release. Unpack it; the build takes the folder as its first argument and uses only `lib/hmgapi-engine.jar`.
  - The Android `dx` tool as a jar at `tools/make-hmgapi-mod/dalvik-dx.jar` (not committed): `com.jakewharton.android.repackaged:dalvik-dx` version 9.0.0_r3 from Maven Central, SHA-1 `df4b3258ddb4c7d531143405505a9396949bbb51`.
  - The author key (next section).

The build scripts are POSIX sh. They run on Linux and, on Windows, under Git Bash.

## The author key

HMG-API identifies a mod's author by the key its package is signed with. The mod's UUID, `e3264f78-8e52-846d-8ed6-28e59cd5f68a`, comes from that key, and a head unit takes an update only if it is signed with the key the installed version was signed with.

- The key is not in this repository and must never be. The build refuses a key that sits inside the repository.
- Whoever releases the mod needs the key. Without it, a new key gives the mod a new UUID, and everyone who has the mod installed has to remove it before installing the new one.
- A new key is made with the SDK: `java -cp <sdk dir>/lib/hmgapi-engine.jar hmgapi.engine.Signing keygen <key file>`.

## Build and check

```bash
sh tools/make-hmgapi-mod/test.sh <sdk dir>
tools/make-hmgapi-mod/build-hmgapi-mod.sh <sdk dir> <key file>
```

`test.sh` checks the listener's decision about the star choice, `mod.json`, the service script, the README, and a full build with a throwaway key. As part of that it runs HMG-API's own engine from the SDK on the build machine, to see that it reads the finished stick as an installable mod and refuses it for another software build. Without `<sdk dir>` it runs everything that needs no build.

The build writes a ready-to-copy stick folder to `dist/hmgapi-qipad-star-<version>/`: the package at `HMGAPI/updates/qipad-star-<version>.zip` and a `README.txt` with the steps for the car. Its last two output lines are the mod's UUID and the stick folder.

## Releasing a version

1. Set the version in `hmgapi-mod/qipad-star/mod.json` and in `VERSION` at the top of `tools/make-hmgapi-mod/test.sh`.
2. Run `test.sh` with the SDK, then the build with the author key.
3. Replace the folder in `install-sticks/` with the new stick folder. Zips are ignored by git, so add the package with `git add -f`.
4. Update the version in the README and the test table in design.md, and add what was tested on the car to research.md.
5. Commit, then publish a GitHub release tagged `v<version>` with `qipad-star-<version>.zip` attached and its SHA-256 in the notes. The tag is the version in `mod.json` with a `v` in front, as in HMG-API's own mod repositories.

On the car, an update is installed like the first version (HMG-API app > Check USB updates > Update). Restart the head unit afterwards, so that the service runs the new version.

## Another software build

After a head unit software update, or on another car, the mod does nothing: HMG-API refuses it for the build, and the service script checks the build itself. Before either check is widened:

1. Read the pad's transaction numbers from that build's own framework files (research.md, sections 2 to 4; `tools/capture-stick/`, `tools/aidl-codes/`).
2. Confirm them on the car: the getter first, then one write, parked (`tools/read-stick/`, `tools/write-stick/`).
3. Measure the steering wheel star's key code and input device (research.md, "Star capture"; `tools/star-capture/`).
4. Check in HMG-API's source that the wheel star's choice is still kept in `persist.sys.key.swrccustom` and that a mod's choice is still named `hmgapi.star.<mod id>.<choice id>`.
5. Then change `BUILD` in `hmgapi-mod/qipad-star/svc/stard.sh` and `system.product` in `mod.json` together. `test.sh` fails if they differ.

## Working rules

1. Test parked. Treat every write to a vehicle service as live vehicle control.
2. Getter first, then one write, then confirm on the screen.
3. Numbers come from the car's own framework files, never from another car or from memory.
4. No CAN frames of our own. Call the service the car's own settings screen calls.
5. No firmware files, raw head unit logs or keys in the repository. The head unit log contains the car's GPS position.
6. Every on-car test gets a dated entry in research.md: what was sent, what came back, what the screen showed.
7. Code from projects without a license is not copied. Launchpad (gen5w-preconditioning) has none; the listener here was written from the public Linux input-event format.

## If the pad does not switch

The listener logs every decision. In the car: HMG-API app > Mods > Qi Pad Star Button, Log section, under "service stard". The lines say whether it is waiting for the old NEMESIS package to be uninstalled, refusing the software build, or what it read as the star's saved choice on each press.

## Open items

- Not yet recorded on the car: the first press after the car has been off overnight, after the head unit sleeps and wakes, and a long press with the choice selected.
- Where to offer the mod. HMG-API keeps a community catalogue (`catalog/` in its repository); a pull request there also lists the author key as trusted, so that installing no longer warns about an unknown author.
- An on-screen confirmation when the pad switches. HMG-API's client library has the car's own pop-up (`HmgApi.toast`).
- A picture of its own for the star choice is not possible with HMG-API as it is (design.md, section 9).

## Upstream projects

- HMG-API: https://github.com/Open-HMG/HMG-API (`docs/mod-reference.md` is the mod reference; `core/runtime/java/hmgapi/hook/StarKey.java` shows how star choices work)
- NEMESIS: https://github.com/xwtk/hmg_nemesis
- hkmc-coldstart-heat: https://github.com/eclipseempire/hkmc-coldstart-heat (`EXTENDING.md` is the discovery recipe used for the pad command)
- gen5w-preconditioning: https://github.com/paytondevs/gen5w-preconditioning (the port kit used to measure buttons)
