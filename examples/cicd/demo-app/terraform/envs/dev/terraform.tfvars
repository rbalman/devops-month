# dev sizing + domain. Point these at YOUR hosted zone.
region            = "us-east-1"
environment       = "dev"
azs               = ["us-east-1a", "us-east-1b"]
app_instance_type = "t3.small"
db_instance_type  = "t3.small"
key_name          = "CHANGEME-keypair" # an existing EC2 key pair for SSH

# The zone must already exist in Route53; app_domain is a record inside it.
hosted_zone_name = "example.com"         # CHANGEME — your hosted zone
app_domain       = "app.dev.example.com" # CHANGEME — served over HTTPS
