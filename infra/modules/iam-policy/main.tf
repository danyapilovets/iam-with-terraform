terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

resource "aws_iam_policy" "this" {
  name        = var.name
  description = var.description
  path        = var.path
  policy      = var.policy_json
}
