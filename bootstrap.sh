#!/bin/sh

###--- FUNCTIONS ---###

install_package() { pacman --noconfirm --needed -S "$1" >/dev/null 2>&1; }

error() { printf "EXIT STATUS:\\n%s\\n" "$1"; exit; }

refresh_keys() { \
	echo "Refreshing Arch keyrings... "
	pacman --noconfirm --needed -Sy archlinux-keyring >/dev/null 2>&1; 
}

temp_permissions() { \
	echo "Creating temporary permissions in /etc/sudoers..."
	sed -i "/#bootstrap-temp/d" /etc/sudoers
	echo "%wheel ALL=(ALL) NOPASSWD: ALL #bootstrap-temp" >> /etc/sudoers
}

install_req() { \
	echo "Installing core packages and synching times..."
	echo "   Installing curl..."
	pacman --noconfirm --needed -S curl >/dev/null 2>&1; 
	echo "   Installing base-devel..."
	pacman --noconfirm --needed -S base-devel >/dev/null 2>&1; 
	echo "   Installing git..."
	pacman --noconfirm --needed -S git >/dev/null 2>&1; 
	echo "   Installing ntp..."
	pacman --noconfirm --needed -S ntp >/dev/null 2>&1;

	echo "   Synching clocks with ntpdate..."
	ntpdate 0.uk.pool.ntp.org >/dev/null 2>&1	
}

welcome() { \
	read -p "---- WELCOME! ---- `echo $'\n   '`Welcome to Arch (Artix) Bootstrap script. `echo $'\n   '`Are you ready to dive in (Y/n): " check
	echo "------------------"

	if [ "$check" != "Y" ]; then
		exit;
	fi
}

user_check() { \
	read -p "Please enter a username: " name

	if [ `id -u "$name" >/dev/null 2>&1` ]; then
		read -p "---- WARNING! ---- `echo $'\n   '`By proceeding you will overwrite the HOME directory of the $name (inc. all data and .dotfiles) `echo $'\n   '`Are you sure you want to proceed (Y/n): " check
	echo "------------------"
	else
		check="Y"	
	fi

	if [ "$check" != "Y" ]; then
		exit;
	fi
}

create_user() { \
	read -sp "Please enter a password: " pass1
	echo
	read -sp "Please re-enter password: " pass2

	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		echo
		echo "-- Error: Passwords don't match ---"
		read -sp "Please enter a password: " pass1
		echo
		read -sp "Please re-enter password: " pass2
	done ;
	
	echo
	echo "------------------"	
	echo "Adding user $name..."
	useradd -m -g wheel -s /bin/bash "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel "$name" >/dev/null 2>&1 && mkdir -p /home/"$name" >/dev/null 2>&1 && chown "$name":wheel /home/"$name"

	echo "$name:$pass1" | chpasswd
	unset pass1 pass2 ;
	echo "Successfully created user $name..."

	echo "Creating home directory folders $name..."
	gitmk_bin="/home/$name/.local/mkpkg/" ; mkdir -p "$gitmk_bin" ; chown -R "$name":wheel $(dirname "$gitmk_bin")
	bin="/home/$name/.local/bin/" ; mkdir -p "$bin" ; chown -R "$name":wheel $(dirname "$bin")
	configs="/home/$name/.dot/" ; mkdir -p "$configs" ; chown -R "$name":wheel $(dirname "$configs")
	downloads="/home/$name/Downloads/" ; mkdir -p "$downloads" ; chown -R "$name":wheel $(dirname "$downloads")
	wallpapers="/home/$name/Wallpapers/" ; mkdir -p "$wallpapers" ; chown -R "$name":wheel $(dirname "$wallpapers")

	echo "------------------"	
}

final_check() { \
	read -p "---- LAST CHANCE TO EXIT! ---- `echo $'\n   '`Last chance to exit before package installs, .dotfile creation, and initialisation. `echo $'\n   '`Are you sure you want to proceed (Y/n): " check
	echo "------------------"

	if [ "$check" != "Y" ]; then
		exit;
	fi
}

install_core() { \
	sed '/^tag/d' .pkgs/core_pkgs.csv | cut -d ',' -f2 > /tmp/corepkgs
	
	while x=, read -r pkg; do
		install_package "$pkg" 
	done < /tmp/corepkgs
}

install_gitmk() { \
	sed '/^name/d' .pkgs/gitmk_pkgs.csv | cut -d ',' -f1 -f2 > /tmp/gitpkgs
	
	while x=, read -r repo url; do
		echo "Installing $repo from shaun-moate/$repo.git...." 
		sudo -u "$name" git clone "$url" "$gitmk_bin/$name" >/dev/null 2>&1
	        cd "$gitmk_bin/$name" || exit
		make >/dev/null 2>&1
		make install >/dev/null 2>&1
	done < /tmp/gitpkgs
}

install_configs() { \
	sed '/^config/d' .pkgs/configs.csv | cut -d ',' -f1 > /tmp/configs
	
	echo "Installing .dotfiles from shaun-moate/.dotfiles.git..."
	sudo -u "$name" git clone https://github.com/shaun-moate/.dotfiles.git "$configs" >/dev/null 2>&1

	echo "Creating syslinks for each .dotfile to better manage git_repo..."
	while x=, read -r cfg; do
		rm "/home/$name/$cfg" >/dev/null 2>&1 ; ln -sf "$configs/$cfg" "/home/$name/$cfg" 
	done < /tmp/configs
}

install_wallpaper() { \
	echo "Installing wallpapers from shaun-moate/wallpaper.git..."
	sudo -u "$name" git clone https://github.com/shaun-moate/wallpaper.git "$wallpapers" >/dev/null 2>&1
}

install_bin() { \
	echo "Installing useful .sh from shaun-moate/bin.git..."
	sudo -u "$name" git clone https://github.com/shaun-moate/bin.git "$bin" >/dev/null 2>&1
}

###--- INIT ---###
install_package dialog || error "Are you sure you have access to the internet and are running as ROOT?"
welcome || error "Exited bootstrap @ 00 welcome"
user_check || error "Exited bootstrap @ 01 user_check"
create_user || error "Exited bootstrap @ 02 create_user"
final_check || error "Exited bootstrap @ 03 final_check"
refresh_keys || error "Exited bootstrap @ 04 refresh_keys"
install_req || error "Exited bootstrap @ 05 install_req"
temp_permissions || error "Exited bootstrap @ 06 temp_permissions"
install_core || error "Exited bootstrap @ 07 install_core"
install_gitmk || error "Exited bootstrap @ 08 install_gitmk"
install_wallpaper || error "Exited bootstrap @ 09 install_wallpaper"
install_bin || error "Exited bootstrap @ 10 install_bin"
install_configs || error "Exited bootstrap @ 11 install_configs"

echo "Bootstrap is now COMPLETE!"
