//
// Jonathan Gonzalez
// j@0x30.io
// https://github.com/EA1HET
// Nomad v1.0.0 
// Plan date: 2020-12-15
// Job version: 1.0
//
// A Traefik load balancer and reverse proxy server


job "traefik" {
  // This jobs will instantiate a Traefik load balancer and reverse proxy

  region = "global"
  datacenters = ["LAB"]
  type = "system"

  group "proxy" {
    // Number of executions per task that will grouped into the same Nomad host 
    count = 1

    task "traefik" {
       driver = "docker"
       // This is a Docker task using the local Docker daemon 

      env {
        // These are environment variables to pass to the task/container below
        CLOUDNS_AUTH_ID="nnnn"
        CLOUDNS_AUTH_PASSWORD="LongStringOfTextGeneratedByClouDNS"
      } 
      
      config {
        // This is the equivalent to a docker run command line
        image = "traefik:2.3.5"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "/opt/NFS/traefik/acme.json:/etc/traefik/acme.json",
        ]
      } 

      template {
        data = <<EOF
[global]
checkNewVersion = true

[entryPoints]
  [entryPoints.web]
  address = ":80"
    [entryPoints.web.http]
      [entryPoints.web.http.redirections]
        [entryPoints.web.http.redirections.entryPoint]
        to = "websecure"
        scheme = "https"
  [entryPoints.websecure]
  address = ":443"
    [entryPoints.websecure.http.tls]
    certResolver = "le"
  [entryPoints.vpn]
  address = ":993/udp"
  [entryPoints.api]
  address = ":8081"
  [entryPoints.metrics]
  address = ":8082"
  
[providers]
  [providers.consulCatalog]
  prefix = "traefik"
  exposedByDefault = false
    [providers.consulCatalog.endpoint]
    address = "http://127.0.0.1:8500"
    scheme = "http"

[api]
insecure = true
dashboard = true
debug = true

[certificatesResolvers]
  [certificatesResolvers.le]
    [certificatesResolvers.le.acme]
    email = "user@mail.tld"
    storage = "acme.json"
    keyType = "RSA4096"
    caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"
      [certificatesResolvers.le.acme.dnsChallenge]    
      provider = "cloudns"
      delayBeforeCheck = 300

[tls]
  [tls.options]
    [tls.options.default]
    minVersion = "VersionTLS12"
    cipherSuites = [
      "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256",
      ]
EOF
        destination = "local/traefik.toml"
      }

      resources {
        // Hardware limits in this cluster
        cpu = 200
        memory = 256
        network {
          mbits = 100
          port "web" { static = 80 }
          port "websecure" { static = 443 }
          port "vpn" { static = 993 }
          port "api" { static = 8081 }
          port "metrics" { static = 8082 }
        }
      }
      
      service {
        name = "traefik"
        check {
          name = "alive"
          type = "tcp"
          port = "web"
          interval = "10s"
          timeout = "2s"
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

