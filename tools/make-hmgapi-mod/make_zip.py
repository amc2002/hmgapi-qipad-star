#!/usr/bin/env python3
"""Zip a folder the same way every time.

    python make_zip.py <folder> <out zip>

Every file under <folder> goes in, named relative to it with "/", sorted by byte order,
with no folder entries, each dated 2026-01-01 00:00:00 with mode 0644, deflated. The same
folder gives the same bytes. This stands in for the zip command, which HMG-API's own
bin/mkmodpkg.sh uses and Git Bash on Windows does not have.
"""
import os
import sys
import zipfile


def main(argv):
    if len(argv) != 3:
        sys.stderr.write("usage: make_zip.py <folder> <out zip>\n")
        return 2
    folder, out = argv[1], argv[2]
    files = []
    for base, _dirs, names in os.walk(folder):
        for name in names:
            full = os.path.join(base, name)
            files.append((os.path.relpath(full, folder).replace(os.sep, "/"), full))
    if not files:
        sys.stderr.write("make_zip.py: no files under %s\n" % folder)
        return 1
    files.sort(key=lambda f: f[0].encode("utf-8"))
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for rel, full in files:
            info = zipfile.ZipInfo(rel, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3  # Unix on every machine, so the mode below is read as one
            info.external_attr = 0o100644 << 16
            with open(full, "rb") as fh:
                z.writestr(info, fh.read())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
