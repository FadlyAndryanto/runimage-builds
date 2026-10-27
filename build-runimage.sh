#!/usr/bin/env bash
set -e

if [ ! -f "runimage-x86_64" ]; then
    curl -OL "https://github.com/VHSgunzo/runimage/releases/download/continuous/runimage-x86_64"
    chmod +x runimage-x86_64
fi

run_all() {
    set -e
    WINE_PKGS=(
        wine-staging winetricks-git alsa-lib alsa-plugins cups dosbox ffmpeg giflib
        gnutls gst-plugins-base-libs gtk3 lib32-alsa-lib lib32-alsa-plugins lib32-gnutls
        lib32-gtk3 lib32-libcups lib32-libpulse lib32-libva lib32-libxcomposite lib32-libxinerama lib32-ocl-icd
        lib32-vulkan-icd-loader libgphoto2 libpulse libva libxcomposite libxinerama
        ocl-icd samba sane sdl2-compat v4l-utils vulkan-icd-loader
    )
    INSTALL_PKGS=(
        ttf-bitstream-vera steam mcpelauncher-linux-git
        mcpelauncher-ui-git pipewire-alsa pipewire-pulse
        wget chromium xorg-server-xvfb
    )

    echo "=== PHASE 1: Installing packages ==="
    sudo sed -i 's/^#Server/Server/' /etc/pacman.d/blackarch-mirrorlist
    rim-update
    pac --needed --noconfirm -S "${WINE_PKGS[@]}" --assume-installed ntsync-autoload
    pac --needed --noconfirm -S "${INSTALL_PKGS[@]}"
    pac -S prismlauncher-git --noconfirm --assume-installed java-runtime=17
    ln -sf /var/host/bin/xdg-open /usr/bin/xdg-open

    cat <<-'EOF' > "$RUNDIR/config/Run.rcfg"
RIM_SHARE_ICONS="${RIM_SHARE_ICONS:=1}"
RIM_SHARE_FONTS="${RIM_SHARE_FONTS:=1}"
RIM_SHARE_THEMES="${RIM_SHARE_THEMES:=1}"
RIM_HOST_XDG_OPEN="${RIM_HOST_XDG_OPEN:=1}"
RIM_SYS_NVLIBS="${RIM_SYS_NVLIBS:=1}"
EOF

    echo "=== PHASE 2: Profiling apps ==="
    for cmd in mcpelauncher-ui-qt prismlauncher chromium steam; do
        echo "  → $cmd"
        timeout 20s xvfb-run -a bash -c "DWARFS_PROFILE=/tmp/runimage.profile $cmd" || true
    done

    echo "=== PHASE 3: Cleanup + shrink ==="
    pac -Rns --noconfirm xorg-server-xvfb
    RIM_SHRINK_PKGCACHE=1 rim-shrink --all

    echo "=== PHASE 4: Building final image ==="
    rim-build -d -z -c 19 -b 24 -f /tmp/runimage.profile runimage
}

export -f run_all
RIM_OVERFS_MODE=1 RIM_NO_NVIDIA_CHECK=1 ./runimage-x86_64 bash -c run_all

echo "Exporting package list..."
./runimage pacman -Q > package_versions.txt
