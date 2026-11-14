#!/system/bin/sh
# Qi pad capture, read-only. Clears the head unit log, waits while you flip the
# wireless charging setting in the car menu, then saves the log and copies the
# framework files needed to find the method behind that setting.
# Nothing is installed, /system is never remounted, no vehicle command is sent.
# NEMESIS runs this as root with cwd = USB root. KitKat toolbox only: no grep/awk.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib

WAIT=50          # seconds you have to flip the setting off / on / off
LEAD=5           # seconds after the dialog closes before the log is cleared

USBROOT=${0%/*}
case "$USBROOT" in /*) ;; *) USBROOT=$(pwd) ;; esac
# Only ever write to the stick. Never fall back to internal storage.
case "$USBROOT" in
    /storage/usb*|/mnt/media_rw/usb*) ;;
    *) echo "refusing: script is not running from a USB volume ($USBROOT)"; exit 1 ;;
esac

STAMP=$(date '+%Y%m%d-%H%M%S')
OUT=$USBROOT/qi-capture-$STAMP
LOG=$OUT/qi-capture.log
mkdir -p "$OUT" || exit 1
[ -d "$OUT" ] || exit 1

say() {
    LINE="$(date '+%Y-%m-%d %H:%M:%S') $*"
    echo "$LINE"
    echo "$LINE" >> "$LOG"
}

# copy_file SRC DST : byte copy with cat, verified with cmp (toolbox cmp has no -s).
copy_file() {
    if [ ! -f "$1" ]; then say "skip: $1 not present"; return 0; fi
    if cat "$1" > "$2" 2>/dev/null && cmp "$1" "$2" >/dev/null 2>&1; then
        say "ok: copied $1 -> $2"
        md5 "$2" >> "$OUT/md5sums.txt" 2>/dev/null
        return 0
    fi
    say "FAIL: copy of $1 did not verify"
    FAILED=1
    return 1
}

FAILED=0
say "==== qi-capture start (USB root $USBROOT, Android up: $(getprop sys.boot_completed))"

# 1. Identity and inventory (no serials, VIN or location).
REPORT=$OUT/report.txt
{
    echo "# qi-capture report $STAMP"
    echo "software=$(getprop ro.build.product)"
    echo "device=$(getprop ro.product.device)"
    echo "sdk=$(getprop ro.build.version.sdk)"
    echo "incremental=$(getprop ro.build.version.incremental)"
    echo
    echo "[services]"
    service list 2>&1
    echo
    echo "[framework]"
    ls -l /system/framework 2>&1
    echo
    echo "[apps]"
    ls -l /system/app 2>&1
    echo
    echo "[input devices]"
    cat /proc/bus/input/devices 2>&1
} > "$REPORT" 2>&1
say "wrote $REPORT"

# 2. The capture window.
sleep "$LEAD"
logcat -c -b main -b system 2>/dev/null || logcat -c 2>/dev/null
say "log cleared; flip the wireless charging setting now (off, on, off), $WAIT seconds"
sleep "$WAIT"
if logcat -d -v time -b main -b system > "$OUT/logcat-main-system.txt" 2>"$OUT/logcat-stderr.txt"; then
    say "saved logcat-main-system.txt ($(ls -l "$OUT/logcat-main-system.txt"))"
else
    say "two-buffer dump failed; saving the main buffer only"
    logcat -d -v time > "$OUT/logcat-main.txt" 2>>"$OUT/logcat-stderr.txt"
    say "saved logcat-main.txt ($(ls -l "$OUT/logcat-main.txt"))"
fi
logcat -d -v time -b events > "$OUT/logcat-events.txt" 2>/dev/null
say "capture window closed"

# 3. Framework files for the transaction-number lookup, and any settings app odex.
copy_file /system/framework/automotive.odex "$OUT/automotive.odex"
copy_file /system/framework/automotive-service.odex "$OUT/automotive-service.odex"
for F in /system/app/*.odex; do
    case "$F" in
        *Setting*|*setting*|*Vehicle*|*vehicle*) copy_file "$F" "$OUT/${F##*/}" ;;
    esac
done

sync 2>/dev/null
if [ "$FAILED" = 0 ]; then
    say "DONE -> $OUT  (remove the USB drive now)"
    exit 0
fi
say "FINISHED WITH ERRORS -> $OUT  (keep everything; remove the USB drive)"
exit 1
