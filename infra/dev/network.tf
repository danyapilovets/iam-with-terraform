data "aws_subnet" "public" {
  id = var.ec2_public_subnet_id
}

module "vpce_s3" {
  source               = "../modules/vpc-endpoint"
  vpc_id               = data.aws_subnet.public.vpc_id
  service_name         = "com.amazonaws.${var.aws_region}.s3"
  endpoint_type        = "Interface"
  subnet_ids           = [var.ec2_public_subnet_id]
  security_group_ids   = [var.ec2_security_group_id]
  private_dns_enabled  = var.vpc_endpoint_private_dns_enabled
  tags = {
    Environment = var.environment
    Type       = "Interface"
    Service    = "S3"
  }
}

module "vpce_secrets_manager" {
  source               = "../modules/vpc-endpoint"
  vpc_id               = data.aws_subnet.public.vpc_id
  service_name         = "com.amazonaws.${var.aws_region}.secretsmanager"
  endpoint_type        = "Interface"
  subnet_ids           = [var.ec2_public_subnet_id]
  security_group_ids   = [var.ec2_security_group_id]
  private_dns_enabled  = false
  tags = {
    Environment = var.environment
    Type       = "Interface"
    Service    = "SecretsManager"
    Purpose    = "ExternalSecretsOperator"
  }
}

resource "aws_security_group" "vpce_sg" {
  name_prefix = "${local.name_prefix}-vpce-"
  vpc_id      = data.aws_subnet.public.vpc_id
  description = "Security group for VPC Interface Endpoints"
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    description = "HTTPS from VPC resources"
  }
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS TCP queries"
  }
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS UDP queries"
  }
  tags = {
    Environment = var.environment
    Purpose     = "VPCEndpoints"
  }
}

data "aws_vpc" "main" {
  id = data.aws_subnet.public.vpc_id
}
