#!/bin/sh

# Sets up systemd-boot.
bootctl install

echo "default arch.conf
timeout 0" > /boot/loader/loader.conf

echo "title    Arch Linux
linux    /vmlinuz-linux
initrd   /intel-ucode.img
initrd   /initramfs-linux.img
options  root=/dev/sda2 rw quiet loglevel=3 udev.log_level=3 nowatchdog mitigations=off modprobe.blacklist=iTCO_wdt video=eDP-1:d transparent_hugepage=madvise" > /boot/loader/entries/arch.conf
