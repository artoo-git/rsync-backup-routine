# RSYNC local backup routine
Hands-off local incremental backups using rsync

## Overview
This backup script performs incremental backups of specified directories from a main server to a backup machine. It uses rsync to efficiently transfer only changed files while maintaining a complete history of backups through timestamped snapshots.

Features
* Incremental backups: Only transfers files that have changed since the last backup
* Snapshot history: Creates timestamped directories for each backup run
* Space efficiency: Uses *hard links* for unchanged files to minimize storage usage
* File deletion tracking: Removes files from current backup that were deleted on the source
* Automatic resumption: Can resume interrupted backups
* Disk spin-up monitoring: Logs disk activity to help diagnose performance issues

##Configuration
The backup script is configured with the following parameters:

``` Bash
readonly SOURCE_SERVER="x.x.x.x"
readonly SOURCE_PARENT_DIR="user@${SOURCE_SERVER}:/source/directory/" # parent directory
readonly DIRECTORIES=("dir1" "dir2")  # array of child directories to back up
readonly BACKUP_DIR="/destination/directory"
readonly LOG_DIR="/var/log"
readonly LOG_FILE="${LOG_DIR}/backup.log"
readonly DISK="/dev/sdX"  # this is the disk where backup is done
```
## How It Works
### Backup Process
The script creates a new timestamped directory for each backup run
It uses --link-dest to create hard links to unchanged files from previous backups
The --delete option ensures files deleted on the source are also removed from the current backup
A "latest" symlink is updated to point to the most recent successful backup
Backup Structure

```
Text Only
/mnt/backup/
├── dir1/
│   ├── 2025-03-08_10:00:00/  # Yesterday's backup
│   ├── 2025-03-09_10:00:00/  # Today's backup
│   └── latest -> 2025-03-09_10:00:00/
└── dir2/
    ├── 2025-03-08_10:00:00/
    ├── 2025-03-09_10:00:00/
    └── latest -> 2025-03-09_10:00:00/
```

## Safety Features
- Lock file prevents multiple instances from running simultaneously
I- ncomplete marker flags backups that didn't finish properly
- Automatic resumption of interrupted backups
- Validation that backup destination is properly mounted
- Disk Activity Monitoring

The script logs disk spin-up counts before each backup run to help monitor disk activity and diagnose potential performance issues.

## Maintenance
1. Periodically check the backup log at /var/log/backup.log
2. Monitor disk usage on the backup drive to ensure sufficient space

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.
