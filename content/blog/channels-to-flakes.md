---
title: "Channels to flakes"
image: "images/post/arshad-pooloo-FK3s0hRpMNM-unsplash.jpg"
date: 2022-02-12T14:49:55Z
author: "Fernando"
tags: ["Nix"]
categories: ["Linux"]
draft: false
---

## From channels to flakes

This post is a quick PSA for people running NixOS or standalone Home-manager, and are using a flake.

Your flake will have an input for nixpkgs, such as:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
}
```

With the `flake.lock`, it defines the `rev` of nixpkgs that your configuration will use. But that ends there, as **any tool that doesn't use  that revision, will use some other nixpkgs rev**.

For example, non-flake tools such as `nix-shell` will use the channels, and `nix` tools will use the registry.

First of all, you will want to pass your inputs to the nixos or home-manager module system. This is very simple, and while we are at it, pass your entire `inputs`.

```nix
# flake.nix
{
  inputs= {
    nixpkgs.url = "github:NixOS/nixpkgs/<your-branch>";

    home-manager.url = "github:nix-community/home-manager/<your-branch>";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {self, nixpkgs, home-manager, ...}: {
    nixosConfigurations."HOSTNAME" = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
      };
      # ...
    };

    homeConfigurations."USER@HOSTNAME" = home-manager.lib.homeManagerConfiguration {
      extraSpecialArgs = {
        inherit inputs;
      };
      # ...
    };
  };
}
```


## Pinning your channels
The non-flake tools such as `nix-shell`, or whatever uses `<nixpkgs>` will use the channels. The flow of information is:

- Some tool queries `<nixpkgs>` in some nix code.
- Then the `NIX_PATH` environment variable is queried, to search for the value of `nixpkgs`.
- This is usally set by the `nix-channel` command.

```console
$ docker run -it nixos/nix

bash-4.4# printenv NIX_PATH
/nix/var/nix/profiles/per-user/root/channels:/root/.nix-defexpr/channels

nix-repl> <nixpkgs>
/nix/var/nix/profiles/per-user/root/channels/nixpkgs
```

So, the easiest solution is to set **NIX_PATH** to whatever nixpkgs our flake uses, instead of whatever `nix-channel` puts there:

```nix
# configuration.nix
{config, pkgs, inputs, ...}: {
  environment.etc."nix/inputs/nixpkgs".source = inputs.nixpkgs.outPath;
  nix.nixPath = ["nixpkgs=/etc/nix/inputs/nixpkgs"];
}
```

```nix
# home.nix
{config, pkgs, inputs, ...}: {
  xdg.configFile."nix/inputs/nixpkgs".source = inputs.nixpkgs.outPath;
  home.sessionVariables = "nixpkgs=${config.xdg.configHome}/nix/inputs/nixpkgs$\{NIX_PATH:+:$NIX_PATH}";
}
```

After applying the config and rebooting, you would see the output:
```console
$ printenv NIX_PATH
nixpkgs=/etc/nix/inputs/nixpkgs

nix-repl> <nixpkgs>
/etc/nix/inputs/nixpkgs
```
Now any reference to `import <nixpkgs> {}` will use the system's nixpkgs 👏👏👏

## Pinning your registry
Flake-enabled tools, such as `nix shell` or `nix build`, when supplied the `nixpkgs#` flake ref, will also use some nixpkgs rev that is not the one your built your system of. For example `nix build nixpkgs#hello` will resolve nixpkgs to `nixpkgs-unstable`, to whatever rev is the latest.

These "aliases", such as `nixpkgs#` are resolved with the registry, which is a `json` that is parsed by the tool on startup. You can check its value with `nix registry list`.

Pinning the registry in NixOS and home-manager is equivalent:

```nix
# configuration.nix or home.nix
{config, pkgs, inputs, lib, ...}: {
  nix.registry = with lib; mapAttrs' (name: value: nameValuePair name {flake = value;}) inputs;
}
```

After applying the config and rebooting, you would see the output:

```nix
$ nix registry list | grep "flake:nixpkgs "
user   flake:nixpkgs path:/nix/store/lyv9kw3jv8dwp7lr5ik22k3w01rf24w2-source
system flake:nixpkgs path:/nix/store/lyv9kw3jv8dwp7lr5ik22k3w01rf24w2-source
global flake:nixpkgs github:NixOS/nixpkgs/nixpkgs-unstable
```

Now any reference to `nixpkgs#` will use the system's nixpkgs  👏👏👏
## Conclusion
With this, now your system will use the same version of nixpkgs everywhere! Feel free to remove any other channel that you had lying around.

Is this bad UX for flakes? In my honest opinion, yes. But this also requires passing down `inputs` to your modules, which is not the default... Maybe in the future, we will not need to do this at all.