//
// Jonathan Gonzalez
// j@0x30.io
// https://github.com/EA1HET
// Nomad v1.0.0
// Plan date: 2020-12-20
// Job version: 1.0
//
// A Bitwarden personal vault for secrets


job "bitwarden" {
  // This jobs will instantiate a Bitwarden (Rust) vault server

  region = "global"
  datacenters = ["LAB"]
  type = "service"

  group "security" {
    // Number of executions per task that will grouped into the same Nomad host
    count = 1

    task "bitwarden_rs" {
      driver = "docker"
      // This is a Docker task using the local Docker daemon

      env {
        // These are environment variables to pass to the task/container below
        ROCKET_ENV="staging"
        ROCKET_PORT=80
        ROCKET_WORKERS=10
        SIGNUPS_ALLOWED="true"
        INVITATIONS_ALLOWED="true"
        SMTP_HOST=""
        SMTP_FROM="o"
        SMTP_PORT=587
        SMTP_SSL="true"
        SMTP_USERNAME=""
        SMTP_PASSWORD=""
        SMTP_FROM_NAME=""
        PYTHONUNBUFFERED=0
      }

      config {
        // This is the equivalent to a docker run command line
        image = "bitwardenrs/server:1.17.0-alpine"
        network_mode = "bridge"
        port_map {
          bw_web = 80
          bw_wss = 3012
        }
        volumes = [
          "/opt/NFS/bitwarden/data:/data",
        ]
      }

      resources {
        // Hardware limits in this cluster
        cpu = 300
        memory = 384
        network {
          mbits = 100
          port "bw_web" {}
          port "bw_wss" {}
        }
      }

      service {
        // This is used to inform Consul a new service is available
        name = "bitwarden"
        port = "bw_web"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.bitwarden.rule=Host(`bw.0x30.io`)",
        ]
        check {
          name = "alive"
          type = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      restart {
        // The number of attempts to run the job within the specified interval
        attempts = 10
        interval = "5m"
        delay = "25s"
        mode = "delay"
      }

      logs {
        max_files = 5
        max_file_size = 15
      }

      meta {
        VERSION = "v1.0"
        LOCATION = "LAB"
      }

    } // EndTask
  } // EndGroup
} // EndJob
