#!/bin/sh

sudo btrfs subvolume snapshot -r / /snapshot/
sudo btrfs send /snapshot | gzip | ssh user@remotemachine "cat > /path/to/backup/file"
sudo btrfs subvolume delete /snapshot/
