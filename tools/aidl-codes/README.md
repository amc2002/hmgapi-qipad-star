# aidl_codes.py

Reads a Gen5W head unit's `automotive.odex` (or any DEX/ODEX) and prints the
`TRANSACTION_*` constants of the classes you name, plus matching method
signatures. Pure Python 3, no dependencies, read-only.

    python -I aidl_codes.py <file.odex> '<class regex>' '<name regex>'

Example, the USM stub on US EV6 260507:

    python -I aidl_codes.py automotive.odex 'Lcom/hkmc/usm/IUSMService\$Stub;$' 'WirelessCharging'

Validate it on your own file first: `setFrontSeatHeatDrvStep` should print 213
and `setFrontSeatHeatAstStep` 214 on firmware 260507 (values published by the
cold-start heat project and HMG-API). The same job is done by
`tools/dexodex.py` in https://github.com/eclipseempire/hkmc-coldstart-heat.

Run it with `-I` on a copy of the firmware file kept in its own folder, and
never commit the firmware file.
