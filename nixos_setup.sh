#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Function to check and list disks and partitions
check_disks() {
  echo "Listing all disks and partitions:"
  lsblk
}

# Function to select a disk
select_disk() {
  echo "Please select the disk where you want to install NixOS (e.g., /dev/sda):"
  read -rp "Enter disk name: " DISK
  if [ ! -b "$DISK" ]; then
    echo "Invalid disk. Please try again."
    select_disk
  fi
}

# Function to confirm user choice
confirm_choice() {
  echo "You have selected $DISK for partitioning."
  read -rp "Are you sure you want to proceed? This will erase all data on $DISK (y/N): " CONFIRM
  if [[ "$CONFIRM" != "y" ]]; then
    echo "Operation canceled."
    exit 0
  fi
}

# Function to setup partitions
setup_partitions() {
  echo "Setting up partitions on $DISK..."
  parted "$DISK" --align optimal mklabel gpt
  parted "$DISK" --align optimal mkpart ESP fat32 1MiB 512MiB
  parted "$DISK" --align optimal mkpart primary ext4 512MiB 100%
  parted "$DISK" -- set 1 boot on
  mkfs.fat -F32 "${DISK}1"
  mkfs.ext4 "${DISK}2"
}

# Function to mount partitions
mount_partitions() {
  echo "Mounting partitions..."
  mount "${DISK}2" /mnt
  mkdir -p /mnt/boot
  mount "${DISK}1" /mnt/boot
  chmod 700 /mnt/boot  # Set restrictive permissions for /boot
}

# Function to secure the random seed file
secure_random_seed() {
  echo "Securing random seed file..."
  RANDOM_SEED_FILE="/mnt/boot/loader/.#bootctlrandom-seed*"
  
  if [ -e $RANDOM_SEED_FILE ]; then
    chmod 600 $RANDOM_SEED_FILE  # Set restrictive permissions for the random seed file
    echo "Random seed file permissions set to 600."
  else
    echo "Random seed file not found. Skipping."
  fi
}

# Function to create and activate swap file
setup_swap() {
  echo "Setting up swap file..."
  RAM_SIZE=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  SWAP_SIZE=$((RAM_SIZE / 1024))  # Correct calculation
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
  
  # Uncomment the line for GRUB device
  sed -i 's/# boot.loader.grub.device = \"\/dev\/sda\";/boot.loader.grub.device = \"\/dev\/sda\";/g' "$CONFIG_FILE"
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
confirm_choice
setup_partitions
mount_partitions
setup_swap
secure_random_seed  # Secure random seed after mounting
build_system

echo "NixOS installation complete. Please reboot."
