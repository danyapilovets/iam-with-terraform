variable "vpc_id" { type = string }
variable "service_name" { type = string }
variable "endpoint_type" {
  type    = string
  default = "Interface"
}

variable "subnet_ids" {
  type    = list(string)
  default = []
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "private_dns_enabled" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
