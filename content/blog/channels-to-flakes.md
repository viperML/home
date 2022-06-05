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

With the `flake.lock`, it defines the `rev` of nixpkgs that your configuration will use. But that ends there, as **any tool that doesn't use  that rev, will use some other nixpkgs rev**.

For example, non-flake tools such as `nix-shell` will use the channels, and `nix` tools will use the registry.

To begin with, you will want to pass your inputs to the nixos or home-manager module system. This is very simple, and while we are at it, pass your entire `inputs`.

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

bash-4.4# nix repl
Welcome to Nix 2.9.0. Type :? for help.

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

## Pinning your registry
Flake-enabled tools, such as `nix shell` or `nix build`, when supplied the `nixpkgs#` flake ref, will also use some nixpkgs rev that is not the one your built your system of. For example `nix build nixpkgs#hello` will resolve nixpkgs to `nixpkgs-unstable`, to whatever rev is the latest.

These "aliases", such as `nixpkgs#` are resolved with the registry, which is a `json` that is parsed by the tool on startup. You can check its value with `nix registry list`.

Pinning the registry in NixOS is quite easy, while the Home-manager (that I came up with) is more convoluted.

```nix
# configuration.nix
{config, pkgs, inputs, lib, ...}: {
  nix.registry = with lib; mapAttrs' (name: value: nameValuePair name {flake = value;}) inputs;
}
```

```nix
# home.nix
{config, pkgs, inputs, lib, ...}: 
with lib; let 
  registry = builtins.toJSON {
    flakes =
      mapAttrsToList (n: v: {
        exact = true;
        from = {
          id = n;
          type = "indirect";
        };
        to = {
          path = v.outPath;
          type = "path";
        };
      })
      inputs;
    version = 2;
  };
in {
  xdg.configFile."nix/registry.json".text = registry;
}
```

## Conclusion
With this, now your system will use the same version of nixpkgs everywhere! And you won't pull gigabytes of packages after running some command, and using the nix-channel that you didn't update since ages! 👏👏

Is this bad UX for flakes? In my honest opinion, yeah. But this also requires passing down `inputs` to your modules, which is not the default... Maybe in the future, we will not need to do this at all.