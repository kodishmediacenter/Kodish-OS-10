#!/bin/bash
# Instala o reflector (nao vem no ISO)
pacman -Syu --noconfirm reflector wget

set -e

# Layout do teclado
loadkeys br-abnt2
timedatectl set-ntp true

# Detecta o maior disco
DISCO=$(lsblk -dpo NAME,SIZE,TYPE | grep -w disk | sort -k2 -h | tail -n1 | awk '{print $1}')
echo "Disco detectado: $DISCO"
read -rp "TODOS OS DADOS EM $DISCO SERÃO APAGADOS! Deseja continuar? (s/N): " CONFIRMA
[[ "$CONFIRMA" != "s" && "$CONFIRMA" != "S" ]] && exit 1

# Limpa disco
umount -R /mnt || true
wipefs -a "$DISCO"

# Particiona GPT
parted "$DISCO" --script mklabel gpt
parted "$DISCO" --script mkpart ESP fat32 1MiB 513MiB
parted "$DISCO" --script set 1 esp on
parted "$DISCO" --script mkpart primary ext4 513MiB 100%

# Define particoes
if [[ "$DISCO" == *"nvme"* ]]; then
  EFI="${DISCO}p1"
  ROOT="${DISCO}p2"
else
  EFI="${DISCO}1"
  ROOT="${DISCO}2"
fi

# Formata
mkfs.fat -F32 "$EFI"
mkfs.ext4 "$ROOT"

# Monta
mount "$ROOT" /mnt
mkdir -p /mnt/boot/efi
mount "$EFI" /mnt/boot/efi

# Pacotes principais
pacman -S --noconfirm archlinux-keyring
rm -f /var/cache/pacman/pkg/*.zst
pacstrap /mnt base linux linux-firmware vim sudo networkmanager grub efibootmgr os-prober mtools dosfstools

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 🛠️ Configuração no sistema
arch-chroot /mnt /bin/bash <<EOF

# Localizacao
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf

# Hostname
echo "archlinux" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   archlinux.localdomain archlinux
HOSTS

# NetworkManager
systemctl enable NetworkManager

# Suporte a Wi-Fi e Bluetooth
pacman -S --noconfirm iwd bluez bluez-utils blueman
systemctl enable iwd
systemctl enable bluetooth

# Usuario padrao
useradd -m -G wheel -s /bin/bash kodish
echo "kodish:kodish" | chpasswd
echo "root:root" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel

# Ativa deteccao de outros sistemas
echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
os-prober

# GRUB UEFI com fallback
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Set Mirror para Brasil 
pacman -S --noconfirm reflector
reflector --country Brazil --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Interface grafica XFCE + Xorg
pacman -S --noconfirm xorg 

# Ativa LightDM
systemctl enable lightdm
systemctl set-default graphical.target

# Ativa repositorio multilib
sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
pacman -Sy


# Codecs multimidia
pacman -S --noconfirm gst-libav gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly ffmpeg
pacman -S --noconfirm firefox flatpak gparted

# Instalar openssh
pacman -S --noconfirm ssh
systemctl enable sshd
systemctl start sshd


# Extras
pacman -S --noconfirm alsa-utils
pacman -S --noconfirm pipewire pipewire-pulse wireplumber zenity jq lutris
pacman -S --noconfirm noto-fonts-cjk kodi kodi-addon-inputstream-adaptive
pacman -S --noconfirm openbox arandr
pacman -S --noconfirm wget
pacman -S --noconfirm file-roller unzip unrar p7zip
pacman -S --noconfirm file-roller neofetch
pacman -S --noconfirm nemo
pacman -S --noconfirm wine wine-mono wine-gecko lib32-gnutls vulkan-icd-loader lib32-vulkan-icd-loader
pacman -S --noconfirm ttf-liberation ttf-dejavu noto-fonts noto-fonts-emoji
pacman -S --noconfirm fuse2

#

# ✅ Fim
echo -e "\n✅ Arch Linux com XFCE + Whisker, Steam, Multilib, Wi-Fi, Bluetooth e Codecs instalado com sucesso!"
