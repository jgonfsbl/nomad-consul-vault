//
// Jonathan Gonzalez
// j@0x30.io
// https://github.com/EA1HET
// Nomad v1.0.0 
// Plan date: 2020-12-15
// Job version: 1.0
//
// A Redis cache server


job "redis" {
  // This jobs will instantiate a Redis cache into a Docker container

  region = "global"
  datacenters = ["LAB"]
  type = "service"

  group "cache" {
    // Number of executions per task that will grouped into the same Nomad host 
    count = 1

    task "redis" {
       driver = "docker"
       // This is a Docker task using the local Docker daemon 
      
      config {
        // This is the equivalent to a docker run command line
        image = "redis:6.0.9-alpine"
        network_mode = "host"
        port_map {
          redis = 6379
        } 
        volumes = [
          "/opt/NFS/redis/data:/data"
        ]
      } 

      resources {
        // Hardware limits in this cluster
        cpu = 1000
        memory = 1024
        network {
          mbits = 10
          port  "redis"  {
            static = 6379
          }
        }
      }      
      
      service {
        // This is used to inform Consul a new service is available
        name = "redis"
        port = "redis"
        tags = ["redis", "cache", "nosql"]
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
