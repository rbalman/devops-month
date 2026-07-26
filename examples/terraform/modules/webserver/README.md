# `webserver` module

A tiny, reusable Terraform module that creates **one EC2 instance and its security group** (SSH + HTTP). It's intentionally simple — a first module to show how one definition gets reused across projects.

## Usage

```hcl
module "web" {
  source = "../modules/webserver"

  name          = "project-one-web"
  ami_id        = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  # allowed_ssh_cidrs = ["203.0.113.10/32"]   # optional; defaults to 0.0.0.0/0
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — (required) | Name for the instance and its security group |
| `ami_id` | `string` | — (required) | AMI to launch |
| `instance_type` | `string` | `"t3.micro"` | EC2 instance size |
| `allowed_ssh_cidrs` | `list(string)` | `["0.0.0.0/0"]` | CIDRs allowed to SSH in |

## Outputs

| Name | Description |
|---|---|
| `instance_id` | ID of the EC2 instance |
| `public_ip` | Public IP of the instance |
| `security_group_id` | ID of the security group |

See [`../../project-one`](../../project-one) and [`../../project-two`](../../project-two) for two root modules that reuse this one with different variables.

> ⚠️ **Cost:** launching an EC2 instance is billable (a `t3.micro` may fall under the free tier). `terraform destroy` when done.
