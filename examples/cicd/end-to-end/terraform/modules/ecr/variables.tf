variable "name" {
  description = "Name prefix (e.g. end-to-end-dev); repos become <name>-backend / -frontend."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
