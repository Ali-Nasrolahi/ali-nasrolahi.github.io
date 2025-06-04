---
title: "AVR"
date: 2024-11-06T18:58:22Z
draft: false
description: "AVR Group projects"
tags: ['embedded', 'avr', 'microchip']
---

## Introduction

Driven by a passion for low-level programming and embedded systems, I began working with AVR microcontrollers to deepen my expertise in bare-metal development.
AVR microcontrollers offer an ideal platform for hands-on learning in direct hardware control, thanks to their straightforward architecture, comprehensive documentation,
and widespread application in embedded systems.

Projects' sources are publicly available at [GitHub/Ali-Nasrolahi](https://github.com/Ali-Nasrolahi/).

## AVR library

**AVR Library** is a custom library to simplify bare-metal programming across a range of embedded projects.
This library serves as an accessible API, providing a hardware abstraction layer (HAL) for essential communication protocols such as SPI, I2C, and UART.
Designed for flexibility and ease of integration, it enables developers to work directly with low-level hardware functions while benefiting from a streamlined development experience.

Furthermore, it has been utilized as the main framework for my other projects, as well.

Source code is available at [Ali-Nasrolahi/AVRLib](https://github.com/Ali-Nasrolahi/avrlib).

## SD Card Driver with Basic I/O Support

Building on the foundation of the *AVR library*, the SD card driver facilitates data storage and retrieval directly from the microcontroller.
Utilizing the SPI protocol implemented in the HAL, this driver enables efficient communication between the microcontroller and an SD card, allowing for straightforward data management.
This SD card driver supports basic I/O operations, seamlessly integrating with the broader AVR library for smooth, dependency-free data handling.

Source code is available at [Ali-Nasrolahi/AVR-SDCard](https://github.com/Ali-Nasrolahi/avr-sdcard).

## DC Motor control based on L293

A bidirectional DC motor control system was developed using an L293 motor driver, with ADC employed for analog inputs to generate corresponding PWM signals for precise speed control.

Source code with used circuit are available at [Ali-Nasrolahi/AVR-Gists/Motors](https://github.com/Ali-Nasrolahi/avr-gists/tree/master/Motors).

## References

Main reference for all projects are their specifications, such as:

- *Microchip's ATmega datasheet*
- SD Specifications, Part 1: Physical Layer
- The datasheet for each component relevant to each project

Also great public repositories, such as *Arduino's* libraries and community projects, were extremely helpful.
