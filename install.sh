#!/bin/bash
set -e
 
# ============================================================
#  Arch Linux Install Script — Krok 1 (live ISO, przed chroot)
# ============================================================
 
echo "======================================"
echo " Arch Linux Installer — Krok 1/2"
echo "======================================"
echo ""
 
# --- Pytania ---
lsblk
echo ""
read -rp "Podaj dysk docelowy (np. /dev/sda lub /dev/nvme0n1): " DISK
 
read -rp "Podaj nazwę użytkownika: " USERNAME
read -rp "Podaj hostname (nazwa komputera): " HOSTNAME
 
read -rp "Procesor Intel czy AMD? [intel/amd]: " CPU
CPU=$(echo "$CPU" | tr '[:upper:]' '[:lower:]')
 
read -rp "Czy masz kartę graficzną Nvidia? [t/n]: " NVIDIA
NVIDIA=$(echo "$NVIDIA" | tr '[:upper:]' '[:lower:]')
 
# --- Ustalenie nazw partycji ---
if [[ "$DISK" == *"nvme"* ]]; then
    PART_BOOT="${DISK}p1"
    PART_ROOT="${DISK}p2"
else
    PART_BOOT="${DISK}1"
    PART_ROOT="${DISK}2"
fi
 
echo ""
echo "--- Podsumowanie ---"
echo "Dysk:      $DISK"
echo "Boot:      $PART_BOOT"
echo "Root:      $PART_ROOT"
echo "User:      $USERNAME"
echo "Hostname:  $HOSTNAME"
echo "CPU:       $CPU"
echo "Nvidia:    $NVIDIA"
echo ""
read -rp "Kontynuować? Spowoduje to USUNIĘCIE WSZYSTKICH danych na $DISK [tak/nie]: " CONFIRM
if [[ "$CONFIRM" != "tak" ]]; then
    echo "Przerwano."
    exit 1
fi
 
# --- Partycjonowanie ---
echo "==> Tworzenie partycji..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart boot fat32 1MiB 1GiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart root ext4 1GiB 100%
 
# --- Szyfrowanie ---
echo ""
echo "==> Szyfrowanie partycji root (ustaw hasło LUKS)..."
cryptsetup -v luksFormat "$PART_ROOT"
cryptsetup open "$PART_ROOT" cryptroot
 
# --- Formatowanie ---
echo "==> Formatowanie..."
mkfs.ext4 /dev/mapper/cryptroot
mkfs.fat -F32 "$PART_BOOT"
 
# --- Montowanie ---
echo "==> Montowanie..."
mount /dev/mapper/cryptroot /mnt
mount --mkdir "$PART_BOOT" /mnt/boot
 
# --- Paczki bazowe ---
UCODE=""
if [[ "$CPU" == "intel" ]]; then
    UCODE="intel-ucode"
elif [[ "$CPU" == "amd" ]]; then
    UCODE="amd-ucode"
fi
 
echo "==> Instalacja paczek bazowych..."
pacstrap -K /mnt base base-devel linux linux-headers linux-firmware \
    networkmanager vim cryptsetup grub efibootmgr \
    gnome gnome-tweaks os-prober sudo $UCODE
 
# --- Nvidia (opcjonalnie) ---
if [[ "$NVIDIA" == "t" ]]; then
    echo "==> Instalacja sterowników Nvidia..."
    pacstrap /mnt nvidia-open nvidia-utils
fi
 
# --- fstab ---
echo "==> Generowanie fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
 
# --- Kopiowanie skryptu 2 + zmiennych do chroot ---
cp setup-chroot.sh /mnt/setup-chroot.sh
 
cat > /mnt/install-vars.sh <<EOF
DISK="$DISK"
PART_BOOT="$PART_BOOT"
PART_ROOT="$PART_ROOT"
USERNAME="$USERNAME"
HOSTNAME="$HOSTNAME"
CPU="$CPU"
NVIDIA="$NVIDIA"
EOF
 
echo ""
echo "======================================"
echo " Krok 1 zakończony!"
echo "======================================"
echo ""
echo "Teraz wykonaj:"
echo "  arch-chroot /mnt"
echo "  bash /setup-chroot.sh"
