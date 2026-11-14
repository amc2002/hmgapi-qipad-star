#!/system/bin/sh
# Qi pad GETEVENT test (read-only). Checks the one thing the approved design
# (docs/design.md, option A) still assumes: that Android's own getevent tool is on this
# head unit and hands over each key event as it happens, rather than holding them back
# in a buffer. Listens on the main input device for 20 seconds while the steering wheel
# star is pressed, and records once a second how much getevent has written.
# Sends nothing to the car and changes nothing; it only writes to the stick.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib

TARGET_NAME=daudio_wp_daudioplus_cvev_us
WINDOW=20

USBROOT=${0%/*}
case "$USBROOT" in /*) ;; *) USBROOT=$(pwd) ;; esac
case "$USBROOT" in
    /storage/usb*|/mnt/media_rw/usb*) ;;
    *) echo "refusing: script is not running from a USB volume ($USBROOT)"; exit 1 ;;
esac

STAMP=$(date '+%Y%m%d-%H%M%S')
OUT=$USBROOT/qi-getevent-$STAMP
LOG=$OUT/qi-getevent.log
RAW=$OUT/getevent-output.txt
GROWTH=$OUT/growth.txt
mkdir -p "$OUT" || exit 1
[ -d "$OUT" ] || exit 1

say() {
    LINE="$(date '+%Y-%m-%d %H:%M:%S') $*"
    echo "$LINE"
    echo "$LINE" >> "$LOG"
}
fail() { say "FAIL: $*"; echo "$*" > "$OUT/RESULT-FAILED.txt"; sync 2>/dev/null; exit 1; }

say "==== qi-getevent start (USB root $USBROOT, Android up: $(getprop sys.boot_completed), software $(getprop ro.build.product))"

# 1. Is getevent there?
GE=""
for P in /system/bin/getevent /system/xbin/getevent; do
    [ -e "$P" ] && { GE=$P; break; }
done
[ -n "$GE" ] || fail "getevent not found in /system/bin or /system/xbin"
say "getevent: $(ls -l "$GE" 2>&1)"

# 2. Which event node is the main input device? Found by name, as the service will do.
DEV=""
NAME=""
while read LINE; do
    case "$LINE" in
        'N: Name="'*)
            NAME=${LINE#N: Name=\"}
            NAME=${NAME%\"}
            ;;
        'H: Handlers='*)
            if [ "$NAME" = "$TARGET_NAME" ]; then
                for W in ${LINE#H: Handlers=}; do
                    case "$W" in event*) DEV=/dev/input/$W ;; esac
                done
            fi
            ;;
    esac
done < /proc/bus/input/devices
[ -n "$DEV" ] || fail "input device $TARGET_NAME not found"
say "input device: $TARGET_NAME is $DEV"

# 3. Listen for WINDOW seconds. getevent writes to a file on the stick; once a second
# the script notes the file size. If the size rises right after each press, getevent
# passes events through straight away. If it stays at 0, it holds them in a buffer.
: > "$RAW"
"$GE" -t "$DEV" > "$RAW" 2> "$OUT/getevent-errors.txt" &
GPID=$!
say "listening (pid $GPID) for $WINDOW seconds: press the steering wheel star now"
N=0
while [ $N -lt $WINDOW ]; do
    sleep 1
    N=$((N + 1))
    read UP REST < /proc/uptime
    LS=$(ls -l "$RAW" 2>/dev/null)
    set -- $LS
    echo "second=$N uptime=$UP bytes=$4" >> "$GROWTH"
done
kill "$GPID" 2>/dev/null
sleep 1
say "stopped listening"

# 4. Verdict.
LS=$(ls -l "$RAW" 2>/dev/null)
set -- $LS
BYTES=$4
say "getevent wrote $BYTES bytes"
FIRST_GROWTH=""
while read S U B; do
    B=${B#bytes=}
    case "$B" in ''|0) ;; *) [ -z "$FIRST_GROWTH" ] && FIRST_GROWTH=${S#second=} ;; esac
done < "$GROWTH"

sync 2>/dev/null
case "$BYTES" in
    ''|0)
        echo "getevent wrote nothing during the window" > "$OUT/RESULT-buffered-or-no-presses.txt"
        say "RESULT: nothing written. Either getevent buffers its output, or no press arrived."
        ;;
    *)
        echo "first output after second $FIRST_GROWTH, $BYTES bytes in total" > "$OUT/RESULT-streaming-OK.txt"
        say "RESULT: getevent output arrived while listening (first at second $FIRST_GROWTH)."
        ;;
esac
say "DONE"
exit 0
