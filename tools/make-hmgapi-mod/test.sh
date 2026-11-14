#!/bin/sh
# Checks for the qipad-star HMG-API mod: its listener (src/), its mod.json and service
# script (hmgapi-mod/qipad-star), the repository's front page, and its build.
#
#   sh tools/make-hmgapi-mod/test.sh              everything that needs no key
#   sh tools/make-hmgapi-mod/test.sh <sdk dir>    also builds with a throwaway key and checks the package
#
# <sdk dir> is the unpacked HMG-API mod SDK (it holds lib/hmgapi-engine.jar).
# Needs a JDK (javac, java) on PATH and Python 3; the build also needs dalvik-dx.jar
# (see build-hmgapi-mod.sh). One "ok" or "FAIL" line per check. Exit 0 only if every check passed.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
. "$HERE/lib.sh"
cd "$ROOT" || exit 1

MOD=hmgapi-mod/qipad-star
VERSION=2.0.1
FAILS=0
PY=$(find_python) || { echo "FAIL a working Python 3 (python or python3) is needed"; exit 1; }

# check "<what must hold>" <command...>: one line, ok when the command succeeds
check() {
    name=$1
    shift
    if "$@" >/dev/null 2>&1; then echo "ok   $name"; else echo "FAIL $name"; FAILS=$((FAILS + 1)); fi
}

says() { printf '%s\n' "$1" | grep -q -F -- "$2"; }
has() { grep -q -F -- "$2" "$1"; }
has_not() { ! grep -q -F -- "$2" "$1"; }

# ---- the listener's own checks (test/qipad/star/StarDaemonTest.java)
check_listener() {
    rm -rf build/test-classes
    mkdir -p build/test-classes
    if javac --release 8 -encoding UTF-8 -d build/test-classes $(find src test -name '*.java') 2>build/test-classes/javac.log; then
        java -cp build/test-classes qipad.star.StarDaemonTest || FAILS=$((FAILS + 1))
    else
        echo "FAIL the listener and its tests compile (needs a JDK; see build/test-classes/javac.log)"
        FAILS=$((FAILS + 1))
    fi
}

# ---- mod.json
check_mod_json() {
    "$PY" - "$(native_path "$ROOT/$MOD/mod.json")" "$(native_path "$ROOT/$MOD/svc/stard.sh")" "$VERSION" <<'PYEOF' || FAILS=$((FAILS + 1))
import json, re, sys

mod_path, stard_path, version = sys.argv[1], sys.argv[2], sys.argv[3]
fails = 0

def check(name, cond):
    global fails
    print(("ok   " if cond else "FAIL ") + name)
    if not cond:
        fails += 1

try:
    raw = open(mod_path, "rb").read()
except OSError:
    raw = None
check("mod.json exists", raw is not None)

mod = None
if raw is not None:
    try:
        mod = json.loads(raw.decode("utf-8"))
    except ValueError:
        pass
check("mod.json parses as JSON", isinstance(mod, dict))
m = mod if isinstance(mod, dict) else {}

check("mod.json keys are exactly: id name version hmgapi authors license description repo system nemesis_conflicts provides services",
      sorted(m) == sorted("id name version hmgapi authors license description repo system nemesis_conflicts provides services".split()))
check("id is qipad-star and fits HMG-API's id rule",
      m.get("id") == "qipad-star" and re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", str(m.get("id"))) is not None)
check("name is: Qi Pad Star Button", m.get("name") == "Qi Pad Star Button")
authors = m.get("authors")
check("authors is a list of names (HMG-API's catalogue needs it)",
      isinstance(authors, list) and bool(authors) and all(isinstance(a, str) and a for a in authors))
check("repo is this repository's address",
      m.get("repo") == "https://github.com/amc2002/hmgapi-qipad-star")
check("version %s, hmgapi >=1.0.0, license AGPL-3.0" % version,
      (m.get("version"), m.get("hmgapi"), m.get("license")) == (version, ">=1.0.0", "AGPL-3.0"))

try:
    stard = open(stard_path, encoding="utf-8").read().split("\n")
except OSError:
    stard = []
def setting(name):
    for line in stard:
        if line.startswith(name + "="):
            return line[len(name) + 1:].strip()
    return None

build = setting("BUILD")
check("svc/stard.sh has a BUILD= line", bool(build))
check("system.product is the one build stard.sh runs on",
      bool(build) and m.get("system") == {"product": [build]})
check("the old NEMESIS package is named as a conflict (nemesis_conflicts: qipad.star)",
      m.get("nemesis_conflicts") == ["qipad.star"])
check("one star entry: toggle, \"Qi pad on/off\", broadcast qipad.star.action.STAR",
      m.get("provides") == {"star_key": [
          {"id": "toggle", "title": "Qi pad on/off", "broadcast": "qipad.star.action.STAR"}]})
check("one service: stard, script svc/stard.sh, root, started with Android, restarted",
      m.get("services") == [
          {"name": "stard", "script": "svc/stard.sh", "user": "root", "start": "android", "restart": True}])
entries = (m.get("provides") or {}).get("star_key") or [{}]
star_action = setting("STAR_ACTION")
check("stard.sh STAR_ACTION is hmgapi.star.<mod id>.<star entry id> (the listener only acts on this choice)",
      bool(star_action) and star_action == "hmgapi.star.%s.%s" % (m.get("id"), entries[0].get("id")))
check("mod.json has no CR byte and ends with one LF",
      raw is not None and b"\r" not in raw and raw.endswith(b"\n") and not raw.endswith(b"\n\n"))

sys.exit(1 if fails else 0)
PYEOF
}

# ---- the service script, as far as it can be checked off the car
check_script() {
    S=$MOD/svc/stard.sh
    check "svc/stard.sh exists and starts with #!/system/bin/sh" [ "$(sed -n 1p "$S" 2>/dev/null)" = "#!/system/bin/sh" ]
    check "svc/stard.sh has no CR byte (the head unit's shell needs LF)" has_not "$S" "$(printf '\r')"
    check "svc/stard.sh passes the shell's syntax check" sh -n "$S"
    check "it finds its files through HMGAPI_MOD_DIR" has "$S" 'HERE=${HMGAPI_MOD_DIR:-/data/hmgapi/mods/qipad-star}'
    check "it no longer looks for its jar in the NEMESIS package folder" has_not "$S" 'HERE=/data/nemesis/apps/qipad.star'
    check "it waits while the old NEMESIS listener's jar is still there" has "$S" 'while [ -e "$OLD_JAR" ]; do'
    check "...and that jar is /data/nemesis/apps/qipad.star/lib/stard.jar" has "$S" 'OLD_JAR=/data/nemesis/apps/qipad.star/lib/stard.jar'
    WAIT_AT=$(grep -n -F 'while [ -e "$OLD_JAR" ]; do' "$S" | sed 's/:.*//')
    EXEC_AT=$(grep -n '^exec app_process' "$S" | sed 's/:.*//')
    ORDER=wrong
    if [ -n "$WAIT_AT" ] && [ -n "$EXEC_AT" ] && [ "$WAIT_AT" -lt "$EXEC_AT" ]; then ORDER=right; fi
    check "...and the wait comes before the listener is started" [ "$ORDER" = right ]
    check "it keeps the build check" has "$S" 'if [ "$(getprop ro.build.product)" != "$BUILD" ]; then'
    check "it starts the listener with six arguments, the last the star choice" has "$S" '"$DEVICE_NAME" "$KEY_CODE" "$MAX_PRESS_MS" "$COOLDOWN_MS" "$MODE" "$STAR_ACTION"'
}

# ---- what the repository's front page and the stick index tell a reader
# (DOCS_README lets the same checks be pointed at an older README to see them fail)
check_docs() {
    DOCS_README=${DOCS_README:-README.md}
    check "README.md says the project is one HMG-API mod" has "$DOCS_README" "one [HMG-API](https://github.com/Open-HMG/HMG-API) mod"
    check "README.md no longer says HMG-API is not used" has_not "$DOCS_README" "Not used: an [HMG-API]"
    check "README.md tells the user to set the star to Qi pad on/off" has "$DOCS_README" "steering wheel star > **Qi pad on/off**"
    check "README.md links HMG-API at its current home (Open-HMG)" has_not "$DOCS_README" "github.com/VysseCodes/HMG-API"
    check "README.md says to uninstall the old NEMESIS package when moving to the mod" has "$DOCS_README" "NEMESIS Manager > Packages > Qi Pad Star Button > Uninstall"
    check "the stick index lists the mod's stick" has install-sticks/README.txt "hmgapi-qipad-star-$VERSION"
    check "README.md has no working notes at the top" has_not "$DOCS_README" "Picking this up"
    # Nothing in the repository names a person, a private folder or a working session.
    # (The words are put together here so that this file does not match itself.)
    PRIVATE="the own""er|own""er's|aar""on|adc""lo|scratch""pad|one""drive|personal/ev""6|next-sess""ion|hand""over"
    check "no tracked file names a person, a private folder or working notes" sh -c '! git grep -q -i -E "$1" -- . ":!LICENSE"' _ "$PRIVATE"
    check "README.md points to this repository's releases for the download" has "$DOCS_README" "github.com/amc2002/hmgapi-qipad-star/releases/latest"
}

# ---- the build, with a throwaway key
check_build() {
    SDK=$1
    JAR=$(native_path "$SDK/lib/hmgapi-engine.jar")
    BUILD_SH=$HERE/build-hmgapi-mod.sh
    STICK=$ROOT/dist/hmgapi-qipad-star-$VERSION
    ZIP=$STICK/HMGAPI/updates/qipad-star-$VERSION.zip
    T=$(mktemp -d "${TMPDIR:-/tmp}/qipad-star-test.XXXXXX") || { echo "FAIL a work folder under ${TMPDIR:-/tmp}"; FAILS=$((FAILS + 1)); return; }
    trap 'rm -rf "$T" "$STICK" "$ROOT/dist/x.key" "$ROOT/dist/x.key.pub" "$ROOT/$MOD/stray.txt"' EXIT

    check "a throwaway key can be made with the SDK" java -cp "$JAR" hmgapi.engine.Signing keygen "$(native_path "$T/test.key")"

    # the build, run from another folder, with an SDK path that may hold spaces
    OUT=$(cd / && sh "$BUILD_SH" "$SDK" "$T/test.key" 2>&1)
    RC=$?
    check "the build exits 0 when run from /" [ "$RC" -eq 0 ]
    UUID_LINE=$(printf '%s\n' "$OUT" | tail -n 2 | head -n 1)
    STICK_LINE=$(printf '%s\n' "$OUT" | tail -n 1)
    check "its second-to-last line is: UUID <uuid>" expr "$UUID_LINE" : 'UUID [0-9a-f-]\{36\}$'
    check "its last line is: STICK <folder>/hmgapi-qipad-star-$VERSION" expr "$STICK_LINE" : "STICK ..*hmgapi-qipad-star-$VERSION\$"
    UUID=${UUID_LINE#UUID }

    ENTRIES=$(unzip -Z1 "$ZIP" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')
    check "the zip holds exactly: manifest.json, signature, lib/stard.jar, mod.json, svc/stard.sh" [ "$ENTRIES" = "META-HMGAPI/manifest.json META-HMGAPI/signature lib/stard.jar mod.json svc/stard.sh " ]
    check "its entries are sorted, dated 2026-01-01 00:00:00, mode 0644, with no folder entries" "$PY" -c '
import sys, zipfile
i = zipfile.ZipFile(sys.argv[1]).infolist()
names = [x.filename for x in i]
ok = bool(i) and names == sorted(names) and all(
    x.date_time == (2026, 1, 1, 0, 0, 0) and not x.filename.endswith("/") and (x.external_attr >> 16) & 0o777 == 0o644
    for x in i)
sys.exit(0 if ok else 1)' "$(native_path "$ZIP")"
    mkdir "$T/unz"
    unzip -q "$ZIP" -d "$T/unz" 2>/dev/null
    check "mod.json in the zip is byte-identical to the source" cmp "$T/unz/mod.json" "$ROOT/$MOD/mod.json"
    check "svc/stard.sh in the zip is byte-identical to the source" cmp "$T/unz/svc/stard.sh" "$ROOT/$MOD/svc/stard.sh"
    check "lib/stard.jar holds a classes.dex with the listener's star-choice check" "$PY" -c '
import sys, zipfile
dex = zipfile.ZipFile(sys.argv[1]).read("classes.dex")
ok = dex[:4] == b"dex\n" and all(s in dex for s in (b"persist.sys.key.swrccustom", b"pad left alone", b"qipad/star/StarDaemon"))
sys.exit(0 if ok else 1)' "$(native_path "$T/unz/lib/stard.jar")"
    check "the manifest names qipad-star, $VERSION and the printed UUID" "$PY" -c '
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
sys.exit(0 if (m.get("id"), m.get("version"), m.get("uuid")) == ("qipad-star", sys.argv[3], sys.argv[2]) else 1)' "$(native_path "$T/unz/META-HMGAPI/manifest.json")" "$UUID" "$VERSION"
    check "the unzipped package verifies against the printed UUID" java -cp "$JAR" hmgapi.engine.Signing verify "$(native_path "$T/unz")" "$UUID"

    "$PY" "$(native_path "$HERE/make_zip.py")" "$(native_path "$T/unz")" "$(native_path "$T/a.zip")" >/dev/null 2>&1
    "$PY" "$(native_path "$HERE/make_zip.py")" "$(native_path "$T/unz")" "$(native_path "$T/b.zip")" >/dev/null 2>&1
    check "make_zip.py gives the same bytes for the same folder" cmp "$T/a.zip" "$T/b.zip"

    R=$STICK/README.txt
    check "the stick README shows the UUID" has "$R" "$UUID"
    check "the stick README calls the UUID what the app calls it (author key)" has "$R" "author key"
    check "the stick README has the update step (Check USB updates)" has "$R" "Check USB updates"
    check "the stick README names the app's restart button (Restart unit)" has "$R" "Restart unit"
    check "the stick README says to uninstall the old NEMESIS package first" has "$R" "NEMESIS Manager > Packages > Qi Pad Star Button > Uninstall"
    check "the stick README says how to set the star (Qi pad on/off)" has "$R" "steering wheel star > Qi pad on/off"
    FRESH_AT=$(grep -n '^INSTALL$' "$R" | sed 's/:.*//')
    OLD_AT=$(grep -n '^IF THE OLD NEMESIS PACKAGE IS STILL ON THE HEAD UNIT$' "$R" | sed 's/:.*//')
    ORDER=wrong
    if [ -n "$FRESH_AT" ] && [ -n "$OLD_AT" ] && [ "$FRESH_AT" -lt "$OLD_AT" ]; then ORDER=right; fi
    check "the stick README gives the plain install first, the old-package case after it" [ "$ORDER" = right ]
    check "the stick README says where the app shows the listener's log (Mods > Qi Pad Star Button > Log)" has "$R" "HMG-API app > Mods > Qi Pad Star Button, and scroll to Log"
    check "the stick README says the choice does nothing for the head unit's own star" has "$R" "head unit star"

    # HMG-API's own engine, on this machine, reading the stick as the car would
    if [ -n "${HMGAPI_ENGINE_CHECK:-yes}" ]; then
        mkdir "$T/root"
        SCAN=$(HMGAPI_HOST=1 HMGAPI_ROOT="$(native_path "$T/root")" HMGAPI_USB_DIRS="$(native_path "$STICK")" \
            HMGAPI_PRODUCT=$(sed -n 's/^BUILD=//p' "$ROOT/$MOD/svc/stard.sh") \
            java -cp "$JAR" hmgapi.engine.Engine usb-scan 2>&1)
        check "HMG-API's engine reads the stick as an installable mod (status new)" says "$SCAN" '"status": "new"'
        check "...named qipad-star" says "$SCAN" '"id": "qipad-star"'
        SCAN=$(HMGAPI_HOST=1 HMGAPI_ROOT="$(native_path "$T/root")" HMGAPI_USB_DIRS="$(native_path "$STICK")" \
            HMGAPI_PRODUCT=CVEV.USA.0000.V015.012.999999 \
            java -cp "$JAR" hmgapi.engine.Engine usb-scan 2>&1)
        check "...and refuses it on another software build" says "$SCAN" '"status": "refused"'
    fi

    # refusals: exit 1, one plain line, nothing written
    rm -rf "$STICK"
    mkdir -p "$ROOT/dist"
    cp "$T/test.key" "$ROOT/dist/x.key" 2>/dev/null
    cp "$T/test.key.pub" "$ROOT/dist/x.key.pub" 2>/dev/null
    OUT=$(sh "$BUILD_SH" "$SDK" "$ROOT/dist/x.key" 2>&1)
    RC=$?
    check "a key inside the repository is refused: exit 1" [ "$RC" -eq 1 ]
    check "...and the message says 'outside the repository'" says "$OUT" "outside the repository"
    # the same key file, reached through the repository folder's name in capitals
    ALT=$(dirname "$ROOT")/$(basename "$ROOT" | tr '[:lower:]' '[:upper:]')/dist/x.key
    if [ "$ALT" != "$ROOT/dist/x.key" ] && [ -f "$ALT" ]; then   # only where the file system ignores case (Windows, macOS)
        OUT=$(sh "$BUILD_SH" "$SDK" "$ALT" 2>&1)
        RC=$?
        check "a key inside the repository, its path typed in another case, is refused: exit 1" [ "$RC" -eq 1 ]
        check "...and the message says 'outside the repository'" says "$OUT" "outside the repository"
    fi
    rm -f "$ROOT/dist/x.key" "$ROOT/dist/x.key.pub"

    echo "not part of the mod" > "$ROOT/$MOD/stray.txt"
    OUT=$(sh "$BUILD_SH" "$SDK" "$T/test.key" 2>&1)
    RC=$?
    rm -f "$ROOT/$MOD/stray.txt"
    check "a file that is not part of the mod, left in the mod folder, is refused: exit 1" [ "$RC" -eq 1 ]
    check "...and the message names the file" says "$OUT" "stray.txt"

    OUT=$(sh "$BUILD_SH" "$SDK" "$T/nope.key" 2>&1)
    RC=$?
    check "a key that does not exist is refused: exit 1" [ "$RC" -eq 1 ]
    check "...and the message says 'no key at'" says "$OUT" "no key at"

    cp "$T/test.key" "$T/alone.key"
    OUT=$(sh "$BUILD_SH" "$SDK" "$T/alone.key" 2>&1)
    RC=$?
    check "a key without its .pub file is refused: exit 1" [ "$RC" -eq 1 ]
    check "...and the message says 'no public key at'" says "$OUT" "no public key at"

    mkdir "$T/emptysdk"
    OUT=$(sh "$BUILD_SH" "$T/emptysdk" "$T/test.key" 2>&1)
    RC=$?
    check "a folder that is not the SDK is refused: exit 1" [ "$RC" -eq 1 ]
    check "...and the message names lib/hmgapi-engine.jar" says "$OUT" "lib/hmgapi-engine.jar"

    OUT=$(DX_JAR="$T/no-dx.jar" sh "$BUILD_SH" "$SDK" "$T/test.key" 2>&1)
    RC=$?
    check "a missing dalvik-dx.jar is refused: exit 1" [ "$RC" -eq 1 ]
    check "...and the message names dalvik-dx" says "$OUT" "dalvik-dx"

    check "no refused build wrote a stick folder" [ ! -e "$STICK" ]
    check "the build left no work folder behind" [ ! -e "$ROOT/dist/.work" ]
}

check_listener
check_mod_json
check_script
check_docs
[ $# -ge 1 ] && check_build "$1"

if [ "$FAILS" -eq 0 ]; then echo "ALL OK"; exit 0; fi
echo "FAILED"
exit 1
