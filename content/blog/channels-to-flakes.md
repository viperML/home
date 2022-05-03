---
title: "Channels to flakes"
image: "images/post/christopher-burns-Wiu3w-99tNg-unsplash.jpg"
date: 2022-02-12T14:49:55Z
author: "Fernando"
tags: ["Nix", "Cloud"]
categories: ["Linux"]
draft: false
---

## From Channels to Flakes

Nix flakes are a new feature to the nix package manager. One of its main features, is that it allows you to have totally **hermetic** builds or environments, in contrast to the classic way of doing it, with channels. Let's take this `shell.nix` as an example:
```nix
let
  pkgs = import '<nixpkgs>' {};
in pkgs.mkShell {
  packages = [
    pkgs.hello
  ];
}
```
With this, we define a shell environment, and using `nix-shell` in the same directory, we will will have `pkgs.hello` inserted into our path. Nothing new.

But the problem comes from: `import '<nixpkgs>' {}`. With this, we are querying the `NIX_PATH` environment variable, and search the value of `nixpkgs`. In a standard nix installation, the value of nixpkgs is a folder, which was set-up for us, and we can update with the `nix-channel` tool.

{{<image
	src="images/post/channels-to-flakes/nix_path00.png" 
	caption=""
	alt="alter-text"
	command="fill"
	option="q95"
	class="img-fluid"
	title="Hetzner Cloud panel"
>}}

So, the `nixpkgs` used, is just a commit of the `nixpkgs` repository. If we share this snipptet with a colleague, they may have another commit of nixpkgs, thus getting a different result.

Another, more visual example:

1. Clone an old branch from nixpkgs (`nixos-18.09-small` into `/home/nixos/nixos-18`)
2. Clone a recent branch (`master` into `/home/nixos/nixpkgs-master`)

{{<image
	src="images/post/channels-to-flakes/branches00.png" 
	caption=""
	alt="alter-text"
	command="fill"
	option="q95"
	class="img-fluid"
	title="Hetzner Cloud panel"
>}}

3. Manipulate `NIX_PATH`, and use `nix-shell` as usual to get the `bash` package into your path. We get different versions of bash! (duh)

{{<image
	src="images/post/channels-to-flakes/branches01.png" 
	caption=""
	alt="alter-text"
	command="fill"
	option="q95"
	class="img-fluid"
	title="Hetzner Cloud panel"
>}}

## Flakes to the rescue

When using any flake-powered nix command, such as `nix shell` or `nix develop`, the evaluation will be hermetic (pure). No environment variable or configuration file would affect the result.

```console
$ nix run nixpkgs/7f9b6e2babf232412682c09e57ed666d8f84ac2d#bash -- --version
GNU bash, version 5.1.12(1)-release (x86_64-pc-linux-gnu)
Copyright (C) 2020 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>

This is free software; you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
```


## A sidestep into our flake

## Pinning flake inputs

## Pinning "channels"