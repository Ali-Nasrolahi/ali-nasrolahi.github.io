---
title: "Setting Up a Virtual Networking Environment"
date: 2024-08-16T16:57:46Z
draft: false
description: "Setup virtual networking environment using QEMU and Open vSwitch"
tags: ['qemu', 'openvswitch', 'network']
series: ['VirtualNetworking']
series_order: 3
---

In the previous chapter, we introduced the tools we'll be using.
In this chapter, we will explore how each of these tools can help us set up this lab.
As a reminder, ensure you have solid grasp of mentioned topics in the last chapter before moving on.

## The Idea

Network labs typically consist of several PCs (clients), servers, switches, routers, and firewalls.
Implementing these devices is straightforward if viewed in this way:

- We will need a few computers that can act as clients and servers with appropriate operating systems.
- As for routers/firewalls, free software firewalls like `pfSense` can be used reliably.
- For switching, `Open vSwitch` provides a solid foundation and a rich feature set.
- Finally, the connections between these components can be managed using Linux's virtual network devices like `TAP`

If you look closely, you realize the first two could be utilized using `QEMU`'s virtual machines and `TAP` devices for NICs.
This is, essentially, the idea.

## Example scenario

One of my personal lab for a college presentation was to showcase [Snort](https://www.snort.org/)'s capabilities in `IDS/IPS` scenarios.
For this lab, I prepared three components:

- A *Kali* Linux VM as an attacker
- A *pfSense* VM equipped with *Snort* plugin
- and a *Debian* Linux VM as a victim server

I then demonstrated how Snort detects and optionally blocks various types of incoming attacks.
This is the basic scenario, which I will use to explain the components.

## Virtual Machines

Creating virtual machines using QEMU is not as complicated as it might seam.
At a bare minimum, a virtual machine requires a CPU, RAM, and a hard disk.
For our purposes, network interfaces are also necessary. Refer to QEMU's official documentation under
[*System Emulation*](https://www.qemu.org/docs/master/system/introduction.html#) for more details.
Besides hard disks, other components have predefined default behaviors that you can ignore for now.

### Hard disks

For hard disks, we'll use `qemu-img` and `qcow2` format, which is native format for `QEMU`'s [disk images](https://www.qemu.org/docs/master/system/images.html).
There are many tutorials on disk images like [this](https://computernewb.com/wiki/How_to_create_a_disk_image_in_QEMU).
The main usage is something like the following:

```bash
# where myimage.img is the disk image filename and mysize is its size in kilobytes. You can add an M suffix to give the size in megabytes and a G suffix for gigabytes.
qemu-img create <myimage.img> <mysize>

# For example:
qemu-img create -f qcow2 pfsense.img 40G

```

Create images for your clients, servers and firewalls.
> For mentioned scenario, I created three disks for each of the operating systems.

### Install the operating systems

After creating the disks, you're ready to install the OSes. Just download your desired Linux/Firewall/Router ISO images and run virtual machines with corresponding disk and ISO image.
Like before, refer to official documentation for detailed explanation, but here's what I normally use:

```bash
qemu-system-x86_64 \
    -enable-kvm \
    -smp 2 \    # CPU
    -m 1024 \   # RAM
    -hda <DISK IMAGE> \
    -cdrom  <ISO IMAGE> \
```

{{< alert >}}
**TIP** I recommend connecting your host machine to internet
and install all needed packages/plugins on your guest machines.
Your guest machines should be NAT-ed automatically by QEMU and should be able to connect to the internet by default.
{{< /alert >}}

### Network Interfaces

As stated above, we will use TAP devices for both virtual machines and OVS bridges.
To create a TAP device use `ip(8)` command like so:

```bash
ip tuntap add mode tap <tapname>    # Create
ip link set up <tapname>            # Enable

# For example:
ip tuntap add mode tap pfsense_wan_tap
ip link set up pfsense_wan_tap
```

To remove the TAP:

```bash
ip tuntap del mode tap <tapname>
```

Then, pass these TAP devices as `netdev` to virtual machines like so:

```bash
qemu-system-x86_64 \
    <disk and other mentioned options> \
    -device e1000,mac=<mac_addr>,netdev=<id>,id=<id> \
    -netdev tap,id=<id>,ifname=<tapname>,script=no,downscript=no
```

For example my pfSense VM setup is like so:

```bash
qemu-system-x86_64 \
    -enable-kvm \
    -smp 2 \    # CPU
    -m 1024 \   # RAM
    -hda pfsense.img \
    \           # NIC 1
    -device e1000,mac=50:54:00:00:00:42,netdev=wan,id=wan \
    -netdev tap,id=wan,ifname=pfsense_wan_tap,script=no,downscript=no \
    \           # NIC 2
    -device e1000,mac=50:54:00:00:00:43,netdev=lan,id=lan \
    -netdev tap,id=lan,ifname=pfsense_lan_tap,script=no,downscript=no
```

That's about virtual machines and QEMU's environment setup. Let's move on to Open vSwitch.

## Bridges

Managing bridges is simpler compared to the other steps.
Simply design your network, then connect the corresponding VM's TAP port to the bridge.

In the example scenario, I created two bridges:

- one for my LAN network
- another for WAN.

Then connected my client and *pfSense*'s *WAN* port to WAN switch (public network).
The other pfSense's port with my server port are connected to *LAN* bridge.

Something like this:

```text
-----------------           -------------           -------------
|               |           |           |           |           |
|   Attacker    |<=========>|  LAN BR   |<=========>|  pfSense  |
|               |           |           |           |           |
-----------------           -------------           -------------
```

To do so, I've used:

```bash
ovs-vsctl add-br wan_sw
ovs-vsctl add-br lan_sw
ovs-vsctl add-port wan_sw kali_wan_tap
ovs-vsctl add-port wan_sw pfsense_wan_tap
ovs-vsctl add-port lan_sw pfsense_lan_tap
ovs-vsctl add-port lan_sw debian_lan_tap
```

{{< alert >}}
**TIP** If you would like to connect bridges to your host. Try OVS `internal` ports.
{{< /alert >}}

## Put altogether

As you've seen, by using two of the most powerful open-source projects, we've established our own networking lab.
Hopefully, you've learned a few new concepts, or at least sparked your curiosity about how the underlying layers work.

The example scenario with full scripts is available on [My GitHub](https://github.com/Ali-Nasrolahi/network).
For easier management, I've created a `Makefile` and adjusted a couple of targets and options.
Feel free to modify it as you see fit.

Have a great one!
