#!/bin/bash
set -e
set -o pipefail

# Default values for images
DEFAULT_BASE_IMAGE="./img/resolute-server-cloudimg-amd64.img"
DEFAULT_OUT_DIR="out"
DEFAULT_NEW_IMAGE="${DEFAULT_OUT_DIR}/custom_vm_image.img"
DEFAULT_DISK_SIZE="10G" # Default disk size
DEFAULT_VM_HOSTNAME="VM"
DEFAULT_VM_USERNAME="ubuntu"
DEFAULT_VM_PASSWORD="ubuntu"
DEFAULT_BACKING_FORMAT="qcow2" # Assuming base image is qcow2

# Input variables with default values
BASE_IMAGE="$DEFAULT_BASE_IMAGE"
NEW_IMAGE="$DEFAULT_NEW_IMAGE"
OUT_DIR="$DEFAULT_OUT_DIR"
DISK_SIZE="$DEFAULT_DISK_SIZE"
VM_HOSTNAME="$DEFAULT_VM_HOSTNAME"
VM_USERNAME="$DEFAULT_VM_USERNAME"
VM_PASSWORD="$DEFAULT_VM_PASSWORD"
BACKING_FORMAT="$DEFAULT_BACKING_FORMAT"

# Function to show usage
usage() {
  echo "Usage: $0 -b <base_image> -n <new_image> -h <hostname> -u <username> -p <password> -s <disk_size> [-o <out_dir>]"
  echo "  -b  Path to the base image (default: $DEFAULT_BASE_IMAGE)"
  echo "  -n  Name of the new VM image to create (default: $DEFAULT_NEW_IMAGE)"
  echo "  -h  Set the VM hostname (default: $DEFAULT_VM_HOSTNAME)"
  echo "  -u  Set the VM username (default: $DEFAULT_VM_USERNAME)"
  echo "  -p  Set the VM password (default: $DEFAULT_VM_PASSWORD)"
  echo "  -s  Set the disk size (default: $DEFAULT_DISK_SIZE)"
  echo "  -o  Output directory for the image and cloud-init files (default: $DEFAULT_OUT_DIR)"
  exit 1
}

# Parse command line options
while getopts ":b:n:h:u:p:s:o:" opt; do
  case $opt in
    b) BASE_IMAGE="$OPTARG" ;;
    n) NEW_IMAGE="$OPTARG" ;;
    h) VM_HOSTNAME="$OPTARG" ;;
    u) VM_USERNAME="$OPTARG" ;;
    p) VM_PASSWORD="$OPTARG" ;;
    s) DISK_SIZE="$OPTARG" ;;
    o) OUT_DIR="$OPTARG" ;;
    *) usage ;;
  esac
done

# Load base image registry if present.
if [ -f "./images.env" ]; then
  # shellcheck disable=SC1091
  . "./images.env"
fi

# Resolve base image name from images.env if needed.
BASE_IMAGE_RESOLVED="$BASE_IMAGE"
if [ ! -f "$BASE_IMAGE_RESOLVED" ] && [[ "$BASE_IMAGE" =~ ^[A-Z0-9_]+$ ]]; then
  if [ -n "${!BASE_IMAGE}" ]; then
    BASE_IMAGE_RESOLVED="${!BASE_IMAGE}"
  fi
fi

# Ensure output directory exists.
mkdir -p "$OUT_DIR"

# If NEW_IMAGE is a bare filename, place it in OUT_DIR.
if [[ "$NEW_IMAGE" != */* ]]; then
  NEW_IMAGE="${OUT_DIR}/${NEW_IMAGE}"
fi

# Fail fast if the base image cannot be found.
if [ ! -f "$BASE_IMAGE_RESOLVED" ]; then
  echo "Error: Base image not found: $BASE_IMAGE_RESOLVED"
  exit 1
fi

# Canonicalize base image path so qemu-img can resolve it from any CWD.
BASE_IMAGE_REALPATH="$(realpath -e "$BASE_IMAGE_RESOLVED")"

IMAGE_BASENAME="$(basename "$NEW_IMAGE")"
IMAGE_STEM="${IMAGE_BASENAME%.*}"
USER_DATA="${OUT_DIR}/user-data-${IMAGE_STEM}"
META_DATA="${OUT_DIR}/meta-data-${IMAGE_STEM}"
CLOUD_INIT_ISO="${OUT_DIR}/cloud-init-${IMAGE_STEM}.iso"

# Step 1: Create a new image by resizing the base image
qemu-img create -f qcow2 -b "$BASE_IMAGE_REALPATH" -F "$BACKING_FORMAT" "$NEW_IMAGE" "$DISK_SIZE"

# Step 2: Create cloud-init configuration files (user-data and meta-data)
cat > "$USER_DATA" <<EOF
#cloud-config
hostname: $VM_HOSTNAME
users:
  - name: $VM_USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $(echo "$VM_PASSWORD" | openssl passwd -6 -stdin)
ssh_pwauth: true
chpasswd:
  expire: false
EOF

cat > "$META_DATA" <<EOF
instance-id: $(uuidgen)
local-hostname: $VM_HOSTNAME
EOF

# Step 3: Create an ISO for cloud-init
cloud-localds "$CLOUD_INIT_ISO" "$USER_DATA" "$META_DATA"

# Summary
echo "VM image created: $NEW_IMAGE"
echo "Cloud-init ISO created: $CLOUD_INIT_ISO"
echo "Hostname: $VM_HOSTNAME, username: $VM_USERNAME, disk size: $DISK_SIZE"
echo "Base image used: $BASE_IMAGE_REALPATH"
