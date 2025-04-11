---
title: "ADXL345 SPI Accelerometer Driver for BeagleBone Black"
date: 2025-04-11T07:02:37Z
draft: false
description: "Learn how to write a Linux kernel driver for the ADXL345 accelerometer using SPI on BeagleBone Black. This step-by-step guide covers SPI communication, device tree overlays, character device interface, IOCTL commands, and sysfs attributes, with full source code on GitHub. Perfect for embedded Linux developers working on sensor drivers, motion detection, or SPI peripherals—includes Buildroot integration and a test application for validation."
tags: ['beaglebone', 'device driver', 'linux', 'kernel']
---

## Introduction

In this post, I'll walk through my development of a Linux kernel driver for the ADXL345 accelerometer, tested on a BeagleBone Black running a minimal Linux image built with Buildroot.

The ADXL345 is a small, thin, low-power 3-axis accelerometer with high resolution (13-bit) measurement up to ±16g. It's commonly used in embedded systems for motion detection, tilt sensing, and vibration measurement applications. The device communicates via either I2C or SPI (my implementation uses SPI).

This driver demonstrates several Linux kernel concepts:

- SPI device driver implementation
- Character device interface
- IOCTL for device control
- Sysfs attributes for simple user interaction

The full source code is available here:  
📌 [https://github.com/Ali-Nasrolahi/adxl345](https://github.com/Ali-Nasrolahi/adxl345)

## Setup

The driver was developed and tested with:

- **Hardware**: BeagleBone Black board
- **OS**: Minimal Linux image built using Buildroot's `beaglebone_defconfig`
- **Interface**: SPI0 (enabled via device tree overlay included in the project)

To enable the SPI interface, I created a device tree overlay (`BB-SPI0-ADXL345-00A0.dts`) that configures the appropriate pins and SPI controller. The overlay follows the same format as those in the [BeagleBoard overlay repository](https://github.com/beagleboard/bb.org-overlays/tree/master).

## Source Code Layout

### Kernel Side

The driver is logically divided into two components:

1. **adxl-core.c**: Handles low-level register operations and communicates directly with the SPI subsystem. This includes:
   - Register read/write operations
   - Device initialization and configuration
   - Data acquisition from the accelerometer

2. **adxldev.c**: Implements the Linux device driver interface with:
   - Character device operations (open, read, write, release)
   - IOCTL interface for device control
   - Sysfs attribute creation for easy access to device parameters

*Future Improvement Note*: I'm planning to integrate the `regmap` subsystem to abstract the low-level SPI operations, which would make the code more maintainable and potentially more efficient.

### User Space Interface

The driver provides multiple ways to interact with the device:

1. **Character Device Interface**: Traditional file operations (`/dev/adxlX`) for:
   - Simple open/read/close operations
   - Raw acceleration data reading

2. **IOCTL Interface**: For more advanced control:
   - Enable/disable device
   - Set data rate (7-12 corresponding to 25-3200 Hz)
   - Set measurement range (±2g, ±4g, ±8g, ±16g)

3. **Sysfs Attributes**: Easy access via `/sys/class/adxl_class/adxlX/` with:
   - Read-only attributes for X/Y/Z acceleration values
   - Read-write attributes for data rate and range configuration

## Test Application

To demonstrate the driver's functionality, I created a comprehensive test application (`app.c`) that exercises all interfaces. The application performs three main tests:

1. **IOCTL functionality**: Verifies device enable/disable and rate/range settings
2. **Acceleration reading**: Samples and displays acceleration data
3. **Sysfs interface**: Tests attribute reading/writing

Here's an example output from the test application:

```plaintext
ADXL345 Driver Test Application
Usage: This application tests all functionality of the ADXL345 driver
It performs the following tests:
  1. IOCTL interface testing (enable/disable, rate/range settings)
  2. Acceleration data reading
  3. Sysfs attribute interface testing

[00:34:38] Starting ADXL345 driver tests
[00:34:38] Device opened successfully

=== IOCTL FUNCTIONALITY TEST ===
[00:34:38] Device enabled
[00:34:38] Device disabled
[00:34:38] Current data rate: 12
[00:34:38] Data rate set to: 7
[00:34:38] Rate setting verified
[00:34:38] Data rate set to: 8
[00:34:38] Rate setting verified
[00:34:38] Data rate set to: 9
[00:34:38] Rate setting verified
[00:34:38] Data rate set to: 10
[00:34:38] Rate setting verified
[00:34:38] Data rate set to: 11
[00:34:38] Rate setting verified
[00:34:38] Data rate set to: 12
[00:34:38] Rate setting verified
[00:34:38] Current measurement range: 3
[00:34:38] Range set to: 0
[00:34:38] Range setting verified
[00:34:38] Range set to: 1
[00:34:38] Range setting verified
[00:34:38] Range set to: 2
[00:34:38] Range setting verified
[00:34:38] Range set to: 3
[00:34:38] Range setting verified
Test completed successfully

=== ACCELERATION READING TEST ===
[00:34:38] Reading acceleration data...
Sample 1: X=45     Y=-247   Z=43    
Sample 2: X=46     Y=-249   Z=47    
Sample 3: X=44     Y=-244   Z=44    
Sample 4: X=45     Y=-246   Z=44    
Sample 5: X=46     Y=-250   Z=43    
Test completed successfully
[00:34:39] Device closed successfully

=== SYSFS INTERFACE TEST ===

Testing attribute: range
  Current value: 3
  Set to 0: Readback 0
  Set to 1: Readback 1
  Set to 2: Readback 2
  Set to 3: Readback 3

Testing attribute: rate
  Current value: 12
  Set to 9: Readback 9
  Set to 10: Readback 10
  Set to 11: Readback 11
  Set to 12: Readback 12

Testing attribute: x
  Current value: 46
  (Read-only attribute)

Testing attribute: y
  Current value: -251
  (Read-only attribute)

Testing attribute: z
  Current value: 44
  (Read-only attribute)
Test completed successfully
[00:34:39] All tests completed
```

The colorful output (visible when viewing `app.output` with `cat`) makes it easy to distinguish different test sections and results.

## Final Thoughts

Developing this driver was an excellent exercise in Linux kernel programming and embedded systems development. Through this project, I gained:

- Deeper understanding of the Linux device driver model
- Hands-on experience with SPI device communication
- Practical knowledge of device tree overlays for hardware configuration
- Insight into different user-kernel interaction methods (sysfs, ioctl, character devices)

The driver currently works well for basic accelerometer functionality, but there are several potential improvements:

1. Integration with the `regmap` subsystem
2. Adding support for interrupt-driven operation
3. Implementing input subsystem integration for event reporting

I hope this project can serve as a reference for others working with the ADXL345 or similar sensors on embedded Linux platforms.

For those interested in exploring the implementation details or using the driver, the complete source code is available at:  
🔗 [https://github.com/Ali-Nasrolahi/adxl345](https://github.com/Ali-Nasrolahi/adxl345)
