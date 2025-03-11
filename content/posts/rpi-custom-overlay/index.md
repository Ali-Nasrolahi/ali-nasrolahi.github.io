---
title: "Custom Overlay Device Tree Integration for Raspberry Pi 5 with Yocto"
date: 2025-03-11T06:11:52Z
draft: false
description: "Discover how to integrate custom overlay device trees for the Raspberry Pi 5 using the Yocto Project. This concise overview covers setup, compilation, and deployment, helping you customize your hardware configurations and enhance your projects!"
tags: ['rpi', 'linux', 'yocto']
---

## Introduction

Our agenda is simple: we’re going to integrate our own overlay DTS (which compiles into a DTBO) into the Yocto build system for the Raspberry Pi 5. The goal is to have the overlay built, deployed, and enabled automatically. This post is aimed at developers who want to extend the default device tree configuration for custom hardware or functionality without modifying the upstream kernel files.

## What Is a Device Tree Overlay and How Does It Help?

A device tree overlay is a mechanism to modify or extend the base device tree used by your hardware. It allows you to add, disable, or change hardware configuration details at boot time without rewriting the entire device tree blob. This modular approach simplifies hardware customization and maintenance, especially when dealing with custom peripherals or board-specific tweaks.

## Prerequisites

Before diving in, make sure you have the following:

- **Yocto Project Environment:** A working Yocto setup.
- **meta-raspberrypi Layer:** Configured for your specific board (Raspberry Pi 5).
- Basic understanding of BitBake recipes and layer management.

## Creating a Custom Meta-Layer

It’s a best practice to isolate your customizations in a separate meta-layer. Create your custom meta-layer (e.g., `meta-custom-overlay`) and add it to your `bblayers.conf`. This keeps your modifications separate from the official layers and makes maintenance easier.

## Integrating Your DTS File into the RPI Kernel Build Process

To include your custom overlay, follow these steps:

1. **Mimic the Directory Structure:**
  Create the same hierarchy as in `meta-raspberrypi/recipes-kernel/linux/` in your custom meta-layer.

2. **Create a bbappend File:**
  Add a file named `linux-raspberrypi_%.bbappend` in your layer. In this file, append your custom DTS file to the kernel build settings:

3. **SRC_URI Append:**
        Append your overlay DTS file to `SRC_URI` and specify the subdirectory so that it gets copied to the kernel source tree (i.e., `arch/${ARCH}/boot/dts/overlays`).

4. **Register the Overlay:**
        Also, append your overlay (e.g., `overlays/<your-overlay-name>-overlay.dts`) to the `RPI_KERNEL_DEVICETREE_OVERLAYS` variable so it will be compiled into a DTBO during the kernel build.

As an example following could be your `linux-raspberrypi_%.bbappend`:

```bash
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
PACKAGE_ARCH = "${MACHINE_ARCH}"

SRC_URI:append:rpi = " file://<your-overlay-name>-overlay.dts;subdir=git/arch/${ARCH}/boot/dts/overlays"
```

Also hierarchy of the custom meta layer should be similar to the following:

```bash
meta-custom
├── conf
│   └── layer.conf
├── COPYING.MIT
├── README
└── recipes-kernel
    └── linux
        ├── linux-raspberrypi
        │   └── rpi
        │       └── <your-overlay-name>-overlay.dts
        └── linux-raspberrypi_%.bbappend
```

## Enabling the Overlay

Once the overlay is built, you need to ensure it’s loaded at boot:

1. **Replicate the rpi-config Hierarchy:**
    Create a corresponding bbappend for the `rpi-config` recipe in your meta-layer.

2. **Append to do_deploy:**
    In your bbappend, add a snippet to the `do_deploy:append` task that echoes the overlay configuration into `config.txt`. For example:

    ```bash
    echo "dtoverlay=<your-overlay-name>" >> ${CONFIG}
    ```

3. **Verify the hierarchy**
    At the end, similar to the following structure should your meta layer represent:

    ```c
    meta-custom
    ├── conf
    │   └── layer.conf
    ├── COPYING.MIT
    ├── README
    ├── recipes-bsp
    │   └── bootfiles
    │       └── rpi-config_git.bbappend
    └── recipes-kernel
        └── linux
            ├── linux-raspberrypi
            │   └── rpi
            │       └── <your-overlay-name>-overlay.dts
            └── linux-raspberrypi_%.bbappend
    ```

## Few Tips

- **Verify DTS Integrity:**
  Always run the Device Tree Compiler (dtc) to check your DTS file. For example:

  ```bash
  dtc -I dts -O dtb -o <your-overlay-name>.dtbo <your-overlay-name>-overlay.dts
  ```

- **File Naming Convention:**
  Ensure your overlay DTS file ends with `-overlay.dts` (e.g., `custom-overlay.dts`). When referencing it in `RPI_KERNEL_DEVICETREE_OVERLAYS`, omit the `-overlay.dts` suffix; the build system expects a reference like `<your-name>.dtbo`. I spent several hours debugging a misconfiguration due to an incorrect file name.

- **Kernel Build Issues:**
  If you encounter issues during the kernel build, use the kernel `devshell` (e.g., `bitbake linux-raspberrypi -c devshell`) to inspect the placement of your DTS file. It should reside in `arch/${ARCH}/boot/dts/overlays`. Also, try compiling it directly with:

  ```bash
  make overlays/<your-overlay-name>.dtbo
  ```

  (Note: Do not include the `-overlay` suffix in the make target.)

- **Deployment Troubleshooting:**
  If your files aren’t being copied to the target image, check the `IMAGE_BOOT_FILES` variable. Often, the root cause is that `RPI_KERNEL_DEVICETREE_OVERLAYS` does not include your overlay file. Use:

  ```bash
  bitbake -e <your_image>
  ```

  to inspect the final image variables and ensure your overlay is correctly included. I learned this the hard way after spending a couple more hours debugging the deployment.

## Conclusion

In this post, we covered the process of integrating a custom device tree overlay for the Raspberry Pi 5 using Yocto. By setting up a custom meta-layer, modifying the kernel build process, and updating the boot configuration, you can seamlessly include and enable your overlay. I hope these insights and tips help you avoid the pitfalls I encountered. Happy building, and thanks for reading!

## Further Reading

- [Yocto Project Documentation](https://www.yoctoproject.org/docs/latest/)
- [meta-raspberrypi Repository](https://github.com/agherzan/meta-raspberrypi)
