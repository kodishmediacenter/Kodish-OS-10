#!/bin/bash
set -Eeuo pipefail

trap 'echo "ERRO: linha ${LINENO}: ${BASH_COMMAND}" >&2' ERR

clear
printf '\e[0;32m[===============================================================]\e[m\n'
echo '++++++++++ Bem Vindo A Instalação Kodish OS 10 Gamer ++++++++++'
printf '\e[0;32m[===============================================================]\e[m\n'

if [[ $EUID -ne 0 ]]; then
    echo 'ERRO: execute este script como root.' >&2
    exit 1
fi

# Ferramentas necessárias no ISO live.
pacman -Sy --noconfirm --needed reflector wget parted dosfstools

loadkeys br-abnt2
timedatectl set-ntp true

if [[ ! -d /sys/firmware/efi ]]; then
    echo 'ERRO: inicialize o Arch ISO em modo UEFI.' >&2
    exit 1
fi

# Habilita multilib no ambiente live para que pacstrap também possa usar pacotes 32-bit.
if grep -q '^#\[multilib\]' /etc/pacman.conf; then
    sed -i '/^#\[multilib\]/,/^#Include/s/^#//' /etc/pacman.conf
elif grep -q '^\[multilib\]' /etc/pacman.conf; then
    :
else
    cat >> /etc/pacman.conf <<'MULTILIB'

[multilib]
Include = /etc/pacman.d/mirrorlist
MULTILIB
fi
pacman -Sy --noconfirm

DISCO=$(lsblk -dpo NAME,SIZE,TYPE | awk '$3 == "disk" {print $0}' | sort -k2 -h | tail -n1 | awk '{print $1}')
if [[ -z "${DISCO}" ]]; then
    echo 'ERRO: nenhum disco foi detectado.' >&2
    exit 1
fi

echo "Disco detectado: ${DISCO}"
read -rp "TODOS OS DADOS EM ${DISCO} SERÃO APAGADOS! Deseja continuar? (s/N): " CONFIRMA
[[ "${CONFIRMA}" == 's' || "${CONFIRMA}" == 'S' ]] || exit 1

umount -R /mnt 2>/dev/null || true
wipefs -af "${DISCO}"

parted "${DISCO}" --script mklabel gpt
parted "${DISCO}" --script mkpart ESP fat32 1MiB 513MiB
parted "${DISCO}" --script set 1 esp on
parted "${DISCO}" --script mkpart primary ext4 513MiB 100%

if [[ "${DISCO}" == *nvme* || "${DISCO}" == *mmcblk* ]]; then
    EFI="${DISCO}p1"
    ROOT="${DISCO}p2"
else
    EFI="${DISCO}1"
    ROOT="${DISCO}2"
fi

mkfs.fat -F32 "${EFI}"
mkfs.ext4 -F -m 1 "${ROOT}"

mount "${ROOT}" /mnt
mkdir -p /mnt/boot/efi
mount "${EFI}" /mnt/boot/efi

pacman -S --noconfirm --needed archlinux-keyring
pacstrap -K -c /mnt \
    base \
    linux-lts \
    linux-firmware \
    vim \
    sudo \
    networkmanager \
    grub \
    efibootmgr \
    os-prober \
    dosfstools

genfstab -U /mnt > /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<'CHROOT'
set -Eeuo pipefail
trap 'echo "ERRO CHROOT: linha ${LINENO}: ${BASH_COMMAND}" >&2' ERR

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
echo 'pt_BR.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
echo 'LANG=pt_BR.UTF-8' > /etc/locale.conf
echo 'KEYMAP=br-abnt2' > /etc/vconsole.conf

echo 'kodish' > /etc/hostname
cat > /etc/hosts <<'HOSTS'
127.0.0.1   localhost
::1         localhost
127.0.1.1   kodish.localdomain kodish
HOSTS

# Rede, Wi-Fi e Bluetooth.
pacman -S --noconfirm --needed iwd bluez bluez-utils blueman
systemctl enable NetworkManager
groupadd -f autologin
systemctl enable iwd
systemctl enable bluetooth

# Usuário padrão.
if ! id kodish >/dev/null 2>&1; then
    useradd -m -G wheel -s /bin/bash kodish
else
    usermod -aG wheel kodish
fi
echo 'kodish:kodish' | chpasswd
echo 'root:root' | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
gpasswd -a kodish autologin >/dev/null

# GRUB UEFI.
grep -q '^GRUB_DISABLE_OS_PROBER=' /etc/default/grub \
    && sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub \
    || echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Espelhos do Brasil.
pacman -S --noconfirm --needed reflector
reflector --country Brazil --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# =============================================================
# Kodish OS 10 Gamer: Hyprland + Noctalia v5
# =============================================================
# Noctalia v5 está no repositório extra do Arch.
# Hyprland 0.55+ usa Lua em ~/.config/hypr/hyprland.lua.
pacman -S --noconfirm --needed \
    hyprland \
    noctalia \
    xorg-xwayland \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    lightdm \
    lightdm-gtk-greeter \
    foot \
    thunar \
    brightnessctl \
    playerctl \
    wl-clipboard \
    grim \
    slurp

# Sessão própria do Kodish para o LightDM.
mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/kodish-noctalia.desktop <<'DESKTOP'
[Desktop Entry]
Name=Kodish OS 10 Gamer (Noctalia)
Comment=Hyprland + Noctalia v5
Exec=/usr/bin/Hyprland
TryExec=/usr/bin/Hyprland
Type=Application
DesktopNames=Hyprland
Keywords=wayland;hyprland;noctalia;gamer;
DESKTOP

mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-kodish-noctalia.conf <<'LIGHTDM'
[Seat:*]
greeter-session=lightdm-gtk-greeter
autologin-user=kodish
autologin-user-timeout=0
autologin-session=kodish-noctalia
allow-guest=false
LIGHTDM

# Configuração Lua atual do Hyprland.
mkdir -p /home/kodish/.config/hypr
cat > /home/kodish/.config/hypr/hyprland.lua <<'HYPR'
-- Kodish OS 10 Gamer + Noctalia v5

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

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
local terminal = "foot"
local fileManager = "nemo"

-- Noctalia v5: inicialização recomendada pelo projeto.
hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia --daemon")
end)

hl.bind(mainMod .. "+RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. "+E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. "+Q", hl.dsp.window.close())
hl.bind(mainMod .. "+Space", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))

hl.bind(mainMod .. "+left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. "+right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. "+up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. "+down", hl.dsp.focus({ direction = "down" }))

hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. "+" .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. "+SHIFT+" .. key, hl.dsp.window.move({ workspace = i }))
end
HYPR

# Pacotes gamer/multimídia.
pacman -S --noconfirm --needed \
    steam \
    mesa \
    lib32-mesa \
    lib32-libglvnd \
    vulkan-icd-loader \
    lib32-vulkan-icd-loader \
    vulkan-tools \
    gamemode \
    lib32-gamemode \
    mangohud \
    lib32-mangohud \
    firefox \
    flatpak \
    git \
    openssh \
    alsa-utils \
    pipewire \
    pipewire-pulse \
    wireplumber \
    zenity \
    jq \
    kodi \
    kodi-addon-inputstream-adaptive \
    wget \
    unzip \
    7zip \
    unrar \
    ttf-liberation \
    ttf-dejavu \
    noto-fonts \
    noto-fonts-emoji \
    antimicrox \
    ntfs-3g \
    mpv \
    cronie \
    plymouth

# Serviços.
systemctl enable lightdm
systemctl enable cronie
systemctl enable sshd
systemctl set-default graphical.target

# Flathub.
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true

# Scripts Kodish.
mkdir -p /kodish/scripts /kodish/icon
chown -R kodish:kodish /kodish
chmod 755 /kodish /kodish/scripts
cd /kodish/scripts

for file in flatpaks.sh instalar_nyaa.sh spotlight.sh hw.sh chaos-repo.sh gamefmidia.sh instalar-kodix.sh; do
    url="https://raw.githubusercontent.com/kodishmediacenter/Kodish-OS-10/refs/heads/main/scripts-kodish-gamer/${file}"
    if wget -q "$url" -O "$file"; then
        chmod +x "$file"
    else
        echo "Aviso: não foi possível baixar ${file}"
        rm -f "$file"
    fi
done

# Launcher e logo Plymouth.
if wget -q 'https://raw.githubusercontent.com/kodishmediacenter/Kodish-OS-10/refs/heads/main/Kodish%20OS/logo-slider.zip' -O logo-slider.zip; then
    if unzip -tq logo-slider.zip >/dev/null 2>&1; then
        unzip -oq logo-slider.zip
        mkdir -p /usr/share/plymouth/themes
        cp -r logo-slider /usr/share/plymouth/themes/
        plymouth-set-default-theme -R logo-slider || true
    fi
fi

# Desktop launcher.
mkdir -p /home/kodish/Desktop
if wget -q 'https://raw.githubusercontent.com/kodishmediacenter/Kodish_OS/refs/heads/master/scripts-kodish-gamer/deckloader.desktop' -O /home/kodish/Desktop/deckloader.desktop; then
    chmod +x /home/kodish/Desktop/deckloader.desktop
fi

# Ícone.
wget -q 'https://raw.githubusercontent.com/kodishmediacenter/Kodish-OS-10/refs/heads/main/Kodish%20OS/deckloader.png' -O /kodish/icon/deckloader.png || true

# Wallpaper.
mkdir -p /usr/share/backgrounds/kodish
wget -q 'https://raw.githubusercontent.com/kodishmediacenter/Kodish-OS-10/d1b090f5233a7957117fa87fd746ea4bdd2876b3/yona/xfce-x.svg' -O /usr/share/backgrounds/kodish/kodish-wallpaper.svg || true

# Bash do usuário.
cat > /home/kodish/.bashrc <<'BASHRC'
# Kodish OS 10 Gamer
alias update='sudo pacman -Syu && flatpak update -y'
alias upgrade='sudo pacman -Syu'
alias fupdate='flatpak update -y && sudo flatpak update -y'
alias iftk='f() { app_id=${1##*/}; flatpak install "$app_id" -y; }; f'
alias ftk='sudo pacman -S'
alias stremio='flatpak run com.stremio.Stremio'
alias retrodeck='flatpak install flathub net.retrodeck.retrodeck'
alias wallpaper='nemo /usr/share/backgrounds/kodish'
alias pos='sh /kodish/scripts/flatpaks.sh'
alias inyaa='sh /kodish/scripts/instalar_nyaa.sh'
alias info='sh /kodish/scripts/hw.sh'
alias spotlight='sh /kodish/scripts/spotlight.sh'
alias chaos='sh /kodish/scripts/chaos-repo.sh'
BASHRC

chown -R kodish:kodish /home/kodish/.config /home/kodish/.bashrc /home/kodish/Desktop
cp /home/kodish/.bashrc /etc/skel/.bashrc
chmod 755 /home/kodish/Desktop

# Limpa o cache de pacotes para economizar espaço em instalações de 32 GB.
rm -f /var/cache/pacman/pkg/*.pkg.tar.* /var/cache/pacman/pkg/*.sig 2>/dev/null || true

# Evita cópia antiga de XFCE/Hyprland conf conflitando com o Lua.
rm -f /home/kodish/.config/hypr/hyprland.conf

CHROOT

clear
echo '==============================================================='
echo 'Instalação Kodish OS 10 Gamer + Noctalia v5 concluída!'
echo 'Sessão: Hyprland (Wayland)'
echo 'Shell: Noctalia v5'
echo 'Login automático: kodish'
echo '==============================================================='
