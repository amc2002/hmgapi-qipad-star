#!/system/bin/sh
# Service "stard" of the HMG-API mod qipad-star: starts the star button listener.
# HMG-API (hmgapid) runs this as root once Android is up, restarts it if it stops and
# stops it when the mod is turned off. Output goes to /data/hmgapi/logs/qipad-star/stard.log.
HERE=${HMGAPI_MOD_DIR:-/data/hmgapi/mods/qipad-star}
BUILD=CVEV.USA.0000.V015.012.260507
DEVICE_NAME=daudio_wp_daudioplus_cvev_us
KEY_CODE=43
MAX_PRESS_MS=800
COOLDOWN_MS=2000
MODE=live
# The pad is switched only while the wheel star (Setup > Button) is set to this choice:
# "Qi pad on/off", which this mod adds (hmgapi.star.<mod id>.<entry id>).
STAR_ACTION=hmgapi.star.qipad-star.toggle
# The listener of the old NEMESIS package qipad.star (versions up to 1.0).
OLD_JAR=/data/nemesis/apps/qipad.star/lib/stard.jar

export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

# The transaction numbers are only verified for this build. On any other, stay idle
# (not exit, so it is not started again and again).
if [ "$(getprop ro.build.product)" != "$BUILD" ]; then
    log "head unit build is $(getprop ro.build.product), not $BUILD: not starting"
    while true; do sleep 3600; done
fi

while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 2; done
N=0
while true; do
    case "$(service check com.hkmc.micom.usm 2>&1)" in
        *": found"*) break ;;
    esac
    N=$((N + 1))
    [ $N = 1 ] && log "waiting for com.hkmc.micom.usm"
    sleep 2
done

# The old NEMESIS package has a listener of its own, which switches the pad on every press.
# Next to this one a press could switch the pad twice. Wait until it has been uninstalled.
N=0
while [ -e "$OLD_JAR" ]; do
    N=$((N + 1))
    [ $N = 1 ] && log "the old NEMESIS package qipad.star is still installed: uninstall Qi Pad Star Button in NEMESIS Manager > Packages. Not listening until it is gone"
    sleep 10
done
[ $N -gt 0 ] && log "the old NEMESIS package is gone"

# app_process needs the boot class path, in case the service did not inherit it.
if [ -z "$BOOTCLASSPATH" ] && [ -r /init.environ.rc ]; then
    while read CMD NAME VALUE; do
        [ "$CMD" = export ] && export "$NAME=$VALUE"
    done < /init.environ.rc
fi

export CLASSPATH=$HERE/lib/stard.jar
exec app_process /system/bin --nice-name=qipad-stard qipad.star.StarDaemon \
    "$DEVICE_NAME" "$KEY_CODE" "$MAX_PRESS_MS" "$COOLDOWN_MS" "$MODE" "$STAR_ACTION"
