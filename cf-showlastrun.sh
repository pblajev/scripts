#!/bin/bash

# ---------------------------------------------------------------------------
# Find the last run timestamp
#
# Last Log Example:
# Thu Jan  8 10:18:21 2015:Lock removed normally :pid=31058:lock.munin...
lastLog="`tail -1 /var/cfengine/cf3.*.runlog`"

logRegex="\S+ (\S+ [0-9 ]\S+) (\S+) \S+ \S+ \S+ \S+$"

if [[ $lastLog =~ $logRegex ]]; then
    lastRunDate=${BASH_REMATCH[1]}
    lastRunTime=${BASH_REMATCH[2]}
fi

echo "=== [${lastRunDate} - ${lastRunTime}] Last Run ==="
echo "$lastLog"; echo ""

# ---------------------------------------------------------------------------
# Display the last event
#
# Example file names:
# cf_tzboss_local__1404935466_Wed_Jul__9_12_51_06_2014_0x7f238f4ed700
# cf_tzadmin_local__1402383692_Tue_Jun_10_00_01_32_2014_0x7f1a1ce05700

fileName="`ls -t /var/cfengine/outputs/ | grep -v previous | head -1`"

# ---------------------------------------------------------------------------
#                 Month        DD    HH    MM    SS      YYYY
#fileRegex="cf_\S+_(\S+)_[0-9_](\S+)_(\S+)_(\S+)_(\S+)_[[:digit:]]{4}_0x\S+$"

#                     Date          HH    MM    SS      YYYY
fileRegex="cf_\S+_(\S+_[0-9_]\S+)_(\S+)_(\S+)_(\S+)_[[:digit:]]{4}_0x\S+$"

#if [[ $fileName =~ $fileRegex ]]; then
#       echo "Matches"
#       i=1
#       n=${#BASH_REMATCH[*]}
#       while [[ $i -lt $n ]]; do
#               echo "    capture[$i]: ${BASH_REMATCH[$i]}"
#               let i++
#       done
#fi

if [[ $fileName =~ $fileRegex ]]; then
    date=${BASH_REMATCH[1]}
    hour=${BASH_REMATCH[2]}
    minute=${BASH_REMATCH[3]}
    second=${BASH_REMATCH[4]}
fi

echo "=== [${date} - ${hour}:${minute}:${second}] Last Event ==="
echo "$fileName"
cat /var/cfengine/outputs/${fileName}

exit 0
# ----
