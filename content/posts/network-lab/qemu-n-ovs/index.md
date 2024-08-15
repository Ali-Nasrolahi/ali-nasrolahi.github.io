---
title: "QEMU And Open vSwitch"
date: 2024-08-15T19:34:14Z
draft: false
description: "Intro to QEMU and Open vSwitch"
tags: ['qemu', 'open vswitch', 'network']
series: ['VirtualNetworking']
series_order: 2
---

In this part, we will take an overview of three main components, which were mentioned in the previous post. Those are `QEMU/KVM`, `Open vSwitch` and `ip(8)` command.
Each of these tools, designed by experts, provides a robust infrastructure for industry use.
Naturally, in this series, we will only scratch the surface of the capabilities this toolset provides,
but even a glimpse into their abilities should intrigue any curious reader.

## QEMU

According to **QEMU (Quick Emulator)**'s [Wikipedia](https://en.wikipedia.org/wiki/QEMU):

> QEMU is a free and open-source emulator. It emulates a computer's processor through dynamic binary translation and provides
> a set of different hardware and device models for the machine, enabling it to run a variety of guest operating systems.

Also according to QEMU's [official documentation](https://www.qemu.org/docs/master/about/index.html):

> QEMU can be used in several different ways. The most common is for System Emulation, where it provides a virtual model of an entire machine (CPU, memory and emulated devices)
> to run a guest OS. In this mode the CPU may be fully emulated, or it may work with a hypervisor such as KVM, Xen or Hypervisor.Framework to allow the guest to run directly on the host CPU.

If you've had experience with virtualization before, the concept of **emulation** should be familiar to you.
Usually, *emulation* refers to virtual implementation (software-defined) of some kind of hardware(s).
For examples, there are many projects that *emulate* different types of CPUs, MCUs (Microcontroller), MPUs (Microprocessor) and even peripheral devices.
> An example of emulated devices is the well-known loopback device for NICs and hard disks.

QEMU supports various CPUs (x86, ARM, AVR, MIPS), network devices, hard disks and a lot more! All of this is available in *userspace* as well.
Additionally, to boost guest performance, QEMU utilizes accelerators like [KVM](https://www.kernel.org/doc/html/latest/virt/kvm/index.html) to give
closest experience to actual hardware for virtual environments.

If you haven't had any experience with QEMU, I'd recommend getting hands-on with some tutorials and simple concepts.
For this series, ensure you've gained a broad grasp of [Network emulation](https://www.qemu.org/docs/master/system/devices/net.html), which is heavily used in later chapters.

## Open vSwitch

Similar to QEMU, according to **Open vSwitch**'s [Wikipedia](https://en.wikipedia.org/wiki/Open_vSwitch):

> Open vSwitch (OVS) is an open-source implementation of a distributed virtual multilayer switch. The main purpose of Open vSwitch is to provide a switching stack for hardware virtualization environments,
> while supporting multiple protocols and standards used in computer networks.

And according to OVS [homepage](https://www.openvswitch.org/):

> Open vSwitch is a production quality, multilayer virtual switch. It is designed to enable massive network automation through programmatic extension,
> while still supporting standard management interfaces and protocols (e.g. NetFlow, sFlow, IPFIX, RSPAN, CLI, LACP, 802.1ag).
> In addition, it is designed to support distribution across multiple physical servers similar to VMware's vNetwork distributed vswitch or Cisco's Nexus 1000V.

These descriptions should clearly demonstrate OVS's capabilities.
Although OVS is overkill for our purposes and could easily be replaced by *Linux Bridges*, I still prefer to use it in this series
To follow along, a basic understanding of *bridges* and *ports* should be more than enough. To get started maybe try [this](https://medium.com/@ozcankasal/understanding-open-vswitch-part-1-fd75e32794e4).

## IP

`ip` is a unified utility that substitutes legacy ones like `ifconfig`, `route`, `brctl` and more.
It is widely available on conventional Linux distributions and should be installed by default.
To learn more, please refer to the [iproute2](https://en.wikipedia.org/wiki/Iproute2) project's Wikipedia.

In the next chapter, we start to building our environment and discuss main ideas.
