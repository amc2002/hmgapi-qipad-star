package qipad.star;

import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.FileInputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.text.SimpleDateFormat;
import java.util.Date;

/**
 * Steering wheel star button -> front wireless charging pad toggle.
 *
 * Runs as root through app_process, started by svc/stard.sh. Reads raw key events from one
 * input device (read-only: Android and the car still receive every press). On a short press
 * of the configured key it first reads the car's saved wheel star choice (Setup > Button) and
 * goes on only if that is STAR_ACTION, the "Qi pad on/off" choice the HMG-API mod qipad-star
 * adds. Then it reads the pad with getter 465 and, in live mode, writes the other value with
 * setter 130 on com.hkmc.micom.usm, then reads it back. In dry mode it only logs what it
 * would write. With any other star choice the pad is left alone.
 *
 * Arguments: DEVICE_NAME KEY_CODE MAX_PRESS_MS COOLDOWN_MS MODE(dry|live) STAR_ACTION
 *
 * Written for this project from the Linux input_event layout; no code taken from elsewhere.
 */
public final class StarDaemon {

    // struct input_event on 32-bit ARM: tv_sec(4) tv_usec(4) type(2) code(2) value(4)
    private static final int EVENT_SIZE = 16;
    private static final int EV_KEY = 1;

    private static final String SERVICE = "com.hkmc.micom.usm";
    private static final String GETTER = "465";
    private static final String SETTER = "130";
    private static final String SERVICE_BIN = "/system/bin/service";

    // Where the car keeps the wheel star's choice from Setup > Button (HMG-API reads and sets
    // the same property). Read with getprop from the PATH svc/stard.sh sets.
    private static final String STAR_PROP = "persist.sys.key.swrccustom";
    private static final String GETPROP = "getprop";

    private static final SimpleDateFormat STAMP = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

    private StarDaemon() {}

    public static void main(String[] args) {
        if (args.length != 6) {
            log("usage: DEVICE_NAME KEY_CODE MAX_PRESS_MS COOLDOWN_MS dry|live STAR_ACTION");
            System.exit(2);
        }
        String deviceName = args[0];
        int keyCode = Integer.parseInt(args[1]);
        long maxPressMs = Long.parseLong(args[2]);
        long cooldownMs = Long.parseLong(args[3]);
        boolean live = "live".equals(args[4]);
        String starAction = args[5];

        String path = findDevice(deviceName);
        if (path == null) {
            log("input device not found: " + deviceName);
            System.exit(3);
        }
        log("start: " + deviceName + " = " + path + ", key " + keyCode + ", short press under "
                + maxPressMs + " ms, pause " + cooldownMs + " ms, "
                + (live ? "LIVE (writes)" : "DRY RUN (no writes)")
                + ", only while the wheel star is set to " + starAction);

        try {
            listen(path, keyCode, maxPressMs, cooldownMs, live, starAction);
        } catch (IOException e) {
            log("input read failed: " + e);
            System.exit(4);
        }
    }

    private static void listen(String path, int keyCode, long maxPressMs, long cooldownMs,
            boolean live, String starAction) throws IOException {
        DataInputStream in = new DataInputStream(new FileInputStream(path));
        byte[] ev = new byte[EVENT_SIZE];
        long downAt = -1;
        long lastAction = Long.MIN_VALUE / 2;
        while (true) {
            in.readFully(ev);
            if (u16(ev, 8) != EV_KEY || u16(ev, 10) != keyCode) continue;
            int value = s32(ev, 12);
            long t = u32(ev, 0) * 1000L + u32(ev, 4) / 1000L;
            if (value == 1) {
                downAt = t;
            } else if (value == 0) {
                if (downAt < 0) continue;
                long held = t - downAt;
                downAt = -1;
                if (held < 0 || held > maxPressMs) {
                    log("hold of " + held + " ms ignored");
                    continue;
                }
                // Asked at every press, so a change in Setup > Button counts from the next one.
                String saved = run(GETPROP, STAR_PROP);
                if (!isOurChoice(saved, starAction)) {
                    log("press (" + held + " ms): wheel star is set to \"" + oneLine(saved)
                            + "\", not Qi pad on/off; pad left alone");
                    continue;
                }
                if (t - lastAction < cooldownMs) {
                    log("press ignored (within " + cooldownMs + " ms of the last one)");
                    continue;
                }
                lastAction = t;
                toggle(held, live);
            }
            // value 2 (autorepeat) is ignored.
        }
    }

    private static void toggle(long held, boolean live) {
        String raw = run(SERVICE_BIN, "call", SERVICE, GETTER);
        int before = decode(raw);
        if (before != 1 && before != 2) {
            log("press (" + held + " ms): pad read gave no 1 or 2, nothing written. raw: " + oneLine(raw));
            return;
        }
        int target = before == 1 ? 2 : 1;
        if (!live) {
            log("press (" + held + " ms): pad is " + name(before) + ", would write " + target
                    + " (" + name(target) + "). DRY RUN, nothing written");
            return;
        }
        String reply = run(SERVICE_BIN, "call", SERVICE, SETTER, "i32", Integer.toString(target));
        // The getter reports the new value only after the car has confirmed it (seen on the
        // car: an immediate read still shows the old value). Re-read for up to 3 seconds.
        int after = -1;
        long waited = 0;
        for (int i = 0; i < 12; i++) {
            sleep(250);
            waited += 250;
            after = decode(run(SERVICE_BIN, "call", SERVICE, GETTER));
            if (after == target) break;
        }
        log("press (" + held + " ms): pad " + name(before) + " -> wrote " + target + " -> reads "
                + name(after) + " after " + waited + " ms" + (after == target ? "" : "  MISMATCH")
                + ". reply: " + oneLine(reply));
    }

    /**
     * True only when the car's saved wheel star choice is exactly the wanted one (white space
     * around it aside). Anything else, including no value and a failed read, is not ours.
     */
    static boolean isOurChoice(String saved, String wanted) {
        if (saved == null || wanted == null || wanted.isEmpty()) return false;
        return saved.trim().equals(wanted);
    }

    /** 1 or 2 from "Parcel(00000000 0000000N ...", otherwise -1. */
    static int decode(String raw) {
        if (raw == null) return -1;
        if (raw.indexOf("Parcel(00000000 00000001") >= 0) return 1;
        if (raw.indexOf("Parcel(00000000 00000002") >= 0) return 2;
        return -1;
    }

    private static String name(int v) {
        return v == 1 ? "OFF(1)" : v == 2 ? "ON(2)" : "?(" + v + ")";
    }

    /** Event node of the input device with this exact name, from /proc/bus/input/devices. */
    static String findDevice(String wanted) {
        BufferedReader r = null;
        try {
            r = new BufferedReader(new FileReader("/proc/bus/input/devices"));
            String name = null;
            String line;
            while ((line = r.readLine()) != null) {
                if (line.startsWith("N: Name=\"")) {
                    name = line.substring(9, line.length() - 1);
                } else if (line.startsWith("H: Handlers=") && wanted.equals(name)) {
                    for (String w : line.substring(12).trim().split("\\s+")) {
                        if (w.startsWith("event")) return "/dev/input/" + w;
                    }
                }
            }
        } catch (IOException e) {
            log("cannot read input device list: " + e);
        } finally {
            if (r != null) try { r.close(); } catch (IOException ignored) { }
        }
        return null;
    }

    private static String run(String... cmd) {
        Process p = null;
        try {
            p = Runtime.getRuntime().exec(cmd);
            p.getOutputStream().close();
            String out = readAll(p.getInputStream());
            readAll(p.getErrorStream());
            p.waitFor();
            return out;
        } catch (Exception e) {
            return "error: " + e;
        } finally {
            if (p != null) p.destroy();
        }
    }

    private static String readAll(InputStream in) throws IOException {
        StringBuilder sb = new StringBuilder();
        byte[] buf = new byte[512];
        int n;
        while ((n = in.read(buf)) > 0) sb.append(new String(buf, 0, n, "UTF-8"));
        in.close();
        return sb.toString();
    }

    private static void sleep(long ms) {
        try { Thread.sleep(ms); } catch (InterruptedException ignored) { }
    }

    private static String oneLine(String s) {
        return s == null ? "" : s.replace('\n', ' ').replace('\r', ' ').trim();
    }

    static int u16(byte[] b, int o) {
        return (b[o] & 0xff) | (b[o + 1] & 0xff) << 8;
    }

    static int s32(byte[] b, int o) {
        return (b[o] & 0xff) | (b[o + 1] & 0xff) << 8 | (b[o + 2] & 0xff) << 16 | b[o + 3] << 24;
    }

    static long u32(byte[] b, int o) {
        return s32(b, o) & 0xffffffffL;
    }

    static synchronized void log(String msg) {
        System.out.println(STAMP.format(new Date()) + " " + msg);
        System.out.flush();
    }
}
