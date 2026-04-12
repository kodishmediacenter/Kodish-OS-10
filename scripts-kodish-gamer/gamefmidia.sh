# Converte Kodish OS Gaming para Media Center

# Atualizar os Pacotes
sudo pacman -Syy

# Remover os Pacotes Gamer  
sudo pacman -Rns lutris steam antimicrox

# Instalar os Pacotes Entretenimento
sudo pacman -S spotify-launcher handbrake-cli

# Instalar os Codecs
sudo pacman -S lame libmad libvorbis libvpx x264 x265
sudo pacman -S libdvdcss libdvdread libdvdnav
sudo pacman -S libva libva-utils

# Instalar os Flatpak
flatpak install flathub ca.littlesvr.asunder
flatpak install flathub com.stremio.Stremio
flatpak install flathub rocks.shy.VacuumTube

# Instalar pacotes 
sudo pacman -S unzip unrar 

# Remover deckloader 
rm -r /home/kodish/Desktop/deckloader.desktop
