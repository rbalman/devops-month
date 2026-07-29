variable "name" {
  description = "Name prefix (e.g. demo-app-dev); repos become <name>-backend / -frontend."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
