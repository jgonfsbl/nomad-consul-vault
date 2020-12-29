
# Nomad + Consul + Vault
### Also including: LetsEncrypt + DNSmasq + HAProxy and/or Traefik + some other example jobs for typically networked services

The following *how-to guide* was created in order to simplify the creation of a laboratory composed of the follwing components:

Hardware:

- 3 x Raspberry Pi 4 Model B (4Gb RAM)
- 1 x Mikrotik CCS6010 switch (8 GEth & 2 SFP+)
- 1 x QNAP (NAS) server, for NFS exports

Principial Software:

- HashiCorp Nomad
- HashiCorp Consul
- HashiCrop Vault

Additional Software:

- LetsEncrypt
- Docker
- DNSmasq
- HAProxy
- Traefik
- NIGNX
- Redis
- PostgreSQL
- MariaDB
- Bitwarden
- ClouDNS Updater



## Changes to perfom on `/etc/hosts`

In order to simplify refer to hosts, in the machine hosts file you should add something like the below snippet. DON'T TRUST DNS!

```
192.168.0.21  node1
192.168.0.22  node2
192.168.0.23  node3
```


## Changes to perfom on `/boot/config.txt`

__This change is specific for Raspberry Pi systems running Raspbian (Buster)__

```
[all]
# dtoverlay=vc4-fkms-v3d
start_x=0
enable_uart=1
dtoverlay=w1-gpio
dtoverlay=disable-wifi
dtoverlay=disable-bt
```


## Changes to perfom on `/etc/fstab`
Following changes are oriented to minimize the ammount of system I/O over disk. This is specially important on ebbeded systems or systems like Raspberry Pi, where disk degradation can force system unavailability.

Following same ratonale, the idea is to persist data over a NFS volume. In the case below, a QNAP system was exporting NFS v3 shares being mounted by the operating system at boot time.

The following text snippet needs to be added at the bottom of a reciently installed linux operating system:

```
# Added in order to enlarge TF Card life
# ---------------------------------------------------------------------------------------------
  tmpfs /tmp                            tmpfs defaults,noatime,nosuid,size=100m           0 0
  tmpfs /var/tmp                        tmpfs defaults,noatime,nosuid,size=100m           0 0
  tmpfs /var/lib/sudo                   tmpfs defaults,noatime,nosuid,mode=0755,size=2m   0 0
  tmpfs /var/log                        tmpfs defaults,noatime,nosuid,mode=0755,size=100m 0 0
  tmpfs /var/spool/mqueue               tmpfs defaults,noatime,nosuid,mode=0700,size=30m  0 0
  tmpfs /var/named/chroot/var/run/named tmpfs defaults,noatime,nosuid,mode=0770,size=2m   0 0

# NFS QNAP
192.168.xxx.yyy:/NFSroot/nomad /opt/NFS nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0
```

## Changes to perfom on `/etc/apt`
As a part of the installation process, podman and other OCI related container image supports is goint to be activated in Nomad. With that purpose, Nomad requires extra packages in addition to those provided by Raspbian install. Steps follows:

```
# Support for OCI, Podman and other container related tools/libraries
echo 'deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/Raspbian_10/ /' | sudo tee /etc/apt/sources.list.d/devel_kubic_libcontainers_stable.list
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/Raspbian_10/Release.key | sudo apt-key add -
sudo apt update -qq
```



# Generic Docker installation
```
curl -fsSL https://get.docker.com | sh
```



# Manual `docker-compose` installation
```
apt install -y libffi-dev libssl-dev python3-dev python3 python3-pip python3-paramiko

pip3 install docker-compose
```



# Installation of `DNSmasq` package
Install the package:
```
apt install dnsmasq -y
cd /etc
cp -p dnsmasq.conf dnsmasq.conf.original
```

Ensure this is part of your configuration file in `/etc/dnsmasq.conf`:
```  
# Configuration file for dnsmasq.

# port=5353
bind-interfaces

domain-needed
bogus-priv
# no-resolv
# no-poll

server=/consul/127.0.0.1#8600

cache-size=1000
conf-dir=/etc/dnsmasq.d/,*.conf
``` 

Ensure `DNSmasq` is an enabled service with the following command:
```  
systemctl list-unit-files | grep enabled
```  

Finally, restart the `DNSmasq` service for changes to take effect:
```  
service dnsmasq restart
``` 



# HashiCorp NOMAD installation
*Please note, URL shown below is for ARM-based systems*

## Nomad installation
Follow this steps:

```
wget https://releases.hashicorp.com/nomad/1.0.0/nomad_1.0.0_linux_arm.zip
unzip nomad_1.0.0_linux_arm.zip
mv nomad /usr/local/bin
mkdir /etc/nomad.d
mkdir /var/lib/nomad/
```


## Nomad configuration
Once completed, the configuration files must be provided, nomad can adopt two types of roles, server or simply node. When you configure Nomad as server that node can be responsible for scheduling jobs, something necessary. So, at least some of your Nomad nodes need to be of type "server". 

The configuration of a Nomad node can be easily divided into pieces for better understanding:  

- base.hcl, the basic configuration options
- server.hcl, to configure a node as a server (which is responsible for scheduling)
- client.hcl, to configure a node as a client (which is responsible for running workloads)

Place one of these under `/etc/nomad.d` depending on the node's role.


### /etc/systemd/system/nomad.service
Then, the init script for SystemD needs to be installed. An example follows. The file must be placed in the path `/etc/systemd/system/nomad.service`

```
[Unit]
Description="HashiCorp Nomad"
Documentation=https://nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

# When using Nomad with Consul it is not necessary to start Consul first. These
# lines start Consul before Nomad as an optimization to avoid Nomad logging
# that Consul is unavailable at startup.
Wants=consul.service
After=consul.service

[Service]
Type=simple
# User=nomad
# Group=nomad
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
KillMode=process
KillSignal=SIGINT
LimitNOFILE=65536
LimitNPROC=infinity
RestartSec=2
StartLimitBurst=3
StartLimitIntervalSec=10
TasksMax=infinity
OOMScoreAdjust=-1000

[Install]
WantedBy=multi-user.target
```

Then, some folders needs to be created on local mount. This directory structure needs to reflect following directory tree:

```
root@node1:/opt/nomad# tree ./
./
├── data
│   └── plugins
└── jobs
```

Finally, the configuration files, as follows:

### /etc/nomad.d/base.hcl
```
name = "NODE1"
region = "global"
datacenter = "LAB"

data_dir = "/opt/nomad/data"

log_level = "INFO"
enable_syslog = true

advertise {
  http = "192.168.0.21"
   rpc = "192.168.0.21"
  serf = "192.168.0.21"
}

acl {
  enabled = false
  token_ttl = "30s"
  policy_ttl = "60s"
}

consul {
  # The address to the Consul agent.
  address = "127.0.0.1:8500"

  # The service name to register the server and client with Consul.
  server_service_name = "nomad-servers"
  client_service_name = "nomad-clients"

  # Enables automatically registering the services.
  auto_advertise = true

  # Enabling the server and client to bootstrap using Consul.
  server_auto_join = true
  client_auto_join = true
}

# telemetry {
#  publish_allocation_metrics = true
#  publish_node_metrics       = true
#  prometheus_metrics         = true
# }
```

### /etc/nomad.d/client.hcl
```
client {
  enabled = true
  host_volume "qnap-nfs" {
    path = "/opt/NFS"
    read_only = false
  }
  server_join {
    retry_join = [ "192.168.0.22", "192.168.0.23" ]
    retry_max = 3
    retry_interval = "15s"
  }  
  meta {
  }
}

plugin "docker" {
  config {
    allow_caps = [ "ALL" ]
    volumes {
      enabled = true
    }
  }
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}
```

### /etc/nomad.d/server.hcl
```
server {
  enabled = true
  raft_protocol = 3
  bootstrap_expect = 3
}
```

To test the configuration above, run __`nomad agent -config=/etc/nomad.d`__.

If everything works properly, then, enable the service system-wide using command __`systemctl enable nomad.service`__ or __`nomad server members`__ or __`nomad node status`__.


# HashiCorp CONSUL installation
*Please note, URL shown below is for ARM-based systems*

## Consul installation
Follow this steps:

```
wget wget https://releases.hashicorp.com/consul/1.9.0/consul_1.9.0_linux_armhfv6.zip
unzip consul_1.9.0_linux_armhfv6.zip
mv consul /usr/local/bin
```

## Consul configuration
### /etc/systemd/system/consul.service
Once performed the above steps, then, the init script for SystemD needs to be installed. An example follows. The file must be placed in the path `/etc/systemd/system/consul.service`:

```
[Unit]
Description="HashiCorp Consul"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.targes
ConditionFileNotEmpty=/etc/consul.d/config.jsoc

[Service]
Type=simple
# User=consul
# Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/local/bin/consul reload
Restart=on-failure
KillMode=process
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

Then, some folders needs to be created on a shared folder, i.e. on a NFS mount. This directory structure needs to reflect following directory tree:

```
root@node1:/opt/consul# tree ./
./
└── data
```

Finally, The configuration files, as follows:


### /etc/consul.d/config.json
*Note 1: remove the line of __bootstrap_expect__ and change __server__ to false when configuring a consul client-only node*

*Note 2: encryuption key must be generated as explained in [the official Consul documentation](https://www.consul.io/docs/security/encryption)*

```
{
    "server": true,
    "bootstrap_expect": 3,

    "acl_default_policy": "allow",

    "addresses": {
        "dns": "0.0.0.0",
        "grpc": "0.0.0.0",
        "http": "0.0.0.0",
        "https": "0.0.0.0"
    },

    "advertise_addr": "192.168.0.21",
    "advertise_addr_wan": "192.168.0.21",
    "bind_addr": "192.168.0.21",
    "client_addr": "0.0.0.0",

    "connect": {
        "enabled": true
    },

    "data_dir": "/opt/consul/data",
    "datacenter": "LAB",
    "disable_update_check": false,
    "domain": "consul",

    "enable_script_checks": false,
    "enable_syslog": true,
    "encrypt": "32bytes_base64_encoded_encryption_key",

    "log_level": "INFO",
    "node_name": "NODE1",

    "performance": {
        "leave_drain_time": "5s",
        "raft_multiplier": 1,
        "rpc_hold_timeout": "7s"
    },

    "ports": {
        "dns": 8600,
        "http": 8500,
        "server": 8300
    },

    "raft_protocol": 3,
    "retry_interval": "30s",
    "retry_interval_wan": "30s",
    "retry_join": [
        "192.168.0.22",
        "192.168.0.23"
    ],
    "retry_max": 0,
    "retry_max_wan": 0,

    "syslog_facility": "local0",

    "telemetry": {
        "disable_compat_1.9": true
    },

    "ui_config": {
        "enabled": true
    }
}
```

To test the configuration above, run __`consul agent -config-dir=/etc/consul.d`__.

If everything works properly, then, enable the service system-wide using command __`systemctl enable consul.service`__ and/or __`consul members`__.



# HashiCorp VAULT installation
*Please note, URL is for ARM-based systems*

## Vault installation
Follow this steps:

```
wget https://releases.hashicorp.com/vault/1.6.0/vault_1.6.0_linux_arm.zip
unzip vault_1.6.0_linux_arm.zip
mv vault /usr/local/bin
mkdir /etc/vault.d
```


## Vault configuration
### /etc/vault.d/server.config
The configuration file for a basic Vault implementation with Consul backed:

```
# disable_cache = true
# disable_mlock = true

ui = true

# Advertise the non-loopback interface
api_addr = "http://192.168.0.21:8200"
cluster_addr = "http://192.168.0.21:8201"

backend "consul" {
  address = "127.0.0.1:8500"
  path = "vault/"
  scheme = "http"
  tls_disable = 1
}

listener "tcp" {
  address = "192.168.0.21:8200"
  cluster_address = "192.168.0.21:8201"
  tls_disable = 1
}

listener "tcp" {
  address = "127.0.0.1:8200"
  cluster_address = "127.0.0.1:8201"
  tls_disable = 1
}

# telemetry {
#   prometheus_retention_time = "30s"
#   statsite_address = "127.0.0.1:8125"
#   disable_hostname = true
# }

```


### /etc/systemd/system/vault.service
Then, the init script for SystemD needs to be installed. An example follows. The file must be placed in the path `/etc/systemd/system/vault.service`

```
[Unit]
Description="HashiCorp Vault"
Documentation=http://www.vaultproject.io
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
# User=vault
# Group=vault
ExecStart=/usr/local/bin/vault server -config /etc/vault.d/server.config
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
```

> **Note**: By default, Vault tries to use HTTPS scheme in API communication. In order to override this behavior you
> need to export an environment variable. You can do this in the console and it will take action in the same moment,
> but, it's better to export the environment variable from .bashrc or .profile. An example follows:
>
> File: ~/.bashrc:
> export VAULT_ADDR='http://127.0.0.1:8200'


If everything works properly, then, enable the service system-wide using command __`systemctl enable vault.service`__ and/or __`vault status`__.

## Vault unseal
When Vault is first installed it comes sealed, which essentially means, it cannot be used. Vault needs to be unsealed to allow secrets to be created.

>__NOTE:__ IN ORDER TO SIMPLIFY UNSEAL PROCEDURE, GO TO THE VAULT WEB USER INTERFACE AND FOLLOW STEPS INDICATED. 

Once Vault is unsealed you will receive one or more keys and a root token. You must keep this information in a safe place. Later, every time Vault gets restarted Vault will initialize again in sealed mode, so, you will need to unseal Vault again. If you want to automate this step you will require something like the following script.


### /etc/vault.d/unseal_vault.sh
```
#!/bin/bash

# Assumptions: vault is already initialized. Please, confirm this step!!

# Node setup
$NODE=node1

# Fetching first three keys to unseal the vault
KEY_1=base64_1st-third-encryption-key-comes-here
KEY_2=base64_2nd-third-encryption-key-comes-here
KEY_3=base64_3rd-third-encryption-key-comes-here

# Unseal using first key
curl --silent -X PUT \
  http://$NODE:8200/v1/sys/unseal \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -d '{ "key": "'$KEY_1'" }'

# Unseal using second key
curl --silent -X PUT \
  http://$NODE:8200/v1/sys/unseal \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -d '{ "key": "'$KEY_2'" }'

# Unseal using third key
curl --silent  -X PUT \
  http://$NODE:8200/v1/sys/unseal \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -d '{ "key": "'$KEY_3'" }'
```

Above script can be ussed, for example, from an Ansible playbook to perform configuration management over the Vault server/service.



# LetsEncrypt wildcard certificate creations
Once the triad Nomad/Consul/Vault is installed it's time to start securing the workloads while some services get operational for the first time. This is the time for LetsEncrypt.   

When you schedule a lot of workloads, specially in the form of containers, you can issue certificates per workload/domain name upon need, as Traefik does. Alternatively, you can also issue a wildcard certificate that can be used more widely without the burder of its often emission, renew and scheduling, as HAPRoxy does. That's going to be the approach shown here, below. 

LetEncrypt offers different challenge types (http-01, tls-sni-01, tls-alpn-01 and dns-01) as well as a wide range of clients. All of the challenges work similar with the only exception that only dns-01 works in order to get a wildcard certificate. So, in this scenario, the idea is to leverage as much as possible the docker capabilities by scheduling a container that can obtain a wildcard certificate for an entire domain on a simple manner. And that simple manner is leveraging DNS records, and more appropiately, TXT records. 

LetEncrypt also counts with a wide range of clients for all type of operating systems, programming languages, software and tools. In this case we'll use a container based on LEGO, Let’s Encrypt client and ACME library written in Go. LEGO offers a container (https://hub.docker.com/r/goacme/lego and https://github.com/go-acme/lego) that if used intelligently can greatly simplify the painful process of certificate issuance. 

Following is the essential part of the nomad job that will run the LEGO container in charge of obtaining and renewing quarterly a wildcard certificate: 

```  
docker run \
  -e CLOUDNS_AUTH_ID="nnnn" \
  -e CLOUDNS_AUTH_PASSWORD="TextStringActingAsToken" \
  -v /opt/goacme-lego/certs:/certs \
  goacme/lego \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --dns cloudns --accept-tos --email user@email.tld \
    --pem --path /certs \
    --dns.resolvers pns31.cloudns.net \
    --domains "*.dommain.tld" \
    run
```  

In the example above you can realize there are two environment variables mentioning CLouDNS. This is the DNS provider used in this scenario but LEGO offers a wide range of providers, as you can see in https://go-acme.github.io/lego/dns/. 


# HashiCorp TERRAFORM installation
*Please note, URL is for ARM-based systems*

```
wget https://releases.hashicorp.com/terraform/0.13.5/terraform_0.13.5_linux_arm.zip
unzip terraform_0.13.5_linux_arm.zip
mv terraform /usr/local/bin
```

# High Availability with `keepalived` 

Keepalived is a package that implements VRRP protocol versions 2 and 3. In essence, this is Master-Slaves / Primary-Secondaries implementation for a network high availability solution. 

- Package installation
```
apt install keepalived
```


- Configuration files for master/primary node on `/etc/keepalived/keepalived.conf`:
``` 
vrrp_instance VI_RPI {
    state MASTER
    interface eth0
    virtual_router_id 100
    priority 200
    advert_int 1
    
    authentication {
        auth_type AH
        auth_pass k33p@l!ved
    }
    
    use_vmac
    unicast_src_ip 192.168.0.21
    virtual_ipaddress {
        192.168.0.20 dev eth0 label eth0:vip
    }
    unicast_peer {
        192.168.0.22
        192.168.0.23
    }
}
```

- Configuration files for slaves/secondary nodes on `/etc/keepalived/keepalived.conf`:
``` 
vrrp_instance VI_RPI {
    state BACKUP
    interface eth0
    virtual_router_id 100
    priority 150
    advert_int 1
    
    authentication {
        auth_type AH
        auth_pass k33p@l!ved
    }
    
    use_vmac
    unicast_src_ip 192.168.0.22
    virtual_ipaddress {
        192.168.0.20 dev eth0 label eth0:vip
    }
    unicast_peer {
        192.168.0.21
        192.168.0.23
    }
}
```

... and ...

``` 
vrrp_instance VI_RPI {
    state BACKUP
    interface eth0
    virtual_router_id 100
    priority 100
    advert_int 1
    
    authentication {
        auth_type AH
        auth_pass k33p@l!ved
    }
    
    use_vmac
    unicast_src_ip 192.168.0.23
    virtual_ipaddress {
        192.168.0.20 dev eth0 label eth0:vip
    }
    unicast_peer {
        192.168.0.21
        192.168.0.22
    }
}
```




- Edit /etc/sysctl.conf and add at the bottom of the file the following lines:

    ```
    # Bind nonlocal IPs to real interfaces
    net.ipv4.ip_nonlocal_bind = 1
    ```

- Edit /etc/rc.local, and add before `exit 0` this line
  ```
  service procps reload
  ```
- Reboot


# Remove IPv6 support from network stack

- Edit /etc/sysctl.conf and add at the bottom of the file the following lines:

    ```
    # DISABLE IPv6
    net.ipv6.conf.all.disable_ipv6=1
    net.ipv6.conf.default.disable_ipv6=1
    net.ipv6.conf.lo.disable_ipv6=1
    net.ipv6.conf.eth0.disable_ipv6 = 1
    ```

- Edit /etc/rc.local, and add before `exit 0` this line **OR** ensure it was already added and continue to the final step power recycling the system.
  ```
  service procps reload
  ```
- Reboot



# Stop unnecessary system services

- List services

  ```
  systemctl list-unit-files | grep enabled
  ```

- Stop services unwanted (they are kept in /lib/systemd/system/*.service)

  ```
  systemctl disable [servicename].service
  ```

- Disabled services

  ```
  systemctl disable avahi-daemon
  systemctl disable triggerhappy
  systemctl disable dbus-fi.w1.wpa_supplicant1.service
  systemctl disable wpa_supplicant.service
  systemctl disable bluetooth.service
  ```


# Remove sound support
__This change is specific for Raspberry Pi systems running Raspbian (Buster)__

- Add `blacklist snd_bcm2835` in `/etc/modprobe.d/alsa-blacklist.conf` and finally reboot


# Disable Wi-Fi and Bluetooth kernel modules at boot time

- Add this lines to /etc/modprobe.d/blacklist-wifibluez.conf

  ```
  ## WiFi
  blacklist brcmfmac
  blacklist brcmutil

  ## Bluetooth
  blacklist btbcm
  blacklist hci_uart
  ```


