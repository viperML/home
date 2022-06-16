---
title: "Declarative ubuntu installation"
image: "images/post/alexandru-bogdan-8fvQRP-YwgI-unsplash.jpg"
date: 2022-02-12T14:49:55Z
author: "Fernando"
tags: ["Ubuntu"]
categories: ["Linux"]
draft: true
---

# Declarative Ubuntu installation
* "Add this PPA to your system to install this application..."
* "Modify your systemd configuration and enable this service..."

If you have ever done some of that, we can agree that it is impossible to keep track of every single change to a system since we install it. The OS starts fresh, and starts to deviate over time, from the "vanilla" configuration.

How Linux systems are layed out is also awkward in that sense: we know that `/usr` is managed by the package manager, but so is `/etc`. What parts of `/etc` did you modify, which ones came preinstalled, or which ones were the results of you running some command as root?

A solution to this would be to totally split these conflicting aspects of an installation: "configuration" and "state". Your "configuration" could be a collection of modifications to `/etc` (only the modifications!), and list of installed packages. The "state" therefore, is the result of evaluating a configuration.

## Using your package manager!
Instead of scripts to modify `/etc`, or match the list of installed packages to a given one, why don't we use a metapackage?

For example:

* `configuration.deb`
* Depends on: every installed package that you want in your system.
* Sets up files in `/etc`

With this layout, installing new packages is a matter of addding a new dependency to `configuration.deb`, and you can use it to put anything into `/etc` declaratively.

Furthermore, we can apply this "metapackage" into a barebones Ubuntu debootstrap. This metapackage can also be git-tracked, registering every change you have done to your system. Did you run into the system imperatively and the state no longer matches the package? Then wipe the system and reinstall the metapackage! 

You will still want to store some sources of *actual* state, such as `/home` or `/var`, using LVM, BTRFS or ZFS subvolumes, for example.

## stage0, stage1, stage2
For this declarative system, the least steps you have, the better. Ideally we would have just 1 step, aka "From 0 to a complete installation in one single command". I divided it into 3 steps:

- Basic Ubuntu debootstrap
- `stage1.deb`, configures `apt` before installing more packages
- `stage2.deb` installs every dependency of the system, and every configuration file

You can find the source code for the experiment in [github.com/viperML/ubuntu-declarative](https://github.com/viperML/ubuntu-declarative), to not bloat the post with code.

To create these metapackages, I just laid a folder such as:

```
 .
├──  stage1
│  ├──  DEBIAN
│  │  └──  control
│  └──  etc
│     └──  apt
│        ├──  apt.conf.d
│        │  ├──  00stage1
│        │  └──  99jammy
│        ├──  preferences.d
│        │  ├──  kinetic
│        │  └──  stage1
│        ├──  sources.list.d
│        │  ├──  graphics-drivers-ubuntu-ppa-jammy.list
│        │  ├──  jammy.list
│        │  ├──  kinetic.list
│        │  └──  microsoft.list
│        └──  trusted.gpg.d
│           ├──  graphics-drivers-ubuntu-ppa.gpg
│           └──  microsoft.gpg
```

The `control` file, would have the contents:

```
Package: stage2
Version: 1.0.1
Architecture: amd64
Maintainer: Anonymous
Description: No description
Depends: linux-generic, linux-image-generic, linux-headers-generic, linux-firmware,
  cryptsetup, dracut, zfs-dracut,
  keyboard-configuration, console-setup, console-setup-linux, kbd,
  iproute2, network-manager,
  sudo, vim, curl, git, man, manpages, strace, neofetch,
  software-properties-common,
  nvidia-driver-510,
  kde-plasma-desktop, kubuntu-wallpapers, plasma-nm, ark,
  flatpak,
  nix-setup-systemd,
  code
```

## Setting up the users
Instead adding your user imperatively, or as some post-install hook, you can use `systemd-sysusers` to automatically add your user:

```
$ cat stage2/etc/sysusers.d/ayats.conf
u ayats 1000:100 "Fernando Ayats" /home/ayats /usr/bin/bash
```

This won't set any password, but you can also set automatic login to tty or your display manager:

```
$ cat stage2/etc/systemd/system/getty@.service.d/autologin.conf
[Service]
X-RestartIfChanged=false
ExecStart=
ExecStart=@/usr/sbin/agetty agetty '--login-program' '/usr/bin/login' '--autologin' 'ayats' --noclear --keep-baud %I 115200,38400,9600 $TERM
```

```
$ cat stage2/etc/sddm.conf.d/autologin.conf
[Autologin]
User=ayats
Session=plasma
```

## Bootloader and initrd


## Closing thoughts