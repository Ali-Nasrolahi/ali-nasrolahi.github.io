---
title: "Using Yocto for Raspberry Pi Kernel Module Development"
date: 2025-03-06T09:30:47Z
draft: false
description: "This post explores how to use the Yocto Project to build a development environment for Raspberry Pi kernel module development. By leveraging Yocto's powerful build system, you can generate a tailored toolchain and environment, ensuring compatibility and efficiency for your custom kernel modules."
tags: ['rpi', 'yocto', 'kernel']
---

### Introduction

The Yocto Project is a powerful and flexible build system for creating custom Linux distributions. One of its key benefits is the ability to create a tailored environment for cross-compiling applications and kernel modules for various hardware platforms, including the Raspberry Pi. This post will guide you through the process of setting up Yocto to build a development environment for kernel module development on the Raspberry Pi, with a focus on the Raspberry Pi 5.

### Prerequisites

Before diving into the build process, ensure you have the following prerequisites:

- A host machine running a Linux distribution (Ubuntu or similar is recommended).
- A Raspberry Pi 5
- A stable internet connection for downloading Yocto layers and dependencies.
- Basic familiarity with Yocto, Linux kernel modules, and cross-compiling.

### Building the Image

The first step in using Yocto with Raspberry Pi is creating a custom image tailored for your needs. You'll need to set up the Yocto environment and build an image for the Raspberry Pi. Follow these steps:

1. Clone the Yocto (aka. `poky`) repository and initialize the environment:

   ```bash
   git clone --depth 1 git://git.yoctoproject.org/poky -b scarthgap
   ```

2. Set up the Raspberry Pi layers:
   - Add the `meta-raspberrypi` layer to your Yocto setup. You can find instructions in the [OpenEmbedded Index](https://layers.openembedded.org/layerindex/branch/master/layer/meta-raspberrypi/)

3. Configure the build to target Raspberry Pi 5 by selecting the appropriate machine and meta layers.

4. Build the image:

   ```bash
   source oe-init-build-env build-rpi
   bitbake core-image-minimal
   ```

This step will generate a bootable image with the necessary kernel and modules for the Raspberry Pi.

{{< alert >}}
**TIP** I've used **core-image-minimal**, you may choose appropriate image based on your needs.
As suggestion, I do recommend to include `openssh-server` package in your image which makes the deployment of out-of-tree modules easier.
{{< /alert >}}

### Building the SDK

Next, you'll need to build the Yocto SDK for cross-compiling kernel modules on your host machine. To build the SDK:

0. Ensure you''ve already included `kernel-devsrc` for the SDK. You may add following line to the end of your `local.conf`

    ```conf
    TOOLCHAIN_TARGET_TASK += "kernel-devsrc"
    ```

1. Run the following command to build the SDK from your Yocto environment:

   ```bash
   bitbake -c populate_sdk core-image-minimal
   ```

2. Once the SDK build is completed successfully, you should be able to see the outputs in `<build_dir>/tmp/deploy/sdk` directory.

   ```bash
   ➜  build-rpi git:(scarthgap) ls -lh tmp/deploy/sdk
    total 634M
    -rw-r--r-- 2 build build  14K Mar  5 22:33 poky-glibc-x86_64-core-image-minimal-cortexa76-raspberrypi5-toolchain-5.0.7.host.manifest
    -rw-r--r-- 2 build build 1.4M Mar  5 22:33 poky-glibc-x86_64-core-image-minimal-cortexa76-raspberrypi5-toolchain-5.0.7-host.spdx.tar.zst
    -rwxr-xr-x 2 build build 629M Mar  5 22:45 poky-glibc-x86_64-core-image-minimal-cortexa76-raspberrypi5-toolchain-5.0.7.sh
    -rw-r--r-- 2 build build  13K Mar  5 22:32 poky-glibc-x86_64-core-image-minimal-cortexa76-raspberrypi5-toolchain-5.0.7.target.manifest
    -rw-r--r-- 2 build build 3.3M Mar  5 22:32 poky-glibc-x86_64-core-image-minimal-cortexa76-raspberrypi5-toolchain-5.0.7-target.spdx.tar.zst
    -rw-r--r-- 2 build build 354K Mar  5 22:32 poky-glibc-x86_64-core-image-minimal-cortexa76-raspberrypi5-toolchain-5.0.7.testdata.json
   ```

### Extracting the SDK and Setting Up the Environment

After building the SDK, extract it on your host machine and set up the environment using the included shell script.
Mine is called `poky-glibc-x86_64-core-image-minimal-cortexa76-raspberrypi5-toolchain-5.0.7.sh`.

1. Extract the SDK:

   ```bash
   ./poky-glibc-x86_64-core-image-minimal-cortexa76-raspberrypi5-toolchain-5.0.7.sh
    Poky (Yocto Project Reference Distro) SDK installer version 5.0.7
    =================================================================
    Enter target directory for SDK (default: /opt/poky/5.0.7):
   ```

   You will be prompted to choose the location for the uncompressed SDK.

2. Source the setup script to initialize the environment:

   ```bash
   source /opt/poky/5.0.7/environment-setup-cortexa76-poky-linux
   ```

3. This will configure the necessary paths and environment variables, enabling you to cross-compile necessary packages for the Raspberry Pi.

4. To cross-compile the kernel modules you'll need to prepare the kernel source.

5. First find the SDK's kernel tree, mine is located in `<sdk_location>/sysroots/cortexa76-poky-linux/usr/src/kernel`

6. Then run following commands to prepare the kernel for module development:

    ```bash
    make prepare scripts
    ```

{{< alert >}}
Before prepare the kernel, ensure you already sourced the environment setup script. That is, `environment-setup-cortexa76-poky-linux`
{{< /alert >}}

All done! Now use preceding kernel tree as your `KERNEL_SRC` in your module development `Makefile`.

### Creating a Sample Kernel Module

Now that the environment is set up, you can begin developing kernel modules for your Raspberry Pi. For this example, we'll create a simple "Hello, World!" kernel module.

1. Create a directory for your kernel module and create the following files:

   - `hello_world.c` (the module code)
   - `Makefile` (to build the module)

   Example `hello_world.c`:

   ```c
   #include <linux/module.h>
   #include <linux/kernel.h>
   #include <linux/init.h>

   static int __init hello_init(void) {
       printk(KERN_INFO "Hello, World!\n");
       return 0;
   }

   static void __exit hello_exit(void) {
       printk(KERN_INFO "Goodbye, World!\n");
   }

   module_init(hello_init);
   module_exit(hello_exit);

   MODULE_LICENSE("GPL");
   ```

2. Create a `Makefile` to compile the module:

   ```make
   KERNEL_SRC="<location of the kernel tree>"
   obj-m += hello_world.o
   all:
       make -C $(KERNEL_SRC) M=$(PWD) modules
   clean:
       make -C $(KERNEL_SRC) M=$(PWD) clean
   ```

3. Then use `make` to build the `ko` file

### Deploying the Kernel Module

After building the kernel module, you need to deploy it to the Raspberry Pi. You can either copy the module over SSH or use an SD card.

1. Copy the kernel module to the Raspberry Pi:

   ```bash
   scp hello_world.ko <user>@<rpi_ip>:/tmp
   ```

2. SSH into the Raspberry Pi:

   ```bash
   ssh <user>@<rpi_ip>
   ```

3. Load the module on the Raspberry Pi:

   ```bash
   insmod /tmp/hello_world.ko
   ```

4. Unload the module:

    ```bash
    sudo rmmod hello_world
    ```

5. Check the kernel log to confirm the module's load and unload message:

   ```bash
   dmesg | tail
   ```

### Thank you

### References

- [https://www.yoctoproject.org/docs/](https://www.yoctoproject.org/docs/)
- [https://github.com/agherzan/meta-raspberrypi](https://github.com/agherzan/meta-raspberrypi)
- [https://www.kernel.org/doc/html/latest/](https://www.kernel.org/doc/html/latest/)
- [https://docs.yoctoproject.org/dev-manual/start.html](https://docs.yoctoproject.org/dev-manual/start.html)
- [https://docs.yoctoproject.org/kernel-dev/index.html](https://docs.yoctoproject.org/kernel-dev/index.html)
- [https://docs.yoctoproject.org/sdk-manual/index.html](https://docs.yoctoproject.org/sdk-manual/index.html)
- [https://stackoverflow.com/questions/60923890/how-to-build-linux-kernel-module-using-yocto-sdk](https://stackoverflow.com/questions/60923890/how-to-build-linux-kernel-module-using-yocto-sdk)
