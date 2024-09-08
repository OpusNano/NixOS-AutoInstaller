#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Function to check and list disks and partitions
check_disks() {
  echo "Listing all disks and partitions:"
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
}

# Function to get the largest unallocated space
get_largest_unallocated() {
  echo "Finding the largest unallocated space on $DISK..."
  parted "$DISK" unit MiB print free | grep 'Free Space' | awk '{print $1, $2, $3, $4}' | sort -k3,3nr | head -n1
}

# Function to select a disk
select_disk() {
  echo "Please select the disk where you want to install NixOS (e.g., /dev/sda):"
  read -rp "Enter disk name: " DISK
  if [ ! -b "$DISK" ]; then
    echo "Invalid disk. Please try again."
    select_disk
  fi

  # Display unallocated space
  UNALLOCATED_SPACE=$(get_largest_unallocated)
  if [ -z "$UNALLOCATED_SPACE" ]; then
    echo "No unallocated space found on $DISK. Exiting."
    exit 1
  fi

  echo "The largest unallocated space on $DISK is: $UNALLOCATED_SPACE"
  read -rp "Do you want to use this space for NixOS installation? (y/N): " CONFIRM
  if [[ "$CONFIRM" != "y" ]]; then
    echo "Operation canceled."
    exit 0
  fi
}

# Function to setup partitions in unallocated space
setup_partitions() {
  echo "Setting up partitions in unallocated space on $DISK..."
  START=$(echo "$UNALLOCATED_SPACE" | awk '{print $1}')
  END=$(echo "$UNALLOCATED_SPACE" | awk '{print $3}')
  
  # Adjust partition creation using the unallocated space range
  parted "$DISK" --align optimal mkpart ESP fat32 "${START}"MiB "512MiB"
  parted "$DISK" --align optimal mkpart primary ext4 "512MiB" "${END}"MiB
  parted "$DISK" -- set 1 boot on

  mkfs.fat -F32 "${DISK}1"
  mkfs.ext4 "${DISK}2"
}

# Function to mount partitions
mount_partitions() {
  echo "Mounting partitions..."
  mount "${DISK}2" /mnt
  mkdir -p /mnt/boot
  mount -o umask=0077 "${DISK}1" /mnt/boot
}

# Function to create and activate swap file
setup_swap() {
  echo "Setting up swap file..."
  RAM_SIZE=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  SWAP_SIZE=$((RAM_SIZE / 1024))  # Correct calculation
  
  # Limit the swap size to 4GB if RAM size exceeds 4GB
  if [ "$SWAP_SIZE" -gt 4096 ]; then
    SWAP_SIZE=4096
  fi

  dd if=/dev/zero of=/mnt/swapfile bs=1M count=$SWAP_SIZE
  chmod 600 /mnt/swapfile
  mkswap /mnt/swapfile
  swapon /mnt/swapfile
  echo "/swapfile none swap sw 0 0" >> /mnt/etc/fstab
}

# Function to edit the NixOS configuration file
edit_configuration() {
  echo "Editing the NixOS configuration file..."
  CONFIG_FILE="/mnt/etc/nixos/configuration.nix"
  
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "NixOS configuration file not found. Exiting."
    exit 1
  fi

  # Add custom systemd service for fixing /boot permissions after boot
  cat <<EOF >> "$CONFIG_FILE"
{
  systemd.services.fixBootPermissions = {
    description = "Fix permissions for /boot and random-seed file";
    after = [ "local-fs.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.coreutils}/bin/chmod 700 /boot && ${pkgs.coreutils}/bin/chmod 600 /boot/loader/random-seed";
      Type = "oneshot";
      RemainAfterExit = true;
    };
    wantedBy = [ "multi-user.target" ];
  };
}
EOF
}

# Function to build the system
build_system() {
  echo "Building the system..."
  nixos-generate-config --root /mnt

  # Edit configuration before installing
  edit_configuration
  
  nixos-install
}

# Main script execution
check_disks
select_disk
setup_partitions
mount_partitions
setup_swap
build_system

echo "NixOS installation complete. Please reboot."
