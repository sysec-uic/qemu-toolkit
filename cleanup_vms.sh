#!/bin/bash
set -e
set -o pipefail

# Defaults should mirror allocate_vms.sh
DEFAULT_COUNT=1
DEFAULT_OUT_DIR="out"
DEFAULT_IMAGE_PREFIX="vm"
DEFAULT_TMUX_PREFIX="vm"
DEFAULT_START_INDEX=0

usage() {
  echo "Usage: $0 -n <count> [options]"
  echo "  -n  Number of VMs to clean up (default: $DEFAULT_COUNT)"
  echo "  -o  Output directory (default: $DEFAULT_OUT_DIR)"
  echo "  -i  VM image name prefix (default: $DEFAULT_IMAGE_PREFIX)"
  echo "  -t  tmux session prefix (default: $DEFAULT_TMUX_PREFIX)"
  echo "  -S  Start index (default: $DEFAULT_START_INDEX)"
  exit 1
}

while getopts ":n:o:i:t:S:" opt; do
  case $opt in
    n) COUNT="$OPTARG" ;;
    o) OUT_DIR="$OPTARG" ;;
    i) IMAGE_PREFIX="$OPTARG" ;;
    t) TMUX_PREFIX="$OPTARG" ;;
    S) START_INDEX="$OPTARG" ;;
    *) usage ;;
  esac
done

COUNT=${COUNT:-$DEFAULT_COUNT}
OUT_DIR=${OUT_DIR:-$DEFAULT_OUT_DIR}
IMAGE_PREFIX=${IMAGE_PREFIX:-$DEFAULT_IMAGE_PREFIX}
TMUX_PREFIX=${TMUX_PREFIX:-$DEFAULT_TMUX_PREFIX}
START_INDEX=${START_INDEX:-$DEFAULT_START_INDEX}

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -le 0 ]; then
  echo "Error: count must be a positive integer."
  exit 1
fi

END_INDEX=$((START_INDEX + COUNT - 1))
INDEX_WIDTH=${#END_INDEX}

for ((i=0; i<COUNT; i++)); do
  INDEX=$((START_INDEX + i))
  PAD_INDEX=$(printf "%0${INDEX_WIDTH}d" "$INDEX")
  VM_NAME="${IMAGE_PREFIX}-${PAD_INDEX}"
  TMUX_SESSION="${TMUX_PREFIX}-${PAD_INDEX}"

  if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "Stopping tmux session: $TMUX_SESSION"
    tmux kill-session -t "$TMUX_SESSION"
  fi

  echo "Removing files for VM ${PAD_INDEX}"
  rm -f \
    "${OUT_DIR}/${VM_NAME}.img" \
    "${OUT_DIR}/cloud-init-${VM_NAME}.iso" \
    "${OUT_DIR}/user-data-${VM_NAME}" \
    "${OUT_DIR}/meta-data-${VM_NAME}"
done

echo "Cleanup complete for ${COUNT} VM(s)."
