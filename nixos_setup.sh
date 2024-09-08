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

# Function to select a disk
select_disk() {
  echo "Please select the disk where you want to install NixOS (e.g., sda):"
  read -rp "Enter disk name: " DISK
  if [ ! -b "/dev/$DISK" ]; then
    echo "Invalid disk. Please try again."
    select_disk
  fi
}

# Function to select the largest unallocated space
select_unallocated_space() {
  echo "Finding the largest unallocated space on /dev/$DISK..."
  UNALLOCATED=$(parted /dev/$DISK unit GB print free | awk '/Free Space/ {print $3, $4}' | sort -nrk 1 | head -n 1)
  START=$(echo $UNALLOCATED | awk '{print $1}')
  END=$(echo $UNALLOCATED | awk '{print $2}')
  SIZE=$(echo "$END - $START" | bc)

  if [ -z "$START" ] || [ -z "$END" ]; then
    echo "No unallocated space found on /dev/$DISK."
    exit 1
  fi

  echo "Largest unallocated space found: $SIZE GB from $START to $END."
}

# Function to confirm user choice
confirm_choice() {
  echo "You have selected /dev/$DISK for partitioning from $START to $END."
  read -rp "Are you sure you want to proceed? This will erase data in the selected space (y/N): " CONFIRM
  if [[ "$CONFIRM" != "y" ]]; then
    echo "Operation canceled."
    exit 0
  fi
}

# Function to setup partitions
setup_partitions() {
  echo "Setting up partitions on /dev/$DISK from $START to $END..."
  parted /dev/$DISK --align optimal mkpart primary ext4 "$START" "$END"
  mkfs.ext4 "/dev/${DISK}1"
}

# Function to mount partitions
mount_partitions() {
  echo "Mounting partitions..."
  mount "/dev/${DISK}1" /mnt
  mkdir -p /mnt/boot
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
select_unallocated_space
confirm_choice
setup_partitions
mount_partitions
setup_swap
build_system

echo "NixOS installation complete. Please reboot."
