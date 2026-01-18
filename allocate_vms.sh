#!/bin/bash
set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
DEFAULT_BASE_IMAGE="./img/noble-server-cloudimg-amd64.img"
DEFAULT_COUNT=1
DEFAULT_BASE_PORT=2222
DEFAULT_VCPU=2
DEFAULT_MEMORY=2
DEFAULT_DISK_SIZE="10G"
DEFAULT_OUT_DIR="out"
DEFAULT_USERNAME_PREFIX="student"
DEFAULT_HOSTNAME_PREFIX="vm"
DEFAULT_IMAGE_PREFIX="vm"
DEFAULT_TMUX_PREFIX="vm"
DEFAULT_PASSWORD="ubuntu"
DEFAULT_NETWORK="user"
DEFAULT_TAP_INTERFACE="tap0"
DEFAULT_START_INDEX=0

usage() {
  echo "Usage: $0 -n <count> -p <base_port> [options]"
  echo "  -b  Base image path or alias (default: $DEFAULT_BASE_IMAGE)"
  echo "  -n  Number of VMs to allocate (default: $DEFAULT_COUNT)"
  echo "  -p  Base SSH port (VM index n uses base_port+n)"
  echo "  -c  Number of vCPUs per VM (default: $DEFAULT_VCPU)"
  echo "  -m  Memory size in GB per VM (default: $DEFAULT_MEMORY)"
  echo "  -s  Disk size for each VM image (default: $DEFAULT_DISK_SIZE)"
  echo "  -o  Output directory (default: $DEFAULT_OUT_DIR)"
  echo "  -u  Username prefix (default: $DEFAULT_USERNAME_PREFIX)"
  echo "  -h  Hostname prefix (default: $DEFAULT_HOSTNAME_PREFIX)"
  echo "  -i  VM image name prefix (default: $DEFAULT_IMAGE_PREFIX)"
  echo "  -t  tmux session prefix (default: $DEFAULT_TMUX_PREFIX)"
  echo "  -P  Password for all VM users (default: $DEFAULT_PASSWORD)"
  echo "  -N  Network type: 'user' or 'tap' (default: $DEFAULT_NETWORK)"
  echo "  -T  TAP interface name (default: $DEFAULT_TAP_INTERFACE)"
  echo "  -S  Start index (default: $DEFAULT_START_INDEX)"
  exit 1
}

# Parse command line options
while getopts ":b:n:p:c:m:s:o:u:h:i:t:P:N:T:S:" opt; do
  case $opt in
    b) BASE_IMAGE="$OPTARG" ;;
    n) COUNT="$OPTARG" ;;
    p) BASE_PORT="$OPTARG" ;;
    c) VCPU="$OPTARG" ;;
    m) MEMORY="$OPTARG" ;;
    s) DISK_SIZE="$OPTARG" ;;
    o) OUT_DIR="$OPTARG" ;;
    u) USERNAME_PREFIX="$OPTARG" ;;
    h) HOSTNAME_PREFIX="$OPTARG" ;;
    i) IMAGE_PREFIX="$OPTARG" ;;
    t) TMUX_PREFIX="$OPTARG" ;;
    P) PASSWORD="$OPTARG" ;;
    N) NETWORK_TYPE="$OPTARG" ;;
    T) TAP_INTERFACE="$OPTARG" ;;
    S) START_INDEX="$OPTARG" ;;
    *) usage ;;
  esac
done

BASE_IMAGE=${BASE_IMAGE:-$DEFAULT_BASE_IMAGE}
COUNT=${COUNT:-$DEFAULT_COUNT}
BASE_PORT=${BASE_PORT:-$DEFAULT_BASE_PORT}
VCPU=${VCPU:-$DEFAULT_VCPU}
MEMORY=${MEMORY:-$DEFAULT_MEMORY}
DISK_SIZE=${DISK_SIZE:-$DEFAULT_DISK_SIZE}
OUT_DIR=${OUT_DIR:-$DEFAULT_OUT_DIR}
USERNAME_PREFIX=${USERNAME_PREFIX:-$DEFAULT_USERNAME_PREFIX}
HOSTNAME_PREFIX=${HOSTNAME_PREFIX:-$DEFAULT_HOSTNAME_PREFIX}
IMAGE_PREFIX=${IMAGE_PREFIX:-$DEFAULT_IMAGE_PREFIX}
TMUX_PREFIX=${TMUX_PREFIX:-$DEFAULT_TMUX_PREFIX}
PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}
NETWORK_TYPE=${NETWORK_TYPE:-$DEFAULT_NETWORK}
TAP_INTERFACE=${TAP_INTERFACE:-$DEFAULT_TAP_INTERFACE}
START_INDEX=${START_INDEX:-$DEFAULT_START_INDEX}

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -le 0 ]; then
  echo "Error: count must be a positive integer."
  exit 1
fi

if ! [[ "$BASE_PORT" =~ ^[0-9]+$ ]]; then
  echo "Error: base port must be a number."
  exit 1
fi

END_INDEX=$((START_INDEX + COUNT - 1))
INDEX_WIDTH=${#END_INDEX}

for ((i=0; i<COUNT; i++)); do
  INDEX=$((START_INDEX + i))
  PAD_INDEX=$(printf "%0${INDEX_WIDTH}d" "$INDEX")
  VM_NAME="${IMAGE_PREFIX}-${PAD_INDEX}"
  VM_IMAGE="${VM_NAME}.img"
  HOSTNAME="${HOSTNAME_PREFIX}-${PAD_INDEX}"
  USERNAME="${USERNAME_PREFIX}${PAD_INDEX}"
  PORT=$((BASE_PORT + INDEX))
  TMUX_SESSION="${TMUX_PREFIX}-${PAD_INDEX}"
  CLOUD_INIT_ISO="${OUT_DIR}/cloud-init-${VM_NAME}.iso"

  echo "Allocating VM ${PAD_INDEX}: ${VM_IMAGE} on port ${PORT}"

  "$SCRIPT_DIR/create_vm_image.sh" \
    -b "$BASE_IMAGE" \
    -n "$VM_IMAGE" \
    -h "$HOSTNAME" \
    -u "$USERNAME" \
    -p "$PASSWORD" \
    -s "$DISK_SIZE" \
    -o "$OUT_DIR"

  "$SCRIPT_DIR/launch_vm.sh" \
    -i "${OUT_DIR}/${VM_IMAGE}" \
    -p "$PORT" \
    -c "$VCPU" \
    -m "$MEMORY" \
    -t "$TMUX_SESSION" \
    -C "$CLOUD_INIT_ISO" \
    -n "$NETWORK_TYPE" \
    -T "$TAP_INTERFACE" \
    -A
done

echo "Allocated ${COUNT} VM(s). Connect with: ssh ${USERNAME_PREFIX}<index>@localhost -p <base_port+index>"
