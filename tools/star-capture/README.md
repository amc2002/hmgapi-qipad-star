# Star button capture

Uses Launchpad's read-only vehicle porting kit, which is not included here (Launchpad
has no license file). Download `Launchpad-port-kit-usb.zip` from the Precondition
releases at https://github.com/paytondevs/gen5w-preconditioning/releases, unzip it onto
an empty FAT32 or exFAT stick, and follow STAR-STEPS.txt instead of the kit's own
README step about the TUNE knob. The kit writes `launchpad-port-report.txt` to the
stick; its `key_capture` section lists every key event with device name, code, value
and time since start.
