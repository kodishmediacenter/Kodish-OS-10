sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
sudo mv /etc/pacman.conf /etc/pacman.conf.bkp
sudo cd /etc/
sudo wget https://raw.githubusercontent.com/kodishmediacenter/Kodish-OS-10/refs/heads/main/scripts-kodish-gamer/pacman.conf
sudo mv pacman.conf /etc
sudo pacman -Syy
