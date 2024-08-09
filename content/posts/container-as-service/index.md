---
title: "How to Run Containers at Startup"
date: 2024-08-09T09:14:46Z
draft: false
tags: ['docker', 'container', 'systemd']
---

In this article, we'll explore how to automatically run containers when the system boots up.
While this could be achieved using orchestration frameworks like `Kubernetes`,
that's often too complex for local development environments or local CI/CD pipelines.
To accomplish this, `systemd` services can simplify the process.

## What is `systemd` and its services?

It's quite likely that you've encountered systemd or at least heard about it before.  
According to its [Wikipedia](https://en.wikipedia.org/wiki/Systemd):

> systemd is a software suite that provides an array of system components for Linux operating systems. The main aim is to unify service configuration and behavior across Linux distributions. Its primary component is a "system and service manager" — an init system used to bootstrap user space and manage user processes.

For our purposes, it's enough to know that systemd manages the system's services.  But what is a `service`?

In this context, a `service` refers to a *daemon process* that *automatically* starts when the operating system **boots up**.
Some services are critical for the usability of a system, while others are less so.
In Linux, most services end with the `-d` suffix, indicating that they are daemons (e.g., systemd, sshd).
Whether critical or not, services make our lives much easier, as you'll soon see!

That's enough introduction, let's get into it.

## Let's write a `systemd` service for our containers

If you are on a Linux machine, visit official `systemd.service`  reference manual by issuing `man systemd.service`.
Here, I'm not going to explain everything about systemd.service syntax; let's keep that for another post.
Nevertheless, if you're interested, check out [this article](https://linuxhandbook.com/create-systemd-services/).
Our exploration of services isn't that deep, so you should be good to follow along anyway.

Let's start by creating our service file. Name it whatever you like, just make sure it suffixed by `.service`.
For instance: `container.service`

```service
[Unit]
Description=Run my containers
Requires=docker.service <other services>.....
After=docker.service <other services>.......

[Service]
ExecStart=/usr/bin/docker run <whatever option you would normally set>
ExecStop=/usr/bin/docker stop <container>
Restart=no
```

By looking at this snippet, you should get the general idea!  
In `[Unit]`, we indicate what this service is and what it needs to be running properly (you could use whatever container provider you'd use instead of `docker`).
If you're confused by `After` and `Requires` see [this](https://serverfault.com/questions/812584/in-systemd-whats-the-difference-between-after-and-requires).
`ExecStart` and `ExecStop` are self-explanatory; `Restart` just says there's no need to restart the service for example when it exits.

One idea is to use a custom script in place of the `docker` command in `ExecStart=` and `ExecStop=`.
Or, my favorite option, just use `docker compose` and set everything up there.
What I would do is create a `/opt/personal/docker/service.yml` file and modify `container.service` to something like this:

```service
[Unit]
Description=Run my containers
Requires=docker.service
After=docker.service

[Service]
ExecStart=/usr/bin/docker compose -d -f /opt/personal/docker/service.yml up
ExecStop=/usr/bin/docker compose -f /opt/personal/docker/service.yml down
Restart=no

```

Now you could easily create a service file and a compose file and configure it however you like.
Just a reminder, you can easily add multiple dependencies for your container.
For example, let's say you have your `nginx` and `postgres` containers
configured on your testing server. But for them to work, you need to make sure the network is already online.
So, just add `network-online.target` to your requirements.

## Place the config files

`Systemd`'s system-wide services are usually placed inside `/etc/systemd/system/`,
but you can specify user-specific services at `~/.config/systemd/` as well.
Just note that enabling system-wide services requires superuser privileges.
Move the files based on your preference.

## Enable the service

The final step is enabling the services, so they run automatically after reboots.
> Use the `--now` flag to start the service immediately.

For system-wide:

```bash
sudo systemctl daemon-reload
sudo systemctl enable container.service
```

And for users:

```bash
systemctl --user daemon-reload
systemctl --user enable container.service
```

That's it! You're all set.
