#!/system/bin/sh
# Qi pad WRITE test: exactly ONE write. Reads the front pad value (getter 465); if it is
# 1 (off) or 2 (on), writes the other value once with setter 130, reads it back, and
# saves a short head unit log around the write. Leaves the pad in the new state so you
# can confirm it on the screen and switch it back by hand in the menu.
# Confirmed on this car before this script existed: getter 465 answers 1 while the
# screen shows OFF; the settings screen itself sends 130 with 1 or 2.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib

USBROOT=${0%/*}
case "$USBROOT" in /*) ;; *) USBROOT=$(pwd) ;; esac
case "$USBROOT" in
    /storage/usb*|/mnt/media_rw/usb*) ;;
    *) echo "refusing: script is not running from a USB volume ($USBROOT)"; exit 1 ;;
esac

STAMP=$(date '+%Y%m%d-%H%M%S')
OUT=$USBROOT/qi-write-$STAMP
LOG=$OUT/qi-write.log
mkdir -p "$OUT" || exit 1
[ -d "$OUT" ] || exit 1

say() {
    LINE="$(date '+%Y-%m-%d %H:%M:%S') $*"
    echo "$LINE"
    echo "$LINE" >> "$LOG"
}
fail() { say "FAIL: $*"; echo "$*" > "$OUT/RESULT-write-FAILED.txt"; sync 2>/dev/null; exit 1; }

decode() {
    case "$1" in
        *"Parcel(00000000 00000001"*) VALUE=1 ;;
        *"Parcel(00000000 00000002"*) VALUE=2 ;;
        *) VALUE=unknown ;;
    esac
}
read_front() {
    RAW=$(service call com.hkmc.micom.usm 465 2>&1)
    decode "$RAW"
}

say "==== qi-write start (USB root $USBROOT, Android up: $(getprop sys.boot_completed), software $(getprop ro.build.product))"
[ "$(getprop ro.build.product)" = CVEV.USA.0000.V015.012.260507 ] || fail "not the build these codes were read from; nothing sent"
[ "$(getprop sys.boot_completed)" = 1 ] || fail "Android not up; nothing sent"

# 1. Read first.
read_front; V0=$VALUE
say "before: front pad getter 465 = $V0 (raw: $RAW)"
case "$V0" in
    1) TARGET=2 ;;
    2) TARGET=1 ;;
    *) fail "getter did not answer 1 or 2; nothing sent" ;;
esac

# 2. One write, with a short log window around it.
logcat -c -b main -b system 2>/dev/null || logcat -c 2>/dev/null
say "writing: service call com.hkmc.micom.usm 130 i32 $TARGET"
WRAW=$(service call com.hkmc.micom.usm 130 i32 "$TARGET" 2>&1)
say "write reply: $WRAW"
sleep 2
logcat -d -v time -b main -b system > "$OUT/logcat-around-write.txt" 2>/dev/null || logcat -d -v time > "$OUT/logcat-around-write.txt" 2>/dev/null

# 3. Read back.
read_front; V1=$VALUE
say "after:  front pad getter 465 = $V1 (raw: $RAW)"
case "$WRAW" in *"Parcel(00000000"*) ;; *) fail "write reply was not a clean parcel (value now $V1)" ;; esac

sync 2>/dev/null
if [ "$V1" = "$TARGET" ]; then
    echo "before=$V0 wrote=$TARGET after=$V1" > "$OUT/RESULT-write-OK-now-$V1.txt"
    say "DONE: pad value went $V0 -> $V1. Check the screen, then switch it back by hand in the menu."
    exit 0
fi
echo "before=$V0 wrote=$TARGET after=$V1" > "$OUT/RESULT-write-MISMATCH-now-$V1.txt"
say "MISMATCH: wrote $TARGET but getter reads $V1. Nothing else sent."
exit 1
