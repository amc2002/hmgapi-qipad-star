#!/bin/sh
# Builds the qipad-star HMG-API mod package and a ready-to-copy USB stick folder.
#
#   tools/make-hmgapi-mod/build-hmgapi-mod.sh <sdk dir> <key file>
#       -> dist/hmgapi-qipad-star-<version>/HMGAPI/updates/qipad-star-<version>.zip
#          dist/hmgapi-qipad-star-<version>/README.txt
#
# The package holds mod.json and svc/stard.sh from hmgapi-mod/qipad-star, and lib/stard.jar,
# the listener compiled here from src/.
#
# <sdk dir>   the unpacked HMG-API mod SDK (hmgapi-mod-sdk-<version>.zip from an HMG-API
#             release). Only lib/hmgapi-engine.jar is used, for its signing tool.
# <key file>  the author key, with <key file>.pub beside it. Made once with the SDK:
#               java -cp <sdk dir>/lib/hmgapi-engine.jar hmgapi.engine.Signing keygen <key file>
#             Keep it outside this repository and backed up: every version has to be signed
#             with the same key, or HMG-API will not take it as an update.
#
# Needs a JDK (javac, java), Python 3, and the Android dx tool as a jar in DX_JAR (default
# tools/make-hmgapi-mod/dalvik-dx.jar; Jake Wharton's repackaging of AOSP dx, 9.0.0_r3, from
# Maven Central: com.jakewharton.android.repackaged:dalvik-dx, SHA-1
# df4b3258ddb4c7d531143405505a9396949bbb51). The jar is not committed.
# HMG-API's own bin/mkmodpkg.sh packs a mod the same way but needs the zip command; this
# script zips with make_zip.py instead.
# The last two lines printed are "UUID <the mod's uuid>" and "STICK <the stick folder>".
# On any refusal it prints one line, exits 1 and writes nothing.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
. "$HERE/lib.sh"

die() {
    echo "build-hmgapi-mod: $1" >&2
    exit 1
}

# inside_repo <file>: succeeds when the file is inside this repository, however its path is typed
# (Windows ignores the case of a path, so comparing the text of two paths is not enough)
inside_repo() {
    "$PY" -c '
import os, sys
norm = lambda p: os.path.normcase(os.path.realpath(p))
key, root = norm(sys.argv[1]), norm(sys.argv[2])
try:
    inside = os.path.commonpath([key, root]) == root
except ValueError:  # on different drives
    inside = False
sys.exit(0 if inside else 1)' "$(native_path "$1")" "$(native_path "$ROOT")"
}

# mod_field <name>: that field of the mod's mod.json
mod_field() {
    "$PY" -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))[sys.argv[2]])' "$(native_path "$MOD/mod.json")" "$1" | tr -d '\r'
}

[ $# -eq 2 ] || die "usage: build-hmgapi-mod.sh <sdk dir> <key file>"
SDK=$1
KEY=$2
ID=qipad-star
MOD=$ROOT/hmgapi-mod/$ID
DX_JAR=${DX_JAR:-$HERE/dalvik-dx.jar}
command -v java >/dev/null 2>&1 || die "java is needed"
command -v javac >/dev/null 2>&1 || die "a JDK is needed (javac not found)"
PY=$(find_python) || die "Python 3 is needed (python or python3)"
[ -f "$SDK/lib/hmgapi-engine.jar" ] || die "no HMG-API mod SDK at $SDK (lib/hmgapi-engine.jar not found)"
[ -f "$DX_JAR" ] || die "no dalvik-dx.jar at $DX_JAR (see the top of this script for where to get it)"
[ -f "$KEY" ] || die "no key at $KEY"
[ -f "$KEY.pub" ] || die "no public key at $KEY.pub"
KEY=$(cd "$(dirname "$KEY")" && pwd -P)/$(basename "$KEY")
inside_repo "$KEY" && die "the signing key must be kept outside the repository ($KEY is inside it)"
EXTRA=$(cd "$MOD" && find . -mindepth 1 ! -path ./mod.json ! -path ./svc ! -path ./svc/stard.sh | head -n 1)
[ -z "$EXTRA" ] || die "hmgapi-mod/$ID must hold only mod.json and svc/stard.sh (found ${EXTRA#./}); nothing else belongs in the package"

JAR=$(native_path "$SDK/lib/hmgapi-engine.jar")
VERSION=$(mod_field version)
NAME=$(mod_field name)
[ -n "$VERSION" ] && [ -n "$NAME" ] || die "no version or name in $MOD/mod.json"
STICK=$ROOT/dist/hmgapi-$ID-$VERSION
WORK=$ROOT/dist/.work

rm -rf "$WORK"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/classes" "$WORK/$ID/lib" "$WORK/$ID/svc" "$WORK/check"

# the listener: compile for Java 8, then convert to the head unit's dex format (Android 4.4)
(cd "$ROOT" && javac --release 8 -encoding UTF-8 -d "$(native_path "$WORK/classes")" $(find src -name '*.java'))
java -cp "$(native_path "$DX_JAR")" com.android.dx.command.Main --dex --min-sdk-version=19 \
    "--output=$(native_path "$WORK/$ID/lib/stard.jar")" "$(native_path "$WORK/classes")"

# sign a copy of the mod, zip it, then check the zip itself the way HMG-API will
cp "$MOD/mod.json" "$WORK/$ID/"
cp "$MOD/svc/stard.sh" "$WORK/$ID/svc/"
java -cp "$JAR" hmgapi.engine.Signing sign "$(native_path "$WORK/$ID")" "$(native_path "$KEY")" >/dev/null
"$PY" "$(native_path "$HERE/make_zip.py")" "$(native_path "$WORK/$ID")" "$(native_path "$WORK/$ID-$VERSION.zip")"
"$PY" -m zipfile -e "$(native_path "$WORK/$ID-$VERSION.zip")" "$(native_path "$WORK/check")"
UUID=$(java -cp "$JAR" hmgapi.engine.Signing uuid "$(native_path "$KEY.pub")" | tr -d '\r')
RESULT=$(java -cp "$JAR" hmgapi.engine.Signing verify "$(native_path "$WORK/check")" "$UUID") || die "the finished package did not verify: $RESULT"

rm -rf "$STICK"
mkdir -p "$STICK/HMGAPI/updates"
cp "$WORK/$ID-$VERSION.zip" "$STICK/HMGAPI/updates/$ID-$VERSION.zip"
cat > "$STICK/README.txt" <<EOF
$NAME
HMG-API mod $ID $VERSION

WHAT THIS IS
  One HMG-API mod. A short press of the steering wheel star switches the front wireless
  charging pad on or off, while the star is set to "Qi pad on/off" in the car's
  Setup > Button menu. The mod adds that choice to the star lists and runs the listener
  that switches the pad. With any other star setting the pad is left alone. A long press
  is left to the car.

  The choice is for the steering wheel star. It also shows in the head unit star's list,
  where it does nothing: the listener only acts on the steering wheel star.

  For head unit software CVEV.USA.0000.V015.012.260507 with HMG-API 1.0.0 or newer.

  Mod UUID: $UUID
  HMG-API shows this as the "author key" when it asks whether to install the mod.

INSTALL
  1. Copy the HMGAPI folder that is next to this file to the top of a USB stick, so the
     stick holds HMGAPI/updates/$ID-$VERSION.zip. Do not unzip the file.
  2. In the car: HMG-API app > Check USB updates. In the row for this mod, press Install.
  3. A box asks "Install $NAME?" and says the author is not on HMG-API's
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
  HMG-API app > Mods > $NAME, and scroll to Log. Under "service stard" are
  the listener's last lines. They say what it is doing:
  - "the old NEMESIS package qipad.star is still installed": see the section above.
  - "wheel star is set to ..., not Qi pad on/off": the star is on another choice (step 6).
  - "head unit build is ...": this mod is not for that software version.
  - nothing under "service stard": restart the head unit and look again.
  The full log is /data/hmgapi/logs/$ID/stard.log on the head unit.

IN NEMESIS MANAGER
  NEMESIS Manager > Packages lists this mod as well, with the id hmgapi.$ID.
  HMG-API puts every mod it installs there. It is one mod, shown in two places.

REMOVE
  1. First set the steering wheel star to another choice (Setup > Button).
  2. HMG-API app > Mods > $NAME > Remove $NAME, and confirm.
     Then press Apply changes (it may say "Nothing to change").
  3. Press Restart unit and confirm.
  If the star is still on "Qi pad on/off" when the mod is removed or turned off, HMG-API
  sets it to None at the next restart. With None, every press opens the button setup screen.
EOF

echo "UUID $UUID"
echo "STICK $STICK"
