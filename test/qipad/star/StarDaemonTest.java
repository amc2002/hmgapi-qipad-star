package qipad.star;

/**
 * Checks for StarDaemon's decision about the saved star choice. A plain main with no test
 * library, run by tools/make-package/test.sh. It lives outside src/ so it is never packaged.
 */
public final class StarDaemonTest {

    private static int fails = 0;

    private StarDaemonTest() {}

    private static void check(String name, boolean cond) {
        System.out.println((cond ? "ok   " : "FAIL ") + name);
        if (!cond) fails++;
    }

    public static void main(String[] args) {
        final String w = "hmgapi.star.qipad-star.toggle";

        check("the mod's choice is ours", StarDaemon.isOurChoice(w, w));
        check("...also with the newline getprop adds", StarDaemon.isOurChoice(w + "\n", w));
        check("...also with CR LF", StarDaemon.isOurChoice(w + "\r\n", w));
        check("...also with spaces around it", StarDaemon.isOurChoice("  " + w + " ", w));

        check("an empty value is not ours", !StarDaemon.isOurChoice("", w));
        check("a missing value (null) is not ours", !StarDaemon.isOurChoice(null, w));
        check("None (the stock action) is not ours",
                !StarDaemon.isOurChoice("com.mobis.intent.action.SWRC_CUSTOM_SHORTCUT", w));
        check("another HMG-API choice is not ours", !StarDaemon.isOurChoice("hmgapi.star.hmgapi.open", w));
        check("a longer value that starts with ours is not ours", !StarDaemon.isOurChoice(w + "2", w));
        check("a shorter value is not ours", !StarDaemon.isOurChoice("hmgapi.star.qipad-star", w));
        check("the same letters in capitals are not ours", !StarDaemon.isOurChoice(w.toUpperCase(), w));
        check("a failed getprop is not ours", !StarDaemon.isOurChoice("error: java.io.IOException: x", w));

        check("with no wanted choice given, our value is not ours", !StarDaemon.isOurChoice(w, ""));
        check("...and an empty value is not ours either", !StarDaemon.isOurChoice("", ""));
        check("...and the same for a missing wanted choice (null)", !StarDaemon.isOurChoice(w, null));

        System.exit(fails == 0 ? 0 : 1);
    }
}
