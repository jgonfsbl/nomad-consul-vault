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
        CLOUDNS_AUTH_ID="nnnnnnnn"
        CLOUDNS_AUTH_PASSWORD="LongStringOfTextUsedAsToken"
      }

      config {
        // This is the equivalent to a docker run command line
        image = "traefik:2.3.6"
        network_mode = "host"
        port_map {
          web = 80
          websecure = 443
          traefik = 8081
        }
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "/opt/NFS/traefik/acme.json:/acme.json",
        ]
      }

      template {
        destination = "local/traefik.toml"
        data = <<EOF
[global]
checkNewVersion = true
sendAnonymousUsage = false

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
    [entryPoints.websecure.http]
      [entryPoints.websecure.http.tls]
      certResolver = "le"
  [entryPoints.traefik]
  address = ":8081"

[ping]
  entryPoint = "traefik"

[api]
  dashboard = true
  insecure = true
  debug = true

[tls]
  [tls.options]
    [tls.options.default]
    minVersion = "VersionTLS12"
    sniStrict = true
    cipherSuites = [
      "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256",
    ]
    curvePreferences = [
      "CurveP521",
      "CurveP384",
    ]

[providers]
  [providers.consulCatalog]
  prefix = "traefik"
  exposedByDefault = false
    [providers.consulCatalog.endpoint]
    address = "http://127.0.0.1:8500"
    scheme = "http"

[certificatesResolvers]
  [certificatesResolvers.le]
    [certificatesResolvers.le.acme]
    email = "user@domain.tld"
    storage = "/acme.json"
    keyType = "RSA4096"
    caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"
      [certificatesResolvers.le.acme.dnsChallenge]
      provider = "cloudns"
      delayBeforeCheck = 80
      resolvers = ["185.136.96.66:53", "185.136.97.66:53", "185.136.98.66:53", "185.136.99.66:53"]
EOF
      }

      resources {
        // Hardware limits in this cluster
        cpu = 1000
        memory = 1024
        network {
          mbits = 100
          port "web"       { static = 80   }
          port "websecure" { static = 443  }
          port "traefik"   { static = 8081 }
        }
      }

      service {
        name = "traefik"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.traefik.tls=true",
          "traefik.http.routers.traefik.tls.certResolver=le",
          "traefik.http.routers.traefik.entrypoints=websecure",
          "traefik.http.routers.traefik.rule=Host(`traefik.0x30.io`)",
          "traefik.http.routers.traefik.service=api@internal",
          "traefik.http.services.traefik.loadbalancer.server.port=8081",
        ]
        check {
          name = "alive"
          type = "tcp"
          port = "traefik"
          interval = "10s"
          timeout = "2s"
        }
      }

      restart {
        // The number of attempts to run the job within the specified interval
        attempts = 10
        interval = "5m"
        delay = "10s"
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

