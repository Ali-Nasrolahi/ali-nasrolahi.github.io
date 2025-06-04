---
title: "Writing an I2C EEPROM Driver for AT24 Series"
date: 2025-03-22T17:10:41Z
draft: false
description: ""
tags: ['device driver', 'linux', 'kernel']
---

## Introduction

In this post, I walk through the process of writing a custom I2C device driver for the **AT24-series EEPROM** chips, tested on a **Raspberry Pi 5** running a Yocto-built minimal Linux image.

The **AT24 EEPROM family** includes byte-addressable I2C non-volatile memories commonly used for storing small configuration data, calibration constants, or logs. These EEPROMs are simple but reliable, and writing a driver for them is a great exercise to understand I2C subsystem, character devices, and user-kernel interaction in Linux.

The full source code and a minimal test application are available here:  
> 📌 [https://github.com/Ali-Nasrolahi/at24](https://github.com/Ali-Nasrolahi/at24)

---

## Setup

For this project, I used the following setup:

- **Hardware**: Raspberry Pi 5 with an AT24C02 EEPROM connected to the I2C bus.
- **Software**: Custom Linux kernel built with Yocto (tested on kernel 6.6), minimal core image.
- **Driver Environment**: Kernel module compiled externally, loaded dynamically.
- **Device Tree Overlay**: Included in the repository, used to bind the driver to the EEPROM device via the compatible string `zephyr,eeprom_driver`.

### Applying the Overlay

Before loading the driver, apply the provided overlay to enable the I2C device and bind it to the driver:

```bash
# Example (assuming EEPROM is on i2c1 at address 0x50):
dtoverlay at24-overlay.dtbo
```

Check `dmesg` output to verify the driver loaded and probed correctly:

```bash
dmesg | grep at24
```

---

## 3. Source Code Layout

### 3.1 I/O Implementation

Data transfer is handled via the **I2C SMBus API**, using `i2c_smbus_read_byte_data()` and `i2c_smbus_write_byte_data()` for byte-level access. This reflects the nature of AT24 EEPROMs, which typically support random byte-oriented read/write operations.

A write delay (`msleep()`) is introduced between consecutive byte writes to allow internal EEPROM write cycles to complete.

```c
i2c_smbus_write_byte_data(ldev->client, offset, data);
i2c_smbus_read_byte_data(ldev->client, offset);
```

### 3.2 User Space Interaction

User space interaction is implemented using a **character device** interface. The driver supports:

- `read()` — Read EEPROM contents
- `write()` — Write data to EEPROM
- `llseek()` — Move file offset to random address

This allows simple file I/O from user space using tools like `dd`, or applications written in C, Python, etc.

#### Example: Using `llseek()` for Random Access

```c
lseek(fd, 0x10, SEEK_SET);  // Move to address 0x10
read(fd, buffer, 1);        // Read a byte
```

The EEPROM is exposed as `/dev/eeprom0`, `/dev/eeprom1`, etc., depending on how many devices are registered.

---

## 4. Testing the Driver

You can test the driver in two ways:

### 4.1 Using the C Test App

A minimal **C test application** is provided in the repository to demonstrate file operations. It performs read, write, and seek operations on the `/dev/eepromX` device:

```bash
make app
./app
```

### 4.2 Using Shell and `dd`

You can also interact with the EEPROM from the shell using standard tools like `dd`.

#### Write a byte at offset 0x20

```bash
echo -n -e '\xAB' | dd of=/dev/eeprom0 bs=1 seek=32
```

#### Read a byte from offset 0x20

```bash
dd if=/dev/eeprom0 bs=1 skip=32 count=1 | hexdump -C
```

This makes it easy to inspect, backup, or update EEPROM contents without needing any special utilities.

---

## Final Thoughts

This project demonstrates how to write a simple yet practical **Linux kernel driver** for an I2C EEPROM device. It integrates well with the Linux I2C subsystem, exposes a standard character device interface, and works seamlessly with common user space tools.  
🔗 [GitHub: Ali-Nasrolahi/at24](https://github.com/Ali-Nasrolahi/at24)
