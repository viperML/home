job "http-store" {
  datacenters = ["dc1"]
  group "main-group" {
    count = 1
    network {
      mode = "bridge"
      port "http" {
        static = 8002
        to     = 8080
      }
    }

    task "miniserve" {
      driver = "containerd-driver"

      config {
        flake_ref = "github:viperML/home/bfc57dcd3457106c942ca9a6d59a459a49a5cc7b#serve"
        flake_sha = "sha256-dCrsEghTQD81QzgcBp3K88jy7c5M5eobWcG3LPwW32g="
        entrypoint = [
          "bin/serve",
        ]
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
