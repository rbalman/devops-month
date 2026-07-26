# `loops` — S3 buckets with loops (Day 21, Example 2)

A dedicated example of creating S3 buckets two ways: with `count` and with `for_each`.

| Pattern | Resource | Reference in outputs |
|---|---|---|
| `count` + index | `aws_s3_bucket.numbered` (N numbered buckets) | `aws_s3_bucket.numbered[*].id` |
| `for_each` + map | `aws_s3_bucket.named` (one per entry) | `{ for k, b in ... : k => b.id }` |

## Run it

```bash
terraform init
terraform fmt && terraform validate
terraform apply -var "prefix=golive-<your-initials>"   # bucket names are global
terraform output

terraform destroy -var "prefix=golive-<your-initials>"
```

> ⚠️ **Bucket names are globally unique** — pass a unique `prefix` or `apply` will fail with *BucketAlreadyExists*.
