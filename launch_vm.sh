#!/bin/bash
# This script launches a QEMU VM and adds it to a tmux session
# Usage: ./launch_vm.sh -i teach_vm.img -p 2202 -c 4 -m 8 -t vm-session-teach

# Default values
DEFAULT_VCPU=2
DEFAULT_MEMORY=2  # in GB
DEFAULT_PORT=2222
CLOUD_INIT_IMAGE=""
TMUX_SESSION_NAME="vm-session"

# Function to show usage
usage() {
  echo "Usage: $0 -i <vm_image> -c <vcpu> -m <memory> -p <host_port> [-C <cloud_init_image>] [-t <tmux_session_name>]"
  echo "  -i  Path to the VM image"
  echo "  -c  Number of vCPUs (default: $DEFAULT_VCPU)"
  echo "  -m  Memory size in GB (default: $DEFAULT_MEMORY GB)"
  echo "  -p  Host port to forward to guest port 22 (default: $DEFAULT_PORT)"
  echo "  -C  Optional: Path to the cloud-init ISO image"
  echo "  -t  Optional: Tmux session name (default: $TMUX_SESSION_NAME)"
  exit 1
}

# Parse command line options
while getopts ":i:c:m:p:C:t:" opt; do
  case $opt in
    i) VM_IMAGE="$OPTARG" ;;
    c) VCPU="$OPTARG" ;;
    m) MEMORY="$OPTARG" ;;
    p) HOST_PORT="$OPTARG" ;;
    C) CLOUD_INIT_IMAGE="$OPTARG" ;;
    t) TMUX_SESSION_NAME="$OPTARG" ;;
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
TMUX_SESSION_NAME=${TMUX_SESSION_NAME:-$TMUX_SESSION_NAME}

# Step 1: Convert memory size from GB to MB for QEMU
MEMORY_MB=$(( MEMORY * 1024 ))

# Step 2: Prepare the basic QEMU command
QEMU_CMD="qemu-system-x86_64 \
  -cpu host -nographic \
  -m ${MEMORY_MB} \
  -smp ${VCPU} \
  -hda ${VM_IMAGE} \
  -net nic -net user,hostfwd=tcp::${HOST_PORT}-:22 \
  -enable-kvm"

# Step 3: Optionally add the cloud-init image if provided
if [ -n "$CLOUD_INIT_IMAGE" ]; then
  QEMU_CMD+=" -cdrom ${CLOUD_INIT_IMAGE}"
fi

# Step 4: Check if the tmux session exists
tmux has-session -t $TMUX_SESSION_NAME 2>/dev/null

if [ $? == 0 ]; then
  # The tmux session exists, now we need to check if it's already running QEMU
  if tmux capture-pane -pt $TMUX_SESSION_NAME | grep -q "qemu-system"; then
    echo "Error: Tmux session '$TMUX_SESSION_NAME' is already running a QEMU instance."
    exit 1
  else
    echo "Using existing tmux session: $TMUX_SESSION_NAME"
  fi
else
  # The tmux session does not exist, create a new one
  echo "Creating a new tmux session: ${TMUX_SESSION_NAME}"
  tmux new-session -d -s $TMUX_SESSION_NAME
fi

# Step 5: Send the QEMU command to the tmux session
tmux send-keys -t $TMUX_SESSION_NAME "$QEMU_CMD" C-m

# Attach to the tmux session (optional, can comment out if you don't want to attach immediately)
tmux attach -t $TMUX_SESSION_NAME
