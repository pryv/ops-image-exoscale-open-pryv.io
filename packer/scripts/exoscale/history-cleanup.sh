#!/bin/sh
SCRIPT="${0##*/}"

## History cleanup

# Delete log files
echo "INFO[${SCRIPT}]: Deleting log files ..."
find /var/log -type f \( \
    -name 'debug' -o \
    -name 'messages' -o \
    -name '*log' -o \
    -name '*.gz' -o \
    -name '*.xz' -o \
    -name '*[-_.][0-9]*' -o \
    -name '*.notice' -o \
    -name '*.info' -o \
    -name '*.warn' -o \
    -name '*.err' -o \
    -name '*.crit' \
  \) -exec rm -fv {} \;

# Delete shell history
echo "INFO[${SCRIPT}]: Deleting shell history ..."
rm -fv /root/.bash_history
