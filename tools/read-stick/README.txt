EV6 Qi pad READ stick (read-only)

Asks the car's settings service for the current value of the wireless
charging setting and writes the answer to the drive. It changes nothing.

ON THE COMPUTER
1. On the USB drive, delete the old NEMESIS.data and NEMESIS.sh.
   (The qi-capture folders can stay.)
2. Copy NEMESIS.data and qi-read.sh from this folder to the ROOT of the drive.
3. Eject.

IN THE CAR
1. Park, car on, screen up. Open the wireless charging setting and note
   whether it shows ON or OFF. Do not change it.
2. Insert the drive in the data USB port. Tap Yes within 60 seconds.
3. Wait for the success dialog (a few seconds).
4. Pull the drive. Then the car can go off.

WHAT COMES BACK
A folder qi-read-<date-time> with qi-read.log and a file named
RESULT-front-pad-value-1.txt or RESULT-front-pad-value-2.txt.
Note that number and what the screen showed. Together they settle which value
means ON.
