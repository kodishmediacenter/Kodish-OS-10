#!/bin/bash

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
flatpak install flathub net.davidotek.pupgui2

# Correção google chrome  
flatpak override --user com.google.Chrome --filesystem=xdg-download
flatpak override --user com.google.Chrome --filesystem=home
sudo pacman -S xdg-desktop-portal xdg-desktop-portal-gtk
flatpak override --user com.google.Chrome --filesystem=home
systemctl --user status xdg-desktop-portal
systemctl --user restart xdg-desktop-portal
