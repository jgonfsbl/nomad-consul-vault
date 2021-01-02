//
// Jonathan Gonzalez
// j@0x30.io
// https://github.com/EA1HET
//
// ** HAPROXY **
//


job "haproxy" {

  meta {
    description   = "HAProxy Load Balancer and Reverse Proxy"
    nomad_version = "1.0.1"
    job_version   = "1.0"
    job_date      = "2021-01-01"
    team          = "devops"
    org           = "ea1het"
  }

  region = "global"
  datacenters = ["LAB"]
  type = "system"

  group "gateway" {
    count = 1

    network {
      mode = "host"
      port "http"    { static = 80   }
      port "https"   { static = 443  }
      port "mariadb" { static = 3306 }
      port "pgsql"   { static = 5432 }
      port "redis"   { static = 6379 }
      port "stats"   { static = 9999 }
    }

    // reschedule stanza would be here if type is not system

    task "haproxy" {
      driver = "docker"

      config {
        image = "haproxy:2.3.2-alpine"
        hostname = "mariadb"
        network_mode = "host"
        ports = ["http", "https", "mariadb", "pgsql", "redis", "stats"]
        volumes = [
          "local/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg",
          "local/crt-list.txt:/usr/local/etc/haproxy/crt-list.txt",
          "secrets/fullchain.pem:/usr/local/etc/haproxy/fullchain.pem",
        ]
      }

      env {
        PYTHONUNBUFFERED=0
        TZ="Europe/Madrid"
      }

      // template stanza starts here

      template {
        destination = "local/haproxy.cfg"
        data = <<EOF
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    log         127.0.0.1 local2 info
    pidfile     /var/run/haproxy.pid
    maxconn     10000

    tune.ssl.default-dh-param 2048
    ssl-default-bind-options ssl-min-ver TLSv1.2
    ssl-default-bind-options ssl-max-ver TLSv1.3
    ssl-default-bind-ciphers AES128+EECDH:AES128+EDH

    ## server-state-file /opt/haproxy/haproxy.state


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
    bind ${NOMAD_IP_stats}:${NOMAD_PORT_stats}
    mode http
    stats enable
    stats show-legends
    stats hide-version
    stats realm HAProxy\ Stats
    stats uri /
    stats refresh 60s
    no log


#---------------------------------------------------------------------
# main frontend which proxys to the backends
#---------------------------------------------------------------------

frontend FE_MARIADB
  mode tcp
  option tcplog
  bind ${NOMAD_IP_mariadb}:3306
  default_backend BE_MARIADB

frontend FE_PGSQL
  mode tcp
  option tcplog
  bind ${NOMAD_IP_pgsql}:5432
  default_backend BE_PGSQL

frontend FE_REDIS
  mode tcp
  option tcplog
  bind ${NOMAD_IP_redis}:6379
  default_backend BE_REDIS

frontend FE_HTTP
  bind ${NOMAD_IP_http}:80
  option forwardfor except 127.0.0.0/8
  http-request set-header X-Client-IP req.hdr_ip([X-Forwarded-For])
  http-request add-header X-Forwarded-Proto http
  default_backend BE_HYPRIOT

frontend FE_HTTPS
  bind ${NOMAD_IP_https}:443 ssl crt /usr/local/etc/haproxy/fullchain.pem
  option forwardfor except 127.0.0.0/8
  http-request set-header X-Client-IP req.hdr_ip([X-Forwarded-For])
  http-request add-header X-Forwarded-Proto https
    ## Bitwarden
    use_backend BE_BITWARDEN if { ssl_fc_sni bw.0x30.io }
    ## Echo Service
    use_backend BE_ECHO if { ssl_fc_sni echo.0x30.io }
  default_backend BE_HYPRIOT


#---------------------------------------------------------------------
# backends
#---------------------------------------------------------------------

backend BE_MARIADB
  mode tcp
  timeout client 10800s
  timeout server 10800s
  balance leastconn
  option tcp-check
  server-template mariadb 1-2 _mariadb._tcp.service.consul resolvers consul resolve-opts allow-dup-ip resolve-prefer ipv4 check

backend BE_PGSQL
  mode tcp
  timeout client 10800s
  timeout server 10800s
  balance leastconn
  option tcp-check
  server-template pgsql 1-2 _pgsql._tcp.service.consul resolvers consul resolve-opts allow-dup-ip resolve-prefer ipv4 check

backend BE_REDIS
  mode tcp
  timeout client 10800s
  timeout server 10800s
  balance leastconn
  option tcp-check
  server-template redis 1-3 _redis._tcp.service.consul resolvers consul resolve-opts allow-dup-ip resolve-prefer ipv4 check

backend BE_BITWARDEN
  redirect scheme https code 301 if !{ ssl_fc }
  balance roundrobin
  option httpchk HEAD /
  server-template bitwarden 1-2 _bitwarden._tcp.service.consul resolvers consul resolve-opts allow-dup-ip resolve-prefer ipv4 check

backend BE_ECHO
  redirect scheme https code 301 if !{ ssl_fc }
  balance roundrobin
  option httpchk HEAD /
  server-template echo 3 _echo._tcp.service.consul resolvers consul resolve-opts allow-dup-ip resolve-prefer ipv4 check

backend BE_HYPRIOT
  redirect scheme https code 301 if !{ ssl_fc }
  balance roundrobin
  option httpchk HEAD /
  server-template hypriot 3 _hypriot._tcp.service.consul resolvers consul resolve-opts allow-dup-ip resolve-prefer ipv4 check

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
        destination = "secrets/fullchain.pem"
        data = <<EOG
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
-----BEGIN EC PRIVATE KEY-----
...
-----END EC PRIVATE KEY-----
        EOG
      }

      // template stanza ends here

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
        name = "haproxy"
        port = "stats"
        tags = ["haproxy", "gw", "lb", "rp"]
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

