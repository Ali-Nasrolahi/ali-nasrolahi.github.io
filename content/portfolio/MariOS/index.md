---
title: "MariOS"
date: 2024-11-06T08:42:18Z
draft: false
description: "MariOS – x86 Hobby Operating System Development (In Progress)"
tags: ['osdev', 'in-progress']
---

## Introduction

As a personal challenge to explore operating system design,
I started developing **MariOS**, a custom x86-based hobby OS built from the ground up.
This project has involved learning and applying low-level programming concepts,
system architecture fundamentals, and the intricacies of bare-metal software development.

This project is still *in progress*, and its source code is available at my GitHub [Ali-Nasrolahi/MariOS](https://github.com/Ali-Nasrolahi/MariOS).

## Technical Details

As a fundamental component of **MariOS**, the custom multi-stage bootloader was developed entirely from scratch to initialize the OS.
This multi-stage structure was chosen to manage the complex requirements of loading higher-level components, supporting essential features such as filesystem reading and advanced binary formats.
In the first stage, the bootloader is designed to recognize the FAT16 filesystem, which allows it to locate and load the second-stage bootloader from the disk as a single binary blob.

The second-stage bootloader, crafted with more advanced linking and build configurations,
introduces support for C development, facilitating more complex initialization routines in preparation for the kernel.
This stage expands on the first by incorporating a more comprehensive FAT16 driver to enable reliable data access beyond the initial file loading.
Additionally, the second-stage bootloader includes partial support for the ELF (*in-progress*), allowing for more flexible and sophisticated kernel loading capabilities as development progresses.

Together, these features enable **MariOS** to move from low-level initialization into a robust environment for loading the kernel, establishing a solid base for further advancements in custom operating system development.

## References

In developing **MariOS**, I relied on a variety of resources, including (but not limited to):

- [OSDev](https://wiki.osdev.org/Main_Page) as the main reference.
- Various specifications like: Microsoft's *FAT32*, *ATA* and etc.
- Excellent public repositories, such as: [Nanobyte-os](https://github.com/nanobyte-dev/nanobyte_os), and much more!
