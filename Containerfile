FROM --platform=linux/arm64 quay.io/fedora/fedora-bootc:41

# ADD etc etc

# RUN ln -sr /etc/containers/systemd/*.container /usr/lib/bootc/bound-images.d/

RUN dnf5 install --nogpgcheck --assumeyes --best \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
    dnf5 clean all && rm -rf /var/cache/libdnf5

RUN dnf5 remove -y \
        subscription-manager \
        nano

RUN dnf5 install -y \
        podman \
        toolbox \
        python3.12 \
        pip \
        vim-enhanced \
        NetworkManager \
        cockpit \
        cockpit-podman \
        firewalld \
        usbguard \
        libgpiod \
        && dnf5 clean all

RUN pip install uv && \
    dnf5 remove -y \
        pip \
        python3 \
        python3-pip && \
    dnf5 clean all && \
    uv python install 3.13 3.12

RUN groupadd -g 1000 iceman && \
    useradd -m -u 1000 -g iceman -G wheel iceman && \
    echo "icemaniceman" | passwd --stdin iceman && \
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel && \
    chmod 0440 /etc/sudoers.d/wheel && \
    echo "iceman" >> /etc/hostname 

# needs tidying up but credit to https://github.com/ondrejbudai/fedora-bootc-raspi
RUN dnf5 install -y bcm2711-firmware uboot-images-armv8 && \
    cp -P /usr/share/uboot/rpi_arm64/u-boot.bin /boot/efi/rpi-u-boot.bin && \
    mkdir -p /usr/lib/bootc-raspi-firmwares && \
    cp -a /boot/efi/. /usr/lib/bootc-raspi-firmwares/ && \
    dnf5 remove -y bcm2711-firmware uboot-images-armv8 && \
    mkdir /usr/bin/bootupctl-orig && \
    mv /usr/bin/bootupctl /usr/bin/bootupctl-orig/ && \
    dnf5 clean all && \
    rm -rf /var/cache/dnf5 /var/cache/libdnf5

COPY bootupctl-shim /usr/bin/bootupctl

RUN chmod +x /usr/bin/bootupctl

RUN systemctl enable \
        fstrim.timer \
        podman.socket \
        podman-auto-update.timer && \
    systemctl mask auditd.service

RUN ostree container commit && bootc container lint