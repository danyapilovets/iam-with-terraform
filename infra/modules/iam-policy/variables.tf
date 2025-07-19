variable "name" {
  description = "Name of the IAM policy"
  type        = string
}

variable "description" {
  description = "Policy description"
  type        = string
  default     = "Managed by Terraform"
}

variable "path" {
  description = "Path for the policy"
  type        = string
  default     = "/"
}

variable "policy_json" {
  description = "The IAM policy document (JSON)"
  type        = string
}
