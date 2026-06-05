#!/bin/bash
set -e

# ============================================================
#  Arch Linux Install Script — Krok 2 (po arch-chroot)
# ============================================================

echo "======================================"
echo " Arch Linux Installer — Krok 2/2"
echo "======================================"
echo ""

# --- Wczytanie zmiennych z kroku 1 ---
if [[ -f /install-vars.sh ]]; then
    source /install-vars.sh
else
    echo "Brak pliku /install-vars.sh — podaj dane ręcznie:"
    lsblk
    echo ""
    read -rp "Dysk (np. /dev/sda): " DISK
    if [[ "$DISK" == *"nvme"* ]]; then
        PART_ROOT="${DISK}p2"
    else
        PART_ROOT="${DISK}2"
    fi
    read -rp "Nazwa użytkownika: " USERNAME
    read -rp "Hostname: " HOSTNAME
    read -rp "CPU [intel/amd]: " CPU
fi

echo "--- Konfiguracja ---"
echo "Partycja root (LUKS): $PART_ROOT"
echo "User:     $USERNAME"
echo "Hostname: $HOSTNAME"
echo ""

# --- Strefa czasowa ---
echo "==> Strefa czasowa..."
ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
hwclock --systohc

# --- Locale ---
echo "==> Locale..."
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# --- Hostname ---
echo "==> Hostname..."
echo "$HOSTNAME" > /etc/hostname

# --- Hasło root ---
echo ""
echo "==> Ustaw hasło dla root:"
passwd

# --- Użytkownik ---
echo "==> Tworzenie użytkownika $USERNAME..."
useradd -m -g users -G wheel "$USERNAME"
echo "==> Ustaw hasło dla $USERNAME:"
passwd "$USERNAME"

# --- Sudo ---
echo "==> Konfiguracja sudo..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# --- mkinitcpio ---
echo "==> Konfiguracja mkinitcpio..."
sed -i 's/\(HOOKS=(.*\)block\(.*filesystems\)/\1block encrypt\2/' /etc/mkinitcpio.conf
mkinitcpio -P

# --- GRUB ---
echo "==> Instalacja GRUB..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch-btw

LUKS_UUID=$(blkid -s UUID -o value "$PART_ROOT")
ROOT_UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot)

echo "==> Konfiguracja GRUB (LUKS UUID: $LUKS_UUID)..."
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=${LUKS_UUID}:cryptroot root=UUID=${ROOT_UUID}\"|" /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

# --- Usługi ---
echo "==> Włączanie usług..."
systemctl enable NetworkManager
systemctl enable gdm

# --- Sprzątanie ---
rm -f /install-vars.sh /setup-chroot.sh

echo ""
echo "======================================"
echo " Instalacja zakończona!"
echo "======================================"
echo ""
echo "Wykonaj:"
echo "  exit"
echo "  umount -R /mnt"
echo "  reboot"
