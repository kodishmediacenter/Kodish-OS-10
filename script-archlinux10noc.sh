#!/bin/bash
set -euo pipefail
clear
printf "\e[0;32m[===============================================================]\e[m %s\n" "${1:-}";
echo "++++++++++ Bem Vindo A Instalação Kodish OS 10 Gamer ++++++++++"
printf "\e[0;32m[===============================================================]\e[m %s\n" "${1:-}";

# Instala ferramentas usadas no instalador live
pacman -Syu --noconfirm reflector wget parted dosfstools

# Layout do teclado / relogio
loadkeys br-abnt2
timedatectl set-ntp true

# O script e destinado a uma maquina UEFI
if [[ ! -d /sys/firmware/efi ]]; then
    echo "ERRO: inicialize o ISO do Arch em modo UEFI antes de executar este script."
    exit 1
fi

# Detecta o maior disco
DISCO=$(lsblk -dpo NAME,SIZE,TYPE | awk '$3=="disk" {print $0}' | sort -k2 -h | tail -n1 | awk '{print $1}')
if [[ -z "${DISCO}" ]]; then
    echo "ERRO: nenhum disco foi detectado."
    exit 1
fi

echo "Disco detectado: $DISCO"
read -rp "TODOS OS DADOS EM $DISCO SERÃO APAGADOS! Deseja continuar? (s/N): " CONFIRMA
[[ "$CONFIRMA" != "s" && "$CONFIRMA" != "S" ]] && exit 1

# Limpa disco
umount -R /mnt 2>/dev/null || true
wipefs -a "$DISCO"

# Particiona GPT
parted "$DISCO" --script mklabel gpt
parted "$DISCO" --script mkpart ESP fat32 1MiB 513MiB
parted "$DISCO" --script set 1 esp on
parted "$DISCO" --script mkpart primary ext4 513MiB 100%

# Define particoes
if [[ "$DISCO" == *"nvme"* || "$DISCO" == *"mmcblk"* ]]; then
    EFI="${DISCO}p1"
    ROOT="${DISCO}p2"
else
    EFI="${DISCO}1"
    ROOT="${DISCO}2"
fi

# Formata
mkfs.fat -F32 "$EFI"
mkfs.ext4 -F "$ROOT"

# Monta
mount "$ROOT" /mnt
mkdir -p /mnt/boot/efi
mount "$EFI" /mnt/boot/efi

# Chaves do Arch
pacman -S --noconfirm archlinux-keyring
rm -f /var/cache/pacman/pkg/*.zst

# Sistema base
pacstrap /mnt base linux-lts linux-lts-headers linux-firmware vim sudo networkmanager grub efibootmgr os-prober mtools dosfstools

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configuracao no sistema
arch-chroot /mnt /bin/bash <<'CHROOT'
set -euo pipefail

# Localizacao
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf

# Hostname
echo "kodish" > /etc/hostname
cat > /etc/hosts <<'HOSTS'
127.0.0.1   localhost
::1         localhost
127.0.1.1   kodish.localdomain kodish
HOSTS

# NetworkManager
systemctl enable NetworkManager

# Wi-Fi / Bluetooth
pacman -S --noconfirm iwd bluez bluez-utils blueman
systemctl enable iwd
systemctl enable bluetooth

# Repositorio multilib
sed -i '/^\[multilib\]/,/^Include/{s/^#//}' /etc/pacman.conf
pacman -Syu --noconfirm

# Usuario padrao
if ! id kodish >/dev/null 2>&1; then
    useradd -m -G wheel -s /bin/bash kodish
fi
echo "kodish:kodish" | chpasswd
echo "root:root" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Detecta outros sistemas
if ! grep -q '^GRUB_DISABLE_OS_PROBER=' /etc/default/grub; then
    echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
else
    sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
fi

# GRUB UEFI com fallback
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Mirror do Brasil
pacman -S --noconfirm reflector
reflector --country Brazil --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syu --noconfirm

# =============================================================
# Desktop: Hyprland + Noctalia v5 (Wayland)
# Noctalia atual e distribuido no repositorio extra do Arch.
# =============================================================
pacman -S --noconfirm \
    hyprland \
    noctalia \
    xorg-xwayland \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    qt5-wayland \
    qt6-wayland \
    hyprpolkitagent \
    xfce4-terminal \
    lightdm \
    lightdm-gtk-greeter \
    brightnessctl \
    playerctl \
    wl-clipboard \
    grim \
    slurp

# Sessao Wayland / LightDM
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-kodish.conf <<'LIGHTDM'
[Seat:*]
greeter-session=lightdm-gtk-greeter
autologin-user=kodish
autologin-user-timeout=0
autologin-session=hyprland
LIGHTDM

# Grupo de autologin
getent group autologin >/dev/null || groupadd -r autologin
gpasswd -a kodish autologin >/dev/null

# Hyprland Lua config + Noctalia autostart
mkdir -p /home/kodish/.config/hypr
cat > /home/kodish/.config/hypr/hyprland.lua <<'HYPR'
-- Kodish OS 10 Gamer + Noctalia
-- Configuracao para Hyprland atual (Lua)

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        layout = "dwindle",
        allow_tearing = true,
    },
    decoration = {
        rounding = 8,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = 0xee000000,
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
        },
    },
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
    },
    input = {
        kb_layout = "br",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
    dwindle = {
        preserve_split = true,
    },
})

local mainMod = "SUPER"
local terminal = "xfce4-terminal"
local fileManager = "nemo"

hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
end)

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
HYPR

# Garante fallback se a distribuicao ainda trouxer um hyprland.conf
cat > /home/kodish/.config/hypr/hyprland.conf <<'HYPRCONF'
# Kodish OS 10 usa a configuracao Lua em hyprland.lua.
# O arquivo permanece para compatibilidade com ferramentas antigas.
HYPRCONF

# Ambiente do usuario
mkdir -p /home/kodish/.config
chown -R kodish:kodish /home/kodish/.config

# Comandos de uso rapido
cat >> /home/kodish/.bashrc <<'BASHRC'

# Kodish OS 10
alias update='sudo pacman -Syu && flatpak update -y'
alias upgrade='sudo pacman -Syu'
alias fupdate='flatpak update -y && sudo flatpak update -y'
alias iftk='f() { app_id=${1##*/}; flatpak install "$app_id" -y; }; f'
alias ftk='sudo pacman -S'
alias stremio='flatpak run com.stremio.Stremio'
alias retrodeck='flatpak install flathub net.retrodeck.retrodeck'
alias wallpaper='sudo nemo /usr/share/backgrounds'
alias pos='sh /kodish/scripts/flatpaks.sh'
alias inyaa='sh /kodish/scripts/instalar_nyaa.sh'
alias info='sh /kodish/scripts/hw.sh'
alias spotlight='sh /kodish/scripts/spotlight.sh'
alias chaos='sh /kodish/scripts/chaos-repo.sh'
BASHRC
chown kodish:kodish /home/kodish/.bashrc
cp /home/kodish/.bashrc /etc/skel/.bashrc

# Pacotes gamer / multimidia
pacman -S --noconfirm \
    steam \
    lib32-mesa \
    lib32-libglvnd \
    lib32-vulkan-icd-loader \
    gst-libav \
    gst-plugins-base \
    gst-plugins-good \
    gst-plugins-bad \
    gst-plugins-ugly \
    ffmpeg \
    x264 \
    x265 \
    lame \
    firefox \
    flatpak \
    gparted \
    base-devel \
    git \
    openssh
systemctl enable sshd

# Audio / video / jogos / ferramentas
pacman -S --noconfirm \
    alsa-utils \
    pipewire \
    pipewire-pulse \
    wireplumber \
    zenity \
    jq \
    lutris \
    noto-fonts-cjk \
    kodi \
    kodi-addon-inputstream-adaptive \
    openbox \
    arandr \
    wget \
    file-roller \
    unzip \
    unrar \
    7zip \
    nemo \
    wine \
    wine-mono \
    wine-gecko \
    lib32-gnutls \
    vulkan-icd-loader \
    ttf-liberation \
    ttf-dejavu \
    noto-fonts \
    noto-fonts-emoji \
    fuse2 \
    antimicrox \
    ntfs-3g \
    python-pyqt6 \
    python-psutil \
    python-pygame \
    mpv \
    hardinfo2 \
    plymouth \
    feh \
    cronie \
    vulkan-tools \
    gamemode \
    mangohud \
    lib32-gamemode \
    lib32-mangohud \
    winetricks

# Flathub
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true

# Autostarts de servicos
systemctl enable cronie
systemctl enable NetworkManager
systemctl enable bluetooth

# Pasta para scripts Kodish
mkdir -p /kodish/scripts
chown -R kodish:kodish /kodish
chmod 755 /kodish /kodish/scripts
cd /kodish/scripts

# Scripts externos
wget -q https://raw.githubusercontent.com/kodishmediacenter/Kodish_OS/refs/heads/master/scripts-kodish-gamer/name.sh
sh name.sh || true
rm -f name.sh

# Desktop launcher
mkdir -p /home/kodish/Desktop
cd /home/kodish/Desktop
wget -q https://raw.githubusercontent.com/kodishmediacenter/Kodish_OS/refs/heads/master/scripts-kodish-gamer/deckloader.desktop
chmod +x deckloader.desktop
chown kodish:kodish deckloader.desktop

# Script de teclado (se existir no repositorio)
wget -q https://raw.githubusercontent.com/kodishmediacenter/Kodish_OS/refs/heads/master/scripts-kodish-gamer/keyboardbr.sh
sh keyboardbr.sh || true
rm -f keyboardbr.sh

# Scripts de pos-instalacao Kodish
for file in flatpaks.sh instalar_nyaa.sh spotlight.sh hw.sh chaos-repo.sh gamefmidia.sh instalar-kodix.sh; do
    wget -q "https://raw.githubusercontent.com/kodishmediacenter/Kodish-OS-10/refs/heads/main/scripts-kodish-gamer/${file}" || true
done

# Launcher / logos
wget -q 'https://raw.githubusercontent.com/kodishmediacenter/Kodish-OS-10/refs/heads/main/Kodish%20OS/logo-slider.zip' || true
if [[ -f logo-slider.zip ]]; then
    unzip -o logo-slider.zip
    chmod +x instalar_nyaa.sh instalar-kodix.sh 2>/dev/null || true
    mkdir -p /usr/share/plymouth/themes
    cp -r logo-slider /usr/share/plymouth/themes/
    plymouth-set-default-theme -R logo-slider || true
fi

# Icone do deckloader
mkdir -p /kodish/icon
chmod 777 /kodish/icon
cd /kodish/icon
wget -q 'https://raw.githubusercontent.com/kodishmediacenter/Kodish-OS-10/refs/heads/main/Kodish%20OS/deckloader.png' || true

# Wallpaper Kodish (mantido em uma pasta generica para o Wayland/Noctalia)
mkdir -p /usr/share/backgrounds/kodish
cd /usr/share/backgrounds/kodish
wget -q 'https://raw.githubusercontent.com/kodishmediacenter/Kodish-OS-10/d1b090f5233a7957117fa87fd746ea4bdd2876b3/yona/xfce-x.svg' -O kodish-wallpaper.svg || true

# Permissoes finais
chown -R kodish:kodish /home/kodish/Desktop /home/kodish/.config
chmod 755 /home/kodish/Desktop

# LightDM + Hyprland como sessao principal
systemctl enable lightdm
systemctl set-default graphical.target

CHROOT

# End
clear
echo "==============================================================="
echo "Instalação Kodish OS 10 Gamer + Hyprland + Noctalia concluida!"
echo "Sessao grafica: Hyprland (Wayland)"
echo "Shell: Noctalia v5"
echo "Autologin: usuario kodish"
echo "==============================================================="
