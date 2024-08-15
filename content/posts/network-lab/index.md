---
title: "Part 1: Introduction to Virtual Network"
date: 2024-08-14T18:30:18Z
draft: false
description: "Virtual Network with QEMU/KVM and Open vSwitch Infrastructure"
tags: ['qemu', 'open vswitch', 'network']
series: ['Virtual Networking']
series_order: 1
---

## What Is This Series About?

In this series, we'll explore an unconventional approach to setting up a virtual network laboratory for various scenarios and purposes.
You might be familiar with popular frameworks like [GNS3](https://www.gns3.com/) and [Cisco's Packet Tracer](https://www.netacad.com/courses/packet-tracer)
for learning the fundamentals of networking, switching, routing, and firewalls. Similarly, we'll build *our own infrastructure* for networking,
but with a hands-on experience that delves deeper into the underlying technologies.

## Why?

The motivation behind this approach is driven by curiosity and the desire to gain unique, hands-on experience with the underlying technologies.
Therefore, this series is not intended to be a substitute for the tools mentioned above and does not aim to replicate their objectives.

## Prerequisites

To follow this series, it's recommended that you have experience with the fundamentals of Linux, Bash, Virtualization, and Switching.
The tools we'll use are not designed to be user-friendly or particularly easy to follow; as a result, it might feel a bit frustrating at first.
But that's part of the learning process.

## Environment Setup

I assume you already have a conventional Linux system installed and ready to use. Let's dive in.  
The main components we'll need are:

- [QEMU/KVM](https://www.qemu.org/)
- [Open vSwitch](http://www.openvswitch.org/)
- [IP command](https://linux.die.net/man/8/ip)

Refer to their respective installation pages for installation instructions.
If you're using a conventional distribution (i.e. RHEL-based, Debian-based, or Arch-based),
your repository should already provide pre-built packages. If not, you'll need to compile them manually.

After installation, your system should include the `qemu-system-x86_64`, `ovs-vsctl` and `ip` binaries.

{{< alert >}}
**Note.** On RHEL based system `qemu-system-x86_64` might be called `qemu-kvm` instead.
Don't worry; everything should work fine.
{{< /alert >}}

For testing:

```bash
qemu-system-x86_64 --version
ovs-vsctl --version
ip --br a
```

Using Open vSwitch commands requires superuser privileges, so be sure to use `root` or `sudo` when running the commands.

{{< alert >}}
**Note.** Also ensure `Open vSwitch` service is running. The service name could be
`ovs-vswitchd.service` or `openvswitch.service`. Refer to your distro's Open vSwitch page.
{{< /alert >}}

Excellent! In the next part, we'll cover what each of these tools is and what they do for us.
