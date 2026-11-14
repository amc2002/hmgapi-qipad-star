#!/system/bin/sh
# Qi pad READ check, read-only. Asks the user-settings service for the current value
# of the front wireless charging setting (getter 465) and the rear one (466), twice,
# and writes the answers to this USB drive. It sends no write to any service.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib

USBROOT=${0%/*}
case "$USBROOT" in /*) ;; *) USBROOT=$(pwd) ;; esac
case "$USBROOT" in
    /storage/usb*|/mnt/media_rw/usb*) ;;
    *) echo "refusing: script is not running from a USB volume ($USBROOT)"; exit 1 ;;
esac

STAMP=$(date '+%Y%m%d-%H%M%S')
OUT=$USBROOT/qi-read-$STAMP
LOG=$OUT/qi-read.log
mkdir -p "$OUT" || exit 1
[ -d "$OUT" ] || exit 1

say() {
    LINE="$(date '+%Y-%m-%d %H:%M:%S') $*"
    echo "$LINE"
    echo "$LINE" >> "$LOG"
}

# decode RAW -> sets VALUE to 1, 2, or "unknown"
decode() {
    case "$1" in
        *"Parcel(00000000 00000001"*) VALUE=1 ;;
        *"Parcel(00000000 00000002"*) VALUE=2 ;;
        *"Parcel(00000000 000000fa"*) VALUE=250 ;;
        *) VALUE=unknown ;;
    esac
}

say "==== qi-read start (USB root $USBROOT, Android up: $(getprop sys.boot_completed), software $(getprop ro.build.product))"
[ "$(getprop ro.build.product)" = CVEV.USA.0000.V015.012.260507 ] || { say "refusing: not the build these codes were read from"; exit 1; }

FRONT=unknown
N=1
while [ $N -le 2 ]; do
    RAW=$(service call com.hkmc.micom.usm 465 2>&1)
    decode "$RAW"; FRONT=$VALUE
    say "read $N front (getter 465): value=$FRONT raw: $RAW"
    RAW=$(service call com.hkmc.micom.usm 466 2>&1)
    decode "$RAW"
    say "read $N rear  (getter 466): value=$VALUE raw: $RAW"
    N=$((N + 1))
    [ $N -le 2 ] && sleep 2
done

echo "front pad getter value = $FRONT" > "$OUT/RESULT-front-pad-value-$FRONT.txt"
say "DONE -> $OUT (front pad value $FRONT). Note what the screen shows for the pad setting right now."
sync 2>/dev/null
[ "$FRONT" = unknown ] && exit 1
exit 0
