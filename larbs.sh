#!/bin/sh

# Luke's Auto Rice Bootstrapping Script (LARBS)
# by Luke Smith <luke@lukesmith.xyz>
# License: GNU GPLv3

### OPTIONS AND VARIABLES ###

dotfilesrepo="https://github.com/PlaySomeJazz/dotfiles.git"
progsfile="https://raw.githubusercontent.com/PlaySomeJazz/coffee/master/progs.csv"
aurhelper="yay"
repobranch="master"
export TERM=ansi

### FUNCTIONS ###

installpkg() {
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

welcomemsg() {
	whiptail --title "Welcome!" \
		--msgbox "Welcome to Luke's Auto-Rice Bootstrapping Script!\\n\\nThis script will automatically install a fully-featured Linux desktop, which I use as my main machine.\\n\\n-Luke" 10 60

	whiptail --title "Important Note!" --yes-button "All ready!" \
		--no-button "Return..." \
		--yesno "Be sure the computer you are using has current pacman updates and refreshed Arch keyrings.\\n\\nIf it does not, the installation of some programs might fail." 8 70
}

getuserandpass() {
	# Prompts user for new username and password.
	name=$(whiptail --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(whiptail --nocancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(whiptail --nocancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(whiptail --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

usercheck() {
	! { id -u "$name" >/dev/null 2>&1; } ||
		whiptail --title "WARNING" --yes-button "CONTINUE" \
			--no-button "No wait..." \
			--yesno "The user \`$name\` already exists on this system. LARBS can install for a user already existing, but it will OVERWRITE any conflicting settings/dotfiles on the user account.\\n\\nLARBS will NOT overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that LARBS will change $name's password to the one you just gave." 14 70
}

preinstallmsg() {
	whiptail --title "Let's get this party started!" --yes-button "Let's go!" \
		--no-button "No, nevermind!" \
		--yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || {
		clear
		exit 1
	}
}

adduserandpass() {
	# Adds user `$name` with password $pass1.
	whiptail --infobox "Adding user \"$name\"..." 7 50
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
		usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	export repodir="/home/$name/.local/src"
	export config="/home/$name/.local/etc"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2
}

refreshkeys() {
	case "$(readlink -f /sbin/init)" in
	*systemd*)
		whiptail --infobox "Refreshing Arch Keyring..." 7 40
		pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
		;;
	*)
		whiptail --infobox "Enabling Arch Repositories for more a more extensive software collection..." 7 40
		pacman --noconfirm --needed -S \
			artix-keyring artix-archlinux-support >/dev/null 2>&1
		grep -q "^\[extra\]" /etc/pacman.conf ||
			echo "[extra]
Include = /etc/pacman.d/mirrorlist-arch" >>/etc/pacman.conf
		pacman -Sy --noconfirm >/dev/null 2>&1
		pacman-key --populate archlinux >/dev/null 2>&1
		;;
	esac
}

manualinstall() {
	# Installs $1 manually. Used only for AUR helper here.
	# Should be run after repodir is created and var is set.
	pacman -Qq "$1" && return 0
	whiptail --infobox "Installing \"$1\" manually." 7 50
	sudo -u "$name" mkdir -p "$repodir/$1"
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
		--no-tags -q "https://aur.archlinux.org/$1.git" "$repodir/$1" ||
		{
			cd "$repodir/$1" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$repodir/$1" || exit 1
	sudo -u "$name" \
		makepkg --noconfirm -si >/dev/null 2>&1 || return 1
}

maininstall() {
	# Installs all needed programs from main repo.
	whiptail --title "LARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 9 70
	installpkg "$1"
}

gitmakeinstall() {
	progname="${1##*/}"
	progname="${progname%.git}"
	dir="$repodir/$progname"
	whiptail --title "LARBS Installation" \
		--infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 8 70
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
		--no-tags -q "$1" "$dir" ||
		{
			cd "$dir" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$dir" || exit 1
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return 1
}

aurinstall() {
	whiptail --title "LARBS Installation" \
		--infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 9 70
	echo "$aurinstalled" | grep -q "^$1$" && return 1
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
}

pipxinstall() {
	whiptail --title "LARBS Installation" \
		--infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 9 70
	sudo -u "$name" pipx install "$1" >/dev/null 2>&1
}

installationloop() {
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) ||
		curl -Ls "$progsfile" | sed '/^#/d' >/tmp/progs.csv
	total=$(wc -l </tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
	while IFS=, read -r tag program comment; do
		n=$((n + 1))
		echo "$comment" | grep -q "^\".*\"$" &&
			comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"
		case "$tag" in
		"A") aurinstall "$program" "$comment" ;;
		"G") gitmakeinstall "$program" "$comment" ;;
		"P") pipxinstall "$program" "$comment" ;;
		*) maininstall "$program" "$comment" ;;
		esac
	done </tmp/progs.csv
}

putgitrepo() {
	# Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	whiptail --infobox "Downloading and installing config files..." 7 60
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown "$name":wheel "$dir" "$2"
	sudo -u "$name" git -C "$repodir" clone --depth 1 \
		--single-branch --no-tags -q --recursive -b "$branch" \
		--recurse-submodules "$1" "$dir"
	sudo -u "$name" cp -rfT "$dir" "$2"
}

vimplugininstall() {
	# Installs vim plugins.
	whiptail --infobox "Installing neovim plugins..." 7 60
	mkdir -p "$config/nvim/autoload"
	curl -Ls "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" >  "$config/nvim/autoload/plug.vim"
	chown -R "$name:wheel" "$config/nvim"
	sudo -u "$name" nvim -c "PlugInstall|q|q"
}

fix_mpv_ytdl() {
	whiptail --infobox "Fixing youtube throttling when using mpv..." 7 60
	sudo -u "$name" rustup default stable >/dev/null 2>&1
	sudo -u "$name" git -C "$repodir" clone -q "https://gist.github.com/253347b2c9a53bbd6087f086970106b6.git" "$repodir/ytrangefix"
	cd "$repodir/ytrangefix" || return 1
	sudo -u "$name" mkdir src
	sudo -u "$name" cp main.rs src/
	sudo -u "$name" cargo build --release >/dev/null 2>&1
	scriptdir="$config/mpv/scripts/ytrangefix"
	sudo -u "$name" mkdir -p "$scriptdir"
	sudo -u "$name" cp target/release/http-ytproxy "$scriptdir/"
	sudo -u "$name" cp ytproxy.lua "$scriptdir/main.lua"
	cd "$scriptdir" || return 1
	sudo -u "$name" openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 3650 -passout pass:"third-wheel" -subj "/C=US/ST=private/L=province/O=city/CN=hostname.example.com" >/dev/null 2>&1
	cd /tmp || return 1
}

finalize() {
	whiptail --title "All done!" \
		--msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1).\\n\\n.t Luke" 13 80
}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Arch distro. Install whiptail.
pacman --noconfirm --needed -Sy libnewt ||
	error "Are you sure you're running this as the root user, are on an Arch-based distribution and have an internet connection?"

# Welcome user and pick dotfiles.
welcomemsg || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

# Give warning if user already exists.
usercheck || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

# Refresh Arch keyrings.
refreshkeys ||
	error "Error automatically refreshing Arch keyring. Consider doing so manually."

for x in curl ca-certificates base-devel git ntp zsh dash; do
	whiptail --title "LARBS Installation" \
		--infobox "Installing \`$x\` which is required to install and configure other programs." 8 70
	installpkg "$x"
done

whiptail --title "LARBS Installation" \
	--infobox "Synchronizing system time to ensure successful and secure installation of software..." 8 70
ntpd -q -g >/dev/null 2>&1

adduserandpass || error "Error adding username and/or password."

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
trap 'rm -f /etc/sudoers.d/larbs-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL
Defaults:%wheel,root runcwd=*" >/etc/sudoers.d/larbs-temp

# Make pacman colorful, concurrent downloads and Pacman eye-candy.
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

manualinstall $aurhelper || error "Failed to install AUR helper."

# Make sure .*-git AUR packages get updated automatically.
$aurhelper -Y --save --devel

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop

# Install the dotfiles in the user's home directory, but remove .git dir and
# other unnecessary files.
putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
rm -rf "/home/$name/.git/" "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml" "$config/firefox/latest.xpi"

# Install vim plugins if not alread present.
[ ! -f "$config/nvim/autoload/plug.vim" ] && vimplugininstall

# Disable automatic core dumps
echo "kernel.core_pattern=/dev/null" >/etc/sysctl.d/50-coredump.conf

# Prevent excessive disk head parking
echo 'ACTION=="add", SUBSYSTEM=="block", KERNEL=="sda", RUN+="/usr/bin/hdparm -B 254 -S 0 /dev/sda"' >/etc/udev/rules.d/69-hdparm.rules

# Disable journal writing to disk
sed -i 's/^#Storage=auto$/Storage=none/' /etc/systemd/journald.conf

# Improve font rendering
sed -i '/export FREETYPE_PROPERTIES="truetype:interpreter-version=40"/s/^#//' /etc/profile.d/freetype2.sh

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.local/var/cache/zsh/"
sudo -u "$name" mkdir -p "$config/mpd/playlists/"

# Make dash the default #!/bin/sh symlink.
ln -sfT dash /usr/bin/sh >/dev/null 2>&1

# Transfer some settings over
curl -s -o /usr/local/bin/dra-cla "https://raw.githubusercontent.com/CoolnsX/dra-cla/refs/heads/main/dra-cla"; chown "$name":wheel /usr/local/bin/dra-cla
chmod 755 /usr/local/bin/dra-cla
sudo -u "$name" mkdir -p "$config/nsxiv/exec"
sudo -u "$name" ln -sf "/home/$name/.local/bin/key-handler" "$config/nsxiv/exec/key-handler"
mkdir -p /etc/firefox/policies
mkdir -p /etc/pacman.d/hooks
mkdir -p /usr/local/lib
mv "/home/$name/.local/share/temp/cleanup-packages" /usr/local/lib/cleanup-packages; chown root:root /usr/local/lib/cleanup-packages; chmod 755 /usr/local/lib/cleanup-packages
mv "/home/$name/.local/bin/tordone" /usr/local/bin/tordone; chown "$name":wheel /usr/local/bin/tordone
#mv "/home/$name/.local/share/temp/intel-undervolt.conf" /etc/intel-undervolt.conf
mv "/home/$name/.local/share/temp/phantomjs" /usr/bin/phantomjs
mv "/home/$name/.local/share/temp/ff2mpv-rust" /usr/local/bin/ff2mpv-rust
mv "/home/$name/.local/share/temp/betterfox_updater" /usr/local/bin/betterfox_updater; chown "$name":wheel /usr/local/bin/betterfox_updater
mv "/home/$name/.local/share/temp/keyd_config" /etc/keyd/default.conf
mv "/home/$name/.local/share/temp/updatedb.conf" /etc/updatedb.conf
mv "/home/$name/.local/share/temp/60-ioschedulers.rules" /etc/udev/rules.d/60-ioschedulers.rules
mv "/home/$name/.local/share/temp/policies.json" /etc/firefox/policies/policies.json
mv "/home/$name/.local/share/temp/package_cleanup.hook" /etc/pacman.d/hooks/package_cleanup.hook
mv "/home/$name/.local/share/temp/relink_dash.hook" /etc/pacman.d/hooks/relink_dash.hook
mv "/home/$name/.local/share/temp/95-systemd-boot.hook" /etc/pacman.d/hooks/95-systemd-boot.hook
mv "/home/$name/.local/share/temp/99-sysctl.conf" /etc/sysctl.d/99-sysctl.conf
mv "/home/$name/.local/share/temp/blacklist.conf" /etc/modprobe.d/blacklist.conf
rm -rf "/home/$name/.local/share/temp"
systemctl enable keyd

# Configure Emby
mkdir /media_files
mkdir /media_files/movies
mkdir /media_files/tv
mkdir /media_files/torrents
mkdir /etc/systemd/system/emby-server.service.d
groupadd media
usermod -aG media "$name"
chgrp -R media /media_files
find /media_files -type f -exec chmod 664 {} +
find /media_files -type d -exec chmod 775 {} +
find /media_files -type d -exec chmod g+s {} +
echo "[Service]
SupplementaryGroups=media
ReadWritePaths=/media_files
UMask=0002" >/etc/systemd/system/emby-server.service.d/write-permissions.conf

# Enable undervolting service
#systemctl enable intel-undervolt.service

# Enable tap to click
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
	# Enable left mouse button by tapping
	Option "Tapping" "on"
EndSection' >/etc/X11/xorg.conf.d/40-libinput.conf

# Cleanup some cache every week
echo "e  /home/$name/.cache/lf/ - - - 7d
e  /home/$name/.cache/ueberzugpp/ - - - 7d" > /etc/tmpfiles.d/cleanup-previews.conf

# All this below to get Firefox installed with add-ons and non-bad settings.

whiptail --infobox "Setting browser privacy settings and add-ons..." 7 60

browserdir="$config/mozilla/firefox"
profilesini="$browserdir/profiles.ini"

# Start Firefox headless so it generates a profile. Then get that profile in a variable.
sudo -u "$name" firefox --headless >/dev/null 2>&1 &
sleep 40
profile="$(sed -n "/Default=.*.default-release/ s/.*=//p" "$profilesini")"
pdir="$browserdir/$profile"

# Continue with Firefox configuration
t="/tmp/f$$"
curl -sL -o $t "https://raw.githubusercontent.com/yokoffing/Betterfox/refs/heads/main/user.js"
cat "$config/firefox/custom.js" $t > "$config/firefox/user.js"
sudo -u "$name" ln -sf "$config/firefox/user.js" "$pdir/user.js"
sudo -u "$name" mkdir "/home/$name/.local/etc/mozilla/native-messaging-hosts/"
sudo -u "$name" mv "$config/firefox/ff2mpv.json" "/home/$name/.local/etc/mozilla/native-messaging-hosts/ff2mpv.json"
rm -f $t

# Kill the now unnecessary Firefox instance.
pkill -u "$name" firefox

# Enable audio
sudo -u "$name" systemctl --user enable pipewire mpd

# Tune fstab
awk '{if ($3 == "ext4") print $1" "$2"\t"$3"\t"$4",commit=60 "$5"\t"$6; else print}' /etc/fstab > /etc/fstab.new
mv /etc/fstab.new /etc/fstab

# Fix mpv buffering when using yt-dlp
fix_mpv_ytdl

# Switch to Cloudflare DNS
printf "nameserver 1.1.1.1\nnameserver 1.0.0.1" > /etc/resolv.conf.manually-configured
rm /etc/resolv.conf
ln -s /etc/resolv.conf.manually-configured /etc/resolv.conf

# Allow wheel users to sudo with password and allow several system commands
# (like `shutdown` to run without password).
echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-wheel-can-sudo
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >/etc/sudoers.d/01-cmds-without-password
echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-visudo-editor
mkdir -p /etc/sysctl.d
echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf

# Enable NTP
mkdir -p /etc/systemd/timesyncd.conf.d
printf '%s\n' "[Time]
RootDistanceMaxSec=0.1
PollIntervalMinSec=1d
PollIntervalMaxSec=4w
SaveIntervalSec=infinity" >/etc/systemd/timesyncd.conf.d/local.conf
timedatectl set-ntp true

# Cleanup
rm -f /etc/sudoers.d/larbs-temp

# Last message! Install complete!
finalize
