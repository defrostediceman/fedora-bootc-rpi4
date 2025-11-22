# bootupd /usr/lib/efi Migration Notes

## Migration Overview

This document tracks our migration from the `bootupctl-shim` hack to the native bootupd `/usr/lib/efi` structure for Raspberry Pi 4 firmware management.

**Date**: 2025-01-22
**bootupd version**: v0.2.31 (available in Fedora 42)
**Commit**: 4798e02

## What We Changed

### Previous Approach (bootupctl-shim hack)
```dockerfile
RUN dnf install -y bcm2711-firmware uboot-images-armv8 && \
    cp -P /usr/share/uboot/rpi_arm64/u-boot.bin /boot/efi/rpi-u-boot.bin && \
    mkdir -p /usr/lib/bootc-raspi-firmwares && \
    cp -a /boot/efi/. /usr/lib/bootc-raspi-firmwares/ && \
    dnf remove -y bcm2711-firmware uboot-images-armv8 && \
    mkdir /usr/bin/bootupctl-orig && \
    mv /usr/bin/bootupctl /usr/bin/bootupctl-orig/

COPY bootupctl-shim /usr/bin/bootupctl
```

The shim intercepted `bootupctl backend install` calls and manually copied firmware files to `/boot/efi/`.

### New Approach (/usr/lib/efi structure)
```dockerfile
RUN dnf install -y bcm2711-firmware uboot-images-armv8

RUN FIRMWARE_VERSION=$(rpm -q --queryformat='%{VERSION}-%{RELEASE}' bcm2711-firmware) && \
    UBOOT_VERSION=$(rpm -q --queryformat='%{VERSION}-%{RELEASE}' uboot-images-armv8) && \
    mkdir -p /usr/lib/efi/raspi-firmware/${FIRMWARE_VERSION}/EFI && \
    mkdir -p /usr/lib/efi/raspi-uboot/${UBOOT_VERSION}/EFI && \
    cp -a /boot/efi/. /usr/lib/efi/raspi-firmware/${FIRMWARE_VERSION}/EFI/ && \
    cp -P /usr/share/uboot/rpi_arm64/u-boot.bin /usr/lib/efi/raspi-uboot/${UBOOT_VERSION}/EFI/rpi-u-boot.bin
```

Uses the `/usr/lib/efi/<component>/<version>/EFI/` structure introduced in bootupd v0.2.29.

## bootupd /usr/lib/efi Support

### Version History
- **v0.2.29** (August 11, 2024): Added support for recognizing and generating update metadata from `/usr/lib/efi`
- **v0.2.30** (September 10, 2024): Bug fixes
- **v0.2.31** (September 25, 2024): Latest release (in Fedora 42)

### Key Commits
- **Oct 15, 2024**: "efi: Extend `install()` & `update()` to support `usr/lib/efi`"
- **Oct 14, 2024**: "efi: Stop copying EFI components to `usr/lib/bootupd/updates/`"
- **Sep 28, 2024**: "efi: transfer `usr/lib/ostree-boot` to `usr/lib/efi`"

### Implementation (PR #938)
Merged July 25, 2025 - Extends metadata generation to read from `/usr/lib/efi/` directory structure.

## Expected Directory Structure

According to bootupd source code (`src/efi.rs`):

```
/usr/lib/efi/<component_name>/<version>/EFI/
```

The `get_efi_component_from_usr()` function:
- Walks exactly 3 levels deep from `/usr/lib/efi`
- Looks for directories named "EFI"
- Extracts component name and version from path structure
- Does NOT validate component names (accepts any name, not just grub2/shim)

## CRITICAL QUESTION: File Copy Behavior

### What bootupd Does
From `src/efi.rs` install() function:
```rust
filetree::copy_dir_with_args(&src_dir, efi.path.as_str(), dest, OPTIONS)
```

Where:
- `efi.path` = `"usr/lib/efi/<component>/<version>/EFI"`
- `dest` = `/boot/efi` (ESP mount point)
- `OPTIONS` = `["-rp", "--reflink=auto"]`

This executes: `cp -rp usr/lib/efi/<component>/<version>/EFI /boot/efi`

### Standard cp Behavior
Standard `cp -rp <source_dir> <dest>` copies the directory itself, resulting in:
```
/boot/efi/EFI/  <- Directory and contents copied here
```

### Raspberry Pi Requirements
Raspberry Pi needs files at **ESP root** (`/boot/efi/`), not in subdirectories:
```
/boot/efi/
├── bootcode.bin
├── start4.elf
├── fixup4.dat
├── bcm2711-rpi-4-b.dtb
├── config.txt
├── overlays/
└── rpi-u-boot.bin
```

### The Problem
If bootupd copies `usr/lib/efi/raspi-firmware/VERSION/EFI/` to `/boot/efi/`, we get:
```
/boot/efi/EFI/bootcode.bin  <- WRONG! Files in EFI subdirectory
/boot/efi/EFI/start4.elf
...
```

But Raspberry Pi expects:
```
/boot/efi/bootcode.bin      <- CORRECT! Files at root
/boot/efi/start4.elf
...
```

## Relevant bootupd Issues

### Issue #959 - Support optional update payloads, notably for ARM/AArch64 firmwares
- **Status**: Open (created June 24, 2025)
- **URL**: https://github.com/coreos/bootupd/issues/959
- **Summary**: Raspberry Pi and ARM firmware support is NOT yet fully implemented

**Proposed structure** (from issue):
```
/usr/lib/efi-firmware/uboot-images-armv8/
└── 1:2025.04-1/
    ├── EFI/
    │   └── u-boot.bin
    └── EFI.json
```

Note: Uses `/usr/lib/efi-firmware/` (different path!) with proposed `--board` selection mechanism.

**Proposed commands** (NOT YET IMPLEMENTED):
```dockerfile
RUN dnf install -y uboot-images-armv8
RUN mv u-boot.bin /usr/lib/efi-firmwares/{name}/{version}/EFI/
RUN bootupctl backend extend-firmwares
```

Then at install time:
```bash
bootupd install --board uboot-images-armv8
```

### Issue #766 - support dynamically extending/adding update payloads
- **Status**: Open (created November 7, 2024)
- **URL**: https://github.com/coreos/bootupd/issues/766
- **Summary**: Generic mechanism for extending bootloader payloads

### Issue #651 - Support for Raspberry Pi firmwares/bootloaders
- **Status**: Closed as duplicate of #766 (closed May 28, 2025)
- **URL**: https://github.com/coreos/bootupd/issues/651

### PR #935 - extend-payload-to-esp
- **Status**: Open (NOT merged)
- **URL**: https://github.com/coreos/bootupd/pull/935
- **Summary**: Introduces `bootupctl backend extend-payload-to-esp` command

## Testing Required

### Critical Tests
1. **Build the container** - Does it build successfully?
2. **Check container contents** - Verify `/usr/lib/efi/` structure exists
3. **Generate disk image** with bootc-image-builder
4. **Mount the ESP** from generated image and check:
   - Are files at `/boot/efi/` root or `/boot/efi/EFI/`?
   - Are all required Raspberry Pi files present?
   - Is `config.txt` in the right place?
5. **Boot on actual RPI4** - Does it actually boot?

### Test Commands
```bash
# Build container
podman build --platform=linux/arm64 -t test-rpi4-bootupd .

# Check /usr/lib/efi structure in container
podman run --rm --platform=linux/arm64 test-rpi4-bootupd \
  ls -la /usr/lib/efi/

# Generate disk image
sudo podman run --rm -it --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  -v $(pwd)/output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type raw --rootfs ext4 \
  ghcr.io/defrostediceman/fedora-bootc-rpi4:latest

# Mount and inspect ESP
sudo losetup -fP output/image/disk.raw
sudo mount /dev/loop0p1 /mnt
ls -la /mnt/  # Check if files are at root or in EFI/ subdir
sudo umount /mnt
sudo losetup -d /dev/loop0
```

## Possible Outcomes

### Scenario A: It Works (files end up at ESP root)
bootupd might have special handling that copies directory contents rather than the directory itself.

**Next steps**:
- Document success
- Test firmware updates work in future builds
- Submit findings to upstream bootupd

### Scenario B: It Doesn't Work (files end up in /boot/efi/EFI/)
bootupd copies the EFI directory itself, not its contents.

**Options**:
1. **Revert to bootupctl-shim** until bootupd ARM firmware support is complete
2. **Wait for Issue #959** to be resolved (proper ARM firmware support)
3. **Adjust our structure** - try not using the EFI subdirectory:
   ```
   /usr/lib/efi/raspi-firmware/${VERSION}/
   ├── bootcode.bin
   ├── start4.elf
   ...
   ```
4. **Hybrid approach** - Use both methods temporarily

### Scenario C: Partial Success
Some files work, some don't. Requires deeper investigation.

## Current Status

**UNTESTED** - This approach needs validation before we can confirm it works for Raspberry Pi 4.

## References

### bootupd Repository
- Main repo: https://github.com/coreos/bootupd
- Releases: https://github.com/coreos/bootupd/releases
- Source: https://github.com/coreos/bootupd/blob/main/src/efi.rs

### Related Projects
- Fedora CoreOS config: https://github.com/coreos/fedora-coreos-config
- ondrejbudai's implementation: https://github.com/ondrejbudai/fedora-bootc-raspi

### Documentation
- bootupd README-devel.md: https://github.com/coreos/bootupd/blob/main/README-devel.md
- bootc documentation: https://docs.fedoraproject.org/en-US/fedora-coreos/bootloader-updates/

## Authors & Contributors

- Original bootupctl-shim approach: ondrejbudai
- Migration to /usr/lib/efi: This repository
- bootupd /usr/lib/efi support: HuijingHei (PR #938)

## Next Steps

1. Test the current implementation (see Testing Required section)
2. Document results in this file
3. Based on results:
   - If successful: Update README with success notes
   - If unsuccessful: Revert to bootupctl-shim or try alternative approaches
4. Consider contributing findings to bootupd issue #959

## Update Log

- **2025-01-22**: Initial migration, documented approach and open questions
- **TODO**: Add test results here
