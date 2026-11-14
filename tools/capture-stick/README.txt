EV6 Qi pad capture stick (read-only)

WHAT THIS DOES
Records what the head unit does when you switch the wireless phone charger
on and off in its menu. It installs nothing, changes nothing, and sends no
command to the car. It writes one folder to this USB drive.

ON THE COMPUTER
1. Use an empty FAT32 or exFAT USB drive (or move everything else off it).
2. Copy NEMESIS.data and NEMESIS.sh to the ROOT of the drive. Nothing else
   from any other NEMESIS kit may be on the drive.
3. Eject the drive.

IN THE CAR
1. Park. Car on. Wait for the screen to finish starting.
2. Open the setting first so it is one tap away:
   Setup > Vehicle > Convenience > Wireless Charging System (name may differ
   slightly on your screen). Note whether it is currently on or off.
3. Insert the drive in the data USB port (the wired Android Auto port).
4. Tap Yes on the NEMESIS prompt within 60 seconds.
5. Count to five. Then: switch the setting OFF, count to five,
   switch it ON, count to five, switch it OFF. Leave it OFF.
6. Wait for the success dialog (about 60 seconds after Yes).
7. Remove the drive. A drive left in that port can start wired Android Auto.

WHAT COMES BACK
A folder named qi-capture-<date-time> holding:
  qi-capture.log            what the script did, step by step
  report.txt                software version, service list, file lists
  logcat-main-system.txt    the head unit log for the capture window
  logcat-events.txt         the events log for the same window
  automotive.odex, automotive-service.odex, and any *Setting*/*Vehicle* app
                            files: Kia firmware files, for the lookup only

KEEP PRIVATE
The .odex files are Kia firmware. They stay on your drive. Do not post them
in an issue, a forum, or a chat.

IF IT FAILS
A failure dialog means the script exited with an error. Keep the folder and
qi-capture.log. If no prompt appears at all, unplug, wait, and reinsert.
