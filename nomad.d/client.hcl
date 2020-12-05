client {
  enabled = true
  host_volume "qnap-nfs" {
    path = "/opt/NFS"
    read_only = false
  }
  meta {
  }
}

plugin "docker" {
  config {
    allow_caps = [ "ALL" ]
  }
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

