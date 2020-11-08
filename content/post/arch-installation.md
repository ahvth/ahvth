---
title: "Arch Linux Demystified a.k.a. an Arch Linux Install Reference"
date: 2020-11-07T20:52:34+01:00
draft: false
tags: ["arch", "guide"]
---

> This is an iteration on an [article](https://medium.com/@ahvth/arch-linux-installation-demystified-a-k-a-an-arch-linux-reference-efad34a732c6) I previously posted to medium.com

There are a lot of resources out there on installing Arch Linux, but when I first started with the subject, I always found it difficult to find that one guide with all of the commands spelled out for me with useful examples. So, haphazardly sprawling out on the page below me shall be a list of commands to create a conservative system layout in mostly chronological order. This should serve as a reference for new Arch users going through their first installations, or for experienced users who just need a quick checklist with some handy optimizations over the official guide.

[Read the official installation guide](https://wiki.archlinux.org/index.php/Installation_guide)  
[Get Arch](https://www.archlinux.org/download/)

## Chapter 1: The LiveUSB
**Installer version used at the time of this article’s creation**: `ARCH_202003`

*The first steps of any Arch installation happen on the Arch LiveUSB*

### Keyboard

#### Querying available keyboard layouts

```
find /usr/share/kbd/keymaps/ -type f | more
```

#### Configuring the keyboard

```
loadkeys hu
```

### UEFI / BIOS

Querying BIOS or UEFI

```
ls /sys/firmware/efi/efivars
```

OR

```
efivar -l
```

> If the queries above do not return anything, then the system is running in BIOS (Legacy) mode. If a list is returned, the available UEFI functions will be listed

### Internet

#### Verifying the internet connection

```
ping -c 4 archlinux.org
ifconfig
```

### Time and Date

#### Setting time and date

```
timedatectl set-ntp true
```

### Disks

#### Querying disks

```
fdisk -l
```

#### Disk table creation or modification

Find your block device ID:

```
lsblk
```

> Note: block devices aren't all labeled /dev/sda as in the examples below (these are SATA devices). Other block device naming schemes exist such as nvme0pX, where the last character is the partition number.

```
parted /dev/sda
mklabel MSDOS

# or

mklabel gpt
```

#### Partitioning

```
cfdisk /dev/sda
```

*// This will open the `cfdisk` ncurses disk utility*

*// Example system configuration:*

> Do not copy unless you know the settings are correct for your desired layout.

`--> [ dos ]` *// If no option is presented, clear the current partition table with: `wipefs -a /dev/sda` OR `parted`*

`--> [ new ]` *// Create an EFI parition, if working in EFI mode (Type: `EFI F32`)*

`--> [ new ]` *// Create a system partition (Type: `Linux ext4`)*

`--> [ bootable ]` *// BOOT-flag (for BIOS / Legacy systems)*

`--> [ new ]` *// Create a /home partition (Type: `Linux ext4`)*

`--> [ new ]` *// Create a swap partition if desired (Type: `Linux swap`)*

`--> [ write ]` *// Write changes to disk*

`--> [ quit ]` *// Exit*

#### Create or format a filesystem

> /dev/sdaX represents the partition number of the corresponding partition you just created, such as /dev/sda1

*// Default filesystem for EFI partitions is FAT32*

```
mkfs.vfat /dev/sdaX
```

System partition

*// Default filesystem for the system partition is ext4*

```
mkfs.ext4 /dev/sdaX
```

Swap partition

*// Formatting the swap partition*

```
mkswap /dev/sdaX
```

*// Activating the swap partition*

```
swapon /dev/sdaX
```

#### Mounting partitions

*// The system partition is where the root filesystem will be located*

```
mount /dev/sdaX /mnt
```

*// If you have chosen to use a separate partition for your home folder, then create a mount point for that partition*

```
mkdir /mnt/home
```

*// The home partition will be where the /home folder is located*

```
mount /dev/sdaX /mnt/home
```

### Mirrors and base system install

#### Configuring pacman mirrorlist

```
vim /etc/pacman.d/mirrorlist
```

*// The best strategy is to place the closest server to you by geo-location to the top of the list*

#### Reflector

Alternatively, the `reflector` tool can be used to automatically sort mirrors according to various sorting methods.

*// reflector must be installed separately as it is not included in the LiveUSB image*

```
pacman -S reflector
```

*// The following example command will select the fastest mirror in a given country (using Hungary as an example)*

```
reflector --country Hungary --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```

Usage information [here](https://wiki.archlinux.org/index.php/Reflector).

#### Installing the base system

```
pacstrap /mnt base base-devel linux linux-firmware
```

> To solve hardware compatibility or stability issues resulting from the mainline kernel, use the `linux-lts` package

## Chapter 2 - The `chroot` Environment

Prepare to change from the LiveUSB to the destination filesystem.

*// Generate the fstab for the destination filesystem*

```
genfstab -U /mnt >> /mnt/etc/fstab
```

*// Change over to the destination filesystem*

```
arch-chroot /mnt
```

### Locale and Hostname

#### Timezone

```
ln -sf /usr/share/zoneinfo/Europe/Budapest /etc/localtime
```

#### System time

```
hwclock --systohc
```

#### Character encoding

```
vim /etc/locale.gen
```

*// Uncomment your desired locale's encoding option*

```
locale-gen
```

*// Optionally, depending on desired desktop environment (add with your desired locale to `/etc/locale.conf`)*

```
LANG=hu_HU.UTF-8
LC_ADDRESS=hu_HU.UTF-8
LC_COLLATE=hu_HU.UTF-8
LC_CTYPE=hu_HU.UTF-8
LC_IDENTIFICATION=hu_HU.UTF-8
LC_MEASUREMENT=hu_HU.UTF-8
LC_MESSAGES=hu_HU.UTF-8
LC_MONETARY=hu_HU.UTF-8
LC_NAME=hu_HU.UTF-8
LC_NUMERIC=hu_HU.UTF-8
LC_PAPER=hu_HU.UTF-8
LC_TELEPHONE=hu_HU.UTF-8
LC_TIME=hu_HU.UTF-8
```

#### Keyboard layout

*// Use your desired keyboard layout*

```
echo "KEYMAP=hu > /etc/vconsole.conf"
```

#### Hostname

*// Use your desired hostname here*

```
echo HOSTNAME > /etc/hostname
```

### Users

*// Generate root user password*

```
passwd
```

*// Add your user (-m modifier creates a home folder for the user)*

```
useradd -mg wheel exampleuser
```

*// Assign a password to user*

```
passwd exampleuser
```

*// To enable use of `sudo`, uncomment the following line in `/etc/sudoers`*

```
vim /etc/sudoers
```

*// Uncomment*

```
%wheel ALL=(ALL) ALL
```

### Packages

#### X.org

```
pacman -S dialog xorg xorg-xinit xorg-xauth xterm
```

#### GRUB

> Skip to the next section if using GRUB with UEFI

> Again, replace `/dev/sda` with the target block device you used above.

```
pacman -S grub
grub-mkconfig -o /boot/grub/grub.cfg
grub-install /dev/sda
```

#### GRUB + UEFI

*// UEFI boot requires both `grub` and `efibootmgr`*

```
pacman -S grub efibootmgr
```

*// If this command returns the error `cannot find EFI directory`, you didn't create your EFI partition correctly.*

> `/dev/sdaX is the efi partition you created in Chapter 1`

```
mkdir /efi
mount /dev/sdaX /efi
```

*// Install GRUB*

> You can use whatever value you like in as the `bootloader-id`. This will be the name of the UEFI entry created for Arch.

```
grub-install --target=x86_64-efi --efi-directory=efi --bootloader-id=ARCH
grub-mkconfig -o /boot/grub/grub.cfg
```

### Graphical environments

*// Some examples:*


```
pacman -S gnome
pacman -S lightdm lxde-gtk3
pacman -S lightdm mate
pacman -S lxdm i3-wm
```

#### Display manager initialization

##### GNOME

*// If you are using GNOME*

```
systemctl enable gdm
```

##### LXDE, MATE

*// If you are using LXDE or MATE*

```
systemctl enable lightdm
```

##### i3

*// A simple graphical login for i3wm is LXDM*

```
systemctl enable lxdm
```

#### Initializing the network daemon

> Some DE packages may not include a network manager, NetworkManager is recommended

```
pacman -S networkmanager
systemctl enable NetworkManager.service
```

#### Reboot

The final step is to exit chroot reboot into your freshly installed Arch installation:

```
exit
reboot
```

Congratulations and enjoy your new Arch system!
