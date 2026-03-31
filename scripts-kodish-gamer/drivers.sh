#!/bin/bash

echo "Detectando GPU..."
GPU=$(lspci | grep -E "VGA|3D")

if echo "$GPU" | grep -i nvidia; then
    echo "Instalando NVIDIA + Vulkan"
    sudo pacman -S --noconfirm nvidia-lts nvidia-utils lib32-nvidia-utils
elif echo "$GPU" | grep -i amd; then
    echo "Instalando AMD + Vulkan"
    sudo pacman -S --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
elif echo "$GPU" | grep -i intel; then
    echo "Instalando Intel + Vulkan"
    sudo pacman -S --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel
else
    echo "GPU não detectada"
fi

echo "Instalando Vulkan comum..."
sudo pacman -S --noconfirm vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools

echo "Instalando extras para jogos..."
sudo pacman -S --noconfirm gamemode mangohud lib32-gamemode lib32-mangohud

echo "Finalizado. Reinicie."
