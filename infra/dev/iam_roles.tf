# IAM role, policies and instance profile for EC2

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# CloudWatch logs policy for EC2
data "aws_iam_policy_document" "ec2_logs" {
  statement {
    effect    = "Allow"
    actions   = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

module "policy_ec2_logs" {
  source      = "../modules/iam-policy"
  name        = "${local.name_prefix}-ec2-logs"
  policy_json = data.aws_iam_policy_document.ec2_logs.json
}

module "role_ec2" {
  source                  = "../modules/iam-role"
  name                    = "${local.name_prefix}-role"
  assume_role_policy_json = data.aws_iam_policy_document.ec2_assume.json
  managed_policy_arns     = [module.policy_ec2_logs.policy_arn]
  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "${local.name_prefix}-"
  role        = module.role_ec2.role_name
}
