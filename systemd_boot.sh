#!/bin/sh

# Set XDG base directories
printf '%s\n' 'XDG_CACHE_HOME  DEFAULT=@{HOME}/.local/var/cache
XDG_CONFIG_HOME DEFAULT=@{HOME}/.local/etc
XDG_DATA_HOME   DEFAULT=@{HOME}/.local/share
XDG_STATE_HOME  DEFAULT=@{HOME}/.local/var/state
ZDOTDIR         DEFAULT=${XDG_CONFIG_HOME}/zsh' >>/etc/security/pam_env.conf

# Sets up systemd-boot.
bootctl install

echo "default arch.conf
timeout 0" > /boot/loader/loader.conf

echo "title    Arch Linux
linux    /vmlinuz-linux
initrd   /initramfs-linux.img
options  root=/dev/sda2 rw quiet loglevel=3 udev.log_level=3 nowatchdog mitigations=off modprobe.blacklist=iTCO_wdt video=eDP-1:d transparent_hugepage=madvise" > /boot/loader/entries/arch.conf
