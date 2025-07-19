variable "name" {
  type        = string
  description = "Name of the IAM role"
}

variable "assume_role_policy_json" {
  type        = string
  description = "Assume role policy JSON document"
}

variable "path" {
  type        = string
  description = "Path for the role"
  default     = "/"
}

variable "description" {
  type        = string
  description = "Role description"
  default     = "Managed by Terraform"
}

variable "inline_policies" {
  type        = map(string)
  description = "Map of inline policy documents keyed by policy name"
  default     = {}
}

variable "managed_policy_arns" {
  type        = list(string)
  description = "List of managed policy ARNs to attach"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the role"
  default     = {}
}
