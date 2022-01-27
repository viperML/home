---
title: "Private git repository with NixOS, Gitea and Drone"
image: "images/post/nathan-dumlao-4hjgcuADlL8-unsplash.jpg"
date: 2022-01-27T15:11:36Z
author: "Fernando"
tags: ["Nix", "Cloud"]
categories: ["Linux"]
draft: false
---

In this post I want to show you how I set up a NixOS server running a private Gitea instance, with CI pipelines using Drone, all tied together with Ngninx, Postgres and Sops. Altough there are modules to help with some of this programs individually, putting everything together was non-trivial to, and I hope this can serve you as an example for your deployment.

## Server
I won't go into any detail about how to get NixOS running on a server, because there are different tools to do it, such as:
- [NixOps](https://github.com/NixOS/nixops)
- [deploy-rs](https://github.com/serokell/deploy-rs) (check out my guide [here](https://ayats.org/blog/deploy-rs-example/))
- ...
In the end, the hardware configuration for the server (filesystems, network, etc) will coexist with anything discussed here.

## Sops-nix
To deploy secrets to our machine, we could think of these options:
- Write our secrets directly into `configuration.nix`
- Write our secrets into a file in the machine, (such as `/secret/my-secret`), and reference that file in `configuration.nix`

[sops-nix](https://github.com/Mic92/sops-nix) uses a hybrid approach: our secrets will be stored encrypted into our NixOS configuration, such that only the machine with a master key (our SSH private key) can decrypt them.

```nix
{ config, pkgs, ... }: {
  # See upstream documentation to get started
  sops.age.keyFile = "/secrets/age/keys.txt";
}
```

## Nginx, ACME, Postgres, Docker
Before setting up the other services, we can configure a very basic nginx server, that will proxy the requests to our domains (`{git,drone}.my-domain.tld`) to the internal services. Also remember to punch a hole into the firewall, which comes enabled by default. We will also enable postgres, which will be used by both gitea and drone, and enable docker to run pipelines with the docker runner.
```nix
{ config, pkgs, ... }:
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };

  security.acme = {
    acceptTerms = true;
    certs = {
      "git.my-domain.tld".email = "foo@bar.com";
      "drone.my-domain.tld".email = "foo@bar.com";
    };
  };

  services.postgresql = {
    enable = true;
  };

  virtualisation.docker = {
    enable = true;
  };
}
```

## Gitea
NixOS provides a built-in module to setup Gitea. We only need to add the postgres configuration, and our password via sops. Note that this configuration was taken by [this post by Craige McWhirter](https://mcwhirter.com.au/craige/blog/2019/Deploying_Gitea_on_NixOS), without much modification.

Gitea will run on port `3001`, and the requests to `git.my-domain.tld` will be forwarded by Nginx.

```nix
{ config, pkgs, ... }:
{
  services.nginx.virtualHosts."git.my-domain.tld" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:3001/";
    };
  };

  services.postgresql = {
    authentication = ''
      local gitea all ident map=gitea-users
    '';
    identMap = # Map the gitea user to postgresql
      ''
        gitea-users gitea gitea
      '';
  };

  sops.secrets."postgres/gitea_dbpass" = {
    sopsFile = ../.secrets/postgres.yaml; # bring your own password file
    owner = config.users.users.gitea.name;
  };

  services.gitea = {
    enable = true;
    appName = "My awesome Gitea server"; # Give the site a name
    database = {
      type = "postgres"; # Database type
      passwordFile = config.sops.secrets."postgres/gitea_dbpass".path;
    };
    domain = "git.my-domain.tld";
    rootUrl = "https://git.my-domain.tld/";
    httpPort = 3001;
  };
}
```

## Drone
Drone is a CI server that will integrate with Gitea, showing the status of the pipeline, such as what you find with GitHub's actions or GitLab's pipelines. It uses two (or more) components:
- The server: will communicate between Gitea and the runners
- The runners: will perform the builds

There are a [many runners](https://docs.drone.io/runner/overview/) , but in this example I set-up two of them:
- Docker runner, to run pipelines inside docker images
- Exec runner, that will use the server's nix store

The exec runner will have the advantage of not having to install nix to the recipient OS in the image, and we will be able to keep cached derivations between runs.

As there is no Drone module at the time of writing, I configured these systemd services based on [Mic92's dotifiles](https://github.com/Mic92/dotfiles/tree/035a2c22e161f4fbe4fcbd038c6464028ddce619/nixos/eve/modules/drone):

```nix
{ config, pkgs, ... }:
let
  droneserver = config.users.users.droneserver.name;
in
{
  users.users.droneserver = {
    isSystemUser = true;
    createHome = true;
    group = droneserver;
  };
  users.groups.droneserver = { };

  services.nginx.virtualHosts."drone.my-server.tld" = {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://localhost:3030/";
  };

  services.postgresql = {
    ensureDatabases = [ droneserver ];
    ensureUsers = [{
      name = droneserver;
      ensurePermissions = {
        "DATABASE ${droneserver}" = "ALL PRIVILEGES";
      };
    }];
  };

  # Secrets configured:
  # - DRONE_GITEA_CLIENT_ID
  # - DRONE_GITEA_CLIENT_SECRET
  # - DRONE_RPC_SECRET
  # To get these secrets, please check Drone's documentation for Gitea integration:
  # https://docs.drone.io/server/provider/gitea/

  sops.secrets.drone = {
    sopsFile = ../.secrets/drone.yaml;
    owner = droneserver;
  };

  systemd.services.drone-server = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      EnvironmentFile = [
        config.sops.secrets.drone.path
      ];
      Environment = [
        "DRONE_DATABASE_DATASOURCE=postgres:///droneserver?host=/run/postgresql"
        "DRONE_DATABASE_DRIVER=postgres"
        "DRONE_SERVER_PORT=:3030"
        "DRONE_USER_CREATE=username:viperML,admin:true" # set your admin username

        "DRONE_GITEA_SERVER=https://git.my-domain.tld"
        "DRONE_SERVER_HOST=drone.my-domain.tld"
        "DRONE_SERVER_PROTO=https"
      ];
      ExecStart = "${pkgs.drone}/bin/drone-server";
      User = droneserver;
      Group = droneserver;
    };
  };

  ### Docker runner

  users.users.drone-runner-docker = {
    isSystemUser = true;
    group = "drone-runner-docker";
  };
  users.groups.drone-runner-docker = { };
  # Allow the runner to use docker
  users.groups.docker.members = [ "drone-runner-docker" ];

  systemd.services.drone-runner-docker = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    ### MANUALLY RESTART SERVICE IF CHANGED
    restartIfChanged = false;
    serviceConfig = {
      Environment = [
        "DRONE_RPC_PROTO=http"
        "DRONE_RPC_HOST=localhost:3030"
        "DRONE_RUNNER_CAPACITY=2"
        "DRONE_RUNNER_NAME=drone-runner-docker"
      ];
      EnvironmentFile = [
        config.sops.secrets.drone.path
      ];
      ExecStart = "${pkgs.drone-runner-docker}/bin/drone-runner-docker";
      User = "drone-runner-docker";
      Group = "drone-runner-docker";
    };
  };

  ### Exec runner
  users.users.drone-runner-exec = {
    isSystemUser = true;
    group = "drone-runner-exec";
  };
  users.groups.drone-runner-exec = { };
  # Allow the exec runner to write to build with nix
  nix.allowedUsers = [ "drone-runner-exec" ];

  systemd.services.drone-runner-exec = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    ### MANUALLY RESTART SERVICE IF CHANGED
    restartIfChanged = true;
    confinement.enable = true;
    confinement.packages = [
      pkgs.git
      pkgs.gnutar
      pkgs.bash
      pkgs.nixFlakes
      pkgs.gzip
    ];
    path = [
      pkgs.git
      pkgs.gnutar
      pkgs.bash
      pkgs.nixFlakes
      pkgs.gzip
    ];
    serviceConfig = {
      Environment = [
        "DRONE_RPC_PROTO=http"
        "DRONE_RPC_HOST=127.0.0.1:3030"
        "DRONE_RUNNER_CAPACITY=2"
        "DRONE_RUNNER_NAME=drone-runner-exec"
        "NIX_REMOTE=daemon"
        "PAGER=cat"
        "DRONE_DEBUG=true"
      ];
      BindPaths = [
        "/nix/var/nix/daemon-socket/socket"
        "/run/nscd/socket"
        # "/var/lib/drone"
      ];
      BindReadOnlyPaths = [
        "/etc/passwd:/etc/passwd"
        "/etc/group:/etc/group"
        "/nix/var/nix/profiles/system/etc/nix:/etc/nix"
        "${config.environment.etc."ssl/certs/ca-certificates.crt".source}:/etc/ssl/certs/ca-certificates.crt"
        "${config.environment.etc."ssh/ssh_known_hosts".source}:/etc/ssh/ssh_known_hosts"
        "${builtins.toFile "ssh_config" ''
          Host git.ayats.org
          ForwardAgent yes
        ''}:/etc/ssh/ssh_config"
        "/etc/machine-id"
        "/etc/resolv.conf"
        "/nix/"
      ];
      EnvironmentFile = [
        config.sops.secrets.drone.path
      ];
      ExecStart = "${pkgs.drone-runner-exec}/bin/drone-runner-exec";
      User = "drone-runner-exec";
      Group = "drone-runner-exec";
    };
  };
}
```
