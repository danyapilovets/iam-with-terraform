variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for EC2"
  type        = string
}

variable "sg_id" {
  description = "Security group ID for EC2"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, stage, prod)"
  type        = string
  default     = "dev"
}

variable "project_prefix" {
  description = "Short project prefix to be used in names"
  type        = string
  default     = "iwt"
}

variable "private_dns_enabled" {
  description = "Whether to enable Private DNS on the S3 Interface VPCE"
  type        = bool
  default     = false
} 

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "endpoint_type" {
  description = "VPC endpoint type (Interface or Gateway)"
  type        = string
  default     = "Interface"
}

variable "bucket_force_destroy" {
  description = "Allow S3 bucket to be destroyed even if not empty"
  type        = bool
  default     = false
}

variable "bucket_acl" {
  description = "ACL for the S3 bucket"
  type        = string
  default     = "private"
}

variable "suffix_length" {
  description = "Length of random suffix appended to bucket names"
  type        = number
  default     = 6
}
