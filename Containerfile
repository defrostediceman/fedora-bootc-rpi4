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

# needs tidying up but credit to https://github.com/ondrejbudai/fedora-bootc-raspi
RUN dnf install -y bcm2711-firmware uboot-images-armv8 && \
    cp -P /usr/share/uboot/rpi_arm64/u-boot.bin /boot/efi/rpi-u-boot.bin && \
    mkdir -p /usr/lib/bootc-raspi-firmwares && \
    cp -a /boot/efi/. /usr/lib/bootc-raspi-firmwares/ && \
    dnf remove -y bcm2711-firmware uboot-images-armv8 && \
    mkdir /usr/bin/bootupctl-orig && \
    mv /usr/bin/bootupctl /usr/bin/bootupctl-orig/ && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/cache/libdnf

COPY bootupctl-shim /usr/bin/bootupctl

RUN chmod +x /usr/bin/bootupctl

ADD tmp/config.txt /boot/efi/config.txt

RUN systemctl enable \
        fstrim.timer \
        podman.socket && \
    systemctl mask auditd.service

RUN bootc container lint