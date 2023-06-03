#!/bin/sh

# Uses the `wakeonlan` tool from https://github.com/jpoliv/wakeonlan
# On Mac, you can `brew install wakeonlan`.

# Wake up the monitor by pretending there's activity.
# Replace with the IP and port of your `lgtv_server` setup.
#
# (Note that if the system is actually awake and idle, it will probably just
# immediately put the monitor back to sleep.)
echo 0 | socat STDIO UDP-SENDTO:192.168.2.1:3232

# Now wake up the machine itself.
# Replace with the broadcast address and MAC address of your workstation.
exec wakeonlan -i 192.168.2.255 b4:2e:99:a3:0f:ad
