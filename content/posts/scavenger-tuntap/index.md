---
title: "Dive in Linux TUN/TAP Devices: A Kernel-Level Story"
date: 2025-05-12T17:15:52Z
draft: false
tags: ['kernel', 'network']
---

## What Is This About?

This post began with a practical problem. While working with Open vSwitch (OVS), I tried to mirror traffic to a TAP device. Oddly enough, I saw no traffic coming through. Later, I realized I hadn’t set up a userspace program to attach to the TAP device. Once I did, packets started appearing as expected.

That got me curious: I knew that without a userspace program, packets would be dropped — but what puzzled me was why tools like `tcpdump`, `tshark`, or even `libpcap` couldn’t capture those dropped packets. Where do they go? Why can’t they be sniffed, even though the TAP interface exists?

So I dug into the Linux kernel to understand what’s really going on. This blog post is a deep dive into that investigation — ultimately answering the question:

**Why can't I sniff packets on a TAP device when no userspace program is attached?**

---

## A Few Notes Before You Read

* This post reflects my interpretation and understanding of the issue. I’ve done my best to minimize inaccuracies, but **I might still be wrong in places**. Please keep that in mind.
* **Prior knowledge:** Some familiarity with Linux device drivers is helpful — especially since we’ll be exploring the internals of the `TUN/TAP` driver. Knowing how tools like `tcpdump`, `tshark`, and `libpcap` work is also a plus. An understanding of the Linux networking stack will definitely enhance the experience.
* **Kernel version disclaimer:** I’m working with kernel version `6.14.5-300.fc42.x86_64`. Behavior and internal implementations may vary across different kernel versions.

---

## `TUN/TAP` Driver Internals

You can refer to the official [TUN/TAP documentation](https://www.kernel.org/doc/html/latest/networking/tuntap.html) for more detailed information.

`TAP` provides packet reception and transmission for userspace programs. It functions as a simplified point-to-point or Ethernet device, where instead of receiving packets from physical media, it receives them from userspace programs. Similarly, when sending packets, rather than using physical media, the driver writes them to the userspace program. This makes `TUN/TAP` a useful mechanism for implementing virtual network interfaces.

The `TUN/TAP` driver itself is defined in the Linux kernel at `drivers/net/tun.c`. It has two primary components: the *userspace* side and the *kernel* side. The userspace side is exposed as a character device (`CDev`), a simpler device type compared to block or network devices. This allows userspace applications to interact with the driver using basic I/O system calls like `read(2)` and `write(2)`. When these syscalls are invoked, the corresponding routines within the driver are triggered to handle the requests. The file operations structure (`fops`) for the TUN device defines these interactions.

For example, here’s the `fops` structure for `TUN/TAP`:

```c
static const struct file_operations tun_fops = {
    .owner          = THIS_MODULE,
    .read_iter      = tun_chr_read_iter,
    .write_iter     = tun_chr_write_iter,
    .poll           = tun_chr_poll,
    .unlocked_ioctl = tun_chr_ioctl,
    .open           = tun_chr_open,
    .release        = tun_chr_close,
    .fasync         = tun_chr_fasync,
};
```

This structure serves as the entry point for userspace programs to interact with the driver. It defines the methods that are called when userspace applications attempt to read from or write to the device. After initializing with `open` and `ioctl` calls, userspace programs can write packets using the `write(2)` system call to transmit them and read incoming packets using the `read(2)` system call. These actions correspond to the `write_iter` and `read_iter` methods in the driver, which handle the actual packet transmission and reception. While this mechanism is straightforward, it’s not the primary focus of this post.

On the kernel side, `TUN/TAP` also requires a structure for network packet transmission. This is where the kernel defines the operations that interact with the network subsystem. The relevant kernel structure is `net_device_ops`, and the operations are defined as follows:

```c
static const struct net_device_ops tun_netdev_ops = {
    .ndo_init              = tun_net_init,
    .ndo_uninit            = tun_net_uninit,
    .ndo_open              = tun_net_open,
    .ndo_stop              = tun_net_close,
    .ndo_start_xmit        = tun_net_xmit,
    .ndo_fix_features      = tun_net_fix_features,
    .ndo_select_queue      = tun_select_queue,
    .ndo_set_rx_headroom  = tun_set_headroom,
    .ndo_get_stats64      = tun_net_get_stats64,
    .ndo_change_carrier    = tun_net_change_carrier,
};
```

The most important callback here is `ndo_start_xmit`, which is assigned to `tun_net_xmit`. This function is called when the kernel requests the network driver to send a packet (referred to as `sk_buff`). In the case of TUN/TAP, the packet is ultimately passed to the userspace program, which can then process or transmit it further.

---

## Packet Queues

Packet queues play a critical role in the network stack. When the kernel wants to send a packet through a network device, it first generates the packet and then **enqueues** it in the driver's corresponding queue for transmission. This is part of the mechanism that ensures packets are processed and sent in an orderly fashion. A scheduler then asks the driver to transmit the packet, pulling it from the queue and sending it out.

This process takes place within the kernel's **Traffic Control (TC)** layer, which is an essential part of the network stack. The TC layer is crucial because one of its main components is the **queue discipline** (`qdisc`). If you're unfamiliar with `tc`, I recommend skimming through its manual page ([tc.8](https://www.man7.org/linux/man-pages/man8/tc.8.html)) to get a high-level understanding of how it works. Essentially, `tc` is used to implement Quality of Service (QoS) in networking, allowing you to manage and prioritize packet flows. The `qdisc` determines how packets are managed in queues, deciding when and how they are sent, dropped, or delayed.

Understanding this setup is important because it directly relates to packet handling within TUN/TAP devices. The kernel manages the flow of packets through its networking subsystem, and the TUN/TAP driver fits into this larger picture, especially when it comes to handling packets at the device level.

---

## Setup

To simulate the situation I encountered in my earlier observation, I used a simpler setup, but feel free to adapt this to your own needs. The goal here is to generate packets that need to be transmitted by the TAP device, triggering the call to `tun_net_xmit`. Here’s how I set up the environment:

1. First, I created an on-the-fly TAP interface using the `ip tuntap` command.
2. Then, I brought the interface up using `ip link`.
3. Next, I added a route to redirect packets for the `192.168.1.0/24` network to the TAP device, bypassing the default gateway.
4. Finally, I started generating packets by pinging the target network via the newly created route.

For brevity, I ran these commands as root:

```bash
ip tuntap add name tap0 mode tap
ip link set up tap0
ip route add 192.168.1.0/24 dev tap0

ping -c 1 -I tap0 192.168.1.1
```

To track the kernel's behavior during this process, I used `ftrace`, which is a powerful tool for tracing kernel functions. It’s important to note that this isn’t a tutorial on `ftrace`; if you're unfamiliar with it, I encourage you to check out the [References](#references). Here's how I set it up for my scenario:

```bash
cd /sys/kernel/tracing
echo 0 > tracing_on
echo > trace
echo function_graph > current_tracer
echo $$ > set_ftrace_pid
echo function-fork > trace_options
echo 1 > max_graph_depth
```

This setup uses the `function_graph` tracer, and it only traces the processes related *to my shell and its child processes*. I set `max_graph_depth` to **1** to avoid excessive output, but I could increase it if necessary for more detailed information.

When investigating calls related to the creation and management of the TAP device, I used the following `ftrace` commands to capture the relevant traces:

```bash
echo > trace
echo 'tun_*' > set_graph_function
echo 1 > tracing_on
ip tuntap add name tap0 mode tap
ip link del tap0
echo 0 > tracing_on
```

Here’s an example of the trace output I received, which shows the kernel functions that were invoked during the creation and removal of the `tap0` device:

```bash
$ cat trace
# tracer: function_graph
#
# CPU  DURATION               FUNCTION CALLS
# |    |   |                   |   |   |   |
 2)   2.406 us   |  tun_chr_open [tun]();
 2) ! 746.967 us |  tun_chr_ioctl [tun]();
 2)   0.941 us   |  tun_chr_ioctl [tun]();
 2) ! 360.789 us |  tun_chr_close [tun]();
10)   0.862 us   |  tun_get_size [tun]();
10)   0.322 us   |  tun_fill_info [tun]();
10)   0.427 us   |  tun_device_event [tun]();
10)   0.085 us   |  tun_get_size [tun]();
10)   0.329 us   |  tun_fill_info [tun]();
10)   0.101 us   |  tun_device_event [tun]();
10) + 56.922 us  |  tun_net_uninit [tun]();
 9)   3.363 us   |  tun_free_netdev [tun]();
```

This trace shows the kernel's interactions with the TUN/TAP driver, including function calls related to opening, configuring, and closing the TAP device. These traces help identify what happens in the kernel when the TAP interface is created and used.

---

## Let the Scavenger Hunt Begins

### Initial Observations: Packets Dropped

When running `ip -s link show tap0`, I noticed that packets were being dropped on the **transmit (TX)** side, even though the interface was up.

```bash
$ ip -s link show tap0
7: tap0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc fq_codel state DOWN mode DEFAULT group default qlen 1000
    link/ether 46:f5:81:6f:f2:ff brd ff:ff:ff:ff:ff:ff
    RX: bytes  packets  errors  dropped  missed  mcast
        0      0        0       0        0       0
    TX: bytes  packets  errors  dropped  carrier collsns
        0      0        0       12       0       0
```

To find out what’s happening, I used `ftrace` and filtered for all `tun_*` functions to trace calls inside the TUN/TAP driver. Surprisingly, none were triggered—even while `ping`ing an address in the same subnet as `tap0` (e.g., `192.168.1.1`). Despite that, the `TX dropped` count kept increasing.

This told me something important: **the packets were being dropped before they even reached the driver.**

---

### Following the Trail into the Kernel

To understand the delivery path, I referred to [this Linux Foundation networking flow wiki](https://wiki.linuxfoundation.org/networking/kernel_flow). It gives a helpful overview of the kernel's network stack—from user space down to hardware drivers. Even though it's based on older kernel versions, the structure is still relevant today.

> "The main function of the kernel at the link layer is scheduling the packets to be sent out. For this purpose, Linux uses the queueing discipline (`struct Qdisc`) abstraction... [`dev_queue_xmit`](https://elixir.bootlin.com/linux/v2.6.20/source/net/core/dev.c#L1421) puts the `sk_buff` on the device queue using the `qdisc→enqueue` virtual method."

This led me to the `dev_queue_xmit()` function, a wrapper over `__dev_queue_xmit()`:

```c
static inline int dev_queue_xmit(struct sk_buff *skb)
{
    return __dev_queue_xmit(skb, NULL);
}
```

Great! That function is traceable via `ftrace`. Let’s see what it reveals:

```bash
$ ping -I tap0 192.168.1.1
$ cat trace
# tracer: function_graph
#
# CPU  DURATION              FUNCTION CALLS
  6)   3.711 us              |  __dev_queue_xmit();
  5)   3.650 us              |  __dev_queue_xmit();
  ...
```

Bingo! `__dev_queue_xmit()` is being called. Let’s zoom in:

```bash
$ echo 3 > max_graph_depth
$ ping -I tap0 -c 1 192.168.1.1
$ cat trace
# tracer: function_graph
  3) | __dev_queue_xmit() {
  3) |   arch_irq_work_raise() {
  3) |     x2apic_send_IPI_self();
  3) |   }
  3) |   qdisc_pkt_len_init();
  3) |   netdev_core_pick_tx();
  3) |   _raw_spin_lock();
  3) |   dev_qdisc_enqueue() {
  3) |     noop_enqueue();
  3) |   }
  3) |   __qdisc_run() {
  3) |     dequeue_skb();
  3) |   }
  3) |   kfree_skb_list_reason();
  3) | }
```

That’s it. The packet hits `dev_qdisc_enqueue()` and gets routed into `noop_enqueue()`.

Here's what `noop_enqueue()` does, from `net/sched/sch_generic.c`:

```c
static int noop_enqueue(struct sk_buff *skb, struct Qdisc *qdisc,
                        struct sk_buff **to_free)
{
    dev_core_stats_tx_dropped_inc(skb->dev);
    __qdisc_drop(skb, to_free);
    return NET_XMIT_CN;
}
```

So now we know: **the kernel silently drops packets via `noop_enqueue()`**—they are never handed off to the TUN/TAP driver.

---

### What Happens When a Receiver Is Present?

Let’s now test what happens when we attach a userspace program like `socat`:

```bash
socat - TUN,iff-up,tun-type=tap,tun-name=tap0 > /dev/null
```

Now, ping again:

```bash
$ ping -I tap0 -c 1 192.168.1.1 
$ cat trace
# tracer: function_graph
#
# CPU  DURATION                  FUNCTION CALLS
# |     |   |                     |   |   |   |
  3)               |  __dev_queue_xmit() {
                            ......
  3)               |    sch_direct_xmit() {
  3)   0.071 us    |      _raw_spin_unlock();
  3)   0.776 us    |      validate_xmit_skb_list();
  3)   1.968 us    |      dev_hard_start_xmit();
  3)   0.073 us    |      _raw_spin_lock();
  3)   3.341 us    |    }
  3)               |    __qdisc_run() {
  3)   0.189 us    |      dequeue_skb();
  3)   0.367 us    |    }
                            ......
  3)   7.796 us    |  }
```

This time, the kernel goes through `dev_hard_start_xmit()` instead of `noop_enqueue()`. That tells us the driver (`tun_net_xmit()`) is finally receiving packets!

---

### So, Why Was `noop_enqueue()` Used Before?

The answer lies in the interface flags. Recall the `ip link show` output:

```bash
tap0: <NO-CARRIER,BROADCAST,MULTICAST,UP>
```

The `NO-CARRIER` flag means the interface has no active link—even though it's administratively up (via `ip link set tpa0 up`). For **physical NICs**, this would mean **cable unplugged.** For our **virtual interface** i.e. `TAP`, this means **no userspace program is attached** to handle packets.

Until a reader is attached via `/dev/net/tun`, the kernel silently drops outgoing packets via `noop_enqueue()`. Once the reader attaches and sets the device into `IFF_UP` mode (which `socat` does), the queueing discipline switches, and packets are passed down correctly.

If you're curious, you can explore this logic in:

* `drivers/net/tun.c` (functions like `tun_chr_open()`, `tun_set_iff()`)
* or use tools like `bpftrace`/`ftrace` to trace them live.

---

### Why `tcpdump` and `tshark` Show Nothing

To understand this, we need to examine how these tools operate. Both `tcpdump` and `tshark` rely on `libpcap`, the core library behind most packet-capturing tools. `libpcap` typically uses the kernel's `AF_PACKET` socket family (e.g., `socket(AF_PACKET, SOCK_RAW, ...)` in C), which allows user-space programs to receive *copies* of packets as they traverse the network stack.  

If a packet is dropped **before** reaching the point where `AF_PACKET` taps into the stack—such as in **Traffic Control** (`TC`) or **Netfilter** (e.g., via `iptables`/`nftables` drops)—then the capturing tool will never see it. This is precisely what happened in our case. As we saw earlier, `noop_enqueue()` (from the `qdisc` layer in `TC`) silently discarded the packets. Since the packet never progressed past that point, `tcpdump` and `tshark` had nothing to capture—not even a drop notification.  

This behavior also highlights a key advantage of `eBPF` and `XDP`. These technologies hook into the packet processing path much earlier—`XDP`, for instance, processes packets right after they are received by the network interface driver, **before** they enter the *kernel's networking stack*. This early visibility makes them powerful for observability and filtering. I plan to write more about XDP in the future—it’s a deep and fascinating topic. Stay tuned!

---

## Conclusion

Thank you for joining me on this deep dive! This investigation was a roller-coaster of
frustration, discovery, and—ultimately—rewarding lessons.
I hope you found it as insightful and enjoyable as I did. Until next time!

## References

* **Linux Foundation Networking Flow**  
  Kernel packet processing path overview (historical but structurally relevant).  
  [https://wiki.linuxfoundation.org/networking/kernel_flow](https://wiki.linuxfoundation.org/networking/kernel_flow)

* **Linux Kernel TUN/TAP Documentation**  
  Official guide for TUN/TAP driver functionality.  
  [https://www.kernel.org/doc/html/latest/networking/tuntap.html](https://www.kernel.org/doc/html/latest/networking/tuntap.html)  

* **Linux Kernel Source (`tun.c`)**  
  TUN/TAP driver source code (v6.14).  
  [https://elixir.bootlin.com/linux/v6.14/source/drivers/net/tun.c](https://elixir.bootlin.com/linux/v6.14/source/drivers/net/tun.c)  

* **Linux Kernel Source (`dev.c`)**  
  `__dev_queue_xmit` function for packet transmission (v6.14).  
  [https://elixir.bootlin.com/linux/v6.14/source/net/core/dev.c#L3900](https://elixir.bootlin.com/linux/v6.14/source/net/core/dev.c#L3900)  

* **Linux Traffic Control (`tc`)**  
  Man page for `tc` and queueing disciplines.  
  [https://www.man7.org/linux/man-pages/man8/tc.8.html](https://www.man7.org/linux/man-pages/man8/tc.8.html)  

* **Linux Networking Documentation**  
  Kernel networking stack overview.  
  [https://www.kernel.org/doc/html/latest/networking/index.html](https://www.kernel.org/doc/html/latest/networking/index.html)  

* **`ftrace` Documentation**  
  Guide to using `ftrace` for kernel tracing.  
  [https://www.kernel.org/doc/html/latest/trace/ftrace.html](https://www.kernel.org/doc/html/latest/trace/ftrace.html)  

* **`libpcap` Project**  
  Details on `libpcap` for packet capture.  
  [https://www.tcpdump.org/](https://www.tcpdump.org/)  

* **`eBPF/XDP` Documentation**  
  Introduction to eBPF and XDP for early packet processing.  
  [https://www.kernel.org/doc/html/latest/bpf/index.html](https://www.kernel.org/doc/html/latest/bpf/index.html)
