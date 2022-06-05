#!/bin/sh
# Update Remote server below.
# Use call this in the root folder you want to sync.

echo "Start file sync that changed since last sync"

# Remote server:
remote_host=user@remote-ssh-server
remote_base_path=/path/from/root

# create ssh-socket for faster execution
socket=~/.ssh/syncTimeBasedSocket
ssh -M -S $socket $remote_host exit

files_changed=$(mktemp)
last_sync_date=.last_sync_date
sync_switch_for_find=""

# find last sync date in order to only hash newer files
if [ -f "$last_sync_date" ]; then
 last_date=`cat $last_sync_date`
 sync_switch_for_find="-newermt $last_date"
fi

# save last sync date
date -Iseconds > $last_sync_date

# Create local file hash list and sort it
find . -type f $sync_switch_for_find ! -path "./$last_sync_date" ! -path "./$0*"  > $files_changed

echo "Found:"
cat $files_changed

<$files_changed xargs -r -i scp -o ControlPath=$socket -C '{}' $remote_host:\"$remote_base_path/{}\"

ssh -S $socket -O exit $remote_host

