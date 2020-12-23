//
// Jonathan Gonzalez
// j@0x30.io
// https://github.com/EA1HET
// Nomad v1.0.0
// Plan date: 2020-12-20
// Job version: 1.0
//
// An HAProxy load balancer system (INLINE CONFIG - NO VAULT)


job "haproxy" {
  // This jobs will instantiate an HAProxy Community Edition (LTS) server

  region = "global"
  datacenters = ["LAB"]
  type = "system"

  group "grp-haproxy" {
    // Number of executions per task that will grouped into the same Nomad host
    count = 1

    task "haproxy" {
      driver = "docker"
      // This is a Docker task using the local Docker daemon

      env {
        // These are environment variables to pass to the task/container below
        PYTHONUNBUFFERED=0
      }

      config {
        // This is the equivalent to a docker run command line
        image = "haproxy:2.3.2-alpine"
        network_mode = "host"
        port_map {
          http  = 80
          https = 443
          redis = 6379
          pgsql = 5432
          stats = 9999
        }
        volumes = [
          "local/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg",
          "local/crt-list.txt:/usr/local/etc/haproxy/crt-list.txt",
          "local/fullchain.pem:/usr/local/etc/haproxy/fullchain.pem",
          "local/cbraker.txt:/usr/local/etc/haproxy/cbraker.txt",
        ]
      }

      template {
        destination = "local/haproxy.cfg"
        data = <<EOF
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    ## server-state-file /opt/haproxy/haproxy.state

    log         127.0.0.1 local2 info
    pidfile     /var/run/haproxy.pid
    maxconn     10000
    # chroot    /var/lib/haproxy
    # user      haproxy
    # group     haproxy
    # daemon
    # debug

    tune.ssl.default-dh-param 2048
    ssl-default-bind-options ssl-min-ver TLSv1.2
    ssl-default-bind-options ssl-max-ver TLSv1.3
    ssl-default-bind-ciphers AES128+EECDH:AES128+EDH


#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------

defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option                  http-keep-alive
    option                  http-server-close
    option                  tcp-smart-accept
    option                  tcp-smart-connect
    option                  redispatch
    option                  socket-stats
    retries                 3
    timeout http-request    10s
    timeout http-keep-alive 10s
    timeout connect         5s
    timeout client          50s
    timeout server          50s
    timeout check           10s
    timeout queue           3m
    maxconn                 2048

    ## load-server-state-from-file global

listen STATS
    bind ${NOMAD_IP_http}:9999
    mode http
    stats enable
    stats show-legends
    stats hide-version
    stats realm HAProxy\ Stats
    stats uri /
    stats refresh 120s
    no log


#---------------------------------------------------------------------
# main frontend which proxys to the backends
#---------------------------------------------------------------------

frontend FE_REDIS
  mode tcp
  option tcplog
  bind ${NOMAD_IP_http}:6379
  default_backend BE_REDIS

frontend FE_PGSQL
  mode tcp
  option tcplog
  bind ${NOMAD_IP_http}:5432
  default_backend BE_PGSQL

frontend FE_HTTP
  bind ${NOMAD_IP_http}:80
  option forwardfor except 127.0.0.0/8
  http-request set-header X-Client-IP req.hdr_ip([X-Forwarded-For])
  http-request add-header X-Forwarded-Proto http
    ## LetsEncrypt Certificates
    acl is_letsencrypt path_beg /.well-known/acme-challenge/
    use_backend BE_LE if is_letsencrypt
  default_backend BE_WEBFARM

frontend FE_HTTPS
  bind ${NOMAD_IP_http}:443 ssl crt-list /usr/local/etc/haproxy/crt-list.txt
  option forwardfor except 127.0.0.0/8
  http-request set-header X-Client-IP req.hdr_ip([X-Forwarded-For])
  http-request add-header X-Forwarded-Proto https
    ## Circuit Braker
    use_backend BE_CBRAKER if { ssl_fc_sni -f /usr/local/etc/haproxy/cbraker.txt }
  default_backend BE_WEBFARM


#---------------------------------------------------------------------
# backends
#---------------------------------------------------------------------

backend BE_LE
 server letsencrypt 127.0.0.1:8888

backend BE_CBRAKER
  redirect scheme https code 301 if !{ ssl_fc }
  server circuit-braker ${NOMAD_IP_http}:8080 check

backend BE_REDIS
  mode tcp
  timeout client 10800s
  timeout server 10800s
  balance leastconn
  option tcp-check
  server-template redis 1-3 _redis._tcp.service.consul resolvers consul resolve-opts allow-dup-ip resolve-prefer ipv4 check

backend BE_PGSQL
  mode tcp
  timeout client 10800s
  timeout server 10800s
  balance leastconn
  option tcp-check
  server-template pgsql 1-3 _pgsql._tcp.service.consul resolvers consul resolve-opts allow-dup-ip resolve-prefer ipv4 check

backend BE_WEBFARM
  redirect scheme https code 301 if !{ ssl_fc }
  balance roundrobin
  option httpchk HEAD /
  server-template web 1-6 _web._tcp.service.consul resolvers consul resolve-opts allow-dup-ip resolve-prefer ipv4 check

resolvers consul
  nameserver consul 127.0.0.1:8600
  accepted_payload_size 8192
  hold valid 5s

#---------------------------------------------------------------------
# end
#---------------------------------------------------------------------
        EOF
      }

      template {
        destination = "local/fullchain.pem"
        data = <<EOG
-----BEGIN CERTIFICATE-----
...
...
...
-----END CERTIFICATE-----
-----BEGIN RSA PRIVATE KEY-----
...
...
...
-----END RSA PRIVATE KEY-----
        EOG
      }

      template {
        destination = "local/crt-list.txt"
        data = <<EOH
/usr/local/etc/haproxy/fullchain.pem
        EOH
      }

      template {
        destination = "local/cbraker.txt"
        data = <<EOI

        EOI
      }

      resources {
        // Hardware limits in this cluster
        cpu = 1000
        memory = 1024
        network {
          mbits = 100
          port "http"  { static = 80 }
          port "https" { static = 443 }
          port "redis" { static = 6379 }
          port "pgsql" { static = 5432 }
          port "stats" { static = 9999 }
        }
      }

      service {
        // This is used to inform Consul a new service is available
        name = "haproxy"
        port = "stats"
        tags = [
          "haproxy",
          ]
        check {
          name = "alive"
          type = "http"
          path = "/"
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
