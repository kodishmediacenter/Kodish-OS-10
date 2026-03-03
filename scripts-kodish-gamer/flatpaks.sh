#!/bin/bash
# Script para Kodish OS 10 Pos Instalação

# Flatpak 
flatpak install flathub com.google.Chrome -y 
flatpak install flathub com.heroicgameslauncher.hgl -y
flatpak install flathub com.vysp3r.ProtonPlus -y 

#flatpak install flathub net.retrodeck.retrodeck
flatpak install flathub com.stremio.Stremio -y
flatpak install flathub dev.aunetx.deezer -y 
flatpak install flathub com.github.louis77.tuner -y
flatpak install flathub org.libretro.RetroArch -y 
flatpak install flathub it.mijorus.gearlever -y
flatpak install flathub net.davidotek.pupgui2 -y
flatpak install flathub io.github.kolunmi.Bazaar -y
flatpak install flathub com.obsproject.Studio -y


# Correção google chrome  
flatpak override --user com.google.Chrome --filesystem=xdg-download
flatpak override --user com.google.Chrome --filesystem=home
sudo pacman -S xdg-desktop-portal xdg-desktop-portal-gtk
flatpak override --user com.google.Chrome --filesystem=home
systemctl --user status xdg-desktop-portal
systemctl --user restart xdg-desktop-portal


# Instalando Suporte Aur 
pacman -S --noconfirm git base-devel
cd /opt
sudo git clone https://aur.archlinux.org/yay.git
sudo chown -R kodish:kodish yay
cd yay
makepkg -si
