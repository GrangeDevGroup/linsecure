#!/bin/bash
# ============================================
# LinSecure - Privacy / Security Toolkit
# Author Garrett / Third Party Tool.
# ============================================

# --- REQUIRE ROOT ---
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo ./linsecure.sh"
    exit 1
fi

pause() { read -p "Press Enter to continue..."; }

# -----------------------------
# SYSTEM HARDENING
# -----------------------------
system_hardening() {
    echo "[*] Updating system..."
    sudo apt update && sudo apt upgrade -y

    echo "[*] Installing essential security tools..."
    sudo apt install -y ufw fail2ban apparmor apparmor-utils flatpak curl

    echo "[*] Installing additional security tools..."
    sudo apt install -y clamav clamtk rkhunter chkrootkit
    sudo freshclam
    sudo rkhunter --update
    sudo rkhunter --propupd
    sudo systemctl enable fail2ban --now

    echo "[*] Enabling AppArmor..."
    sudo systemctl enable apparmor --now

    echo "[*] Hardening UFW firewall rules..."
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw enable

    echo "[*] Installing ProtonVPN..."
    wget https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb
    sudo dpkg -i ./protonvpn-stable-release_1.0.8_all.deb && sudo apt update
    sudo apt install proton-vpn-gnome-desktop -y

    echo "[*] Applying kernel / sysctl hardening..."
    sudo bash -c 'cat <<EOF >/etc/sysctl.d/99-hardening.conf
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 2
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.log_martians = 1
EOF'
    sudo sysctl --system

    echo "[✓] System hardening applied and security tools installed."
    pause
}

# -----------------------------
# FIREWALL PARANOID MODE
# -----------------------------
paranoid_firewall() {
    echo "[*] Activating paranoid firewall..."
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default deny outgoing
    sudo ufw allow out 443/tcp
    sudo ufw allow out 80/tcp
    sudo ufw enable
    echo "[✓] Paranoid mode enabled."
    pause
}

# -----------------------------
# RESTORE DEFAULT FIREWALL
# -----------------------------
restore_firewall() {
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw enable
    echo "[✓] Firewall restored."
    pause
}

# -----------------------------
# DISABLE/ENABLE CAMERA
# -----------------------------
disable_camera() {
    sudo bash -c 'echo "blacklist uvcvideo" >/etc/modprobe.d/disable_camera.conf'
    echo "Camera disabled. Reboot required."
    pause
}
enable_camera() {
    sudo rm -f /etc/modprobe.d/disable_camera.conf
    echo "Camera enabled. Reboot required."
    pause
}

# -----------------------------
# MICROPHONE
# -----------------------------
disable_microphone() {
    sudo amixer set Capture nocap
    sudo amixer set Mic nocap 2>/dev/null
    echo "Microphone disabled."
    pause
}
enable_microphone() {
    sudo amixer set Capture cap
    sudo amixer set Mic cap 2>/dev/null
    echo "Microphone enabled."
    pause
}

# -----------------------------
# AUDIO HARDWARE
# -----------------------------
disable_audio() {
    sudo bash -c 'cat <<EOF >/etc/modprobe.d/disable_audio.conf
blacklist snd_hda_intel
blacklist snd_hda_codec
blacklist snd_hda_core
blacklist snd_seq
blacklist snd_pcm
EOF'
    echo "Audio hardware disabled."
    pause
}
enable_audio() {
    sudo rm -f /etc/modprobe.d/disable_audio.conf
    echo "Audio hardware enabled."
    pause
}

# -----------------------------
# BLUETOOTH
# -----------------------------
disable_bluetooth() {
    sudo systemctl disable bluetooth --now
    sudo bash -c 'echo "blacklist btusb" >/etc/modprobe.d/disable_bluetooth.conf'
    echo "Bluetooth disabled."
    pause
}
enable_bluetooth() {
    sudo rm -f /etc/modprobe.d/disable_bluetooth.conf
    sudo systemctl enable bluetooth --now
    echo "Bluetooth enabled."
    pause
}

# -----------------------------
# WIFI HARDWARE
# -----------------------------
disable_wifi() {
    sudo rfkill block wifi
    sudo bash -c 'echo "blacklist iwlwifi" >/etc/modprobe.d/disable_wifi.conf'
    echo "Wi-Fi disabled."
    pause
}
enable_wifi() {
    sudo rfkill unblock wifi
    sudo rm -f /etc/modprobe.d/disable_wifi.conf
    echo "Wi-Fi enabled."
    pause
}

# -----------------------------
# DISABLE/ENABLE IPv6
# -----------------------------
disable_ipv6() {
    sudo bash -c 'cat <<EOF >/etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF'
    sudo sysctl --system
    echo "IPv6 disabled."
    pause
}
enable_ipv6() {
    sudo rm -f /etc/sysctl.d/99-disable-ipv6.conf
    sudo sysctl --system
    echo "IPv6 enabled."
    pause
}

# -----------------------------
# PRIVACY SOFTWARE INSTALL
# -----------------------------
install_privacy() {
    echo "[*] Installing Brave Browser..."
    sudo curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
        | sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
    sudo apt update
    sudo apt install -y brave-browser

    echo "[*] Installing Tor Browser (Flatpak)..."
    sudo flatpak install -y com.github.micahflee.torbrowser-launcher

    echo "[*] Installing MAT2..."
    sudo apt install -y mat2

    echo "[*] Installing OnionShare..."
    sudo apt install -y onionshare

    echo "[*] Installing DNSCrypt Proxy..."
    sudo apt install -y dnscrypt-proxy

    echo "[✓] Privacy tools installed."
    pause
}

# -----------------------------
# TOR ROUTING
# -----------------------------
enable_tor_mode() {
    echo "[*] Enabling Tor transparent proxy (safe mode)..."

    sudo apt install -y tor

    sudo bash -c 'cat <<EOF >/etc/tor/torrc
SOCKSPort 9050
TransPort 9040
DNSPort 5353
AutomapHostsOnResolve 1
EOF'

    sudo systemctl enable tor --now

    echo "[✓] Tor routing enabled (not guaranteed anonymity)."
    pause
}

disable_tor_mode() {
    sudo systemctl disable tor --now
    sudo rm -f /etc/tor/torrc
    echo "[✓] Tor routing disabled."
    pause
}

# -----------------------------
# TEMP CLEANING
# -----------------------------
clean_temp() {
    echo "[*] Cleaning temp directories..."
    sudo rm -rf /tmp/*
    sudo rm -rf /var/tmp/*
    echo "[✓] Temp cleaned."
    pause
}

# -----------------------------
# RAM CACHE CLEANING
# -----------------------------
clean_ram() {
    echo "[*] Dropping filesystem caches (safe)..."
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
    echo "[✓] RAM caches dropped."
    pause
}

# -----------------------------
# LOCATION SERVICES
# -----------------------------
disable_location() {
    sudo systemctl stop geoclue.service
    sudo systemctl disable geoclue.service
    echo "Location services disabled."
    pause
}
enable_location() {
    sudo systemctl enable geoclue.service
    sudo systemctl start geoclue.service
    echo "Location services enabled."
    pause
}

# -----------------------------
# FULL RESTORE MODE
# -----------------------------
restore_all() {
    echo "[*] Restoring all system changes to defaults..."

    sudo rm -f /etc/modprobe.d/disable_*.conf
    sudo rm -f /etc/sysctl.d/99-hardening.conf
    sudo rm -f /etc/sysctl.d/99-disable-ipv6.conf

    sudo rfkill unblock wifi
    sudo systemctl enable bluetooth --now

    restore_firewall

    sudo sysctl --system

    echo "[✓] All changes restored. A reboot is recommended."
    pause
}

# -----------------------------
# MENU
# -----------------------------
while true; do
    clear
    echo "=============================================="
    echo "          LINSECURE PRIVACY TOOLKIT           "
    echo "=============================================="
    echo " 1) System hardening & install security tools"
    echo " 2) Paranoid firewall mode"
    echo " 3) Restore normal firewall"
    echo " 4) Disable camera"
    echo " 5) Enable camera"
    echo " 6) Disable microphone"
    echo " 7) Enable microphone"
    echo " 8) Disable audio hardware"
    echo " 9) Enable audio hardware"
    echo "10) Disable Bluetooth"
    echo "11) Enable Bluetooth"
    echo "12) Disable Wi-Fi hardware"
    echo "13) Enable Wi-Fi hardware"
    echo "14) Disable IPv6"
    echo "15) Enable IPv6"
    echo "16) Install privacy tools"
    echo "17) Enable Tor routing (safe mode)"
    echo "18) Disable Tor routing"
    echo "19) Clean temp files"
    echo "20) Clear RAM cache"
    echo "21) Disable location services"
    echo "22) Enable location services"
    echo "99) Restore all changes"
    echo " 0) Exit"
    echo "=============================================="
    read -p "Choose an option: " opt

    case $opt in
        1) system_hardening ;;
        2) paranoid_firewall ;;
        3) restore_firewall ;;
        4) disable_camera ;;
        5) enable_camera ;;
        6) disable_microphone ;;
        7) enable_microphone ;;
        8) disable_audio ;;
        9) enable_audio ;;
        10) disable_bluetooth ;;
        11) enable_bluetooth ;;
        12) disable_wifi ;;
        13) enable_wifi ;;
        14) disable_ipv6 ;;
        15) enable_ipv6 ;;
        16) install_privacy ;;
        17) enable_tor_mode ;;
        18) disable_tor_mode ;;
        19) clean_temp ;;
        20) clean_ram ;;
        21) disable_location ;;
        22) enable_location ;;
        99) restore_all ;;
        0) exit 0 ;;
        *) echo "Invalid option"; pause ;;
    esac
done
