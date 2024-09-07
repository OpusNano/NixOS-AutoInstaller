# NixOS AutoInstaller Guide

This guide will walk you through using the NixOS AutoInstaller script from the command line interface (CLI) in the minimal NixOS installer.

## Prerequisites

1. **Minimal NixOS Installer**: Ensure you have the minimal NixOS installer booted up. You can download it from the [NixOS download page](https://nixos.org/download/).
2. **Internet Connection**: Make sure you have an active internet connection.
3. **Git**: The minimal installer should have `git` available. If not, you may need to install it.

## Steps

### 1. Boot into the Minimal NixOS Installer

Boot your machine using the minimal NixOS installer ISO. You should be greeted with a shell prompt. For more details, refer to the [NixOS Installation Guide](https://nixos.wiki/wiki/NixOS_Installation_Guide).

### 2. Connect to the Internet

Ensure you have an active internet connection. You can use `nmtui` or `iwctl` for wireless connections. For more information on these tools, check out the [NetworkManager page](https://wiki.nixos.org/wiki/NetworkManager) and the [iwd page](https://nixos.wiki/wiki/Iwd).

```sh
# For wired connections, it should be automatic. For wireless:
nmtui
# or
iwctl
```
### 3. Clone the Repository

Clone the NixOS AutoInstaller repository from GitHub.

```sh
git clone https://github.com/OpusNano/NixOS-AutoInstaller.git
cd NixOS-AutoInstaller
```

### 4. Make the Script Executable

Ensure the script is executable.

```sh
chmod +x install.sh
```

### 5. Run the Script

Execute the script to start the installation process.

```sh
./install.sh
```

### 6. Follow the On-Screen Instructions

The script will guide you through the installation process. Follow the on-screen instructions to complete the installation.

### 7. Reboot

Once the installation is complete, reboot your system.

```sh
reboot
```

## Troubleshooting

- **Script Not Executable**: If you encounter a “Permission denied” error, ensure the script has executable permissions (`chmod +x install.sh`).
- **Internet Connection Issues**: Verify your network settings and ensure you are connected to the internet.
- **Dependency Issues**: If the script fails due to missing dependencies, you may need to manually install them using `nix-env -i`.

## Conclusion

You have successfully used the NixOS AutoInstaller script to install NixOS. For more details, refer to the repository.

Happy installing!
