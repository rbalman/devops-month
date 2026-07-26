# count → reference the whole set with the [*] splat
output "numbered_buckets" {
  value = aws_s3_bucket.numbered[*].id
}

# for_each → reference as a map with a for expression
output "named_buckets" {
  value = { for k, b in aws_s3_bucket.named : k => b.id }
}
