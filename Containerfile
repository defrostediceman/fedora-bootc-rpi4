FROM --platform=linux/arm64 quay.io/fedora/fedora-bootc:42

# ADD etc etc

RUN dnf install --assumeyes --best \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
    dnf clean all && rm -rf /var/cache/libdnf

RUN dnf remove -y nano

RUN dnf install -y \
        podman \
        vim-enhanced \
        nftables \
        usbguard \
        && dnf clean all

RUN groupadd -g 1000 iceman && \
    useradd -m -u 1000 -g iceman -G wheel iceman && \
    echo "icemaniceman" | passwd --stdin iceman && \
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel && \
    chmod 0440 /etc/sudoers.d/wheel

# Install Raspberry Pi firmware and U-Boot
# Using new bootupd /usr/lib/efi structure (bootupd >= 0.2.29)
# Credit to https://github.com/ondrejbudai/fedora-bootc-raspi for the original approach
RUN dnf install -y bcm2711-firmware uboot-images-armv8 && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/cache/libdnf

# Structure firmware for bootupd using /usr/lib/efi/<component>/<version>/EFI/
# This allows bootupd to properly manage and update Raspberry Pi firmware
RUN FIRMWARE_VERSION=$(rpm -q --queryformat='%{VERSION}-%{RELEASE}' bcm2711-firmware) && \
    UBOOT_VERSION=$(rpm -q --queryformat='%{VERSION}-%{RELEASE}' uboot-images-armv8) && \
    echo "Setting up Raspberry Pi firmware with bootupd" && \
    echo "  bcm2711-firmware: ${FIRMWARE_VERSION}" && \
    echo "  uboot-images-armv8: ${UBOOT_VERSION}" && \
    mkdir -p /usr/lib/efi/raspi-firmware/${FIRMWARE_VERSION}/EFI && \
    mkdir -p /usr/lib/efi/raspi-uboot/${UBOOT_VERSION}/EFI && \
    cp -a /boot/efi/. /usr/lib/efi/raspi-firmware/${FIRMWARE_VERSION}/EFI/ && \
    cp -P /usr/share/uboot/rpi_arm64/u-boot.bin /usr/lib/efi/raspi-uboot/${UBOOT_VERSION}/EFI/rpi-u-boot.bin

ADD tmp/config.txt /boot/efi/config.txt

RUN systemctl enable \
        fstrim.timer \
        podman.socket && \
    systemctl mask auditd.service

RUN bootc container lint