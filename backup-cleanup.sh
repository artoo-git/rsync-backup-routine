#!/bin/bash

# Backup cleanup script
# I suggest to test a dryrun then use crontab to shedule it as needed
# Default: Dry run mode (doesn't actually delete anything)

set -o errexit
set -o nounset
set -o pipefail

# Configuration
readonly BACKUP_DIR="/mnt/backup"  # this is the path where backup.sh stores the backups
readonly LOG_FILE="/var/log/backup-cleanup.log"
readonly DIRECTORIES=("DIR_NAME_1" "DIR_NAME_2")  # Array of directories to clean up

# Default to dry run mode
BACKUPS_TO_KEEP=5  # Number of most recent backups to keep
DRY_RUN=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --execute)
      DRY_RUN=false
      shift
      ;;
    --keep=*)
      BACKUPS_TO_KEEP="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--execute] [--keep=N]"
      echo "  --execute    Actually delete files (default is dry run)"
      echo "  --keep=N     Keep N most recent backups (default is $BACKUPS_TO_KEEP)"
      exit 1
      ;;
  esac
done

# Logging function
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_FILE}"
}

log "Starting backup cleanup process."
if $DRY_RUN; then
  log "DRY RUN MODE: No files will be deleted."
fi
log "Will keep the $BACKUPS_TO_KEEP most recent backups for each directory."

# Loop through each directory to clean up
for DIR in "${DIRECTORIES[@]}"; do
  log "Processing directory: ${DIR}"

  # Get the current backup (the one linked by 'latest')
  CURRENT_BACKUP=""
  if [ -L "${BACKUP_DIR}/${DIR}/latest" ]; then
    CURRENT_BACKUP=$(readlink -f "${BACKUP_DIR}/${DIR}/latest")
    log "Current backup (linked by 'latest'): $(basename "$CURRENT_BACKUP")"
  else
    log "Warning: No 'latest' symlink found for ${DIR}. Will still keep the $BACKUPS_TO_KEEP most recent backups."
  fi

  # Get a list of all backups sorted by date (oldest first)
  mapfile -t ALL_BACKUPS < <(find "${BACKUP_DIR}/${DIR}" -maxdepth 1 -type d -name "20*" | sort)

  # Calculate how many to delete
  BACKUPS_COUNT=${#ALL_BACKUPS[@]}
  BACKUPS_TO_DELETE=$((BACKUPS_COUNT - BACKUPS_TO_KEEP))

  log "Found $BACKUPS_COUNT backups, keeping $BACKUPS_TO_KEEP, will delete $BACKUPS_TO_DELETE"

  # HERE'S THE FIXED CODE - Check for incomplete backups IN THE RIGHT PLACE
  log "Checking for incomplete backups in ${DIR}..."
  INCOMPLETE_COUNT=0
  for BACKUP in "${ALL_BACKUPS[@]}"; do
    if [ -f "${BACKUP}/.incomplete" ]; then
      INCOMPLETE_COUNT=$((INCOMPLETE_COUNT+1))
      log "Found incomplete backup: $(basename "$BACKUP")"
    fi
  done

  if [ "$INCOMPLETE_COUNT" -eq "$BACKUPS_COUNT" ]; then
    log "WARNING: All backups appear to be incomplete! Not deleting any backups for ${DIR}."
    continue
  fi

  # Delete oldest backups if we have more than we want to keep
  if [ "${BACKUPS_TO_DELETE}" -gt 0 ]; then
    for ((i=0; i<BACKUPS_TO_DELETE; i++)); do
      # Make sure we're not deleting the current backup
      if [ "${ALL_BACKUPS[i]}" = "$CURRENT_BACKUP" ]; then
        log "Skipping current backup: $(basename "${ALL_BACKUPS[i]}")"
        continue
      fi

      if $DRY_RUN; then
        log "Would delete: $(basename "${ALL_BACKUPS[i]}")"
      else
        log "Deleting: $(basename "${ALL_BACKUPS[i]}")"
        rm -rf "${ALL_BACKUPS[i]}"
      fi
    done
  else
    log "No backups to delete for ${DIR}"
  fi
done

log "Backup cleanup process finished."
if $DRY_RUN; then
  log "This was a dry run. To actually delete files, run with --execute"
fi

