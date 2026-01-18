# QEMU VM Toolkit

This project provides two helper scripts to automate the process of **creating customized VM images** and **launching virtual machines** using QEMU/KVM, cloud-init, and tmux.

## Dependencies

Make sure the following tools are installed:

- QEMU/KVM
- cloud-utils (for cloud-localds)
- tmux (for session management)

On Ubuntu/Debian:
```
sudo apt update
sudo apt install -y qemu-kvm cloud-utils genisoimage tmux
```

## Workflow

1. Use `create_vm_image.sh` to build a `VM image` + `cloud-init` ISO in `./out/`.
2. Use `launch_vm.sh` to boot the VM inside tmux.
3. SSH into the VM using the forwarded port (user networking).

## Quickstart
### Ubuntu 25.04
```
# Step 0: Download a base cloud image into ./img
mkdir -p ./img
pushd ./img
wget https://cloud-images.ubuntu.com/releases/plucky/release/ubuntu-25.04-server-cloudimg-amd64.img
# wget https://fastly.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2  # Arch Linux
popd

# Step 1: Create VM image
./create_vm_image.sh -b ./img/ubuntu-25.04-server-cloudimg-amd64.img -n ubuntu25_vm.img -u testuser -s 64G

# Step 2: Launch VM in tmux
./launch_vm.sh -i out/ubuntu25_vm.img -p 2020 -c 4 -m 4 -t ubuntu25-vm -C out/cloud-init-ubuntu25_vm.iso

# Step 3: SSH into VM
ssh testuser@localhost -p 2020
```

### Arch Linux

```
# Step 0: Download a base cloud image into ./img (inside this repo)
mkdir -p ./img
pushd ./img
wget https://fastly.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2  # Arch Linux
popd

# Step 1: Create VM image
./create_vm_image.sh -b img/Arch-Linux-x86_64-cloudimg.qcow2 -n arch_vm.img -u linux -s 32G

# Step 2: Launch VM in tmux
./launch_vm.sh -i out/arch_vm.img -p 2020 -c 4 -m 4 -t arch-vm -C out/cloud-init-arch_vm.iso

# Step 3: SSH into VM
ssh linux@localhost -p 2020
# The default login password is ubuntu
```

## Scripts

### 1. `create_vm_image.sh`
Creates a new VM disk image from a base cloud image (Ubuntu or Arch), applies cloud-init configuration (hostname, username, password), and generates an ISO for bootstrapping.

#### Usage
```bash
./create_vm_image.sh -b <base_image> -n <new_image> -h <hostname> -u <username> -p <password> -s <disk_size> [-o <out_dir>]
```

#### Options

* -b: Path to the base image (default: `./img/jammy-server-cloudimg-amd64.img`)
* -n: Name of the new VM image (default: `custom_vm_image.img`)
* -h: VM hostname (default: `VM`)
* -u: VM username (default: `ubuntu`)
* -p: VM password (default: `ubuntu`)
* -s: VM disk size (default: `10G`)
* -o: Output directory for the image and cloud-init files (default: `out`)

#### Example
```
./create_vm_image.sh -n myvm.img -h myhost -u alice -p secret123 -s 20G
```

This will:
1. Create a `myvm.img` disk (20G).
2. Set the hostname to `myhost`.
3. Create a user `alice` with password `secret123`.
4. Generate `cloud-init-<image>.iso` for first-boot configuration in `out/`.

#### Arch Linux example
```
./create_vm_image.sh -b ./img/Arch-Linux-x86_64-cloudimg.qcow2 -n arch_vm.img -h archvm -u arch -p arch -s 20G
./launch_vm.sh -i out/arch_vm.img -p 2222 -c 2 -m 4 -t arch-vm -C out/cloud-init-arch_vm.iso
ssh arch@localhost -p 2222
```

#### Base image registry (optional)
You can define base image aliases in `images.env` and pass the alias to `-b`:
```
./create_vm_image.sh -b ARCH_LINUX -n arch_vm.img -h archvm -u arch -p arch -s 20G
```

### 2. launch_vm.sh

Launches a VM inside a tmux session for easier management.
Supports both user networking (with SSH port forwarding) and tap networking (for bridged connections).

#### Usage
```
./launch_vm.sh -i <vm_image> -c <vcpu> -m <memory> -p <host_port> \
  [-C <cloud_init_image>] [-t <tmux_session_name>] \
  [-n <network_type>] [-T <tap_interface>]
```

#### Options
* -i: Path to the VM image (required)
* -c: Number of vCPUs (default: `2`)
* -m: Memory size in GB (default: `2`)
* -p: Host port forwarded to guest SSH port 22 (default: `2222`)
* -C: Optional path to a cloud-init ISO (e.g., `cloud-init.iso`)
* -t: Tmux session name (default: `vm-session`)
* -n: Network type: user or tap (default: user)
* -T: TAP interface name if using -n tap (default: tap0)

#### Examples

Basic launch with user networking:
```
./launch_vm.sh -i myvm.img -c 2 -m 4 -p 2200 -t vm1
```

- Starts the VM with 2 CPUs, 4GB RAM.
- Forwards host port 2200 → guest port 22.
- Runs inside tmux session `vm1`.
- Connect with:
```
ssh alice@localhost -p 2200
```

#### Launch with tap networking:
```
sudo ./launch_vm.sh -i myvm.img -c 4 -m 8 -n tap -T tap0 -t vm-tap
```

- Starts the VM with 4 CPUs, 8GB RAM.
- Uses tap device tap0 for bridged networking.
- Runs inside tmux session vm-tap.
