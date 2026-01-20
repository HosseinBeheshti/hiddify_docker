# Save this as setup_vm.sh and run: sudo bash setup_vm.sh

#!/bin/bash
set -e

echo "============================================="
echo "   KVM Virtual Machine Setup for Hiddify"
echo "============================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# VM Configuration
VM_NAME="hiddify-vm"
VM_RAM="2048"           # 2GB RAM
VM_CPUS="2"
VM_DISK_SIZE="20G"
ISO_URL="https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
ISO_PATH="/var/lib/libvirt/images/ubuntu-24.04.iso"
DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"

echo "Installing KVM..."
apt update
apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst cpu-checker

echo "Checking virtualization support..."
kvm-ok || { echo "KVM not supported. Need nested virtualization."; exit 1; }

systemctl enable --now libvirtd

echo "Downloading Ubuntu ISO..."
[ ! -f "$ISO_PATH" ] && wget -O "$ISO_PATH" "$ISO_URL"

echo "Creating VM disk..."
[ ! -f "$DISK_PATH" ] && qemu-img create -f qcow2 "$DISK_PATH" "$VM_DISK_SIZE"

echo "Creating VM..."
virt-install \
    --name "$VM_NAME" \
    --ram "$VM_RAM" \
    --vcpus "$VM_CPUS" \
    --disk path="$DISK_PATH",format=qcow2 \
    --cdrom "$ISO_PATH" \
    --network network=default \
    --graphics vnc,listen=0.0.0.0,port=5910 \
    --os-variant ubuntu24.04 \
    --noautoconsole

echo ""
echo "✓ VM created! Connect via VNC:"
echo "  vncviewer $(hostname -I | awk '{print $1}'):5910"
echo ""
echo "After Ubuntu install:"
echo "  1. Get VM IP: virsh domifaddr $VM_NAME"
echo "  2. SSH to VM and install Hiddify"
echo ""
echo "VM Commands:"
echo "  virsh list --all"
echo "  virsh start $VM_NAME"
echo "  virsh shutdown $VM_NAME"