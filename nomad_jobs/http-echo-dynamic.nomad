//
// Jonathan Gonzalez
// j@0x30.io
// https://github.com/EA1HET
// Nomad v1.0.0 
// Plan date: 2020-12-15
// Job version: 1.0
//
// A debug container to test network infrastructure, i.e. load balancers and WAFs
//

job "http-echo-dynamic" {
  datacenters = ["LAB"]  
  group "echo" {
    count = 3
    
    task "server" {
      driver = "docker"
    
      config {
        image = "teapow/http-echo:armv7"
      }

      resources {
        network {
          mbits = 10
          port "http8000" {
            static = 8000
          }
        }
      }

      env {
        ECHO_MESSAGE = "${NOMAD_IP_http8000}:${NOMAD_PORT_http8000} - Meta: ${NOMAD_META_VERSION}"
        SERVER_PORT = 8000
      }

      meta {
        VERSION = "v1.0"
      }

      service {
        name = "http-echo-dynamic"
        port = "http8000"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

    } // EndTask
  } // EndGroup
} // EndJob
