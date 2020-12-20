//
// Jonathan Gonzalez
// j@0x30.io
// https://github.com/EA1HET
// Nomad v1.0.0 
// Plan date: 2020-12-20
// Job version: 1.0
//
// A ClouDNS Updater container to keep local IP updated in DNS


job "cloudns" {
  // This jobs will instantiate a ClouDNS updater program on the network

  region = "global"
  datacenters = ["LAB"]
  type = "service"

  group "dns" {
    // Number of executions per task that will grouped into the same Nomad host 
    count = 1

    task "cloudns-updater" {
       driver = "docker"
       // This is a Docker task using the local Docker daemon 

      env {
        // These are environment variables to pass to the task/container below
        URL_CDNS="https://ipv4.cloudns.net/api/dynamicURL/?q=LongTextStringGeneratedByClouDNSPanelForYou"
        URL_IPIO="https://ipinfo.io/json"
        LOG_FILE="iplog.txt"
        HOSTNAME="host.domain.tld"
        SLEEPTIME=600
        PYTHONUNBUFFERED=0
      } 
      
      config {
        // This is the equivalent to a docker run command line
        image = "ea1het/cloudns-updater:latest-armv6"
        network_mode = "host"
      }

      resources {
        // Hardware limits in this cluster
        cpu = 100
        memory = 128
        network {
          mbits = 100
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
