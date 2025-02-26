# Fedora Bootable Container for Raspberry Pi 4

**Please note: work in progress**

Please note this is completely inspired (stolen) from [ondrejbudai](https://github.com/ondrejbudai/fedora-bootc-raspi) and I'm just trying to get a Fedora bootable container working for RPI4.

This repository is aiming to provide a Fedora bootable container for Raspberry Pi 4. The repository will provide a aarch64 container image for your RPI4 to leverage once bootstrapped. 

## Bootc Image Builder

We use BiB to generate a .RAW image to then be flashed onto the RPI4 flash using the RPI Imager or Fedora's ARM Image Installer. The aim to keep as much configuration in the Containerfile as possible, therefore we've opted to not use the Kickstart (config.toml) and opted to provision the device using Layers instead.

```bash
sudo podman run \
  --rm \
  -it \
  --privileged \
  --pull=newer \
   --security-opt label=type:unconfined_t \
   -v $(pwd)/output:/output \
   -v /var/lib/containers/storage:/var/lib/containers/storage
   quay.io/centos-bootc/bootc-image-builder:latest \
   --type raw \
   --rootfs ext4 \
   ghcr.io/defrostediceman/fedora-bootc-rpi4
```
## Convert RAW to XZ

```bash
xz -v -0 -T0 output/image/disk.raw
```

## ARM image installer

Now we've built our RAW image, we now use the Fedora (or Raspberry Pi) ARM Image Installer to flash the image onto the RPI4 with the following command:
```bash
$ sudo arm-image-installer \
--image=</path/to/RAW_image> \
--target=rpi4 \ # rpi4, rpi3, rpi2
--media=/dev/__<sd_card_device> \ # /dev/sdX or /dev/mmcblkX. The lsblk command should help you identify your micro-SD card.
--resizefs
```

Or you can use the `Raspberry Pi Imager` to flash the image onto the RPI4.

## RPI EEPROM & Firmware update

Ensure you have updated your Raspberry Pi 4 to the latest firmware & EEPROM. This can be found [here](https://github.com/raspberrypi/rpi-eeprom) or you can use the following command to update your Raspberry Pi 4 if still running Raspberry Pi OS. Or even better, use the `Raspberry Pi Imager` to update your Raspberry Pi 4..

## First boot

Once you have flashed the image onto the RPI4, you can now boot the RPI4 from the SD card. The SD card should now be ready to use with your Raspberry Pi 4. You can check the contents of the SD card by mounting it and checking the /boot/ folder.