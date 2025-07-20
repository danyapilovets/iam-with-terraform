variable "aws_region" {
  description = "AWS region for banking infrastructure"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for banking system"
  type        = string
  default     = "banking"
}

variable "project_prefix" {
  description = "Short project prefix for resource naming"
  type        = string
  default     = "iwt"
}

variable "s3_bucket_force_destroy" {
  description = "Allow S3 bucket to be destroyed even if not empty"
  type        = bool
  default     = false
}

variable "s3_bucket_acl" {
  description = "ACL for the S3 bucket"
  type        = string
  default     = "private"
}

variable "random_suffix_length" {
  description = "Length of random suffix for unique resource names"
  type        = number
  default     = 6
}

variable "vpc_endpoint_private_dns_enabled" {
  description = "Enable Private DNS on S3 Interface VPC Endpoint"
  type        = bool
  default     = false
}

variable "vpc_endpoint_type" {
  description = "VPC endpoint type"
  type        = string
  default     = "Interface"
  validation {
    condition     = contains(["Interface", "Gateway"], var.vpc_endpoint_type)
    error_message = "VPC endpoint type must be either Interface or Gateway."
  }
}

variable "ec2_ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = ""
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ec2_public_subnet_id" {
  description = "Public subnet ID for EC2 deployment"
  type        = string
  default     = ""
}

variable "ec2_security_group_id" {
  description = "Security group ID for EC2"
  type        = string
  default     = ""
}
