---
title: "Insights into Platform Devices, Drivers, and Buses in the Linux Kernel"
date: 2025-03-13T08:20:15Z
draft: false
description: "This post explores Platform Bus, Platform Devices, and Platform Drivers in the Linux kernel — foundational concepts for managing non-discoverable hardware in embedded systems."
tags: ['linux', 'device driver']
---

## Introduction

In this post, we dive into one of the foundational yet often misunderstood parts of the Linux device model: **Platform Bus**, **Platform Devices**, and **Platform Drivers**. These components are essential for managing embedded systems or board-specific hardware, especially when dealing with non-discoverable devices like I2C, SPI, or UART peripherals.  
We’ll break down each concept, highlight their differences, and walk through a real-world example — the **AT24 EEPROM driver**. Some prior knowledge of the **Device Tree** is recommended, as it’s commonly used to describe hardware in modern ARM-based Linux systems.

---

## What Are Platform Devices?

In the Linux kernel, **Platform Devices** refer to hardware components that cannot be discovered automatically at runtime. Unlike PCI or USB devices, they must be explicitly described—either statically in code or, more commonly, via a **Device Tree** or ACPI table.

To manage these devices, the kernel relies on three core components:

- **Platform Bus (or Platform Controller)**
- **Platform Device**
- **Platform Driver**

Each component plays a specific role in ensuring the proper initialization and management of non-discoverable devices.

---

## Platform Controller (Platform Bus)

The **Platform Bus** (or **Platform Controller**) acts as a communication bridge between the CPU and peripheral devices. It defines the interface through which the CPU accesses these devices.

Common examples include:

- **I2C**
- **SPI**
- **UART**
- **I2S**

Each of these buses has its own controller on the SoC, managed by a driver that initializes the hardware and provides the communication functions required by device drivers.

---

## Platform Devices

A **Platform Device** represents the actual hardware component connected via a platform bus. Since these devices aren't auto-discoverable, they must be described manually—usually via a Device Tree.

Examples include:

- An EEPROM chip on the I2C bus
- A touchscreen controller on SPI
- A serial console over UART

Device Tree entries for these devices typically specify:

- The device's address (e.g., I2C address)
- The bus it is connected to
- Other hardware-specific properties (e.g., page size, voltage constraints)

---

## Platform Drivers

A **Platform Driver** is responsible for managing a specific class of devices on a given platform bus. It matches against a platform device (typically using a `compatible` string defined in the Device Tree) and binds to it.

The platform driver relies on:

1. The **controller driver**, which provides the communication primitives for the bus.
2. The **platform device**, which supplies configuration details about the hardware.

Based on this information, the platform driver exposes a compatible interface to user space.

---

## Platform Driver Example: AT24 EEPROM

Let's examine the **AT24 EEPROM driver** as an example.

**Platform Bus Driver (I2C Controller):**  
On platforms like Raspberry Pi 5, the I2C bus is managed by a controller driver such as `i2c-designware-platform`. This driver initializes the I2C hardware and offers functions that allow other drivers to communicate over the bus.

**Platform Device (EEPROM Definition in Device Tree):**  
A Device Tree entry for an AT24 EEPROM might look like this:

```dts
eeprom@50 {
    compatible = "atmel,24c32";
    reg = <0x50>;
    pagesize = <32>;
    // Additional properties can be added here
};
```

This entry defines a non-discoverable I2C EEPROM device at address `0x50` with a page size of 32 bytes.

**Platform Driver (AT24 Driver):**  
The AT24 driver is a platform driver that:

- Matches the device using the `compatible` property.
- Reads configuration details (such as page size and device size) from the Device Tree.
- Checks the functionality exposed by the controller driver.
- Based on that information, it exposes a compatible interface to user space.

This integration ensures that the EEPROM is managed correctly and its functions are accessible via the appropriate system interface.

---

## Conclusion

Understanding the relationship between **platform buses**, **devices**, and **drivers** is crucial for working with embedded Linux systems.These components form the foundation for managing non-discoverable hardware devices, and the AT24 EEPROM driver example illustrates how the controller driver, platform device, and platform driver interact to provide a robust interface between the hardware and user space.  
Thank you for reading!

---

## Further Reading

- [Platform Devices and Drivers](https://www.kernel.org/doc/html/latest/driver-api/driver-model/platform.html)
- [Understanding Device Tree](https://devicetree-specification.readthedocs.io/en/latest/)
- [Linux I2C Subsystem Documentation](https://www.kernel.org/doc/html/latest/i2c/index.html)
- [AT24 EEPROM Driver Source (drivers/misc/eeprom/at24.c)](https://elixir.bootlin.com/linux/latest/source/drivers/misc/eeprom/at24.c)
