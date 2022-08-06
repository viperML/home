job "home" {
  datacenters = ["dc1"]
  group "group" {
    count = 1

    network {
      mode = "bridge"
      port "http" {
        static = 8002
        to     = 8080
      }
    }

    task "serve" {
      driver = "containerd-driver"

      config {
        flake_ref = "github:viperML/home/${var.rev}#serve"
        flake_sha = var.narHash
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

variable "rev" {
  type = string
  validation {
    condition = var.rev != "null"
    error_message = "Git tree is dirty."
  }
}

variable "narHash" {
  type = string
}
