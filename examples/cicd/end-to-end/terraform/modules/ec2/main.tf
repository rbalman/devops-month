# A group of identical instances (app x2 or db x1). No public IP, no key pair —
# management is entirely over SSM Session Manager, so the instances stay private.
# user_data just makes sure the SSM agent is running on the Ubuntu AMI.

resource "aws_instance" "this" {
  count                       = var.instance_count
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = false

  # Enforce IMDSv2.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    # Ubuntu ships the SSM agent as a snap; make sure it's installed + running
    # so Ansible can reach this host over SSM (no SSH).
    snap install amazon-ssm-agent --classic || true
    snap start amazon-ssm-agent || systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true
  EOF

  tags = merge(var.tags, {
    Name = "${var.name}-${count.index}"
    Role = var.role
  })
}
