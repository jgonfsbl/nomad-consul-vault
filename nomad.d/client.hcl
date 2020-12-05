client {
  enabled = true
  meta {
  }
}

plugin "docker" {
  config {
    allow_caps = [ "ALL" ]
  }
}
