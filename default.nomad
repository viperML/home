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
        flake_ref = "github:viperML/home/e10da1c7f542515b609f8dfbcf788f3d85b14936#serve"
        flake_sha = "sha256-GNay7yDPtLcRcKCNHldug85AhAvBpTtPEJWSSDYBw8U="
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
