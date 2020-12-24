//
// Jonathan Gonzalez
// j@0x30.io
// https://github.com/EA1HET
// Nomad v1.0.0
// Plan date: 2020-12-15
// Job version: 1.0
//

job "mariadb" {
  // This jobs will instantiate a MariaDB database into a Docker container

  region = "global"
  datacenters = ["LAB"]
  type = "service"
  priority = 50

  group "grp-mariadb" {
    // Number of executions per task that will grouped into the same Nomad host
    count = 1

    task "mariadb" {
       driver = "docker"
       // This is a Docker task using the local Docker daemon

      env {
        // These are environment variables to pass to the task/container below
        MYSQL_ROOT_PASSWORD=DB_Root_Password_Here
      }

      config {
        // This is the equivalent to a docker run command line
        image = "linuxserver/mariadb:arm32v7-latest"
        network_mode = "bridge"
        port_map {
          mariadb = 3306
        }
        volumes = [
          "/opt/NFS/mariadb/data:/config"
        ]
      }

      resources {
        // Hardware reservations in this cluster
        cpu = 100
        memory = 50
        network {
          mbits = 10
          port  "mariadb" { static = 3306 }
        }
      }

      service {
        // This is used to inform Consul a new service is available
        name = "mariadb"
        port = "mariadb"
        tags = [
          "mariadb",
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
