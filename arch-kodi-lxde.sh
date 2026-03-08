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
sudo pacman -S --noconfirm kodi samba lirc


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

# Permissoes de usuario
chown -R kodish:kodish /home/kodish/.config

# Extras
pacman -S --noconfirm alsa-utils
pacman -S --noconfirm pipewire pipewire-pulse wireplumber zenity jq lutris
pacman -S --noconfirm noto-fonts-cjk kodi kodi-addon-inputstream-adaptive
pacman -S --noconfirm wget
pacman -S --noconfirm file-roller unzip unrar p7zip
pacman -S --noconfirm file-roller neofetch
pacman -S --noconfirm wine wine-mono wine-gecko lib32-gnutls vulkan-icd-loader lib32-vulkan-icd-loader
pacman -S --noconfirm ttf-liberation ttf-dejavu noto-fonts noto-fonts-emoji
pacman -S --noconfirm fuse2
pacman -S --noconfirm antimicrox
pacman -S --noconfirm  xorg-server xorg-xinit lxde-common lxsession openbox lxpanel pcmanfm
pacman -S lightdm lightdm-gtk-greeter







# Scripts externos
wget https://raw.githubusercontent.com/kodishmediacenter/Kodish_OS/refs/heads/master/scripts-kodish-gamer/name.sh
sh name.sh

mkdir -p /home/kodish/Desktop || mkdir -p "/home/kodish/Área de trabalho"
cd /home/kodish/Desktop 2>/dev/null || cd "/home/kodish/Área de trabalho"
wget https://raw.githubusercontent.com/kodishmediacenter/Kodish_OS/refs/heads/master/scripts-kodish-gamer/deckloader.desktop
chmod +x deckloader.desktop
chown kodish:kodish deckloader.desktop

wget https://raw.githubusercontent.com/kodishmediacenter/Kodish_OS/refs/heads/master/scripts-kodish-gamer/keyboardbr.sh
sh keyboardbr.sh

# Aliases
echo "alias update='sudo pacman -Syu && flatpak update -y'" >> /home/kodish/.bashrc
echo "alias iftk='f() { app_id=\${1##*/}; flatpak install  \"\$app_id\" -y; }; f'" >> /home/kodish/.bashrc
echo "alias ftk='sudo pacman -S install'" >> /home/kodish/.bashrc
echo "alias upgrade='sudo pacman -Syu'" >> /home/kodish/.bashrc
echo "alias stremio='flatpak run com.stremio.Stremio'" >> /home/kodish/.bashrc
echo "alias retrodeck='flatpak install flathub net.retrodeck.retrodeck'" >> /home/kodish/.bashrc
echo "alias fupdate='flatpak update -y && sudo flatpak update -y'" >> /home/kodish/.bashrc
echo "alias wallpaper='sudo nemo /usr/share/backgrounds/xfce'" >> /home/kodish/.bashrc
#echo 'neofetch' >> /home/kodish/.bashrc
chown kodish:kodish /home/kodish/.bashrc

# Autologin
wget https://raw.githubusercontent.com/kodishmediacenter/Kodish-OS-10/refs/heads/main/scripts-kodish-gamer/lightdm.conf
cat lightdm.conf > /etc/lightdm/lightdm.conf
groupadd -r autologin
gpasswd -a kodish autologin


# Instalar yay (Mudei pos)


sudo pacman -S  --noconfirm hardinfo


# criar o ambiente para pós instalação
mkdir /kodish
chmod 777 /kodish
mkdir /kodish/scripts 
chmod 777 /kodish/scripts 
cd /kodish/scripts 
wget https://raw.githubusercontent.com/kodishmediacenter/Kodish-OS-10/refs/heads/main/scripts-kodish-gamer/flatpaks.sh
wget https://raw.githubusercontent.com/kodishmediacenter/Kodish-OS-10/refs/heads/main/scripts-kodish-gamer/instalar_nyaa.sh
chmod +x instalar_nyaa.sh
./instalar_nyaa.sh

EOF

# ✅ Fim
echo -e "\n✅ Arch Linux com XFCE + Whisker, Steam, Multilib, Wi-Fi, Bluetooth e Codecs instalado com sucesso!"
