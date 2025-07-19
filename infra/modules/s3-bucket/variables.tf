variable "bucket_name" {
  type        = string
  description = "Name of the bucket"
}

variable "force_destroy" {
  type        = bool
  description = "Force destroy bucket even if non-empty"
  default     = false
}

variable "acl" {
  type        = string
  description = "Canned ACL for bucket"
  default     = "private"
}

variable "policy_json" {
  type        = string
  description = "Optional bucket policy JSON"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to bucket"
  default     = {}
}
