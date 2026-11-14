EV6 Qi pad WRITE test stick (one write)

Sends ONE write: the same call the car's own settings screen sends when you
tap the wireless charging toggle. Reads the value first, writes the other
value once, reads it back, and saves a short head unit log. It leaves the
pad in the new state (ON if it was OFF) so you can see the change and then
switch it back by hand in the menu.

Values on this car: 1 = off, 2 = on (confirmed with the read stick).

ON THE COMPUTER
1. On the USB drive, delete NEMESIS.data and qi-read.sh.
2. Copy NEMESIS.data and qi-write.sh from this folder to the ROOT of the drive.
3. Eject.

IN THE CAR
1. Park, car on, screen up. Open the wireless charging setting. It should
   show OFF. Keep that screen open.
2. Insert the drive in the data USB port. Tap Yes within 60 seconds.
3. Watch the toggle. Within a few seconds it should show ON. If the screen
   does not change by itself, back out one level and reopen the setting.
4. Wait for the success dialog (about 5 seconds).
5. Pull the drive.
6. Switch the pad OFF again by hand in the menu, the normal way.

WHAT COMES BACK
A folder qi-write-<date-time> with qi-write.log, logcat-around-write.txt,
and RESULT-write-OK-now-2.txt (or MISMATCH / FAILED). Keep the folder,
and note what the screen did.

IF IT FAILS
The script sends nothing unless the build matches and the first read
answers 1 or 2. A FAILED file names the reason. A MISMATCH means the write
was accepted but the read-back did not change; the folder's log shows what was read.
