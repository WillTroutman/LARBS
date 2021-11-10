#!/bin/bash
# This is a script meant to be used to install Arch from the live installation disk
# You should read through it before using it, as it might not be appropriate for use

# is this needed for the live installation disk?
# should still at least do something to ensure internet connection is active
pacman -S --noconfirm dialog || { echo "Error at script start: Are you sure you're running this as the root user? Are you sure you have an internet connection?"; exit; }

dialog --defaultno --title "Simple Arch Installation" --yesno "This is an Arch install script that has been designed for my use.\nAs such, it may or may not work properly for you."  15 60 || exit

dialog --no-cancel --inputbox "Enter a name for your computer." 10 60 2> comp

dialog --defaultno --title "Time Zone select" --yesno "Do you want use the default time zone(America/New_York)?.\n\nPress no for select your own time zone"  10 60 && echo "America/New_York" > tz.tmp || tzselect > tz.tmp

dialog --no-cancel --inputbox "Enter partitionsize in gb, separated by space (swap & root)." 10 60 2>psize

pass1=$(dialog --no-cancel --passwordbox "Enter a root password." 10 60 3>&1 1>&2 2>&3 3>&1)
pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)

while true; do
	[[ "$pass1" != "" && "$pass1" == "$pass2" ]] && break
	pass1=$(dialog --no-cancel --passwordbox "Passwords do not match or are not present.\n\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
done

# why export? why not just use $pass1?
export pass="$pass1"

# figure out what this does
# looks like it makes an array to use for creating partitions, but I have no idea how
IFS=' ' read -ra SIZE <<< $(cat psize)
re='^[0-9]+$'
if ! [ ${#SIZE[@]} -eq 2 ] || ! [[ ${SIZE[0]} =~ $re ]] || ! [[ ${SIZE[1]} =~ $re ]] ; then
    SIZE=(12 25);
fi

timedatectl set-ntp true

# make the device a variable so it can work with devices other than sda
# also need to change the filesystem type for part1 to 1 and part2 to 19 (just add in t\n1 and t\n19? (with actual newline))
# change to gpt
# does this still work if partitions already have signatures?
# perhaps also add in option to not make part4 and add option for gpt and dos
cat <<EOF | fdisk /dev/sda
o	# create an empty dos table
n	# part1 created (boot)
p
+512M
n	# part2 created (swap)
p
+${SIZE[0]}G
n	# part3 created (root)
p
+${SIZE[1]}G
n	# part4 created (home)
p
w	# write changes to disk
EOF
# probably don't need this for fresh install
partprobe

# what does "yes" do?
# devices need to change here, too
yes | mkfs.ext4 /dev/sda4
yes | mkfs.ext4 /dev/sda3
yes | mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2
swapon /dev/sda2
mount /dev/sda3 /mnt
mkdir /mnt/{boot,home}
mount /dev/sda1 /mnt/boot
mount /dev/sda4 /mnt/home

# anything else needed?
pacstrap /mnt base base-devel linux linux-firmware

genfstab -U /mnt >> /mnt/etc/fstab
cp tz.tmp /mnt/tzfinal.tmp
rm tz.tmp

### BEGIN
arch-chroot /mnt echo "root:$pass" | chpasswd

# can't I just skip making this variable?
TZuser=$(cat tzfinal.tmp)

ln -sf /usr/share/zoneinfo/$TZuser /etc/localtime

hwclock --systohc

echo "LANG=en_US.UTF-8" >> /etc/locale.conf
# uncomment the proper line instead of adding an extra one
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

# why not do this with pacstrap earlier?
pacman --noconfirm --needed -S networkmanager
systemctl enable NetworkManager
systemctl start NetworkManager

# create option for systemd-boot or efiboot, or just replace grub altogether
pacman --noconfirm --needed -S grub && grub-install --target=i386-pc /dev/sda && grub-mkconfig -o /boot/grub/grub.cfg

# commented out for now, but will add option to also install my dotfiles when they are done
#pacman --noconfirm --needed -S dialog
#larbs() { curl -O https://raw.githubusercontent.com/WillTroutman/LARBS/master/src/larbs.sh && bash larbs.sh ;}
#dialog --title "Install Luke's Rice" --yesno "This install script will easily let you access Luke's Auto-Rice Boostrapping Scripts (LARBS) which automatically install a full Arch Linux i3-gaps desktop environment.\n\nIf you'd like to install this, select yes, otherwise select no.\n\nLuke"  15 60 && larbs

# why mv and not cat?
# need to edit /etc/hosts, too
mv comp /mnt/etc/hostname

# add option to stay in arch-chroot?
umount -R /mnt && reboot
