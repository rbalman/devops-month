variable "region" {
  type    = string
  default = "us-east-1"
}

variable "prefix" {
  type        = string
  description = "Prefix for bucket names. Bucket names are global, so make this unique (add your initials)."
  default     = "golive"
}

variable "bucket_count" {
  type        = number
  description = "How many numbered buckets to create with count."
  default     = 3
}

variable "buckets" {
  type        = map(string)
  description = "Named buckets to create with for_each (key = purpose, value = name suffix)."
  default = {
    logs    = "logs"
    backups = "backups"
  }
}
