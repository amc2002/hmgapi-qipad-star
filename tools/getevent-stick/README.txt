EV6 Qi pad GETEVENT stick (read-only)

Checks that the head unit's own getevent tool passes button presses
through straight away. The approved design depends on it. It listens to
the buttons for 20 seconds and writes what it saw to the drive. It sends
nothing to the car and changes nothing.

ON THE COMPUTER
1. On the USB drive, move off any NEMESIS.data, NEMESIS.sh, README.txt
   and launchpad-port folder from earlier runs. Only one NEMESIS.data
   may be at the root.
2. Copy NEMESIS.data and qi-getevent.sh from this folder to the ROOT of
   the drive.
3. Eject.

IN THE CAR
1. Park, car on, screen up. The wheel star stays set to None.
2. Insert the drive in the data USB port. Tap Yes within 60 seconds.
3. Right after Yes, count to five, then press the STEERING WHEEL star
   three times, short presses, about three seconds apart. No long press.
4. Leave the drive in until the success dialog (about 25 seconds after Yes).
5. Pull the drive.

WHAT COMES BACK
A folder qi-getevent-<date-time> with:
- RESULT-streaming-OK.txt or RESULT-buffered-or-no-presses.txt
- qi-getevent.log, growth.txt and getevent-output.txt
Send all of the text files. None of them contain positions.
