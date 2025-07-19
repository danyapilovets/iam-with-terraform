terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = var.assume_role_policy_json
  path               = var.path
  description        = var.description
  tags               = var.tags
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies
  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}

resource "aws_iam_role_policy_attachment" "managed" {
  count      = length(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = var.managed_policy_arns[count.index]
}
