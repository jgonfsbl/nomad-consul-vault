//
// Jonathan Gonzalez
// j@0x30.io
// https://github.com/EA1HET
// Nomad v1.0.1
// Plan date: 2020-12-15
// Job version: 1.0
//

job "hypriot" {
  // This jobs will instantiate a MariaDB database into a Docker container

  region = "global"
  datacenters = ["LAB"]
  type = "system"
  priority = 50

  group "web" {
    // Number of executions per task that will grouped into the same Nomad host
    count = 1

    network {
      mode = "bridge"
      port "web" {
        to = 80
      }
    }

    task "hypriot" {
       driver = "docker"
       // This is a Docker task using the local Docker daemon

      config {
        // This is the equivalent to a docker run command line
        image = "hypriot/rpi-busybox-httpd:latest"
        ports = [ "web" ]
        volumes = [
          "/opt/NFS/hypriot/www:/www",
        ]
      }

      resources {
        // Hardware reservation for this job in this cluster
        cpu = 50
        memory = 10
      }

      service {
        // This is used to inform Consul a new service is available
        name = "hypriot"
        port = "web"
        tags = [ "hypriot" ]
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
