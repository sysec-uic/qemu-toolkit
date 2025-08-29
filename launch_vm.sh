#!/bin/bash
# This script launches a QEMU VM and adds it to a tmux session
# Usage: ./launch_vm.sh -i teach_vm.img -p 2202 -c 4 -m 8 -t vm-session-teach -n tap -T tap0

# Default values
DEFAULT_VCPU=2
DEFAULT_MEMORY=2  # in GB
DEFAULT_PORT=2222
DEFAULT_NETWORK="user"
DEFAULT_TAP_INTERFACE="tap0"
CLOUD_INIT_IMAGE=""
TMUX_SESSION_NAME="vm-session"

# Function to show usage
usage() {
  echo "Usage: $0 -i <vm_image> -c <vcpu> -m <memory> -p <host_port> [-C <cloud_init_image>] [-t <tmux_session_name>] [-n <network_type>] [-T <tap_interface>]"
  echo "  -i  Path to the VM image"
  echo "  -c  Number of vCPUs (default: $DEFAULT_VCPU)"
  echo "  -m  Memory size in GB (default: $DEFAULT_MEMORY GB)"
  echo "  -p  Host port to forward to guest port 22 (default: $DEFAULT_PORT)"
  echo "  -C  Optional: Path to the cloud-init ISO image"
  echo "  -t  Optional: Tmux session name (default: $TMUX_SESSION_NAME)"
  echo "  -n  Network type: 'user' or 'tap' (default: $DEFAULT_NETWORK)"
  echo "  -T  TAP interface name (default: $DEFAULT_TAP_INTERFACE)"
  exit 1
}

# Parse command line options
while getopts ":i:c:m:p:C:t:n:T:" opt; do
  case $opt in
    i) VM_IMAGE="$OPTARG" ;;
    c) VCPU="$OPTARG" ;;
    m) MEMORY="$OPTARG" ;;
    p) HOST_PORT="$OPTARG" ;;
    C) CLOUD_INIT_IMAGE="$OPTARG" ;;
    t) TMUX_SESSION_NAME="$OPTARG" ;;
    n) NETWORK_TYPE="$OPTARG" ;;
    T) TAP_INTERFACE="$OPTARG" ;;
    *) usage ;;
  esac
done

# Check if VM image is provided
if [ -z "$VM_IMAGE" ]; then
  echo "Error: VM image is required."
  usage
fi

# Set default values if not provided
VCPU=${VCPU:-$DEFAULT_VCPU}
MEMORY=${MEMORY:-$DEFAULT_MEMORY}
HOST_PORT=${HOST_PORT:-$DEFAULT_PORT}
NETWORK_TYPE=${NETWORK_TYPE:-$DEFAULT_NETWORK}
TAP_INTERFACE=${TAP_INTERFACE:-$DEFAULT_TAP_INTERFACE}
TMUX_SESSION_NAME=${TMUX_SESSION_NAME:-$TMUX_SESSION_NAME}

# Step 1: Convert memory size from GB to MB for QEMU
MEMORY_MB=$(( MEMORY * 1024 ))

# Step 2: Configure network settings
if [ "$NETWORK_TYPE" == "user" ]; then
  NETWORK_OPTS="-net nic -net user,hostfwd=tcp::${HOST_PORT}-:22"
elif [ "$NETWORK_TYPE" == "tap" ]; then
  NETWORK_OPTS="-netdev tap,id=net0,ifname=${TAP_INTERFACE},script=no,downscript=no -device e1000,netdev=net0"
else
  echo "Error: Invalid network type specified. Use 'user' or 'tap'."
  exit 1
fi

# Step 3: Prepare the basic QEMU command
QEMU_CMD="qemu-system-x86_64 \
  -cpu host -nographic \
  -m ${MEMORY_MB} \
  -smp ${VCPU} \
  -hda ${VM_IMAGE} \
  ${NETWORK_OPTS} \
  -enable-kvm"

# Step 4: Optionally add the cloud-init image if provided
if [ -n "$CLOUD_INIT_IMAGE" ]; then
  QEMU_CMD+=" -cdrom ${CLOUD_INIT_IMAGE}"
fi

# Step 5: Check if the tmux session exists
tmux has-session -t $TMUX_SESSION_NAME 2>/dev/null

if [ $? == 0 ]; then
  if tmux capture-pane -pt $TMUX_SESSION_NAME | grep -q "qemu-system"; then
    echo "Error: Tmux session '$TMUX_SESSION_NAME' is already running a QEMU instance."
    exit 1
  else
    echo "Using existing tmux session: $TMUX_SESSION_NAME"
  fi
else
  echo "Creating a new tmux session: ${TMUX_SESSION_NAME}"
  tmux new-session -d -s $TMUX_SESSION_NAME
fi

# Step 6: Send the QEMU command to the tmux session
tmux send-keys -t $TMUX_SESSION_NAME "$QEMU_CMD" C-m

# Step 7: Attach to the tmux session (optional)
tmux attach -t $TMUX_SESSION_NAME