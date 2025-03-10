#!/bin/bash

# Default values for images
DEFAULT_BASE_IMAGE="./img/jammy-server-cloudimg-amd64.img"
DEFAULT_NEW_IMAGE="custom_vm_image.img"
DEFAULT_DISK_SIZE="10G" # Default disk size
DEFAULT_VM_HOSTNAME="VM"
DEFAULT_VM_USERNAME="ubuntu"
DEFAULT_VM_PASSWORD="ubuntu"
DEFAULT_BACKING_FORMAT="qcow2" # Assuming base image is qcow2

# Input variables with default values
BASE_IMAGE="$DEFAULT_BASE_IMAGE"
NEW_IMAGE="$DEFAULT_NEW_IMAGE"
DISK_SIZE="$DEFAULT_DISK_SIZE"
VM_HOSTNAME="$DEFAULT_VM_HOSTNAME"
VM_USERNAME="$DEFAULT_VM_USERNAME"
VM_PASSWORD="$DEFAULT_VM_PASSWORD"
BACKING_FORMAT="$DEFAULT_BACKING_FORMAT"

# Function to show usage
usage() {
  echo "Usage: $0 -b <base_image> -n <new_image> -h <hostname> -u <username> -p <password> -s <disk_size>"
  echo "  -b  Path to the base image (default: $DEFAULT_BASE_IMAGE)"
  echo "  -n  Name of the new VM image to create (default: $DEFAULT_NEW_IMAGE)"
  echo "  -h  Set the VM hostname (default: $DEFAULT_VM_HOSTNAME)"
  echo "  -u  Set the VM username (default: $DEFAULT_VM_USERNAME)"
  echo "  -p  Set the VM password (default: $DEFAULT_VM_PASSWORD)"
  echo "  -s  Set the disk size (default: $DEFAULT_DISK_SIZE)"
  exit 1
}

# Parse command line options
while getopts ":b:n:h:u:p:s:" opt; do
  case $opt in
    b) BASE_IMAGE="$OPTARG" ;;
    n) NEW_IMAGE="$OPTARG" ;;
    h) VM_HOSTNAME="$OPTARG" ;;
    u) VM_USERNAME="$OPTARG" ;;
    p) VM_PASSWORD="$OPTARG" ;;
    s) DISK_SIZE="$OPTARG" ;;
    *) usage ;;
  esac
done

# Step 1: Create a new image by resizing the base image
qemu-img create -f qcow2 -b $BASE_IMAGE -F $BACKING_FORMAT $NEW_IMAGE $DISK_SIZE

# Step 2: Create cloud-init configuration files (user-data and meta-data)
cat > user-data <<EOF
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

cat > meta-data <<EOF
instance-id: $(uuidgen)
local-hostname: $VM_HOSTNAME
EOF

# Step 3: Create an ISO for cloud-init
cloud-localds cloud-init.iso user-data meta-data

# Step 4: Boot the VM with the new image
#qemu-system-x86_64 \
#  -m 2G \
#  -smp 2 \
#  -hda $NEW_IMAGE \
#  -cdrom cloud-init.iso \
#  -boot d \
#  -net nic -net user,hostfwd=tcp::2222-:22 \
#  -enable-kvm

echo "VM image created with hostname: $VM_HOSTNAME, username: $VM_USERNAME, and disk size: $DISK_SIZE"
#echo "You can SSH into the VM using: ssh $VM_USERNAME@localhost -p 2222"
