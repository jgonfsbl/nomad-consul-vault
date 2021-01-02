//
// Jonathan Gonzalez
// j@0x30.io
// https://github.com/EA1HET
//
// ** MARIADB **
//


job "mariadb" {

  meta {
    description   = "MariaDB database"
    nomad_version = "1.0.1"
    job_version   = "1.0"
    job_date      = "2021-01-01"
    team          = "devops"
    org           = "ea1het"
  }

  region = "global"
  datacenters = ["LAB"]
  type = "service"

  group "database" {
    count = 1

    network {
      mode = "bridge"
      port "mariadb" { to = 3306 }
    }

    reschedule {
      unlimited      = false
      attempts       = 10
      interval       = "1h"
      delay          = "5s"
      delay_function = "fibonacci"
      max_delay      = "120s"
    }

    task "mariadb" {
      driver = "docker"

      config {
        image = "linuxserver/mariadb:arm32v7-110.4.17mariabionic-ls5"
        hostname = "mariadb"
        network_mode = "bridge"
        ports = ["mariadb"]
        volumes = [
          "/opt/NFS/mariadb/config:/config",
        ]
      }

      env {
        MYSQL_ROOT_PASSWORD="dbrootpassword"
        MYSQL_DATABASE=development
        MYSQL_USER="dbuser"
        MYSQL_PASSWORD="dbpass"
        TZ="Europe/Madrid"
      }

      // template stanza should come here

      logs {
        max_files = 5
        max_file_size = 10
      }

      resources {
        cpu = 100
        memory = 128
      }

      restart {
        attempts = 3
        interval = "5m"
        delay = "10s"
        mode = "delay"
      }

      service {
        name = "mariadb"
        port = "mariadb"
        tags = ["mariadb","database"]
        check {
          name = "alive"
          type = "tcp"
          interval = "10s"
          timeout  = "2s"
          check_restart {
            limit = 3
            grace = "90s"
            ignore_warnings = false
          }
        }
      }

    } // EndTask
  } // EndGroup
} // EndJob
