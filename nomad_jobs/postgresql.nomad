//
// Jonathan Gonzalez
// j@0x30.io
// https://github.com/EA1HET
// Nomad v1.0.0 
// Plan date: 2020-12-15
// Job version: 1.0
//

job "postgres" {
  // This jobs will instantiate a PostgreSQL database into a Docker container

  region = "global"
  datacenters = ["LAB"]
  type = "service"

  group "rdbms" {
    // Number of executions per task that will grouped into the same Nomad host 
    count = 1

    task "postgres" {
       driver = "docker"
       // This is a Docker task using the local Docker daemon 
   
      env {
        // These are environment variables to pass to the task/container below
        POSTGRES_USER="root"
        POSTGRES_PASSWORD="rootpassword"
      }       
      
      config {
        // This is the equivalent to a docker run command line
        image = "postgres:13-alpine"
        network_mode = "host"
        port_map {
          pgsql = 5432
        } 
        volumes = [
          "/opt/NFS/postgres/data:/var/lib/postgresql/data"
        ]
      } 

      resources {
        // Hardware limits in this cluster
        cpu = 1000
        memory = 1024
        network {
          mbits = 100
          port  "pgsql"  {
            static = 5432
          }
        }
      }      
      
      service {
        // This is used to inform Consul a new service is available
        name = "postgres"
        port = "pgsql"
        tags = ["postgres", "pgsql", "rdbms", "sql"]
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
      }         
      
    } // EndTask
  } // EndGroup
} // EndJob
