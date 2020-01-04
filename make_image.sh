#!/bin/sh
#
# DigitalOcean Archlinux custom image script.
# Might be of use for other virtual enviroments that can use a raw disk
#
# Written by: Derek Robson <robsonde at gmail>
# 

# Add any extra packages here as a space separated list
Core_Packages="base linux linux-firmware gettext inetutils jfsutils logrotate netctl s-nail sysfsutils "
Required_Packages="texinfo usbutils util-linux xfsprogs openssh grub wget gptfdisk git parted "
Optional_Packages="base-devel haveged nano vi "


# Check we have the right tools installed.
which sgdisk > /dev/null 2>&1 
if [ $? -ne 0 ]; then
	echo "Can't find sgdisk"
	echo "Try adding package gptfdisk"
	exit 1
fi

which pacstrap > /dev/null 2>&1 
if [ $? -ne 0 ]; then
	echo "Can't find pacstrap"
	echo "Try adding package arch-install-scripts"
	exit 1
fi


# What is the name of image file?
ImageFile=$1


# Remove any old version of image file.
[ -e "${ImageFile}" ] && rm "${ImageFile}"
[ -e "${ImageFile}.gz" ] && rm "${ImageFile}.gz"


# Start by making a 5GB disk, this could be smaller.
fallocate -l 5120000000 $ImageFile
if [ $? -ne 0 ]; then
	echo "Can't allocate disk space!"
	exit 1
fi


# Use sgdisk to do disk layout
# GPT, with BIOS boot and GRUB
sgdisk -Z $ImageFile
sgdisk -n=1:0:+10M $ImageFile
sgdisk -n=2:0:+5M $ImageFile
sgdisk -n=3:0:0 $ImageFile
sgdisk -c=1:DORoot $ImageFile
sgdisk -c=2:BIOSBoot $ImageFile
sgdisk -c=3:ArchRoot $ImageFile
sgdisk -t=1:8300 $ImageFile
sgdisk -t=2:EF02 $ImageFile
sgdisk -t=3:8300 $ImageFile


# Find and setup loop back mount points
LoopDev=`losetup -f --show -P $ImageFile`
if [ $? -ne 0 ]; then
	echo "Can't setup loopback devices!"
	exit 1
fi


# Create file systems
# NOTE: P1 is the magic DigitalOcean slice.
# NOTE: P2 is the GRUB BIOS slice.
# NOTE: P3 is the root file system.
mkfs.ext4 "${LoopDev}p1"
mkfs.ext4 "${LoopDev}p3"


# Mount the new root file system to /mnt
mount "${LoopDev}p3" /mnt
if [ $? -ne 0 ]; then
	echo "Can't mount the new root file system!"
	exit 1
fi


# pacstrap install things, this is the place to add packages
pacstrap -c -M /mnt $Core_Packages $Required_Packages $Optional_Packages
if [ $? -ne 0 ]; then
	echo "Something went wrong during install of image!"
	exit 1
fi


# We need an fstab
UUID=`blkid -s UUID -o value "${LoopDev}p3"`
echo "# RootFileSystem" >> /mnt/etc/fstab
echo "UUID=${UUID}	/	ext4	rw,relatime	0 1" >> /mnt/etc/fstab


# We need a name servers, if you want different DNS, this is the place to change it.
echo 'nameserver 8.8.8.8' > /mnt/etc/resolv.conf


# Enable all the kernel mirrors.
sed -i '/^#.*kernel/s/^#//' /mnt/etc/pacman.d/mirrorlist


# Set blank machine-id so that a new machine-id is created on first boot.
echo "" > /mnt/etc/machine-id


# Add kernel modules we need for DigitalOcean support.
sed -i 's/MODULES=()/MODULES=(serio_raw floppy ata_piix virtio_scsi virtio_balloon uhci-hcd i8042 libps2 ehci-hcd virtio_net serio atkbd ata_generic failover virtio_pci ehci-pci net_failover pata_acpi)/' /mnt/etc/mkinitcpio.conf


# Write the disk resize script. 
cat << EOF > /mnt/usr/bin/disk_resize.sh
#!/bin/sh
sgdisk -d=3 /dev/vda
sgdisk -n=3:0:0 /dev/vda
sgdisk -c=3:ArchRoot /dev/vda
partprobe /dev/vda
resize2fs /dev/vda3
systemctl disable disk_resize
rm /etc/systemd/system/disk_resize.service
exit 0
EOF

chmod 755 /mnt/usr/bin/disk_resize.sh


# Write the disk resize service file 
cat << EOF > /mnt/etc/systemd/system/disk_resize.service
[Unit]
Description=Disk resize magic

[Service]
ExecStart=/bin/bash -c /usr/bin/disk_resize.sh

[Install]
WantedBy=multi-user.target
EOF


# Write the post install script. 
cat << EOF > /mnt/post_install.sh
#!/bin/sh
mkinitcpio -p linux
/usr/bin/grub-install --target=i386-pc ${LoopDev}
/usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
cd /tmp
sudo -u nobody git clone https://github.com/robsonde/digital-ocean-synchronize-AUR
cd digital-ocean-synchronize-AUR
sudo -u nobody makepkg
pacman --noconfirm -U *.pkg.tar.xz
systemctl enable systemd-timesyncd.service
systemctl enable sshd.service
systemctl enable haveged.service
systemctl enable systemd-networkd.service
systemctl enable disk_resize.service
EOF


chmod 755 /mnt/post_install.sh

# Run the post install inside he new image.
arch-chroot /mnt /post_install.sh
rm /mnt/post_install.sh

# Clean up
umount /mnt
losetup -D

echo "Compressing image"
gzip -k $ImageFile
if [ $? -ne 0 ]; then
	echo "Something went wrong during compress of image!"
	exit 1
fi

exit 0
