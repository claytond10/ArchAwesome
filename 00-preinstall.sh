#!/usr/bin/env bash
#-------------------------------------------------------------------------
#  Arch Linux Post Install Setup and Config
#-------------------------------------------------------------------------
# git and curl are required prior to running

echo "-------------------------------------------------"
echo "Setting up mirrors for optimal download          "
echo "-------------------------------------------------"
iso=$(curl -4 ifconfig.co/country-iso)
timedatectl set-ntp true
pacman -S --noconfirm pacman-contrib terminus-font
setfont ter-v22b
pacman -S --noconfirm reflector rsync
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
mkdir /mnt


echo -e "\nInstalling prereqs...\n$HR"
pacman -S --noconfirm gptfdisk btrfs-progs

echo "-------------------------------------------------"
echo "-------select your disk to format----------------"
echo "-------------------------------------------------"
lsblk
echo "Please enter disk to work on: (example /dev/sda)"
read DISK
echo "THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK"
read -p "are you sure you want to continue (Y/N):" formatdisk

case $formatdisk in 
y|Y|yes|Yes|YES)
echo "--------------------------------------"
echo -e "\nFormatting disk...\n$HR"
echo "--------------------------------------"

# disk prep
sgdisk -Z ${DISK} # zap all on disk
sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1:0:+1000M ${DISK} # partition 1 (UEFI SYS), default start block, 1000MB
sgdisk -n 2:0+4G ${DISK}     # partition 2 (Swap)
sgdisk -n 3:0+5G  ${DISK}    # partition 3 (Home), default start, remaining
sgdisk -n 4:0:0  ${DISK}     # partition 4 (Root), default start, remaining

# set partition types
sgdisk -t 1:ef00 ${DISK}
sgdisk -t 2:8200 ${DISK}
sgdisk -t 3:8300 ${DISK}
sgdisk -t 4:8300 ${DISK}

# label partitions
sgdisk -c 1:"UEFISYS" ${DISK}
sgdisk -c 2:"SWAP" ${DISK}
sgdisk -c 3:"HOME" ${DISK}
sgdisk -c 4:"ROOT" ${DISK}

# make filesystems
echo -e "\nCreating Filesystems...\n"

mkfs.vfat -F32 -n "UEFISYS" "${DISK}1"
mkswap  -L "SWAP" "${DISK}2"
mkfs.btrfs -L "HOME" "${DISK}3"
mkfs.btrfs -L "ROOT" "${DISK}4"
;;
esac

# mount target
swapon "${DISK}2"
mount -t btrfs "${DISK}4" /mnt
mkdir -p /mnt/home "${DISK}3"
mount -t btrfs "${DISK}3" /mnt/home
mkdir /mnt/boot
mkdir /mnt/boot/efi
mount -t vfat "${DISK}1" /mnt/boot/

echo "--------------------------------------"
echo "-- Arch Install on Main Drive       --"
echo "--------------------------------------"
pacstrap /mnt base base-devel linux linux-firmware vim sudo archlinux-keyring wget libnewt --noconfirm --needed
genfstab -U /mnt >> /mnt/etc/fstab
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
echo "--------------------------------------"
echo "-- Bootloader Systemd Installation  --"
echo "--------------------------------------"
bootctl install --esp-path=/mnt/boot
[ ! -d "/mnt/boot/loader/entries" ] && mkdir -p /mnt/boot/loader/entries
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux  
linux /vmlinuz-linux  
initrd  /initramfs-linux.img  
options root=${DISK}4 rw 
EOF
cp -R ~/ArchMatic /mnt/root/
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

echo -ne "
-------------------------------------------------------------------------
                    Network Setup 
-------------------------------------------------------------------------
"
pacman -S --noconfirm --needed networkmanager dhclient
systemctl enable --now NetworkManager

echo "--------------------------------------"
echo "--   BEFOERE RUNNING 01-setup.sh,    --"
echo "--   RUN arch-chrppat and passwd to  --"
echo "--    SET THE ROOT PASSWORD!         --"
echo "---------------------------------------"

