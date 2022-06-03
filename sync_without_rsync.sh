#!/bin/sh
# This script is intended for servers that do not provide rsync.
# Like hosting servers.

# Update the remote server section below first.
# Call this script in the local root folder you want to sync like "sh sync_without_rsync.sh".

# The script works by first creating a list of files with their sha256sums.
# Then, the remote hashes are downloaded and compared using diff.
# Changed files are removed remotely and local added/changed files are copied using scp.
# Finally, the new hash file is copied.
# In case of an error, you can call "sh sync_without_rsync.sh fixremote"
# in order to recalculate the hashes on the remote machine.

echo "Starting file sync"

# Remote server:
remote_host=remote_user@some_ssh_remote_host
remote_base_path=/base/to/copy/to

# create ssh-socket for faster execution
socket=~/.ssh/sshSocket

remote_file_hashes=$(mktemp)
file_hash_changes=$(mktemp)
files_changed=$(mktemp)
file_hashes=.file_hashes.lst

if [ "$1" = "fixremote" ]; then
  echo "Rebuilding remote file hash"
  ssh -S $socket $remote_host cd $remote_base_path; find . -type f ! -path "./$0*" ! -path "./.file_hashes.lst" -exec sha256sum {} \; | ssh -S $socket $remote_host "cat > $remote_base_path/$file_hashes"
  exit
fi

# Create local file hash list and sort it
find . -type f ! -path "./$0*" ! -path "./.file_hashes.lst" -exec sha256sum {} \; | sort > $file_hashes
# Download remote file hash list, may be empty, may be old
scp -o "ControlPath=$socket" -q "$remote_host:$remote_base_path/$file_hashes" $remote_file_hashes
# Create difference
diff $remote_file_hashes $file_hashes > $file_hash_changes
if [ $? -eq 0 ]; then
  echo Nothing changed
else
  # Remove files missing locally
  truncate -s 0 $files_changed
  cat $file_hash_changes | egrep ^\< | cut -d " " -f 4 > $files_changed
  echo "Will delete remotely: "
  xargs echo <$files_changed
  <$files_changed xargs -r -i ssh -S $socket $remote_host rm -f $remote_base_path/{}
  
  # Add files added or changed local
  truncate -s 0 $files_changed
  cat $file_hash_changes | egrep ^\> | cut -d " " -f 4 > $files_changed

  # create folder remote just to be sure
  cat $files_changed | xargs -r dirname | sort | uniq | xargs -i ssh -S $socket $remote_host mkdir -p $remote_base_path/{}

  # copy files
  echo "Adding: "
  <$files_changed xargs -r -i scp -o ControlPath=$socket -C {} $remote_host:$remote_base_path/{}

  # copy hash file for folder
  scp -o "ControlPath=$socket" $file_hashes "$remote_host:$remote_base_path/$file_hashes"
fi

ssh -S $socket -O exit $remote_host

